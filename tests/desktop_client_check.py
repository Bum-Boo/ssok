"""Stdlib rendered-desktop protocol checks; no Godot or provider is launched.

Run ``python -B tests/desktop_client_check.py``. The localhost peer is a test
fixture, not evidence that Godot rendered or physically settled a real robot.
An installed optional MCP SDK additionally exercises its actual tool schemas.
"""

from __future__ import annotations

import asyncio
import base64
from contextlib import redirect_stderr, redirect_stdout
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import secrets
import socket
import struct
import sys
import tempfile
import threading
import time
from typing import Any, Callable
import unittest
from unittest.mock import patch
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.app_control import desktop_client as desktop
from tools.app_control import desktop_mcp


def png_fixture() -> bytes:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 1, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\x00\xff\x00\x00\xff\x00\xff\x00\xff")) + chunk(b"IEND", b""))


def observation_fixture() -> desktop.Observation:
    png = png_fixture()
    return desktop.Observation({
        "episode_id": "episode-1", "robot_instance_id": 101, "part_id": 7,
        "camera_id": "robot-camera", "frame_id": "frame-1", "revision": 4,
        "control_generation": 2, "settle_confirmed_tick": 10,
        "capture_requested_tick": 11, "draw_frame": 9, "physics_tick": 12,
        "width": 2, "height": 1, "sha256": hashlib.sha256(png).hexdigest(),
        "interpolation_enabled": False,
    }, png)


def context_fixture() -> dict[str, Any]:
    metadata = observation_fixture().metadata
    return {"state": "armed", **{key: metadata[key] for key in (*desktop.CONTEXT_KEYS, "frame_id")}}


class LocalPeer:
    """One request on each accepted connection, with explicit peer close."""

    def __init__(self, handler: Callable[[dict[str, Any], socket.socket, int], Any], calls: int = 1):
        self.handler, self.calls = handler, calls
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen()
        self.listener.settimeout(2)
        self.port = self.listener.getsockname()[1]
        self.requests: list[dict[str, Any]] = []
        self.errors: list[Exception] = []
        self.thread = threading.Thread(target=self._run, daemon=True)

    def _run(self) -> None:
        try:
            for index in range(self.calls):
                connection, _ = self.listener.accept()
                with connection:
                    connection.settimeout(2)
                    body = bytearray()
                    while not body.endswith(b"\n"):
                        chunk = connection.recv(65536)
                        if not chunk or len(body) + len(chunk) > desktop.MAX_REQUEST_BYTES:
                            raise RuntimeError("Fixture received an incomplete or oversized request")
                        body.extend(chunk)
                    if body.count(b"\n") != 1:
                        raise RuntimeError("Fixture received multiple request lines")
                    request = json.loads(body)
                    self.requests.append(request)
                    result = self.handler(request, connection, index)
                    if result is not None:
                        wire = result if isinstance(result, bytes) else (json.dumps(result) + "\n").encode()
                        connection.sendall(wire)
        except Exception as exc:
            self.errors.append(exc)
        finally:
            self.listener.close()

    def __enter__(self) -> LocalPeer:
        self.thread.start()
        return self

    def __exit__(self, *_: Any) -> None:
        self.thread.join(3)
        if self.thread.is_alive():
            self.listener.close()
            raise AssertionError("Fixture did not finish")
        if self.errors:
            # Avoid exception reprs containing a received request or test token.
            raise AssertionError("Localhost fixture failed") from None


def reply(data: dict[str, Any]) -> Callable[[dict[str, Any], socket.socket, int], Any]:
    return lambda request, _connection, _index: {"id": request["id"], "data": data}


