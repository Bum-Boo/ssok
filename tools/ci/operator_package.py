"""Build an allowlisted, Git-independent foreground operator ZIP from clean source."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

from tools.app_control.source_identity import MODULE_PATHS, source_head


VERSION = "0.2.0-operator-r40"
EXTRAS = {
    "tools/app_control/start-operator.ps1": "tools/app_control/start-operator.ps1",
    "tools/app_control/setup-operator.ps1": "tools/app_control/setup-operator.ps1",
    "README.md": "tools/app_control/OPERATOR.md",
    "requirements.txt": "tools/motion_lab/requirements-mcp.txt",
    "LICENSE": "LICENSE",
}


def build(root: Path, output: Path) -> dict:
    root = root.resolve()
    head = source_head(root)
    if subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True).strip():
        raise ValueError("Commit operator inputs before building a release archive.")
    contents = {name: (root / name).read_bytes() for name in MODULE_PATHS}
    identity = {"schema_version": 1, "version": VERSION, "source_head": head,
                "files": {name: hashlib.sha256(data).hexdigest() for name, data in contents.items()}}
    contents.update({name: (root / original).read_bytes() for name, original in EXTRAS.items()})
    contents["operator-source.json"] = (json.dumps(identity, indent=2) + "\n").encode("utf-8")
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "x", zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(contents.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 11, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, data)
    return {"archive": str(output), "version": VERSION, "source_head": head,
            "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
            "files": {name: hashlib.sha256(data).hexdigest() for name, data in contents.items()}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(build(Path(__file__).resolve().parents[2], args.out.resolve()), indent=2))
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        parser.exit(1, str(exc) + "\n")


if __name__ == "__main__":
    main()
