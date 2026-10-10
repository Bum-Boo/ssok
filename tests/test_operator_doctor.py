"""Preparation checks refuse unsuitable accounts without exposing their output."""
import io
import json
from pathlib import Path
import subprocess
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from tools.app_control import doctor
from tools.app_control.desktop_client import DesktopError


class OperatorDoctorTest(unittest.TestCase):
    def invoke(self, auth, **kwargs):
        stream = io.StringIO()
        with patch.object(doctor, "source_head", return_value="0" * 40), \
                patch.object(doctor, "mcp_check", return_value=doctor.check("mcp", True, "Available")), \
                patch.object(doctor.shutil, "which", return_value="test-codex"), \
                patch.object(doctor.subprocess, "run", return_value=auth) as process, \
                patch.dict(doctor.os.environ, {"SSOK_AGENT_TOKEN": "private-token-must-not-appear-1234567890"}), \
                patch("sys.stdout", stream):
            code = doctor.main(["--json", "--check-token"])
        return code, stream.getvalue(), process

    def test_accepted_login_reports_preparation_without_auth_output(self):
        raw = b"Logged in using ChatGPT\nprivate-account-detail"
        code, output, process = self.invoke(SimpleNamespace(returncode=0, stdout=raw, stderr=b""))
        self.assertEqual(code, 0)
        self.assertTrue(json.loads(output)["ready"])
        self.assertNotIn("private-account-detail", output)
        self.assertNotIn("private-token-must-not-appear", output)
        process.assert_called_once_with(["test-codex", "login", "status"], capture_output=True, timeout=15)

    def test_other_auth_mode_refuses_even_with_exit_zero_without_leaking_key(self):
        raw = b"Logged in using an API key: secret-key-preview"
        code, output, _ = self.invoke(SimpleNamespace(returncode=0, stdout=b"", stderr=raw))
        self.assertEqual(code, 1)
        self.assertFalse(json.loads(output)["ready"])
        self.assertNotIn("secret-key-preview", output)
        self.assertIn("codex login yourself", output)

    def test_failed_auth_exit_cannot_be_accepted_by_status_text(self):
        result = doctor.login_check
        with patch.object(doctor.subprocess, "run", return_value=SimpleNamespace(returncode=1, stdout=b"Logged in using ChatGPT", stderr=b"")):
            self.assertFalse(result("test-codex")["passed"])

    def test_timeout_reports_recovery_without_partial_auth_output(self):
        with patch.object(doctor.subprocess, "run", side_effect=subprocess.TimeoutExpired(["test-codex", "login", "status"], 15, output=b"secret-account-detail")):
            result = doctor.login_check("test-codex")
        self.assertFalse(result["passed"])
        self.assertIn("15 seconds", result["detail"])
        self.assertNotIn("secret-account-detail", json.dumps(result))

    def test_dependencies_only_never_probes_account_or_token(self):
        with patch.object(doctor, "source_head", return_value="0" * 40), \
                patch.object(doctor, "mcp_check", return_value=doctor.check("mcp", True, "Available")), \
                patch.object(doctor.shutil, "which") as executable, \
                patch.object(doctor.subprocess, "run") as process:
            result = doctor.inspect(Path.cwd(), dependencies_only=True)
        self.assertTrue(result["ready"])
        executable.assert_not_called()
        process.assert_not_called()

    def test_invalid_source_refuses_before_dependency_or_account_probe(self):
        with patch.object(doctor, "source_head", side_effect=DesktopError("Invalid identity")), \
                patch.object(doctor, "mcp_check") as mcp, \
                patch.object(doctor.shutil, "which") as executable:
            result = doctor.inspect(Path.cwd())
        self.assertFalse(result["ready"])
        self.assertIn("fresh complete operator archive", result["checks"][-1]["remedy"])
        mcp.assert_not_called()
        executable.assert_not_called()

    def test_wrong_mcp_version_refuses_before_importing_server(self):
        with patch.object(doctor.metadata, "version", return_value="1.7.0"), \
                patch.object(doctor.importlib, "import_module") as module:
            result = doctor.mcp_check()
        self.assertFalse(result["passed"])
        self.assertIn("setup-operator.ps1", result["remedy"])
        module.assert_not_called()

    def test_missing_codex_returns_actionable_check_without_auth_process(self):
        with patch.object(doctor, "source_head", return_value="0" * 40), \
                patch.object(doctor, "mcp_check", return_value=doctor.check("mcp", True, "Available")), \
                patch.object(doctor.shutil, "which", return_value=None), \
                patch.object(doctor.subprocess, "run") as process:
            result = doctor.inspect(Path.cwd())
        self.assertFalse(result["ready"])
        self.assertIn("Install Codex CLI", next(row for row in result["checks"] if row["id"] == "codex")["remedy"])
        process.assert_not_called()


if __name__ == "__main__":
    unittest.main()
