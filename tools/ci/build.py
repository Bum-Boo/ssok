#!/usr/bin/env python3
"""Export, inspect and package Linux and single-threaded Web release artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT))
from tools.ci.install_godot import BUILD
from tools.ci.stage_identity import write_identity

# Files reached from the bundled documentation, kept outside the application pack.
DOCUMENTATION_REFERENCES = (
    "assets/kenney/SOURCE.json",
    "AGENTS.md",
    "assets/modular_humanoid/README.md",
    "presets/biped_motion.gd",
    "tests/biped_motion_check.gd",
    "tools/motion_lab/MCP.md",
    "tools/motion_lab/PICKUP.md",
    "tools/rl_lab/reference/biped_mujoco_ars.json",
)


def execute(command: list[str], log: Path, *, cwd: Path = PROJECT, env=None) -> None:
    print("Running " + " ".join(command), flush=True)
    result = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=300)
    log.write_text(result.stdout)
    if result.returncode or re.search(r"^(SCRIPT ERROR:|ERROR:)", result.stdout, re.MULTILINE):
        print(result.stdout[-8000:])
        raise SystemExit(f"Build failed; see {log}")


def copy_notices(destination: Path) -> None:
    notices = destination / "licenses"
    notices.mkdir(exist_ok=True)
    sources = {
        "Noto-OFL.txt": PROJECT / "assets/fonts/OFL.txt",
        "Lucide-LICENSE.txt": PROJECT / "assets/icons/lucide/LICENSE",
        "Godot-LICENSE.txt": PROJECT / "tools/release/licenses/Godot-LICENSE.txt",
        "Godot-COPYRIGHT.txt": PROJECT / "tools/release/licenses/Godot-COPYRIGHT.txt",
        "Beehave-LICENSE.txt": PROJECT / "addons/beehave/LICENSE",
        "Godot-State-Charts-LICENSE.txt": PROJECT / "addons/godot_state_charts/LICENSE",
        "Kenney-Interface-Sounds-LICENSE.txt": PROJECT / "assets/kenney/interface-sounds/LICENSE.txt",
    }
    for name, source in sources.items():
        shutil.copy2(source, notices / name)
    for name in ("LICENSE", "THIRD_PARTY_NOTICES.md", "README.md"):
        shutil.copy2(PROJECT / name, destination / name)
    shutil.copytree(PROJECT / "docs", destination / "docs", ignore=shutil.ignore_patterns("*.tmp", "*.bak"))
    for name in DOCUMENTATION_REFERENCES:
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PROJECT / name, target)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--version", default="development")
    parser.add_argument("--output", type=Path, default=PROJECT / "build")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9._-]+", args.version):
        parser.error("Version must contain only letters, numbers, dots, hyphens and underscores")
    actual = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if actual != BUILD:
        parser.error(f"Expected {BUILD}, got {actual}")
    output = args.output.resolve()
    write_identity(PROJECT)
    logs = output / "export-logs"
    logs.mkdir(parents=True, exist_ok=True)
    (output / ".gdignore").touch()
    execute([args.godot, "--headless", "--path", str(PROJECT), "--editor", "--import", "--quit"], logs / "import.log")
    base = [args.godot, "--headless", "--path", str(PROJECT)]
    with tempfile.TemporaryDirectory(prefix="ssok-browser-layout-") as temporary:
        environment = dict(os.environ, XDG_DATA_HOME=temporary, XDG_CONFIG_HOME=temporary)
        execute(base + ["--language", "en", "--script", "res://tools/ci/browser_layout.gd", "--",
                        str(logs / "browser-layout.json")], logs / "browser-layout.log", env=environment)
    artifacts = []
    for platform, filename in (("Web", "index.html"), ("Linux", "ssok.x86_64")):
        destination = output / platform.lower()
        destination.mkdir(exist_ok=True)
        # Fresh directories avoid accidentally publishing stale output from earlier builds.
        for old in destination.iterdir():
            if old.is_dir():
                shutil.rmtree(old)
            else:
                old.unlink()
        execute(base + ["--export-release", platform, str(destination / filename)], logs / f"{platform.lower()}.log")
        copy_notices(destination)
        if platform == "Web":
            (destination / ".nojekyll").touch()
            html = (destination / filename).read_text()
            if not re.search(r"(?:const|var) GODOT_THREADS_ENABLED\s*=\s*false", html):
                raise SystemExit("Web export must be single-threaded for GitHub Pages")
        else:
            with tempfile.TemporaryDirectory(prefix="ssok-export-smoke-") as temporary:
                environment = dict(os.environ, XDG_DATA_HOME=temporary, XDG_CONFIG_HOME=temporary)
                execute([str(destination / filename), "--headless", "--quit-after", "5"], logs / "linux-startup.log", cwd=destination, env=environment)
        pack = destination / ("index.pck" if platform == "Web" else "ssok.pck")
        if platform == "Linux" and not pack.exists():
            pack = destination / "ssok.x86_64.pck"
        with tempfile.TemporaryDirectory(prefix="ssok-pack-audit-") as temporary:
            execute([args.godot, "--headless", "--path", temporary, "--script", str(PROJECT / "tools/ci/check_export.gd"), "--", str(pack), str(logs / f"{platform.lower()}-resources.json")], logs / f"{platform.lower()}-resources.log", cwd=Path(temporary))
        archive = output / f"ssok-{args.version}-{platform.lower()}{'-x86_64' if platform == 'Linux' else ''}.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as package:
            for path in sorted(destination.rglob("*")):
                if path.is_file():
                    package.write(path, path.relative_to(destination))
        with archive.open("rb") as stream:
            checksum = hashlib.file_digest(stream, "sha256").hexdigest()
        artifacts.append({"file": archive.name, "sha256": checksum, "bytes": archive.stat().st_size})
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=PROJECT, capture_output=True, text=True)
    status = subprocess.run(["git", "status", "--porcelain"], cwd=PROJECT, capture_output=True, text=True)
    metadata = {"version": args.version, "godot": BUILD, "commit": commit.stdout.strip(),
                "dirty_worktree": bool(status.stdout.strip()), "artifacts": artifacts}
    (output / "release.json").write_text(json.dumps(metadata, indent=2) + "\n")
    (output / "SHA256SUMS").write_text("".join(f"{a['sha256']}  {a['file']}\n" for a in artifacts))
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
