#!/usr/bin/env python3
"""Install the exact official Linux editor and web/Linux export templates."""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import platform
import shutil
import subprocess
import urllib.request
import zipfile

VERSION = "4.7.2"
BUILD = "4.7.2.stable.official.ed1daf0bf"
BASE = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable"
# Release asset SHA-256 digests from the official GitHub release, 2026-09-22.
ASSETS = {
    f"Godot_v{VERSION}-stable_linux.x86_64.zip": "cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4",
    f"Godot_v{VERSION}-stable_export_templates.tpz": "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011",
}
TEMPLATES = (
    "version.txt", "linux_debug.x86_64", "linux_release.x86_64",
    "web_nothreads_debug.zip", "web_nothreads_release.zip",
)


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def download(name: str, cache: Path) -> Path:
    destination = cache / name
    if destination.exists() and digest(destination) == ASSETS[name]:
        return destination
    temporary = destination.with_suffix(destination.suffix + ".partial")
    print(f"Downloading official {name}", flush=True)
    with urllib.request.urlopen(f"{BASE}/{name}", timeout=120) as response, temporary.open("wb") as target:
        shutil.copyfileobj(response, target, length=1024 * 1024)
    if digest(temporary) != ASSETS[name]:
        temporary.unlink()
        raise SystemExit(f"SHA-256 mismatch for {name}; nothing installed")
    temporary.replace(destination)
    return destination


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path("build/toolchain"))
    parser.add_argument("--templates", action="store_true", help="Also install the web and Linux templates (1.28 GB download)")
    args = parser.parse_args()
    if platform.system() != "Linux" or platform.machine() not in {"x86_64", "AMD64"}:
        parser.error("This installer targets Linux x86_64; use the same official version on other hosts")
    directory = args.directory.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    (directory / ".gdignore").touch()
    if directory.parent.name == "build":
        (directory.parent / ".gdignore").touch()
    cache = directory / "downloads"
    cache.mkdir(exist_ok=True)
    editor_name = f"Godot_v{VERSION}-stable_linux.x86_64"
    archive = download(editor_name + ".zip", cache)
    with zipfile.ZipFile(archive) as package:
        with package.open(editor_name) as source, (directory / "godot").open("wb") as destination:
            shutil.copyfileobj(source, destination)
    (directory / "godot").chmod(0o755)
    actual = subprocess.check_output([str(directory / "godot"), "--version"], text=True).strip()
    if actual != BUILD:
        raise SystemExit(f"Unexpected official editor identity: {actual}")
    if args.templates:
        archive = download(f"Godot_v{VERSION}-stable_export_templates.tpz", cache)
        data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
        template_dir = data_home / "godot/export_templates" / f"{VERSION}.stable"
        template_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as package:
            for name in TEMPLATES:
                with package.open("templates/" + name) as source, (template_dir / name).open("wb") as destination:
                    shutil.copyfileobj(source, destination)
        if (template_dir / "version.txt").read_text().strip() != f"{VERSION}.stable":
            raise SystemExit("Export template version mismatch")
        print(f"Templates: {template_dir}")
    print(f"GODOT={directory / 'godot'}")


if __name__ == "__main__":
    main()
