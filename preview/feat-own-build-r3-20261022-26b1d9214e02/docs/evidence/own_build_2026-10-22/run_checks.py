"""Execute the CI check list when the sandbox cannot create its loopback mock server.

This is diagnostic, not a passing replacement for verify.py: mock and rendered checks retain
their failures. No checks are skipped and the original timeout/error gates are unchanged.
"""
import argparse
import os
from pathlib import Path
import sys
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from tools.ci.verify import checks, report, run
from tools.ci.install_godot import BUILD


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=ROOT / "build/toolchain/godot")
    parser.add_argument("--output", type=Path, default=ROOT / "build/own-build-final2")
    args = parser.parse_args()
    actual = subprocess.check_output([str(args.godot.resolve()), "--version"], text=True).strip()
    if actual != BUILD:
        parser.error(f"Expected {BUILD}, got {actual}")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / ".gdignore").touch()
    environment = dict(os.environ, GODOT=str(args.godot.resolve()), PYTHONDONTWRITEBYTECODE="1")
    for key in ("OPENAI_API_KEY", "SSOK_LIVE", "SSOK_MODEL", "SSOK_BRIDGE_TOKEN",
                "SSOK_UI_TEST_URL", "SSOK_UI_TEST_TOKEN", "SSOK_AGENT_TOKEN"):
        environment.pop(key, None)
    results = []
    with tempfile.TemporaryDirectory(prefix="ssok-own-build-checks-") as temporary:
        for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            environment[key] = str(Path(temporary) / key.lower())
        for check in checks(str(args.godot.resolve()), sys.executable):
            results.append(run(check, output, environment))
            report(results, output)
    failures = sum(not row["passed"] for row in results)
    print(f"{len(results)} checks; {failures} failures; {output / 'results.json'}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