class DesktopProtocolChecks(unittest.TestCase):
    def setUp(self) -> None:
        self.token = secrets.token_urlsafe(32)
        self.environment = patch.dict(os.environ, {"SSOK_AGENT_TOKEN": self.token})
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def test_scoped_stop_transmits_only_exact_owner_and_reports_replacement_state(self) -> None:
        owner = observation_fixture().metadata
        state = context_fixture() | {"state": "ready", "episode_id": "new-episode",
                                    "owner_revoked": True, "stop_scope": "context_replaced"}
        with LocalPeer(reply(state)) as peer:
            result = desktop.DesktopClient(port=peer.port).stop(owner)
        self.assertEqual(peer.requests[0]["args"], {key: owner[key] for key in desktop.CONTEXT_KEYS})
        self.assertEqual(result["state"], "ready")
        self.assertTrue(result["owner_revoked"])
        self.assertEqual(result["stop_scope"], "context_replaced")

    def test_malformed_scoped_stop_never_becomes_global_stop(self) -> None:
        client = desktop.DesktopClient()
        with patch.object(client, "request") as request:
            for owner in ({}, {"episode_id": "", "revision": 0, "control_generation": 1},
                          {"episode_id": "old", "revision": True, "control_generation": 1}):
                with self.subTest(owner=owner), self.assertRaises(desktop.DesktopError):
                    client.stop(owner)
            request.assert_not_called()

    def test_scoped_stop_requires_owner_revocation_acknowledgement(self) -> None:
        with LocalPeer(reply(context_fixture() | {"state": "stopped"})) as peer:
            with self.assertRaises(desktop.DesktopError):
                desktop.DesktopClient(port=peer.port).stop(observation_fixture().metadata)

    def test_describe_uses_env_one_line_and_filters_privileged_data(self) -> None:
        state = context_fixture() | {"graph": {"hidden": "scene coordinates"}, "stage_result": "answer"}
        with LocalPeer(reply(state)) as peer:
            client = desktop.DesktopClient(port=peer.port)
            result = client.describe()
        request = peer.requests[0]
        self.assertEqual(set(request), {"id", "token", "tool", "args"})
        self.assertTrue(request["token"] == self.token)
        self.assertEqual((request["tool"], request["args"]), ("describe", {}))
        self.assertEqual(result, context_fixture())
        self.assertNotIn(self.token, repr(client))

    def test_observe_verifies_frame_bytes_and_metadata(self) -> None:
        observation = observation_fixture()
        with LocalPeer(reply(observation.wire_data())) as peer:
            result = desktop.DesktopClient(port=peer.port).observe(context_fixture())
        self.assertEqual(result, observation)
        self.assertEqual(peer.requests[0]["tool"], "observe")

    def test_describe_allows_unstarted_disabled_episode(self) -> None:
        context = context_fixture() | {"state": "disabled", "episode_id": "", "frame_id": 0, "enabled": False}
        with LocalPeer(reply(context)) as peer:
            result = desktop.DesktopClient(port=peer.port).describe()
        self.assertEqual(result["episode_id"], "")
        self.assertEqual(result["state"], "disabled")
        with LocalPeer(reply(context | {"state": "ready", "enabled": True})) as peer:
            with self.assertRaises(desktop.DesktopError):
                desktop.DesktopClient(port=peer.port).describe()

    def test_fragmented_reply(self) -> None:
        def handler(request: dict[str, Any], connection: socket.socket, _: int) -> None:
            wire = (json.dumps({"id": request["id"], "data": context_fixture()}) + "\n").encode()
            for offset in range(0, len(wire), 7):
                connection.sendall(wire[offset:offset + 7])
        with LocalPeer(handler) as peer:
            self.assertEqual(desktop.DesktopClient(port=peer.port).describe(), context_fixture())

    def test_no_token_or_short_token_never_connects(self) -> None:
        for token in ("", "x" * 31):
            with self.subTest(length=len(token)), patch.dict(os.environ, {"SSOK_AGENT_TOKEN": token}), patch.object(socket, "create_connection") as connect:
                with self.assertRaises(desktop.DesktopError):
                    desktop.DesktopClient().describe()
                connect.assert_not_called()

    def test_non_loopback_and_unbounded_timeout_rejected(self) -> None:
        for host in ("localhost", "0.0.0.0", "192.0.2.1", "example.com"):
            with self.subTest(host=host), self.assertRaises(desktop.DesktopError):
                desktop.DesktopClient(host=host)
        for timeout in (0, -1, 15.1, float("inf"), float("nan"), True):
            with self.subTest(timeout=timeout), self.assertRaises(desktop.DesktopError):
                desktop.DesktopClient(timeout=timeout)

    def test_oversized_or_nonfinite_request_never_connects(self) -> None:
        for args in ({"padding": "x" * desktop.MAX_REQUEST_BYTES}, {"value": float("nan")}):
            with self.subTest(kind=list(args)[0]), patch.object(socket, "create_connection") as connect:
                with self.assertRaises(desktop.DesktopError):
                    desktop.DesktopClient().request("observe", args)
                connect.assert_not_called()

    def test_unsupported_privileged_tool_never_connects(self) -> None:
        with patch.object(socket, "create_connection") as connect:
            for tool in ("get_scene", "get_result", "set_program", "run"):
                with self.subTest(tool=tool), self.assertRaises(desktop.DesktopError):
                    desktop.DesktopClient().request(tool)
            connect.assert_not_called()

    def test_malformed_envelope_json_or_framing(self) -> None:
        invalid = [b"not JSON\n", b"\xff\n", b'{}', b'{}\n{}\n', b'{}\n',
                   b'{"id":"a","id":"b","data":{}}\n', b'{"id":NaN,"data":{}}\n']
        for body in invalid:
            with self.subTest(index=invalid.index(body)), LocalPeer(lambda _r, _c, _i: body) as peer:
                with self.assertRaises(desktop.DesktopError):
                    desktop.DesktopClient(port=peer.port).describe()
        with LocalPeer(lambda r, _c, _i: {"id": r["id"], "data": {}, "error": "bad"}) as peer:
            with self.assertRaises(desktop.DesktopError):
                desktop.DesktopClient(port=peer.port).describe()

    def test_oversized_response(self) -> None:
        with LocalPeer(lambda _r, _c, _i: b"x" * (desktop.MAX_RESPONSE_BYTES + 1)) as peer:
            with self.assertRaisesRegex(desktop.DesktopError, "4 MiB"):
                desktop.DesktopClient(port=peer.port).describe()

    def test_peer_error_preserves_only_safe_code(self) -> None:
        with LocalPeer(lambda r, _c, _i: {"id": r["id"], "error": {"code": "stale_frame", "message": "private diagnostics"}}) as peer:
            with self.assertRaises(desktop.DesktopServerError) as caught:
                desktop.DesktopClient(port=peer.port).describe()
        self.assertEqual(caught.exception.code, "stale_frame")
        self.assertNotIn("private diagnostics", str(caught.exception))

    def test_reflected_token_is_never_returned_or_printed(self) -> None:
        with LocalPeer(reply(context_fixture() | {"extra": self.token})) as peer:
            out, err = io.StringIO(), io.StringIO()
            with redirect_stdout(out), redirect_stderr(err):
                status = desktop.main(["--port", str(peer.port), "describe"])
        self.assertEqual(status, 1)
        self.assertNotIn(self.token, out.getvalue() + err.getvalue())

    def test_secret_in_receipt_args_never_reaches_peer(self) -> None:
        with patch.object(socket, "create_connection") as connect:
            with self.assertRaisesRegex(desktop.DesktopError, "authentication data"):
                desktop.DesktopClient().trace_dispatch("frame-1", observation_fixture().metadata["sha256"],
                                                     2, self.token, "operator-test", 9, episode_id="episode-1")
            connect.assert_not_called()

    def test_timeout_closes_without_retry(self) -> None:
        def handler(_r: dict[str, Any], _c: socket.socket, _i: int) -> None:
            time.sleep(0.09)
        with LocalPeer(handler) as peer:
            started = time.monotonic()
            with self.assertRaisesRegex(desktop.DesktopError, "timed out"):
                desktop.DesktopClient(port=peer.port, timeout=0.03).describe()
            self.assertLess(time.monotonic() - started, 0.2)
        self.assertEqual(len(peer.requests), 1)

    def test_trickle_response_has_total_deadline(self) -> None:
        def handler(_r: dict[str, Any], connection: socket.socket, _i: int) -> None:
            for _ in range(15):
                try:
                    connection.sendall(b" ")
                except OSError:
                    return
                time.sleep(0.015)
        with LocalPeer(handler) as peer:
            started = time.monotonic()
            with self.assertRaisesRegex(desktop.DesktopError, "timed out"):
                desktop.DesktopClient(port=peer.port, timeout=0.06).describe()
            self.assertLess(time.monotonic() - started, 0.2)
        self.assertEqual(len(peer.requests), 1)

    def test_wrong_id_and_wrong_observation_context(self) -> None:
        with LocalPeer(lambda _r, _c, _i: {"id": "other", "data": context_fixture()}) as peer:
            with self.assertRaisesRegex(desktop.DesktopError, "ID"):
                desktop.DesktopClient(port=peer.port).describe()
        for key in desktop.CONTEXT_KEYS:
            context = context_fixture()
            context[key] = "other" if key == "episode_id" else context[key] + 1
            with self.subTest(key=key), LocalPeer(reply(observation_fixture().wire_data())) as peer:
                with self.assertRaisesRegex(desktop.DesktopError, "stale"):
                    desktop.DesktopClient(port=peer.port).observe(context)

    def test_bad_hash_dimensions_base64_and_schema(self) -> None:
        bad_hash = observation_fixture().wire_data()
        bad_hash["metadata"]["sha256"] = "0" * 64
        bad_dimensions = observation_fixture().wire_data()
        bad_dimensions["metadata"]["width"] = 3
        bad_base64 = observation_fixture().wire_data() | {"png_base64": "%%%"}
        privileged = observation_fixture().wire_data()
        privileged["metadata"]["sonar_distance"] = 42
        timeline = observation_fixture().wire_data()
        timeline["metadata"]["settle_confirmed_tick"] = 13
        for index, data in enumerate((bad_hash, bad_dimensions, bad_base64, privileged, timeline)):
            with self.subTest(index=index), LocalPeer(reply(data)) as peer:
                with self.assertRaises(desktop.DesktopError):
                    desktop.DesktopClient(port=peer.port).observe()

    def test_incomplete_and_corrupt_png(self) -> None:
        for png in (b"not a PNG", png_fixture()[:-12], png_fixture()[:-1] + b"x"):
            metadata = observation_fixture().metadata | {"sha256": hashlib.sha256(png).hexdigest()}
            with self.subTest(size=len(png)), self.assertRaises(desktop.DesktopError):
                desktop.Observation(metadata, png).verify()

    def test_step_bounds_and_consumed_frame(self) -> None:
        with LocalPeer(reply({"state": "armed", "episode_id": "episode-1", "frame_id": "frame-1", "success": True})) as peer:
            result = desktop.DesktopClient(port=peer.port).drive_step("frame-1", 4, 2, 30, "brake", episode_id="episode-1")
        self.assertTrue(result["success"])
        self.assertEqual(peer.requests[0]["args"], {"episode_id": "episode-1", "frame_id": "frame-1", "revision": 4, "control_generation": 2, "ticks": 30, "action": "brake"})
        with patch.object(socket, "create_connection") as connect:
            for ticks in (0, 31, 1.5, True, "1"):
                with self.subTest(ticks=ticks), self.assertRaises(desktop.DesktopError):
                    desktop.DesktopClient().drive_step("frame-1", 4, 2, ticks, episode_id="episode-1")
            with self.assertRaises(desktop.DesktopError):
                desktop.DesktopClient().drive_step("frame-1", 4, 2, 1, "arbitrary_code", episode_id="episode-1")
            connect.assert_not_called()
        with LocalPeer(reply({"state": "armed", "episode_id": "episode-1", "frame_id": "other", "success": True})) as peer:
            with self.assertRaisesRegex(desktop.DesktopError, "consumed frame"):
                desktop.DesktopClient(port=peer.port).drive_step("frame-1", 4, 2, 1, episode_id="episode-1")

    def test_step_and_receipt_require_nonempty_string_episode_before_connecting(self) -> None:
        metadata = observation_fixture().metadata
        with patch.object(socket, "create_connection") as connect:
            with self.assertRaises(TypeError):
                desktop.DesktopClient().drive_step("frame-1", 4, 2, 1)
            with self.assertRaises(TypeError):
                desktop.DesktopClient().trace_dispatch("frame-1", metadata["sha256"], 2, "Brake.", "operator-test", 9)
            for episode_id in (None, "", " ", 1, True):
                with self.subTest(episode_id=episode_id), self.assertRaisesRegex(desktop.DesktopError, "episode_id"):
                    desktop.DesktopClient().drive_step("frame-1", 4, 2, 1, episode_id=episode_id)
                with self.subTest(receipt_episode_id=episode_id), self.assertRaisesRegex(desktop.DesktopError, "episode_id"):
                    desktop.DesktopClient().trace_dispatch("frame-1", metadata["sha256"], 2, "Brake.", "operator-test", 9,
                                                         episode_id=episode_id)
            connect.assert_not_called()

    def test_step_rejects_missing_or_changed_reply_episode_even_when_ids_collide(self) -> None:
        for episode in ({}, {"episode_id": "restarted-episode"}):
            with self.subTest(episode=episode), LocalPeer(reply({"state": "armed", "frame_id": "frame-1", "success": True} | episode)) as peer:
                with self.assertRaisesRegex(desktop.DesktopError, "consumed episode"):
                    desktop.DesktopClient(port=peer.port).drive_step("frame-1", 4, 2, 1, episode_id="episode-1")

    def test_stop_requires_no_frame_or_revision(self) -> None:
        with LocalPeer(reply({"state": "stopped", "control_generation": 3, "scene_coordinates": [0, 0, 0]})) as peer:
            self.assertEqual(desktop.DesktopClient(port=peer.port).stop(), {"state": "stopped", "control_generation": 3})
        self.assertEqual((peer.requests[0]["tool"], peer.requests[0]["args"]), ("stop", {}))

    def test_trace_dispatch_is_receipt_only_and_bounded(self) -> None:
        metadata = observation_fixture().metadata
        with LocalPeer(reply({"recorded": True})) as peer:
            result = desktop.DesktopClient(port=peer.port).trace_dispatch("frame-1", metadata["sha256"], 2, "Brake at the visible wall.", "operator-test", 9,
                                                                         episode_id=metadata["episode_id"])
        self.assertTrue(result["recorded"])
        self.assertEqual(peer.requests[0]["tool"], "trace_dispatch")
        self.assertEqual(peer.requests[0]["args"]["episode_id"], metadata["episode_id"])
        with patch.object(socket, "create_connection") as connect:
            with self.assertRaises(desktop.DesktopError):
                desktop.DesktopClient().trace_dispatch("frame-1", metadata["sha256"], 2, "x" * 241, "operator-test", 9,
                                                     episode_id=metadata["episode_id"])
            with self.assertRaises(desktop.DesktopError):
                desktop.DesktopClient().trace_dispatch("frame-1", metadata["sha256"], 2, "Brake.", "operator-test", 101,
                                                     episode_id=metadata["episode_id"])
            connect.assert_not_called()

    def test_cli_observe_writes_readback_verified_sidecar_metadata_only(self) -> None:
        observation = observation_fixture()
        def handler(request: dict[str, Any], _c: socket.socket, index: int) -> dict[str, Any]:
            return {"id": request["id"], "data": context_fixture() if index == 0 else observation.wire_data()}
        with tempfile.TemporaryDirectory() as folder, LocalPeer(handler, calls=2) as peer:
            output = Path(folder) / "camera.png"
            out, err = io.StringIO(), io.StringIO()
            with redirect_stdout(out), redirect_stderr(err):
                status = desktop.main(["--port", str(peer.port), "observe", "--out", str(output)])
            self.assertEqual(status, 0)
            self.assertEqual(err.getvalue(), "")
            self.assertEqual(json.loads(out.getvalue()), observation.metadata)
            self.assertNotIn("png_base64", out.getvalue())
            self.assertNotIn(self.token, out.getvalue())
            self.assertEqual(desktop.load_observation(output), observation)
            self.assertEqual(desktop.load_observation(output.with_suffix(".json")), observation)
            output.write_bytes(b"tampered")
            with self.assertRaisesRegex(desktop.DesktopError, "SHA-256"):
                desktop.load_observation(output)
        self.assertEqual([request["tool"] for request in peer.requests], ["describe", "observe"])

    def test_cli_step_refuses_all_stale_contexts_before_action(self) -> None:
        for key in (*desktop.CONTEXT_KEYS, "frame_id"):
            context = context_fixture()
            context[key] = "other" if isinstance(context[key], str) else context[key] + 1
            with self.subTest(key=key), tempfile.TemporaryDirectory() as folder, LocalPeer(reply(context)) as peer:
                frame = Path(folder) / "frame.png"
                desktop.write_observation(observation_fixture(), frame)
                out, err = io.StringIO(), io.StringIO()
                with redirect_stdout(out), redirect_stderr(err):
                    status = desktop.main(["--port", str(peer.port), "step", "--frame", str(frame), "--ticks", "1"])
                self.assertEqual(status, 1)
                self.assertEqual(out.getvalue(), "")
                self.assertIn("stale", err.getvalue())
            self.assertEqual([request["tool"] for request in peer.requests], ["describe"])

    def test_cli_step_uses_saved_context_and_waits_for_reply(self) -> None:
        def handler(request: dict[str, Any], _c: socket.socket, index: int) -> dict[str, Any]:
            data = context_fixture() if index == 0 else {"episode_id": "episode-1", "frame_id": "frame-1", "state": "armed", "success": True}
            return {"id": request["id"], "data": data}
        with tempfile.TemporaryDirectory() as folder, LocalPeer(handler, calls=2) as peer:
            frame = Path(folder) / "frame.png"
            desktop.write_observation(observation_fixture(), frame)
            out = io.StringIO()
            with redirect_stdout(out):
                status = desktop.main(["--port", str(peer.port), "step", "--frame", str(frame.with_suffix(".json")), "--ticks", "2"])
            self.assertEqual(status, 0)
            self.assertTrue(json.loads(out.getvalue())["success"])
        self.assertEqual([request["tool"] for request in peer.requests], ["describe", "drive_step"])
        self.assertEqual(peer.requests[1]["args"]["episode_id"], "episode-1")

    def test_cli_step_and_receipt_stop_when_saved_metadata_has_no_episode(self) -> None:
        with tempfile.TemporaryDirectory() as folder, patch.object(socket, "create_connection") as connect:
            frame = Path(folder) / "old-frame.png"
            desktop.write_observation(observation_fixture(), frame)
            metadata = observation_fixture().metadata
            del metadata["episode_id"]
            frame.with_suffix(".json").write_text(json.dumps(metadata), encoding="utf-8")
            commands = (["step", "--frame", str(frame), "--ticks", "1"],
                        ["trace-dispatch", "--frame", str(frame), "--summary", "Brake.", "--provider", "operator-test", "--max-calls", "9"])
            for command in commands:
                with self.subTest(command=command[0]), redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                    self.assertEqual(desktop.main(command), 1)
            connect.assert_not_called()

    def test_cli_receipt_uses_saved_episode_and_refuses_process_restart(self) -> None:
        for restarted in (False, True):
            context = context_fixture() | ({"episode_id": "restarted-episode"} if restarted else {})
            def handler(request: dict[str, Any], _c: socket.socket, index: int) -> dict[str, Any]:
                return {"id": request["id"], "data": context if index == 0 else {"receipt": "hash_matched", "frame_id": "frame-1"}}
            with self.subTest(restarted=restarted), tempfile.TemporaryDirectory() as folder, LocalPeer(handler, calls=1 if restarted else 2) as peer:
                frame = Path(folder) / "frame.png"
                desktop.write_observation(observation_fixture(), frame)
                out, err = io.StringIO(), io.StringIO()
                with redirect_stdout(out), redirect_stderr(err):
                    status = desktop.main(["--port", str(peer.port), "trace-dispatch", "--frame", str(frame),
                                           "--summary", "Brake.", "--provider", "operator-test", "--max-calls", "9"])
                self.assertEqual(status, 1 if restarted else 0)
                if restarted:
                    self.assertIn("stale", err.getvalue())
                else:
                    self.assertEqual(json.loads(out.getvalue())["receipt"], "hash_matched")
            if restarted:
                self.assertEqual([request["tool"] for request in peer.requests], ["describe"])
            else:
                self.assertEqual(peer.requests[1]["args"]["episode_id"], "episode-1")


