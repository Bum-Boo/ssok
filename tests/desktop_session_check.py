"""Session-contract regressions; fixture observations are not navigation evidence."""
import tempfile
from pathlib import Path
import threading
import time
import unittest
import asyncio
import base64
import importlib.util
import json
import os
import secrets
import io
from contextlib import redirect_stdout, redirect_stderr
from types import SimpleNamespace
from unittest.mock import patch

from tools.app_control.desktop_client import DesktopError, DesktopClient, Observation, CONTEXT_KEYS
from tools.app_control.desktop_session import DesktopGoalSession
from tools.app_control.desktop_mcp import create_goal_server
from tests.desktop_client_check import observation_fixture
from tests.desktop_client_check import LocalPeer
from tools.app_control import run_goal


class FixtureClient:
    def __init__(self):
        self.metadata = dict(observation_fixture().metadata)
        self.calls = []
        self.stopped = False
        self.fail_action = False
        self.counter = 0

    def describe(self):
        return self.metadata | {"state": "ready"}

    def observe(self, context):
        from tools.app_control.desktop_client import Observation
        self.calls.append("observe")
        self.counter += 1
        self.metadata["frame_id"] = str(self.counter)
        frame = observation_fixture()
        metadata = frame.metadata | {"frame_id": self.metadata["frame_id"]}
        self.metadata = dict(metadata)
        return Observation(metadata, frame.png)

    def trace_dispatch(self, *args, **kwargs):
        self.calls.append(("receipt", args, kwargs))
        return {"receipt": "hash_matched"}

    def drive_step(self, frame_id, revision, generation, ticks, action, *, episode_id):
        self.calls.append(("action", ticks, action))
        if self.fail_action:
            raise DesktopError("Lost action reply.")
        return {"state": "ready", "frame_id": frame_id, "episode_id": episode_id}

    def stop(self, context):
        if any(context[key] != self.metadata[key] for key in CONTEXT_KEYS):
            self.calls.append("scoped_stop_replaced")
            return {"state": "ready", "owner_revoked": True, "stop_scope": "context_replaced"}
        self.stopped = True
        self.calls.append("stop")
        return {"state": "stopped", "owner_revoked": True, "stop_scope": "matched_context"}


