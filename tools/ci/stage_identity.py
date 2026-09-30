"""Bundle the stage evaluator's source/model identity for exported applications."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

DIRECTORIES = ("src/core", "src/runtime", "src/profiles", "assets/parts", "assets/meshes")


def write_identity(project: Path) -> Path:
    hashes = {
        "res://" + path.relative_to(project).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for directory in DIRECTORIES
        for path in sorted((project / directory).rglob("*"))
        if path.suffix in {".gd", ".tres", ".res"}
    }
    target = project / "assets/stage_runtime_identity.json"
    target.write_text(json.dumps(hashes, sort_keys=True, indent=2) + "\n")
    return target


if __name__ == "__main__":
    write_identity(Path(__file__).resolve().parents[2])
