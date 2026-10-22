"""Resolve checkout identity or verify the modules in a portable operator archive."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

from .desktop_client import DesktopError


MODULE_PATHS = tuple("tools/app_control/" + name for name in (
    "desktop_client.py", "desktop_session.py", "desktop_mcp.py", "run_goal.py",
    "run_operator.py", "experiment_session.py", "source_identity.py",
))


def source_head(root: Path) -> str:
    root = root.resolve()
    stamp = root / "operator-source.json"
    if stamp.exists():
        try:
            if stamp.stat().st_size > 65536:
                raise ValueError("identity too large")
            identity = json.loads(stamp.read_text(encoding="utf-8"))
            if (type(identity.get("schema_version")) is not int or identity["schema_version"] != 1
                    or not isinstance(identity.get("source_head"), str)
                    or not re.fullmatch(r"[0-9a-f]{40}", identity["source_head"])
                    or not isinstance(identity.get("files"), dict)
                    or set(identity["files"]) != set(MODULE_PATHS)):
                raise ValueError("invalid identity")
            for name in MODULE_PATHS:
                path = root / name
                if not path.resolve().is_relative_to(root):
                    raise ValueError("module outside archive")
                digest = identity["files"][name]
                if (not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest)
                        or hashlib.sha256(path.read_bytes()).hexdigest() != digest):
                    raise ValueError("module changed")
            return identity["source_head"]
        except (OSError, ValueError, TypeError, AttributeError) as exc:
            raise DesktopError("Operator package identity is invalid or files changed; extract a fresh archive.") from exc
    try:
        checkout = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], cwd=root,
                                           text=True, stderr=subprocess.DEVNULL, timeout=15).strip()
        if Path(checkout).resolve() != root:
            raise ValueError("not the checkout root")
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root,
                                       text=True, stderr=subprocess.DEVNULL, timeout=15).strip()
        if not re.fullmatch(r"[0-9a-f]{40}", head):
            raise ValueError("invalid Git identity")
        return head
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        raise DesktopError("Operator source identity unavailable; use a checkout or a complete operator archive.") from exc
