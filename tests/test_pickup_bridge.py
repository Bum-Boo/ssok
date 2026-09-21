"""Pickup bridge boundaries and races. All OpenAI requests are mocked, never billed."""

import copy
from concurrent.futures import ThreadPoolExecutor
import io
import json
from pathlib import Path
import threading
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request

from tools.motion_lab.pickup import (
    BOUNDS, DEFAULT_POLICY, MockPickupProposer, OpenAIPickupProposer,
    validate_candidates, validate_metrics, validate_policy, validate_request,
)
from tools.motion_lab.server import make_server
from tools.motion_lab.service import LabError, MODEL, MotionService

PROJECT = Path(__file__).resolve().parents[1]
FINGERPRINT = "a" * 64


def request(**changes):
    return {"graph_fingerprint": FINGERPRINT, "count": 4, **changes}


def metrics(**changes):
    return {"finite": True, "fallen": False, "success": True, "lift_m": .4,
            "hold_seconds": 3.0, "min_upright": .98, "score": 42.0,
            "simulation_seconds": 12.0, **changes}


def candidates(count=4):
    return [{"policy": dict(DEFAULT_POLICY), "reason": "Test fixture"} for _ in range(count)]


def response(**changes):
    return {"status": "completed", "output": [{"type": "message", "content": [
        {"type": "output_text", "text": json.dumps({"candidates": candidates()})}]}],
        "usage": {"input_tokens": 80, "output_tokens": 40, "total_tokens": 120}, **changes}


def final_job(service, started):
    service._worker.join(4)
    if service._worker.is_alive():
        raise AssertionError("Pickup worker did not finish")
    return service.pickup.get(started["id"])


class ImmediateBipedEvaluator:
    def evaluate(self, request, policy, cancelled):
        return {"score": 1.0, "finite": True, "fallen": False}


class FixturePickupProposer:
    def propose(self, request, cancelled, on_dispatch, on_usage):
        on_dispatch()
        on_usage({"input_tokens": 80, "output_tokens": 40, "total_tokens": 120})
        return candidates(request["count"])


class ValidationTests(unittest.TestCase):
    def test_default_policy_and_all_numeric_bounds(self):
        self.assertEqual(validate_policy(DEFAULT_POLICY), DEFAULT_POLICY)
        for key, (low, high) in BOUNDS.items():
            for value in (low, high):
                validate_policy({**DEFAULT_POLICY, key: value})
            for value in (low - .001, high + .001, True, False, "1", None,
                          float("nan"), float("inf"), 10**1000):
                with self.subTest(key=key, value=str(value)[:20]), self.assertRaises(LabError):
                    validate_policy({**DEFAULT_POLICY, key: value})
        for value in ({}, [], None, {**DEFAULT_POLICY, "code": "run()"}):
            with self.assertRaises(LabError):
                validate_policy(value)

    def test_request_schema_size_and_integer_limits(self):
        good = validate_request(request())
        self.assertEqual(good["round"], 0)
        self.assertEqual(good["history"], [])
        for count in range(1, 5):
            self.assertEqual(validate_request(request(count=count))["count"], count)
        invalid = [None, [], {}, request(count=True), request(count=0), request(count=5),
                   request(round=True), request(round=-1), request(round=32),
                   request(graph_fingerprint="A" * 64), request(graph_fingerprint="../scene"),
                   request(goal=" "), request(goal="x" * 2001), request(goal="x" * 70000),
                   request(allow_paid=1), request(model="other"), request(history={}),
                   request(history=[{}] * 33), request(history=[{"policy": DEFAULT_POLICY}]),
                   request(history=[{"policy": DEFAULT_POLICY, "metrics": metrics(), "code": "x"}])]
        for value in invalid:
            with self.subTest(value=str(value)[:60]), self.assertRaises(LabError):
                validate_request(value)

    def test_exact_feedback_subset_and_isolation(self):
        payload = request(history=[{"policy": dict(DEFAULT_POLICY), "metrics": metrics()}])
        result = validate_request(payload)
        self.assertEqual(result["history"], payload["history"])
        payload["history"][0]["metrics"]["score"] = -99
        self.assertEqual(result["history"][0]["metrics"]["score"], 42)
        for value in (metrics(finite=1), metrics(score=True), metrics(score=float("nan")),
                      metrics(score=10**1000), metrics(simulation_seconds=-1),
                      metrics(min_upright=2), metrics(secret="not allowed"), {}, []):
            with self.subTest(value=str(value)[:60]), self.assertRaises(LabError):
                validate_metrics(value)
        validate_metrics(metrics(finite=False, fallen=True, success=False))

    def test_candidate_schema_count_reason_and_policy(self):
        self.assertEqual(len(validate_candidates(candidates(), 4)), 4)
        for value in ([], candidates(3), candidates(5), {}, [None] * 4,
                      [{"policy": DEFAULT_POLICY, "reason": "", "code": "x"}] * 4,
                      [{"policy": DEFAULT_POLICY, "reason": " "}] * 4,
                      [{"policy": DEFAULT_POLICY, "reason": "x" * 401}] * 4,
                      [{"policy": {}, "reason": "fixture"}] * 4):
            with self.assertRaises(LabError):
                validate_candidates(value, 4)


