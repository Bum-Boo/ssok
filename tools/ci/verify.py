#!/usr/bin/env python3
"""Run the full ssok suite with isolated user data, mock HTTP and retained results."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import secrets
import signal
import subprocess
import sys
import tempfile
import threading
import time
import xml.etree.ElementTree as ET

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT))
from tools.ci.install_godot import BUILD


@dataclass
class Check:
    name: str
    command: list[str]
    timeout: int = 300


def checks(godot: str, python: str) -> list[Check]:
    base = [godot, "--headless", "--path", str(PROJECT), "--language", "en", "--fixed-fps", "60"]
    result = [Check("import", [godot, "--headless", "--path", str(PROJECT), "--editor", "--import", "--quit"], 300),
              Check("scene-load", base + ["--quit-after", "5"], 60)]
    variants = {
        "humanoid_motion_check": [["walk"], ["backward"], ["pick"], ["run"], ["walk", "--reverse-links"]],
        "modular_humanoid_check": [["walk"], ["pick"], ["pick", "--reverse-links"]],
        "humanoid_ui_check": [[], ["--modular"]],
    }
    for path in sorted((PROJECT / "tests").glob("*_check.gd")):
        for arguments in variants.get(path.stem, [[]]):
            suffix = "-" + "-".join(a.removeprefix("--") for a in arguments) if arguments else ""
            command = base + ["--script", str(path)] + (["--", *arguments] if arguments else [])
            result.append(Check(path.stem + suffix, command))
    python_files = set((PROJECT / "tests").glob("test_*.py"))
    python_files.update((PROJECT / "tests").glob("*_check.py"))
    python_files.update((PROJECT / "tools").rglob("test_*.py"))
    for path in sorted(python_files):
        if any(part in {"runs", "__pycache__", ".venv", "node_modules"} for part in path.parts):
            continue
        relative = path.relative_to(PROJECT)
        result.append(Check(str(relative).replace("/", "-"), [python, "-m", "unittest", str(relative), "-v"]))
    return result


def run(check: Check, output: Path, environment: dict[str, str]) -> dict:
    log_path = output / (check.name + ".log")
    started = time.monotonic()
    timed_out = False
    print(f"RUN  {check.name}", flush=True)
    with log_path.open("w") as log:
        process = subprocess.Popen(check.command, cwd=PROJECT, env=environment, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=check.timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            code = 124
            log.write(f"\nTIMEOUT after {check.timeout} seconds\n")
    text = log_path.read_text(errors="replace")
    script_error = bool(re.search(r"^SCRIPT ERROR:", text, re.MULTILINE))
    bootstrap_error = check.name in {"import", "scene-load"} and bool(re.search(r"^ERROR:", text, re.MULTILINE))
    passed = code == 0 and not script_error and not bootstrap_error
    result = {"name": check.name, "passed": passed, "exit_code": code,
              "seconds": round(time.monotonic() - started, 3), "timeout": timed_out,
              "log": log_path.name, "command": check.command}
    print(f"{'PASS' if passed else 'FAIL'} {check.name} ({result['seconds']:.1f}s)", flush=True)
    if not passed:
        print(text[-3000:], flush=True)
    return result


def report(results: list[dict], output: Path) -> None:
    failures = sum(not r["passed"] for r in results)
    data = {"engine": BUILD, "checks": len(results), "failures": failures, "results": results}
    (output / "results.json").write_text(json.dumps(data, indent=2) + "\n")
    suite = ET.Element("testsuite", name="ssok", tests=str(len(results)), failures=str(failures),
                       time=str(round(sum(r["seconds"] for r in results), 3)))
    for row in results:
        case = ET.SubElement(suite, "testcase", name=row["name"], time=str(row["seconds"]))
        if not row["passed"]:
            ET.SubElement(case, "failure", message=f"exit {row['exit_code']}; see {row['log']}").text = (output / row["log"]).read_text(errors="replace")[-8000:]
    ET.ElementTree(suite).write(output / "junit.xml", encoding="utf-8", xml_declaration=True)
    rows = ["# ssok verification", "", f"Godot `{BUILD}` · {len(results)} checks · {failures} failures", "",
            "Every failed check blocks this command. No expected-failure suppression.", "",
            "| Check | Result | Seconds |", "|---|---|---:|"]
    rows.extend(f"| `{r['name']}` | {'PASS' if r['passed'] else 'FAIL'} | {r['seconds']:.1f} |" for r in results)
    (output / "SUMMARY.md").write_text("\n".join(rows) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--python", default=sys.executable)
    parser.add_argument("--output", type=Path, default=PROJECT / "build/verification")
    parser.add_argument("--match", help="Run selected check names (regular expression); not a full release check")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()
    selected = [c for c in checks(args.godot, args.python) if not args.match or re.search(args.match, c.name)]
    if args.list:
        for check in selected:
            print(check.name)
        return 0
    if not selected:
        parser.error("No checks selected")
    actual = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if actual != BUILD:
        parser.error(f"Expected {BUILD}, got {actual}; engine migration requires an ADR")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / ".gdignore").touch()
    (PROJECT / "build").mkdir(exist_ok=True)
    (PROJECT / "build/.gdignore").touch()
    with tempfile.TemporaryDirectory(prefix="ssok-verify-") as temporary:
        # The server's Godot children and each test inherit the same isolated data root.
        for key in ("OPENAI_API_KEY", "SSOK_LIVE", "SSOK_MODEL", "SSOK_BRIDGE_TOKEN"):
            os.environ.pop(key, None)
        for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            os.environ[key] = str(Path(temporary) / key.lower())
        os.environ["GODOT"] = args.godot
        os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
        from tools.motion_lab.server import make_server
        from tools.motion_lab.service import MotionService
        service = MotionService(PROJECT, provider="mock", godot=args.godot, max_calls=32)
        token = secrets.token_urlsafe(32)
        server = make_server(service, token, port=0)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        environment = dict(os.environ, SSOK_UI_TEST_URL=f"http://127.0.0.1:{server.server_address[1]}", SSOK_UI_TEST_TOKEN=token)
        results = []
        try:
            for check in selected:
                results.append(run(check, output, environment))
                report(results, output)
        finally:
            server.shutdown()
            server.server_close()
            service.close()
            thread.join(timeout=5)
    failures = sum(not r["passed"] for r in results)
    print(f"{len(results)} checks; {failures} failures. Results: {output / 'SUMMARY.md'}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
