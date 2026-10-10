"""Check local operator preparation without opening ssok or starting a model."""
import argparse
import importlib
from importlib import metadata
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from .desktop_client import DesktopError
from .source_identity import source_head


MCP_VERSION = "2.2.0"
SETUP_HINT = "Run tools/app_control/setup-operator.ps1 in this archive."


def check(check_id, passed, detail, remedy=""):
    return {"id": check_id, "passed": passed, "detail": detail,
            "remedy": remedy if not passed else ""}


def mcp_check():
    try:
        installed = metadata.version("mcp")
    except metadata.PackageNotFoundError:
        return check("mcp", False, "The selected Python has no MCP SDK.", SETUP_HINT)
    if installed != MCP_VERSION:
        return check("mcp", False, "MCP must match the archive's pinned version2.2.0.", SETUP_HINT)
    try:
        server = importlib.import_module("mcp.server")
        getattr(server, "MCPServer")
        importlib.import_module("mcp.server.mcpserver.exceptions")
        importlib.import_module("mcp.server.mcpserver.utilities.types")
    except (ImportError, AttributeError):
        return check("mcp", False, "The selected Python cannot import the required MCP server.", SETUP_HINT)
    return check("mcp", True, "Pinned MCP2.2.0 server is available.")


def login_check(executable):
    try:
        result = subprocess.run([executable, "login", "status"], capture_output=True, timeout=15)
    except subprocess.TimeoutExpired:
        return check("login", False, "Codex login status exceeded15 seconds.",
                     "Check codex login status in your terminal, then run this check again.")
    except (OSError, subprocess.SubprocessError):
        return check("login", False, "Codex login status could not run.",
                     "Check the Codex CLI installation and PATH.")
    # Never return raw output: other auth modes may include account or key details.
    if result.returncode == 0 and b"Logged in using ChatGPT" in result.stdout + result.stderr:
        return check("login", True, "Existing Codex ChatGPT login is available.")
    return check("login", False, "An existing Codex ChatGPT login is required; API-key fallback is disabled.",
                 "Run codex login yourself, choose ChatGPT sign-in, then check again.")


def inspect(root, *, dependencies_only=False, check_token=False):
    checks = [check("python", sys.version_info >= (3, 11), "Python3.11 or newer is required.",
                    "Install Python3.11 or newer, then run the local setup command.")]
    try:
        source_head(root)
    except DesktopError:
        checks.append(check("source", False, "Operator identity is missing or files changed.",
                            "Extract a fresh complete operator archive, or use the actual checkout root."))
        return {"ready": False, "checks": checks}
    checks.append(check("source", True, "Operator archive identity or checkout root is available."))
    checks.append(mcp_check())
    if not dependencies_only:
        executable = shutil.which("codex")
        checks.append(check("codex", executable is not None, "Codex CLI must be available on PATH.",
                            "Install Codex CLI following the linked official setup guide, then reopen the terminal."))
        if executable:
            checks.append(login_check(executable))
    if check_token:
        checks.append(check("token", len(os.environ.get("SSOK_AGENT_TOKEN", "")) >= 32,
                            "App and operator need the same shell token of at least32 characters.",
                            "Follow the README token/app-start steps in this shell; never paste the token into a goal."))
    return {"ready": all(row["passed"] for row in checks), "checks": checks}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Emit classified checks, never raw login/token data")
    parser.add_argument("--dependencies-only", action="store_true", help="Check local Python/MCP/source without account checks")
    parser.add_argument("--check-token", action="store_true", help="Also check shell-token presence/length, never its value")
    args = parser.parse_args(argv)
    result = inspect(Path(__file__).resolve().parents[2], dependencies_only=args.dependencies_only,
                     check_token=args.check_token)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        for row in result["checks"]:
            print(("OK: " if row["passed"] else "FIX: ") + row["id"] + " - " + row["detail"])
            if row["remedy"]:
                print("  " + row["remedy"])
        print("Local checks passed; submit a goal intentionally in ssok." if result["ready"] else
              "Complete the listed setup steps, then run this check again.")
    return 0 if result["ready"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