class APITests(unittest.TestCase):
    def invoke(self, value, cancelled=None, dispatch=None, usage=None):
        self.dispatches, self.usages = [], []
        with patch("tools.motion_lab.pickup.urllib.request.build_opener") as build:
            raw = value if isinstance(value, bytes) else json.dumps(value).encode()
            build.return_value.open.return_value = io.BytesIO(raw)
            result = OpenAIPickupProposer("synthetic-secret-key").propose(
                validate_request(request()), cancelled or threading.Event(),
                dispatch or (lambda: self.dispatches.append(1)),
                usage or self.usages.append,
            )
            req = build.return_value.open.call_args.args[0]
            self.payload = json.loads(req.data)
            self.assertEqual(req.full_url, "https://api.openai.com/v1/responses")
            self.assertEqual(build.return_value.open.call_count, 1)
            self.assertEqual(build.return_value.open.call_args.kwargs["timeout"], 45)
        return result

    def test_exact_model_one_call_strict_bounded_batch_no_tools_no_storage(self):
        result = self.invoke(response())
        self.assertEqual(len(result), 4)
        self.assertEqual(self.payload["model"], MODEL)
        self.assertFalse(self.payload["store"])
        self.assertNotIn("tools", self.payload)
        self.assertLessEqual(self.payload["max_output_tokens"], 2048)
        self.assertNotIn("synthetic-secret-key", json.dumps(self.payload))
        self.assertEqual(self.dispatches, [1])
        self.assertEqual(self.usages[0]["total_tokens"], 120)
        schema = self.payload["text"]["format"]
        self.assertTrue(schema["strict"])
        self.assertEqual(schema["schema"]["properties"]["candidates"]["minItems"], 4)
        self.assertEqual(schema["schema"]["properties"]["candidates"]["maxItems"], 4)
        self.assertIn("NOT model-weight training", self.payload["instructions"])
        self.assertIn("NOT independently verified", self.payload["instructions"])

    def test_incomplete_refusal_and_bad_shape_fail_but_retain_valid_usage(self):
        cases = [response(status="incomplete"), response(output=[]),
                 response(output=[{"type": "message", "content": [{"type": "refusal"}]}]),
                 response(output={}), response(output=[None]),
                 response(output=[{"type": "message", "content": [None]}]),
                 response(output=[{"type": "message", "content": [{"type": "output_text", "text": 1}]}]),
                 response(output=[{"type": "message", "content": [{"type": "output_text", "text": '{"candidates":[]}'}]}])]
        for value in cases:
            with self.subTest(value=value), self.assertRaises(LabError):
                self.invoke(value)
            self.assertEqual(self.usages[0]["total_tokens"], 120)

    def test_invalid_response_and_usage_are_sanitized(self):
        for value in (b"x" * 1_000_001, b"NaN", [], response(usage=[]),
                      response(usage={"input_tokens": True}),
                      response(usage={"input_tokens": -1})):
            with self.assertRaises(LabError):
                self.invoke(value)

    def test_missing_usage_stays_unknown_instead_of_claiming_zero_tokens(self):
        self.invoke(response(usage=None))
        self.assertEqual(self.usages, [{}])
        self.invoke(response(usage={}))
        self.assertEqual(self.usages, [{}])

    def test_http_error_no_retry_no_secret_body(self):
        for error in (urllib.error.HTTPError("https://api.openai.com", 429, "upstream secret", {}, None),
                      urllib.error.URLError("upstream secret"), TimeoutError("upstream secret")):
            calls = []
            with patch("tools.motion_lab.pickup.urllib.request.build_opener") as build:
                build.return_value.open.side_effect = error
                with self.assertRaises(LabError) as caught:
                    OpenAIPickupProposer("synthetic-key").propose(
                        validate_request(request()), threading.Event(), lambda: calls.append(1), lambda usage: None)
                self.assertNotIn("secret", str(caught.exception))
                self.assertEqual(calls, [1])
                self.assertEqual(build.return_value.open.call_count, 1)

    def test_pre_cancel_and_encoding_cancel_never_dispatch(self):
        cancelled = threading.Event()
        cancelled.set()
        with patch("tools.motion_lab.pickup.urllib.request.build_opener") as build:
            with self.assertRaises(LabError):
                OpenAIPickupProposer("synthetic-key").propose(
                    validate_request(request()), cancelled,
                    lambda: self.fail("Pre-cancelled request must not dispatch"), lambda usage: None)
            build.assert_not_called()
        cancelled.clear()
        original_dumps = json.dumps

        def encode_cancel(value, *args, **kwargs):
            encoded = original_dumps(value, *args, **kwargs)
            if isinstance(value, dict) and value.get("model") == MODEL:
                cancelled.set()
            return encoded

        with patch("tools.motion_lab.pickup.json.dumps", side_effect=encode_cancel):
            with patch("tools.motion_lab.pickup.urllib.request.build_opener") as build:
                with self.assertRaises(LabError):
                    OpenAIPickupProposer("synthetic-key").propose(
                        validate_request(request()), cancelled,
                        lambda: self.fail("Encoding-cancelled request must not dispatch"), lambda usage: None)
                build.assert_not_called()