@unittest.skipUnless(importlib.util.find_spec("mcp") is not None, "Optional MCP SDK is not installed")
class OptionalMcpChecks(unittest.TestCase):
    def test_actual_sdk_tool_schema_image_and_action_capability(self) -> None:
        class FixtureClient:
            def describe(self) -> dict[str, Any]:
                return context_fixture()

            def observe(self, _context: dict[str, Any]) -> desktop.Observation:
                return observation_fixture()

            def stop(self) -> dict[str, Any]:
                return {"state": "stopped"}

            def drive_step(self, frame_id: Any, _revision: int, _generation: int, _ticks: int, _action: str, *, episode_id: str) -> dict[str, Any]:
                return {"state": "armed", "episode_id": episode_id, "frame_id": frame_id, "success": True}

        async def exercise() -> None:
            server = desktop_mcp.create_server(FixtureClient())
            tools = await server.list_tools()
            self.assertEqual({tool.name for tool in tools}, {"describe", "observe", "stop"})
            for tool in tools:
                schema = getattr(tool, "input_schema", getattr(tool, "inputSchema", {}))
                self.assertNotIn("token", json.dumps(schema))
            result = await server.call_tool("observe", {})
            self.assertEqual([content.type for content in result.content], ["text", "image"])
            self.assertEqual(json.loads(result.content[0].text), observation_fixture().metadata)
            self.assertEqual(base64.b64decode(result.content[1].data), png_fixture())
            server = desktop_mcp.create_server(FixtureClient(), allow_actions=True)
            tools = await server.list_tools()
            self.assertEqual({tool.name for tool in tools}, {"describe", "observe", "stop", "drive_step"})
            step_tool = next(tool for tool in tools if tool.name == "drive_step")
            schema = getattr(step_tool, "input_schema", getattr(step_tool, "inputSchema", {}))
            self.assertIn("episode_id", schema["required"])
            result = await server.call_tool("drive_step", {"episode_id": "episode-1", "frame_id": "frame-1", "revision": 4, "control_generation": 2, "ticks": 1, "action": "forward"})
            self.assertFalse(getattr(result, "is_error", getattr(result, "isError", False)))
        asyncio.run(exercise())


if __name__ == "__main__":
    unittest.main(verbosity=2)
