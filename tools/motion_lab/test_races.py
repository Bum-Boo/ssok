"""Deterministic cancellation-window regressions; no real API/process calls."""

import base64
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import socket
import threading
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request

from .server import make_server
from .service import (DEFAULT_POLICY, MODEL, GodotEvaluator, LabError,
                      MockProposer, MotionService, OpenAIProposer, validate_request)


PROJECT = Path(__file__).resolve().parents[2]


def fixture_metrics():
    return dict(score=1.0, forward_m=0.01, lateral_m=0.0, yaw_rad=0.0,
                min_upright=1.0, min_height_m=0.13, fallen=False, finite=True)


class ImmediateEvaluator:
    def evaluate(self, request, policy, cancelled):
        return fixture_metrics()


class CountingProposer:
    def __init__(self):
        self.calls = 0

    def propose(self, request, history, index, cancelled=None):
        self.calls += 1
        return dict(DEFAULT_POLICY), "Offline race-test fixture", {}


class CancellationWindowTests(unittest.TestCase):
    def test_cancel_during_history_copy_prevents_proposal_and_budget_use(self):
        entered, release = threading.Event(), threading.Event()

        class PausedHistoryService(MotionService):
            def get(self, job_id):
                if threading.current_thread() is self._worker and not entered.is_set():
                    entered.set()
                    if not release.wait(3):
                        raise RuntimeError("History-test barrier timed out")
                return super().get(job_id)

        proposer = CountingProposer()
        service = PausedHistoryService(
            PROJECT, provider="openai", api_key="synthetic-no-network-key",
            max_calls=1, evaluator=ImmediateEvaluator(), proposer=proposer,
        )
        try:
            started = service.start({"rounds": 1, "allow_paid": True})
            self.assertTrue(entered.wait(3))
            cancelled = service.cancel(started["id"])
            self.assertEqual(cancelled["state"], "cancelling")
            self.assertEqual(proposer.calls, 0)
            release.set()
            service._worker.join(3)
            self.assertFalse(service._worker.is_alive())
            self.assertEqual(service.get(started["id"])["state"], "cancelled")
            self.assertEqual(proposer.calls, 0)
            self.assertEqual(service.calls_used, 0)
        finally:
            release.set()
            service.close()

    def test_cancel_before_godot_evaluation_never_launches_process(self):
        cancelled = threading.Event()
        cancelled.set()
        with patch("tools.motion_lab.service.subprocess.Popen") as launch:
            with self.assertRaises(LabError):
                GodotEvaluator(PROJECT).evaluate({"command": [0, 1]}, DEFAULT_POLICY, cancelled)
            launch.assert_not_called()

    def test_cancel_during_godot_payload_encoding_never_launches_process(self):
        cancelled = threading.Event()
        original_encode = base64.b64encode

        def encode_and_cancel(payload):
            encoded = original_encode(payload)
            cancelled.set()
            return encoded

        with patch("tools.motion_lab.service.base64.b64encode", side_effect=encode_and_cancel):
            with patch("tools.motion_lab.service.subprocess.Popen") as launch:
                with self.assertRaises(LabError):
                    GodotEvaluator(PROJECT).evaluate({"command": [0, 1]}, DEFAULT_POLICY, cancelled)
                launch.assert_not_called()

    def test_cancel_before_openai_proposal_never_opens_connection(self):
        cancelled = threading.Event()
        cancelled.set()
        with patch("tools.motion_lab.service.urllib.request.build_opener") as build:
            with self.assertRaises(LabError):
                OpenAIProposer("synthetic-no-network-key").propose(
                    validate_request({}), [], 0, cancelled=cancelled,
                )
            build.return_value.open.assert_not_called()

    def test_cancel_during_api_body_encoding_never_opens_connection(self):
        cancelled = threading.Event()
        request = validate_request({})
        original_dumps = json.dumps

        def dumps_and_cancel(value, *args, **kwargs):
            encoded = original_dumps(value, *args, **kwargs)
            if isinstance(value, dict) and value.get("model") == MODEL:
                cancelled.set()
            return encoded

        with patch("tools.motion_lab.service.json.dumps", side_effect=dumps_and_cancel):
            with patch("tools.motion_lab.service.urllib.request.build_opener") as build:
                with self.assertRaises(LabError):
                    OpenAIProposer("synthetic-no-network-key").propose(request, [], 0, cancelled=cancelled)
                self.assertTrue(cancelled.is_set())
                build.return_value.open.assert_not_called()

    def test_cancelled_mock_proposal_stops_without_candidate(self):
        cancelled = threading.Event()
        cancelled.set()
        history = [{"policy": dict(DEFAULT_POLICY), "metrics": fixture_metrics()}]
        with self.assertRaises(LabError):
            MockProposer().propose(validate_request({}), history, 0, cancelled=cancelled)


class HTTPBoundaryTests(unittest.TestCase):
    def test_partial_headers_have_a_connection_timeout(self):
        service = MotionService(PROJECT, api_key="")
        server = make_server(service, "synthetic-local-test-token-12345", port=0)
        self.assertEqual(server.RequestHandlerClass.timeout, 5)
        server.RequestHandlerClass.timeout = 0.2
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            with socket.create_connection(server.server_address, timeout=2) as connection:
                connection.settimeout(2)
                connection.sendall(b"GET /v1/status HTTP/1.1\r\nHost: ")
                self.assertEqual(connection.recv(1), b"")
        finally:
            server.shutdown()
            server.server_close()
            service.close()
            worker.join(1)

    def test_eight_concurrent_http_starts_accept_exactly_one_job(self):
        class WaitingEvaluator:
            def evaluate(self, request, policy, cancelled):
                cancelled.wait(5)
                raise LabError("Cancelled")

        service = MotionService(PROJECT, api_key="", evaluator=WaitingEvaluator())
        token = "synthetic-local-test-token-12345"
        server = make_server(service, token, port=0)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        url = "http://127.0.0.1:" + str(server.server_address[1]) + "/v1/search"

        def start_request(_):
            request = urllib.request.Request(
                url, data=b"{}", headers={"Authorization": "Bearer " + token,
                                          "Content-Type": "application/json"},
            )
            try:
                response = urllib.request.urlopen(request, timeout=3)
            except urllib.error.HTTPError as exc:
                response = exc
            with response:
                return response.status, json.load(response)

        try:
            with ThreadPoolExecutor(max_workers=8) as pool:
                results = list(pool.map(start_request, range(8)))
            self.assertEqual(sum(code == 202 for code, _ in results), 1)
            self.assertEqual(sum(code == 400 for code, _ in results), 7)
            self.assertEqual(len(service._jobs), 1)
            for code, job in results:
                if code == 202:
                    service.cancel(job["id"])
        finally:
            service.close()
            server.shutdown()
            server.server_close()
            worker.join(1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
