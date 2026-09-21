"""Optional real-SDK protocol checks: python -m unittest tests.motion_mcp_check -v."""

from __future__ import annotations

import json
import asyncio
from functools import wraps
import os
from pathlib import Path
import shutil
import sys
import subprocess
import time
import unittest

from mcp import Client, StdioServerParameters

from tools.motion_lab.mcp_server import create_server


PROJECT = Path(__file__).resolve().parents[1]
TOOL_NAMES = {
    "describe_motion_lab",
    "start_motion_search",
    "get_motion_search",
    "cancel_motion_search",
}


class FakeService:
    """No simulator or network; only the adapter contract is exercised here."""

    def __init__(self) -> None:
        self.jobs: dict[str, dict] = {}
        self.received: dict | None = None

    def describe(self) -> dict:
        return {"provider": "mock", "model": "gpt-5.6-luna", "calls_used": 0}

    def start(self, payload: dict) -> dict:
        self.received = payload
        job = {"id": "job-1", "state": "running", "history": [], "best": None}
        self.jobs[job["id"]] = job
        return dict(job)

    def get(self, job_id: str) -> dict:
        return dict(self.jobs[job_id])

    def cancel(self, job_id: str) -> dict:
        self.jobs[job_id]["state"] = "cancelled"
        return self.get(job_id)


def with_client(method):
    @wraps(method)
    async def run(self) -> None:
        self.service = FakeService()
        # AnyIO scopes must enter/exit in one task, unlike unittest setup/teardown.
        async with Client(create_server(self.service)) as client:
            self.client = client
            await method(self)

    return run


class AdapterProtocolChecks(unittest.IsolatedAsyncioTestCase):
    @with_client
    async def test_exact_tool_capabilities(self) -> None:
        result = await self.client.list_tools()
        self.assertEqual({tool.name for tool in result.tools}, TOOL_NAMES)
        for tool in result.tools:
            self.assertNotIn("api_key", json.dumps(tool.input_schema).lower())
            self.assertNotIn("execute", tool.name)
        self.assertEqual((await self.client.list_resources()).resources, [])
        self.assertEqual((await self.client.list_prompts()).prompts, [])

    @with_client
    async def test_read_only_annotations(self) -> None:
        definitions = {tool.name: tool for tool in (await self.client.list_tools()).tools}
        self.assertTrue(definitions["describe_motion_lab"].annotations.read_only_hint)
        self.assertTrue(definitions["get_motion_search"].annotations.read_only_hint)
        self.assertFalse(definitions["start_motion_search"].annotations.read_only_hint)
        self.assertFalse(definitions["start_motion_search"].annotations.idempotent_hint)
        self.assertTrue(definitions["start_motion_search"].annotations.open_world_hint)
        self.assertTrue(definitions["cancel_motion_search"].annotations.idempotent_hint)

    @with_client
    async def test_describe_makes_no_search(self) -> None:
        result = await self.client.call_tool("describe_motion_lab", {})
        self.assertFalse(result.is_error)
        self.assertEqual(result.structured_content["provider"], "mock")
        self.assertEqual(self.service.jobs, {})

    @with_client
    async def test_start_preserves_validated_data_and_offline_consent_default(self) -> None:
        result = await self.client.call_tool("start_motion_search", {"request": {"goal": "walk forward"}})
        self.assertFalse(result.is_error)
        self.assertEqual(self.service.received, {"goal": "walk forward", "rounds": 2, "allow_paid": False})
        self.assertEqual(result.structured_content["id"], "job-1")

    @with_client
    async def test_malformed_requests_never_reach_service(self) -> None:
        invalid = [
            {"goal": ""},
            {"goal": "   "},
            {"goal": "a" * 2001},
            {"goal": "walk", "rounds": True},
            {"goal": "walk", "rounds": "2"},
            {"goal": "walk", "rounds": 5},
            {"goal": "walk", "allow_paid": "false"},
            {"goal": "walk", "command": [1]},
            {"goal": "walk", "command": [0, 2]},
            {"goal": "walk", "command": [0, float("nan")]},
            {"goal": "walk", "api_key": "not-a-real-key"},
            {"goal": "walk", "source": "arbitrary source"},
            {"goal": "walk", "graph": {"too_large": "x" * 65536}},
            {"goal": "walk", "policy": {"non_finite": float("nan")}},
            {"goal": "walk", "policy": {"cycle_seconds": float("nan"), "stride_degrees": 16,
                                          "lean_degrees": 20, "posture_degrees": 4}},
        ]
        for payload in invalid:
            with self.subTest(payload=payload):
                result = await self.client.call_tool("start_motion_search", {"request": payload})
                self.assertTrue(result.is_error)
                self.assertIsNone(self.service.received)

    @with_client
    async def test_unknown_tool_is_not_executed(self) -> None:
        result = await self.client.call_tool("execute_code", {"source": "print('unsafe')"})
        self.assertTrue(result.is_error)
        self.assertIsNone(self.service.received)

    @with_client
    async def test_unknown_job_is_safe_error(self) -> None:
        result = await self.client.call_tool("get_motion_search", {"job_id": "unknown"})
        self.assertTrue(result.is_error)
        self.assertNotIn("Traceback", str(result.content))

    @with_client
    async def test_start_get_cancel(self) -> None:
        await self.client.call_tool("start_motion_search", {"request": {"goal": "walk"}})
        got = await self.client.call_tool("get_motion_search", {"job_id": "job-1"})
        self.assertEqual(got.structured_content["state"], "running")
        cancelled = await self.client.call_tool("cancel_motion_search", {"job_id": "job-1"})
        self.assertEqual(cancelled.structured_content["state"], "cancelled")
        again = await self.client.call_tool("cancel_motion_search", {"job_id": "job-1"})
        self.assertEqual(again.structured_content["state"], "cancelled")

    @with_client
    async def test_internal_exception_details_are_redacted(self) -> None:
        def failure() -> dict:
            raise OSError("synthetic-sensitive-diagnostic-value")

        self.service.describe = failure
        result = await self.client.call_tool("describe_motion_lab", {})
        self.assertTrue(result.is_error)
        self.assertNotIn("synthetic-sensitive-diagnostic-value", str(result.content))

    @with_client
    async def test_job_id_requires_bounded_string(self) -> None:
        for job_id in ["", 1, "a" * 129]:
            with self.subTest(job_id=job_id):
                result = await self.client.call_tool("get_motion_search", {"job_id": job_id})
                self.assertTrue(result.is_error)