class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.services = []

    def tearDown(self):
        for service in self.services:
            service.close()

    def service(self, **kwargs):
        service = MotionService(PROJECT, api_key=kwargs.pop("api_key", ""), **kwargs)
        self.services.append(service)
        return service

    def test_mock_reports_no_gpt_calls_and_uses_best_eligible_feedback(self):
        service = self.service()
        changed = {**DEFAULT_POLICY, "torso_lean_deg": 30.0}
        failed = {**DEFAULT_POLICY, "torso_lean_deg": 15.0}
        history = [{"policy": changed, "metrics": metrics()},
                   {"policy": failed, "metrics": metrics(fallen=True, score=100)}]
        final = final_job(service, service.pickup.start(request(history=history)))
        self.assertEqual(final["state"], "completed")
        self.assertEqual(final["mode"], "mock")
        self.assertEqual(final["api_calls"], 0)
        self.assertEqual(service.calls_used, 0)
        self.assertEqual(final["candidates"][0]["policy"]["torso_lean_deg"], 28)
        final["candidates"][0]["policy"]["torso_lean_deg"] = 999
        self.assertNotEqual(service.pickup.get(final["id"])["candidates"][0]["policy"]["torso_lean_deg"], 999)
        self.assertTrue(service.describe()["pickup"]["supported"])

    def test_missing_key_consent_and_budget_are_checked(self):
        missing = self.service(provider="openai")
        with self.assertRaisesRegex(LabError, "OPENAI_API_KEY"):
            missing.pickup.start(request(allow_paid=True))
        live = self.service(provider="openai", api_key="synthetic-key", max_calls=1,
                            pickup_proposer=FixturePickupProposer())
        with self.assertRaisesRegex(LabError, "allow_paid"):
            live.pickup.start(request())
        final = final_job(live, live.pickup.start(request(allow_paid=True)))
        self.assertEqual(final["api_calls"], 1)
        self.assertEqual(live.calls_used, 1)
        self.assertEqual(final["usage"]["total_tokens"], 120)
        self.assertNotIn("synthetic-key", json.dumps(final) + json.dumps(live.describe()))
        with self.assertRaisesRegex(LabError, "budget"):
            live.pickup.start(request(allow_paid=True))
        with self.assertRaisesRegex(LabError, "budget"):
            live.start({"rounds": 1, "allow_paid": True})

    def test_biped_call_consumes_same_budget(self):
        class BipedProposer:
            def propose(self, request, history, index, cancelled=None):
                return dict(request["policy"]), "fixture", {}

        service = self.service(provider="openai", api_key="synthetic-key", max_calls=1,
                               evaluator=ImmediateBipedEvaluator(), proposer=BipedProposer(),
                               pickup_proposer=FixturePickupProposer())
        started = service.start({"rounds": 1, "allow_paid": True})
        service._worker.join(4)
        self.assertEqual(service.get(started["id"])["state"], "completed")
        with self.assertRaisesRegex(LabError, "budget"):
            service.pickup.start(request(allow_paid=True))

    def test_failed_call_still_counts_and_invalid_proposal_retains_usage(self):
        class FailingProposer(FixturePickupProposer):
            def propose(self, request, cancelled, on_dispatch, on_usage):
                super().propose(request, cancelled, on_dispatch, on_usage)
                return []

        service = self.service(provider="openai", api_key="synthetic-key", max_calls=1,
                               pickup_proposer=FailingProposer())
        final = final_job(service, service.pickup.start(request(allow_paid=True)))
        self.assertEqual(final["state"], "failed")
        self.assertEqual(final["candidates"], [])
        self.assertEqual(final["usage"]["total_tokens"], 120)
        self.assertEqual(service.calls_used, 1)

    def test_cancellation_before_dispatch_is_free_and_rejects_biped_overlap(self):
        entered, release = threading.Event(), threading.Event()

        class DelayedProposer(FixturePickupProposer):
            def propose(self, request, cancelled, on_dispatch, on_usage):
                entered.set()
                if not release.wait(3):
                    raise AssertionError("Dispatch barrier timed out")
                return super().propose(request, cancelled, on_dispatch, on_usage)

        service = self.service(provider="openai", api_key="synthetic-key", max_calls=1,
                               pickup_proposer=DelayedProposer())
        try:
            started = service.pickup.start(request(allow_paid=True))
            self.assertTrue(entered.wait(3))
            with self.assertRaisesRegex(LabError, "already running"):
                service.start({"rounds": 1, "allow_paid": True})
            with self.assertRaisesRegex(LabError, "already running"):
                service.pickup.start(request(allow_paid=True))
            self.assertEqual(service.pickup.cancel(started["id"])["state"], "cancelling")
            release.set()
            final = final_job(service, started)
            self.assertEqual(final["state"], "cancelled")
            self.assertTrue(final["cancel_requested"])
            self.assertEqual(final["api_calls"], 0)
            self.assertEqual(service.calls_used, 0)
        finally:
            release.set()

    def test_cancel_in_flight_retains_billable_usage_without_candidates(self):
        entered, release = threading.Event(), threading.Event()

        class InFlightProposer:
            def propose(self, request, cancelled, on_dispatch, on_usage):
                on_dispatch()
                entered.set()
                if not release.wait(3):
                    raise AssertionError("Response barrier timed out")
                on_usage({"input_tokens": 80, "output_tokens": 40, "total_tokens": 120})
                return candidates(request["count"])

        service = self.service(provider="openai", api_key="synthetic-key", max_calls=1,
                               pickup_proposer=InFlightProposer())
        try:
            started = service.pickup.start(request(allow_paid=True))
            self.assertTrue(entered.wait(3))
            service.pickup.cancel(started["id"])
            release.set()
            final = final_job(service, started)
            self.assertEqual(final["state"], "cancelled")
            self.assertEqual(final["api_calls"], 1)
            self.assertEqual(final["usage"]["total_tokens"], 120)
            self.assertEqual(final["candidates"], [])
        finally:
            release.set()

    def test_close_cancels_pickup_and_rejects_new_jobs(self):
        entered = threading.Event()

        class WaitingProposer:
            def propose(self, request, cancelled, on_dispatch, on_usage):
                entered.set()
                cancelled.wait(3)
                on_dispatch()
                return candidates()

        service = self.service(pickup_proposer=WaitingProposer())
        started = service.pickup.start(request())
        self.assertTrue(entered.wait(3))
        service.close()
        self.assertEqual(service.pickup.get(started["id"])["state"], "cancelled")
        with self.assertRaisesRegex(LabError, "closed"):
            service.pickup.start(request())


