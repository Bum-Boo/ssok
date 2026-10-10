"""Run the real goal entry point from a package root without a Git checkout."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from tools.app_control import run_goal
from tools.app_control.source_identity import source_head
from tools.app_control.desktop_client import DesktopError


MODULES = (
    "desktop_client.py", "desktop_session.py", "desktop_mcp.py", "run_goal.py",
    "run_operator.py", "experiment_session.py", "source_identity.py", "doctor.py",
)
SOURCE_HEAD = "1e565b2c8bfd87a8aed162abb24b1e97209efc40"


class ReadyClient:
    def __init__(self):
        self.stops = []

    def describe(self):
        return {"state": "ready", "episode_id": "test-episode", "revision": 1,
                "control_generation": 7}

    def stop(self, context):
        self.stops.append(context)
        return {"state": "stopped", "owner_revoked": True, "stop_scope": "owned_context"}


class OperatorReleaseTest(unittest.TestCase):
    def package(self, root):
        source = Path(run_goal.__file__).resolve().parent
        files = {}
        for name in MODULES:
            target = root / "tools/app_control" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            data = (source / name).read_bytes() if (source / name).exists() else b"# Package identity fixture.\n"
            target.write_bytes(data)
            files[target.relative_to(root).as_posix()] = hashlib.sha256(data).hexdigest()
        stamp = {"schema_version": 1, "source_head": SOURCE_HEAD, "files": files}
        (root / "operator-source.json").write_bytes((json.dumps(stamp) + "\n").encode())

    def invoke(self, root):
        client = ReadyClient()
        output = root / "evidence"

        def launch(*args, **kwargs):
            camera = output / "camera"
            camera.mkdir()
            events = [{"event": "observe", "data": {}},
                      {"event": "action_result", "data": {}},
                      {"event": "observe", "data": {}},
                      {"event": "stop", "data": {"reason": "actor_stop", "confirmed": True}}]
            (camera / "events.jsonl").write_bytes(("\n".join(json.dumps(e) for e in events) + "\n").encode())
            return SimpleNamespace(returncode=0, communicate=lambda **kwargs: (b"", b""), poll=lambda: 0)

        provider = Mock(side_effect=launch)
        # Isolate provider/auth mocks from subprocess used by the real Git lookup.
        process_api = SimpleNamespace(
            check_output=subprocess.check_output, Popen=provider,
            run=lambda *args, **kwargs: SimpleNamespace(returncode=0, stdout=b"Logged in using ChatGPT", stderr=b""),
            TimeoutExpired=subprocess.TimeoutExpired, SubprocessError=subprocess.SubprocessError,
            PIPE=subprocess.PIPE,
        )
        with patch.object(run_goal, "__file__", str(root / "tools/app_control/run_goal.py")), \
                patch.object(run_goal, "DesktopClient", return_value=client), \
                patch.object(run_goal, "subprocess", process_api), \
                patch.object(run_goal.signal, "signal"), \
                patch("sys.stdout", new_callable=io.StringIO), patch("sys.stderr", new_callable=io.StringIO):
            code = run_goal.main(["--goal", "Observe, move once, observe, stop.", "--out", str(output), "--codex", "test-codex"])
        return code, output, provider, client

    def test_package_goal_dispatches_without_git_checkout(self):
        with tempfile.TemporaryDirectory(prefix="ssok-operator-release-") as folder:
            root = Path(folder).resolve()
            self.assertEqual(root.parent, Path(tempfile.gettempdir()).resolve())
            self.package(root)
            probe = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, capture_output=True)
            self.assertNotEqual(probe.returncode, 0)
            code, output, provider, client = self.invoke(root)
            self.assertEqual(code, 0, "A portable goal must get past provenance recording.")
            provider.assert_called_once()
            self.assertEqual(json.loads((output / "dispatch.json").read_text())["source_head"], SOURCE_HEAD)
            self.assertEqual(len(client.stops), 1)

    def test_changed_package_module_stops_before_provider_launch(self):
        with tempfile.TemporaryDirectory(prefix="ssok-operator-release-") as folder:
            root = Path(folder).resolve()
            self.assertEqual(root.parent, Path(tempfile.gettempdir()).resolve())
            self.package(root)
            with (root / "tools/app_control/desktop_mcp.py").open("ab") as stream:
                stream.write(b"# Changed since packaging.\n")
            code, output, provider, client = self.invoke(root)
            self.assertEqual(code, 1)
            provider.assert_not_called()
            self.assertTrue(json.loads((output / "result.json").read_text())["stop_confirmed"])
            self.assertEqual(len(client.stops), 1)

    def test_changed_packaged_doctor_stops_before_provider_launch(self):
        with tempfile.TemporaryDirectory(prefix="ssok-operator-release-") as folder:
            root = Path(folder).resolve()
            self.package(root)
            with (root / "tools/app_control/doctor.py").open("ab") as stream:
                stream.write(b"# Changed since packaging.\n")
            code, output, provider, client = self.invoke(root)
            self.assertEqual(code, 1)
            provider.assert_not_called()
            self.assertTrue(json.loads((output / "result.json").read_text())["stop_confirmed"])
            self.assertEqual(len(client.stops), 1)

    def test_missing_package_identity_stops_before_provider_launch(self):
        with tempfile.TemporaryDirectory(prefix="ssok-operator-release-") as folder:
            root = Path(folder).resolve()
            self.assertEqual(root.parent, Path(tempfile.gettempdir()).resolve())
            code, output, provider, client = self.invoke(root)
            self.assertEqual(code, 1)
            provider.assert_not_called()
            self.assertTrue(json.loads((output / "result.json").read_text())["stop_confirmed"])
            self.assertEqual(len(client.stops), 1)

    def test_invalid_identity_cannot_fall_back_to_git(self):
        invalid = [[], {"schema_version": True}, {"schema_version": 1, "source_head": "unknown", "files": {}},
                   {"schema_version": 1, "source_head": SOURCE_HEAD, "files": {"../outside.py": "0" * 64}}]
        with tempfile.TemporaryDirectory(prefix="ssok-operator-release-") as folder:
            root = Path(folder).resolve()
            self.assertEqual(root.parent, Path(tempfile.gettempdir()).resolve())
            for value in invalid:
                with self.subTest(value=value):
                    (root / "operator-source.json").write_bytes(json.dumps(value).encode())
                    with patch("tools.app_control.source_identity.subprocess.check_output") as git:
                        with self.assertRaises(DesktopError):
                            source_head(root)
                        git.assert_not_called()


if __name__ == "__main__":
    unittest.main()