class StdioProtocolChecks(unittest.IsolatedAsyncioTestCase):
    def server_parameters(self) -> StdioServerParameters:
        environment = {key: value for key, value in os.environ.items() if key not in {"OPENAI_API_KEY", "SSOK_MODEL"}}
        return StdioServerParameters(
            command=sys.executable,
            args=["-m", "tools.motion_lab.mcp_server"],
            cwd=PROJECT,
            env=environment,
        )

    async def test_stdio_current_protocol_and_tool_discovery(self) -> None:
        async with Client(self.server_parameters(), read_timeout_seconds=15) as client:
            self.assertEqual(client.protocol_version, "2026-07-28")
            self.assertEqual({tool.name for tool in (await client.list_tools()).tools}, TOOL_NAMES)
            result = await client.call_tool("describe_motion_lab", {})
            self.assertFalse(result.is_error)
            self.assertEqual(result.structured_content["provider"], "mock")

    async def test_stdio_legacy_handshake(self) -> None:
        async with Client(self.server_parameters(), mode="legacy", read_timeout_seconds=15) as client:
            self.assertEqual(client.protocol_version, "2025-11-25")
            self.assertEqual({tool.name for tool in (await client.list_tools()).tools}, TOOL_NAMES)

    async def test_stdio_real_service_start_and_cancel(self) -> None:
        parameters = self.server_parameters()
        parameters.env["GODOT"] = os.environ.get("GODOT") or shutil.which("godot") or "godot"
        # CI installs the pinned engine outside PATH. Exercise the same operator override.
        parameters.env["PATH"] = str(PROJECT / "build/empty-executable-path")
        async with Client(parameters, read_timeout_seconds=15) as client:
            started = await client.call_tool("start_motion_search", {"request": {"goal": "walk forward", "rounds": 1}})
            self.assertFalse(started.is_error, started.content)
            job_id = started.structured_content["id"]
            await asyncio.sleep(0.05)
            got = await client.call_tool("get_motion_search", {"job_id": job_id})
            self.assertFalse(got.is_error, got.content)
            self.assertNotEqual(got.structured_content["state"], "failed", got.structured_content)
            cancelled = await client.call_tool("cancel_motion_search", {"job_id": job_id})
            self.assertFalse(cancelled.is_error, cancelled.content)
            self.assertEqual(cancelled.structured_content["id"], job_id)
            self.assertIn(cancelled.structured_content["state"], {"cancelled", "cancelling", "completed"})
            deadline = time.monotonic() + 5
            while cancelled.structured_content["state"] == "cancelling" and time.monotonic() < deadline:
                await asyncio.sleep(0.05)
                cancelled = await client.call_tool("get_motion_search", {"job_id": job_id})
            self.assertIn(cancelled.structured_content["state"], {"cancelled", "completed"})


class OperatorConfigurationChecks(unittest.TestCase):
    def test_live_mode_without_key_fails_before_start(self) -> None:
        environment = {key: value for key, value in os.environ.items() if key != "OPENAI_API_KEY"}
        result = subprocess.run(
            [sys.executable, "-m", "tools.motion_lab.mcp_server", "--live"],
            cwd=PROJECT, env=environment, capture_output=True, text=True, timeout=15,
        )
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertIn("requires OPENAI_API_KEY", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
