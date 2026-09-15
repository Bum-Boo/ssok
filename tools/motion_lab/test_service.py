"""Run with python3 -m unittest tools.motion_lab.test_service; no paid requests."""

import copy
import io
import json
from pathlib import Path
import threading
import time
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request

from .server import make_server
from .service import (BOUNDS, DEFAULT_POLICY, MODEL, GodotEvaluator, LabError,
                      MotionService, OpenAIProposer, strict_json, validate_policy,
                      validate_request)

PROJECT = Path(__file__).resolve().parents[2]


def metrics(score=1.0, fallen=False):
    return dict(score=score, forward_m=0.01, lateral_m=0.0, yaw_rad=0.0,
                min_upright=1.0, min_height_m=0.13, fallen=fallen, finite=True)


class Evaluator:
    def __init__(self, scores=(1, 0, 2), failed=False):
        self.scores, self.requests, self.failed = list(scores), [], failed

    def evaluate(self, request, policy, cancelled):
        self.requests.append((copy.deepcopy(request), dict(policy)))
        if self.failed:
            raise LabError("Unsupported graph")
        return metrics(self.scores.pop(0))


class Proposer:
    def __init__(self):
        self.calls = []

    def propose(self, request, history, index, cancelled=None):
        self.calls.append(copy.deepcopy(history))
        result = dict(DEFAULT_POLICY)
        result["posture_degrees"] = float(index)
        return result, "fixture", dict(input_tokens=20, output_tokens=10, total_tokens=30)


def wait_job(service, job_id):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        job = service.get(job_id)
        if job["state"] in ("failed", "completed", "cancelled"):
            return job
        time.sleep(0.005)
    raise AssertionError("search did not finish")


class ValidationTests(unittest.TestCase):
    def test_policy_exact_finite_bounds(self):
        self.assertEqual(validate_policy(DEFAULT_POLICY), DEFAULT_POLICY)
        for key, (low, high) in BOUNDS.items():
            for value in (low - 0.001, high + 0.001, float("nan"), float("inf"), True, "1", None, 10**1000):
                with self.subTest(key=key, value=str(value)[:20]), self.assertRaises(LabError):
                    validate_policy({**DEFAULT_POLICY, key: value})
        for value in ({}, [], None, {**DEFAULT_POLICY, "code": "print(1)"}):
            with self.assertRaises(LabError):
                validate_policy(value)

    def test_request_rejects_invalid_inputs(self):
        for value in ([1], {"rounds": True}, {"rounds": 5}, {"goal": ""}, {"goal": "x" * 2001},
                      {"command": [1, 1]}, {"command": [0, 0]}, {"command": [10**1000, 1]},
                      {"allow_paid": "yes"}, {"model": "other"}, {"graph": {}}):
            with self.subTest(value=str(value)[:30]), self.assertRaises(LabError):
                validate_request(value)
        self.assertEqual(validate_request({})["rounds"], 2)

    def test_graph_no_paths_or_nonfinite(self):
        graph = dict(version=1, parts=[dict(id="servo", transform=[1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])], links=[])
        validate_request({"graph": graph})
        for value in ("../servo", "res://assets/servo", "a" * 81):
            graph["parts"][0]["id"] = value
            with self.assertRaises(LabError):
                validate_request({"graph": graph})

    def test_strict_json(self):
        for value in ('{"x":NaN}', '{"x":Infinity}', 'oops', '[' * 2000):
            with self.assertRaises(LabError):
                strict_json(value)