class GoalChecks(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.client = FixtureClient()
        self.session = DesktopGoalSession(self.client, Path(self.folder.name) / "camera", max_steps=1, max_observations=2)

    def decide(self, **changes):
        values = {"frame_sha256": self.session.frame.metadata["sha256"], "summary": "Floor is visible; try a short step.",
                  "action": "forward", "ticks": 3} | changes
        return self.session.decide(**values)

    def test_claimed_context_rejects_stop_then_reenable_before_first_image(self):
        claimed = {key: self.client.metadata[key] for key in CONTEXT_KEYS}
        session = DesktopGoalSession(self.client, Path(self.folder.name) / "claimed", expected_context=claimed)
        self.client.metadata["control_generation"] += 1
        with self.assertRaises(DesktopError):
            session.observe()
        self.assertFalse(self.client.stopped)
        self.assertIn("scoped_stop_replaced", self.client.calls)
        self.assertNotIn("observe", self.client.calls)
        self.assertEqual(session.steps, 0)

    def test_claimed_context_rejects_changed_first_frame_after_describe(self):
        claimed = {key: self.client.metadata[key] for key in CONTEXT_KEYS}
        session = DesktopGoalSession(self.client, Path(self.folder.name) / "claimed", expected_context=claimed)
        image = observation_fixture()
        self.client.observe = lambda _: Observation(image.metadata | {"episode_id": "replacement-episode"}, image.png)
        with self.assertRaises(DesktopError):
            session.observe()
        self.assertTrue(self.client.stopped)
        self.assertEqual(session.observations, 0)

    def test_matching_claimed_context_keeps_action_and_reobserve(self):
        claimed = {key: self.client.metadata[key] for key in CONTEXT_KEYS}
        session = DesktopGoalSession(self.client, Path(self.folder.name) / "claimed", expected_context=claimed)
        image = session.observe()
        session.decide(image.metadata["sha256"], "Wall visible.", "forward", 3)
        session.observe()
        session.stop()
        self.assertEqual((session.steps, session.observations), (1, 2))

    def test_operator_endpoints_are_not_actor_client_capabilities(self):
        for tool in ("operator_poll", "operator_leave"):
            with self.assertRaises(DesktopError):
                DesktopClient().request(tool, {"operator_id": "fixture-operator-identity"})

    def test_real_bytes_receipt_finite_action_reobserve_and_close(self):
        image = self.session.observe()
        self.assertEqual((self.session.output / "observation-1.png").read_bytes(), image.png)
        result = self.decide()
        self.assertEqual(result["steps_remaining"], 0)
        self.session.observe()
        self.session.stop()
        with self.assertRaises(DesktopError):
            self.session.observe()
        receipt = next(x for x in self.client.calls if isinstance(x, tuple) and x[0] == "receipt")
        self.assertEqual(receipt[1][1], image.metadata["sha256"])

    def test_wrong_image_hash_cancels_without_action(self):
        self.session.observe()
        with self.assertRaises(DesktopError):
            self.decide(frame_sha256="0" * 64)
        self.assertTrue(self.client.stopped)
        self.assertFalse(any(isinstance(x, tuple) and x[0] == "action" for x in self.client.calls))

    def test_missing_and_consumed_frame_cannot_act(self):
        with self.assertRaises(DesktopError):
            self.session.decide("0" * 64, "Brake.", "brake", 1)
        self.assertFalse(self.client.stopped)
        self.assertTrue(self.session.closed.is_set())

    def test_second_observe_before_decision_cancels(self):
        self.session.observe()
        with self.assertRaises(DesktopError):
            self.session.observe()
        self.assertEqual(self.client.calls.count("observe"), 1)
        self.assertTrue(self.client.stopped)

    def test_stale_human_revision_cancels_without_action(self):
        self.session.observe()
        self.client.metadata["revision"] += 1
        with self.assertRaises(DesktopError):
            self.decide()
        self.assertFalse(self.client.stopped)
        self.assertIn("scoped_stop_replaced", self.client.calls)

    def test_new_episode_cannot_rebind_after_step(self):
        self.session.observe()
        self.decide()
        self.client.metadata["episode_id"] = "another-episode"
        with self.assertRaises(DesktopError):
            self.session.observe()
        self.assertFalse(self.client.stopped)
        self.assertIn("scoped_stop_replaced", self.client.calls)

    def test_step_budget_reserves_final_image_then_refuses_movement(self):
        self.session.observe()
        self.decide()
        self.session.observe()
        with self.assertRaises(DesktopError):
            self.decide()
        self.assertEqual(sum(isinstance(x, tuple) and x[0] == "action" for x in self.client.calls), 1)

    def test_lost_reply_never_retries_and_revokes_session(self):
        self.session.observe()
        self.client.fail_action = True
        with self.assertRaises(DesktopError):
            self.decide()
        self.assertTrue(self.client.stopped)
        self.assertTrue(self.session.closed.is_set())
        self.assertEqual(self.session.steps, 1)

    def test_deadline_fails_closed(self):
        self.session.context = {key: self.client.metadata[key] for key in CONTEXT_KEYS}
        self.session.deadline = time.monotonic() - 1
        with self.assertRaises(DesktopError):
            self.session.observe()
        self.assertTrue(self.client.stopped)

    def test_stop_does_not_wait_for_inflight_lock(self):
        self.session.context = {key: self.client.metadata[key] for key in CONTEXT_KEYS}
        self.session.lock.acquire()
        thread = threading.Thread(target=self.session.stop)
        thread.start()
        thread.join(timeout=1)
        self.session.lock.release()
        self.assertFalse(thread.is_alive())
        self.assertTrue(self.client.stopped)

    def test_unbound_stop_closes_session_without_revoking_any_desktop(self):
        result = self.session.stop()
        self.assertTrue(self.session.closed.is_set())
        self.assertEqual(result, {"owner_revoked": True, "stop_scope": "unbound"})
        self.assertEqual(self.client.calls, [])

    def test_first_observation_failure_has_already_bound_cleanup_owner(self):
        def fail(_context):
            raise DesktopError("Observation reply lost.")
        self.client.observe = fail
        with self.assertRaises(DesktopError):
            self.session.observe()
        self.assertTrue(self.client.stopped)
        self.assertEqual(self.session.context, {key: self.client.metadata[key] for key in CONTEXT_KEYS})

    def test_invalid_bounds_do_not_create_session(self):
        for kwargs in ({"max_steps": 9}, {"max_steps": True}, {"max_observations": 1}, {"seconds": 0}):
            with self.subTest(kwargs=kwargs), self.assertRaises(DesktopError):
                DesktopGoalSession(self.client, Path(self.folder.name) / "invalid", **kwargs)

    @unittest.skipUnless(importlib.util.find_spec("mcp") is not None, "Optional MCP SDK unavailable")
    def test_goal_sdk_image_decision_and_stop_tools(self):
        async def exercise():
            server = create_goal_server(self.session)
            listed = await server.list_tools()
            self.assertEqual({tool.name for tool in listed}, {"observe", "decide", "stop"})
            result = await server.call_tool("observe", {})
            self.assertEqual([item.type for item in result.content], ["text", "image"])
            self.assertEqual(base64.b64decode(result.content[1].data), observation_fixture().png)
            metadata = json.loads(result.content[0].text)
            result = await server.call_tool("decide", {"frame_sha256": metadata["sha256"], "summary": "Floor is visible.", "action": "forward", "ticks": 3})
            self.assertFalse(result.is_error)
            result = await server.call_tool("observe", {})
            self.assertFalse(result.is_error)
            result = await server.call_tool("stop", {})
            self.assertFalse(result.is_error)
        asyncio.run(exercise())


class RunnerCleanupChecks(unittest.TestCase):
    def test_exit_during_context_poll_still_drains_diagnostics_and_writes_receipt(self):
        client = FixtureClient()
        states = iter([client.metadata | {"state": "ready"}, client.metadata | {"state": "stopped"}])
        client.describe = lambda: next(states)
        replies = iter([run_goal.subprocess.TimeoutExpired("fixture", .5),
                        (b'{"type":"turn.failed","error":{"message":"stream ended"}}', b"discarded")])
        def communicate(**kwargs):
            reply = next(replies)
            if isinstance(reply, Exception):
                raise reply
            return reply
        process = SimpleNamespace(returncode=1, poll=lambda: 1, communicate=communicate)
        with tempfile.TemporaryDirectory() as folder, \
                patch.dict(os.environ, {"SSOK_AGENT_TOKEN": "fixture-token"}), \
                patch.object(run_goal, "DesktopClient", return_value=client), \
                patch.object(run_goal, "source_head", return_value="fixture-source"), \
                patch.object(run_goal.signal, "signal"), \
                patch.object(run_goal.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout=b"Logged in using ChatGPT", stderr=b"")), \
                patch.object(run_goal.subprocess, "Popen", return_value=process), \
                redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            evidence = Path(folder) / "evidence"
            self.assertEqual(run_goal.main(["--goal", "Stop.", "--out", str(evidence), "--codex", "fixture"]), 1)
            result = json.loads((evidence / "result.json").read_text())
            self.assertEqual(result["status"], "operator_or_app_stopped")
            self.assertTrue(result["stop_confirmed"])
            self.assertEqual(json.loads((evidence / "cli-events.json").read_text())[0]["diagnostic"], "stream ended")
        self.assertEqual(client.calls, ["stop"])

    def test_cli_failure_keeps_terminal_diagnostics_and_scoped_stop_without_retry(self):
        client = FixtureClient()
        goal = "Observe then stop."
        token = "fixture-secret-token"
        events = [{"type": "error", "message": "Transport disconnected " + token},
                  {"type": "turn.failed", "error": {"message": "Request failed " + goal}}]
        process = SimpleNamespace(returncode=1, poll=lambda: 1,
                                  communicate=lambda **kwargs: (b"broken\n[]\nnull\n" + b"\n".join(json.dumps(x).encode() for x in events),
                                                                 b"private stderr must never persist"))
        with tempfile.TemporaryDirectory() as folder, \
                patch.dict(os.environ, {"SSOK_AGENT_TOKEN": token}), \
                patch.object(run_goal, "DesktopClient", return_value=client), \
                patch.object(run_goal, "source_head", return_value="fixture-source"), \
                patch.object(run_goal.signal, "signal"), \
                patch.object(run_goal.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout=b"Logged in using ChatGPT", stderr=b"")), \
                patch.object(run_goal.subprocess, "Popen", return_value=process) as launch, \
                redirect_stdout(io.StringIO()) as output, redirect_stderr(io.StringIO()) as errors:
            evidence = Path(folder) / "evidence"
            self.assertEqual(run_goal.main(["--goal", goal, "--out", str(evidence), "--codex", "fixture"]), 1)
            launch.assert_called_once()
            result = json.loads((evidence / "result.json").read_text())
            self.assertEqual((result["status"], result["cli_exit"]), ("cli_failed", 1))
            self.assertTrue(result["stop_confirmed"] and result["owner_revocation_confirmed"])
            self.assertFalse(result["final_reobserved"])
            rows = json.loads((evidence / "cli-events.json").read_text())
            self.assertIn("Transport disconnected", rows[0]["diagnostic"])
            self.assertIn("Request failed", rows[1]["diagnostic"])
            recorded = output.getvalue() + errors.getvalue() + (evidence / "cli-events.json").read_text()
            for private in (token, goal, "private stderr"):
                self.assertNotIn(private, recorded)
        self.assertTrue(client.stopped)
        self.assertEqual(client.calls, ["stop"])

    def test_stale_preflight_scopes_cleanup_without_stopping_replacement_or_launching_cli(self):
        owner = {key: observation_fixture().metadata[key] for key in CONTEXT_KEYS}
        current = owner | {"episode_id": "replacement-episode", "control_generation": owner["control_generation"] + 1,
                           "state": "ready", "frame_id": "new-frame"}
        def handler(request, _connection, index):
            data = current if index == 0 else current | {"owner_revoked": True, "stop_scope": "context_replaced"}
            return {"id": request["id"], "data": data}
        with tempfile.TemporaryDirectory() as folder, LocalPeer(handler, calls=2) as peer, \
                patch.dict(os.environ, {"SSOK_AGENT_TOKEN": secrets.token_hex(32)}):
            client = DesktopClient(port=peer.port)
            with patch.object(run_goal, "DesktopClient", return_value=client), \
                    patch.object(run_goal.signal, "signal"), \
                    patch.object(run_goal.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout=b"Logged in using ChatGPT", stderr=b"")), \
                    patch.object(run_goal.subprocess, "Popen") as launch:
                code = run_goal.main(["--goal", "Observe then stop.", "--out", str(Path(folder) / "evidence"),
                                      "--codex", "fixture", "--expected-context", json.dumps(owner)])
            self.assertEqual(code, 1)
            launch.assert_not_called()
            self.assertFalse((Path(folder) / "evidence").exists())
        self.assertEqual([request["tool"] for request in peer.requests], ["describe", "stop"])
        self.assertEqual(peer.requests[1]["args"], owner)

    def test_unbound_login_failure_never_stops_an_existing_desktop(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(run_goal, "DesktopClient") as client, \
                patch.object(run_goal.signal, "signal"), \
                patch.object(run_goal.subprocess, "run", return_value=SimpleNamespace(returncode=1, stdout=b"", stderr=b"")):
            self.assertEqual(run_goal.main(["--goal", "Observe then stop.", "--out", str(Path(folder) / "evidence"),
                                            "--codex", "fixture"]), 1)
            client.return_value.stop.assert_not_called()
            client.return_value.describe.assert_not_called()


class PublicCliDiagnosticChecks(unittest.TestCase):
    def collect(self, events):
        raw = b"\n".join(json.dumps(x).encode() for x in events)
        return run_goal.public_cli_events(raw, token="fixture-token", goal="private goal")

    def test_top_level_nested_and_legacy_errors_remain_distinct(self):
        rows, _ = self.collect([{"type": "error", "message": "connection lost"},
                               {"type": "turn.failed", "error": {"message": "quota exceeded"}},
                               {"type": "item.completed", "item": {"type": "error", "text": "tool unavailable"}}])
        self.assertEqual([x["diagnostic"] for x in rows], ["connection lost", "quota exceeded", "tool unavailable"])

    def test_error_redaction_precedes_truncation_and_discards_private_payloads(self):
        private = ["fixture-token", "private goal", "sk-secretkey", "secretBearer", "secretValue",
                   "0199a213-81c0-7800-8aa1-bbab2a035a53", "private-user", "imageBytes", "Z" * 90]
        message = "failed " + " ".join([private[0], private[1], private[2], "Bearer " + private[3],
                                        "api_key=" + private[4], private[5], "/home/private-user/cache",
                                        "data:image/png;base64,imageBytes", private[8]]) + " safe" * 200
        rows, _ = self.collect([{"type": "error", "message": message},
                               {"type": "item.completed", "item": {"type": "reasoning", "text": "private reasoning", "id": "private-id"}},
                               {"type": "item.completed", "item": {"type": "agent_message", "text": "private response"}}])
        serialized = json.dumps(rows)
        for value in private + ["private reasoning", "private response", "private-id"]:
            self.assertNotIn(value, serialized)
        self.assertLessEqual(len(rows[0]["diagnostic"]), 400)
        self.assertIn("failed", rows[0]["diagnostic"])

    def test_malformed_and_unknown_shapes_do_not_throw_or_capture_payloads(self):
        raw = b'broken\n\xff\n' + b"\n".join(json.dumps(x).encode() for x in
              [None, [], 1, {"type": [], "item": []}, {"type": "turn.failed", "error": ["private"]},
               {"type": "error", "message": {"private": "content"}}, {"type": "error", "message": ""}])
        rows, usage = run_goal.public_cli_events(raw, token="", goal="")
        self.assertEqual(len(rows), 4)
        self.assertEqual([r["diagnostic"] for r in rows[1:]], ["unspecified CLI diagnostic"] * 3)
        self.assertNotIn("private", json.dumps(rows))
        self.assertEqual(usage, {})

    def test_only_allowlisted_metadata_and_integer_usage_survive(self):
        rows, usage = self.collect([{"type": "item.completed", "item": {"type": "mcp_tool_call", "server": "ssok", "tool": "observe", "arguments": "private"}},
                                   {"type": "turn.completed", "usage": {"input_tokens": 4, "cached_input_tokens": True, "output_tokens": 2, "private": "data"}}])
        self.assertEqual(rows[0]["tool"], "observe")
        self.assertEqual(usage, {"input_tokens": 4, "output_tokens": 2})
        self.assertNotIn("private", json.dumps(rows))


if __name__ == "__main__":
    unittest.main(verbosity=2)