class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.service = MotionService(PROJECT, api_key="")
        self.token = "synthetic-local-pickup-token-12345"
        self.server = make_server(self.service, self.token, port=0, origins=["http://localhost:8060"])
        self.worker = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.worker.start()
        self.url = "http://127.0.0.1:" + str(self.server.server_address[1])

    def tearDown(self):
        self.service.close()
        self.server.shutdown()
        self.server.server_close()
        self.worker.join(2)

    def http(self, path, payload=None, authorized=True, **headers):
        headers = {"Content-Type": "application/json", **headers}
        if authorized:
            headers["Authorization"] = "Bearer " + self.token
        req = urllib.request.Request(self.url + path,
                                     data=json.dumps(payload).encode() if payload is not None else None,
                                     headers=headers)
        try:
            result = urllib.request.urlopen(req, timeout=3)
        except urllib.error.HTTPError as exc:
            result = exc
        with result:
            return result.status, json.load(result), result.headers

    def test_propose_poll_cancel_and_status(self):
        status, started, _ = self.http("/v1/pickup/propose", request())
        self.assertEqual(status, 202)
        final_job(self.service, started)
        status, final, _ = self.http("/v1/pickup/" + started["id"])
        self.assertEqual(status, 200)
        self.assertEqual(final["state"], "completed")
        self.assertEqual(len(final["candidates"]), 4)
        self.assertEqual(self.http("/v1/pickup/" + started["id"] + "/cancel", {})[0], 200)
        self.assertEqual(self.http("/v1/pickup/" + started["id"] + "/cancel", {"bad": 1})[0], 400)
        self.assertTrue(self.http("/v1/status")[1]["pickup"]["supported"])
        self.assertEqual(self.http("/v1/pickup/unknown")[0], 400)

    def test_auth_origin_size_and_content_type(self):
        self.assertEqual(self.http("/v1/pickup/propose", request(), authorized=False)[0], 401)
        self.assertEqual(self.http("/v1/pickup/propose", request(), Origin="https://evil.invalid")[0], 403)
        self.assertEqual(self.http("/v1/pickup/propose", request(), Host="evil.invalid")[0], 403)
        self.assertEqual(self.http("/v1/pickup/propose", request(), **{"Content-Type": "text/plain"})[0], 415)
        self.assertEqual(self.http("/v1/pickup/propose", request(goal="x" * 70000))[0], 413)
        status, _, headers = self.http("/v1/pickup/propose", request(), Origin="http://localhost:8060")
        self.assertEqual(status, 202)
        self.assertEqual(headers["Access-Control-Allow-Origin"], "http://localhost:8060")
        self.assertEqual(headers["Cache-Control"], "no-store")

    def test_concurrent_mixed_http_jobs_accept_exactly_one(self):
        class WaitingProposer:
            def propose(self, request, cancelled, on_dispatch, on_usage):
                cancelled.wait(5)
                raise LabError("Cancelled")

        class WaitingEvaluator:
            def evaluate(self, request, policy, cancelled):
                cancelled.wait(5)
                raise LabError("Cancelled")

        self.service.pickup._proposer = WaitingProposer()
        self.service._evaluator = WaitingEvaluator()

        def start(index):
            return self.http("/v1/pickup/propose", request()) if index % 2 else self.http("/v1/search", {})

        with ThreadPoolExecutor(max_workers=8) as pool:
            result = list(pool.map(start, range(8)))
        self.assertEqual(sum(code == 202 for code, _, _ in result), 1)
        self.assertEqual(sum(code == 400 for code, _, _ in result), 7)
        self.assertEqual(len(self.service._jobs) + len(self.service.pickup._jobs), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