class SearchTests(unittest.TestCase):
    def setUp(self):
        self.services = []

    def tearDown(self):
        for service in self.services:
            service.close()

    def service(self, **kwargs):
        service = MotionService(PROJECT, **kwargs)
        self.services.append(service)
        return service

    def test_baseline_feedback_best_retention_and_isolation(self):
        evaluator, proposer = Evaluator(), Proposer()
        service = self.service(evaluator=evaluator, proposer=proposer)
        job = service.start({"rounds": 2})
        final = wait_job(service, job["id"])
        self.assertEqual(final["state"], "completed")
        self.assertEqual(len(final["history"]), 3)
        self.assertEqual(final["best"]["metrics"]["score"], 2)
        self.assertEqual([len(h) for h in proposer.calls], [1, 2])
        self.assertEqual(final["api_calls"], 0)
        final["best"]["policy"]["cycle_seconds"] = 999
        self.assertNotEqual(service.get(job["id"])["best"]["policy"]["cycle_seconds"], 999)

    def test_keep_baseline_when_all_proposals_worse(self):
        service = self.service(evaluator=Evaluator((3, 2, 1)), proposer=Proposer())
        final = wait_job(service, service.start({})["id"])
        self.assertEqual(final["best"]["reason"], "Measured baseline; no model call")

    def test_fall_not_selected_even_with_higher_score(self):
        service = self.service(evaluator=Evaluator((1,)), proposer=Proposer())
        job = service.start({"rounds": 1})
        wait_job(service, job["id"])
        service._record(job["id"], DEFAULT_POLICY, metrics(999, fallen=True), "fall")
        self.assertFalse(service.get(job["id"])["best"]["metrics"]["fallen"])

    def test_missing_key_paid_consent_and_budget(self):
        missing = self.service(provider="openai", api_key="", evaluator=Evaluator())
        with self.assertRaisesRegex(LabError, "OPENAI_API_KEY"):
            missing.start({"allow_paid": True})
        proposer = Proposer()
        live = self.service(provider="openai", api_key="test-only-not-a-real-key", max_calls=1,
                            evaluator=Evaluator((1, 2)), proposer=proposer)
        with self.assertRaisesRegex(LabError, "allow_paid"):
            live.start({"rounds": 1})
        with self.assertRaisesRegex(LabError, "budget"):
            live.start({"rounds": 2, "allow_paid": True})
        final = wait_job(live, live.start({"rounds": 1, "allow_paid": True})["id"])
        self.assertEqual(final["api_calls"], 1)
        self.assertEqual(final["usage"]["total_tokens"], 30)
        self.assertNotIn("test-only-not-a-real-key", json.dumps(final) + json.dumps(live.describe()))
        with self.assertRaisesRegex(LabError, "budget"):
            live.start({"rounds": 1, "allow_paid": True})

    def test_invalid_baseline_never_calls_model(self):
        proposer = Proposer()
        service = self.service(evaluator=Evaluator(failed=True), proposer=proposer)
        job = wait_job(service, service.start({})["id"])
        self.assertEqual(job["state"], "failed")
        self.assertEqual(proposer.calls, [])

    def test_cancel_stops_subsequent_work_and_rejects_overlap(self):
        entered = threading.Event()
        class WaitingEvaluator:
            def evaluate(self, request, policy, cancelled):
                entered.set()
                cancelled.wait(3)
                raise LabError("Cancelled")
        proposer = Proposer()
        service = self.service(evaluator=WaitingEvaluator(), proposer=proposer)
        started = service.start({})
        self.assertTrue(entered.wait(1))
        with self.assertRaisesRegex(LabError, "already running"):
            service.start({})
        service.cancel(started["id"])
        final = wait_job(service, started["id"])
        self.assertEqual(final["state"], "cancelled")
        self.assertEqual(proposer.calls, [])
        self.assertEqual(final["history"], [])


class APITests(unittest.TestCase):
    def response(self, **overrides):
        return {"status": "completed", "output": [
            {"type": "reasoning", "summary": []},
            {"type": "message", "content": [{"type": "output_text", "text": json.dumps(
                {"policy": DEFAULT_POLICY, "reason": "measured change"})}]}],
                "usage": {"input_tokens": 12, "output_tokens": 20, "total_tokens": 32}, **overrides}

    def invoke(self, response):
        proposer = OpenAIProposer("unit-test-key")
        with patch("urllib.request.build_opener") as build:
            build.return_value.open.return_value = io.BytesIO(json.dumps(response).encode())
            result = proposer.propose(validate_request({}), [], 0)
            req = build.return_value.open.call_args.args[0]
            payload = json.loads(req.data)
            self.assertEqual(payload["model"], MODEL)
            self.assertFalse(payload["store"])
            self.assertTrue(payload["text"]["format"]["strict"])
            self.assertNotIn("unit-test-key", json.dumps(payload))
            self.assertEqual(req.full_url, "https://api.openai.com/v1/responses")
            self.assertNotIn("tools", payload)
        return result

    def test_structured_responses_request_and_parse(self):
        policy, reason, usage = self.invoke(self.response())
        self.assertEqual(policy, DEFAULT_POLICY)
        self.assertEqual(usage["total_tokens"], 32)

    def test_incomplete_refusal_and_schema_rejection(self):
        for response in (self.response(status="incomplete"), self.response(output=[]),
                         self.response(output=[{"type": "message", "content": [{"type": "refusal"}]}])):
            with self.assertRaises(LabError):
                self.invoke(response)

    def test_http_error_sanitized_and_no_retry(self):
        with patch("urllib.request.build_opener") as build:
            build.return_value.open.side_effect = urllib.error.HTTPError(
                "https://api.openai.com", 429, "secret upstream detail", {}, None)
            with self.assertRaises(LabError) as result:
                OpenAIProposer("unit-test-key").propose(validate_request({}), [], 0)
            self.assertIn("429", str(result.exception))
            self.assertNotIn("secret", str(result.exception))
            self.assertEqual(build.return_value.open.call_count, 1)


class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.service = MotionService(PROJECT, evaluator=Evaluator((1, 2)), proposer=Proposer())
        self.token = "test-bridge-token-long-enough-only"
        self.server = make_server(self.service, self.token, 0, ["http://localhost:8060"])
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = "http://127.0.0.1:" + str(self.server.server_address[1])

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.service.close()
        self.thread.join(1)

    def request(self, path, body=None, headers=None, token=True, method=None):
        actual_headers = {"Content-Type": "application/json"}
        if token:
            actual_headers["Authorization"] = "Bearer " + self.token
        actual_headers.update(headers or {})
        req = urllib.request.Request(self.url + path, headers=actual_headers,
                                     data=json.dumps(body).encode() if body is not None else None, method=method)
        try:
            response = urllib.request.urlopen(req, timeout=3)
        except urllib.error.HTTPError as exc:
            response = exc
        with response:
            return response.status, json.loads(response.read()), response.headers

    def test_auth_origin_host_and_cors(self):
        self.assertEqual(self.request("/v1/status", token=False)[0], 401)
        self.assertEqual(self.request("/v1/status", headers={"Origin": "https://evil.invalid"})[0], 403)
        self.assertEqual(self.request("/v1/status", headers={"Host": "evil.invalid"})[0], 403)
        code, payload, headers = self.request("/v1/status", headers={"Origin": "http://localhost:8060"})
        self.assertEqual(code, 200)
        self.assertEqual(payload["provider"], "mock")
        self.assertEqual(headers["Access-Control-Allow-Origin"], "http://localhost:8060")
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertEqual(self.request("/v1/status", token=False, method="OPTIONS",
                                      headers={"Origin": "http://localhost:8060"})[0], 200)

    def test_start_poll_cancel_and_errors(self):
        code, job, _ = self.request("/v1/search", {"rounds": 1})
        self.assertEqual(code, 202)
        wait_job(self.service, job["id"])
        code, final, _ = self.request("/v1/search/" + job["id"])
        self.assertEqual(final["state"], "completed")
        self.assertEqual(self.request("/v1/search/" + job["id"] + "/cancel", {})[0], 200)
        self.assertEqual(self.request("/v1/search", {"rounds": 99})[0], 400)
        self.assertEqual(self.request("/unknown")[0], 404)
        self.assertEqual(self.request("/v1/search", {}, headers={"Content-Type": "text/plain"})[0], 415)
        self.assertEqual(self.request("/v1/search", {"goal": "x" * 70000})[0], 413)


if __name__ == "__main__":
    unittest.main()
