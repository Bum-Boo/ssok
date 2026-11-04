"""One bounded camera-only goal session; never calls a provider or starts Godot."""
import json
import os
from pathlib import Path
import threading
import time
from typing import Any

from .desktop_client import DesktopClient, DesktopError, Observation, CONTEXT_KEYS, assert_context, write_observation


def validate_goal_context(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != {"episode_id", "revision", "control_generation"}:
        raise DesktopError("Invalid claimed goal context.")
    if not isinstance(value["episode_id"], str) or not 1 <= len(value["episode_id"]) <= 256:
        raise DesktopError("Invalid claimed episode.")
    if any(type(value[key]) is not int or value[key] < 0 for key in ("revision", "control_generation")):
        raise DesktopError("Invalid claimed goal generation.")
    return dict(value)


class DesktopGoalSession:
    def __init__(self, client: DesktopClient, output: Path, *, max_steps: int = 4,
                 max_observations: int = 5, seconds: int = 240,
                 provider: str = "OpenAI / gpt-6-astra / Codex CLI",
                 expected_context: dict[str, Any] | None = None) -> None:
        for value, lower, upper in ((max_steps, 1, 8), (max_observations, 2, 9), (seconds, 15, 600)):
            if type(value) is not int or not lower <= value <= upper:
                raise DesktopError("Invalid goal session limit.")
        if max_observations < max_steps + 1:
            raise DesktopError("Reserve a final observation after every allowed action.")
        if not isinstance(provider, str) or not 1 <= len(provider) <= 80:
            raise DesktopError("Invalid goal provider label.")
        token = os.environ.get("SSOK_AGENT_TOKEN", "")
        if token and token in provider:
            raise DesktopError("Provider label must not contain authentication data.")
        self.client, self.output, self.provider = client, Path(output), provider
        self.max_steps, self.max_observations = max_steps, max_observations
        self.deadline = time.monotonic() + seconds
        self.steps = self.observations = self.calls = 0
        self.frame: Observation | None = None
        self.last_frame_id: Any = None
        self.context: dict[str, Any] | None = validate_goal_context(expected_context) if expected_context is not None else None
        self.closed = threading.Event()
        self.lock = threading.Lock()
        self.output.mkdir(parents=True, exist_ok=False)
        self.record("session", {"max_steps": max_steps, "max_observations": max_observations,
                                "seconds": seconds, "provider": provider})

    def record(self, kind: str, data: dict[str, Any]) -> None:
        # Only explicitly constructed public fields reach this journal, never wire envelopes.
        with (self.output / "events.jsonl").open("a", encoding="utf-8") as handle:
            handle.write(json.dumps({"event": kind, "data": data}, ensure_ascii=False, allow_nan=False) + "\n")

    def stop(self, reason: str = "actor_stop") -> dict[str, Any]:
        self.closed.set()
        # Stop never waits behind the action lock; the app has its own priority Stop lane.
        if self.context is None:
            result = {"owner_revoked": True, "stop_scope": "unbound"}
            self.record("stop", {"reason": reason, "confirmed": True, "stop_scope": "unbound"})
            return result
        try:
            result = self.client.stop(self.context)
        except DesktopError:
            self.record("stop", {"reason": reason, "confirmed": False})
            raise DesktopError("Goal ended; desktop Stop could not be confirmed. Use local Stop.") from None
        self.record("stop", {"reason": reason, "confirmed": result.get("owner_revoked") is True,
                             "state": result.get("state", "unknown"), "stop_scope": result.get("stop_scope")})
        return result

    def _check(self) -> None:
        if self.closed.is_set():
            raise DesktopError("Goal session is closed; enable a new session intentionally.")
        if time.monotonic() >= self.deadline or self.calls >= 2 * self.max_observations + self.max_steps:
            raise DesktopError("Goal session time or tool-call limit reached.")
        self.calls += 1

    def _run(self, operation: Any) -> Any:
        if not self.lock.acquire(blocking=False):
            self.stop("concurrent_request")
            raise DesktopError("Concurrent goal requests are rejected; session stopped.")
        try:
            self._check()
            result = operation()
            if self.closed.is_set():
                raise DesktopError("Goal was stopped while the request was in flight.")
            return result
        except Exception:
            if not self.closed.is_set():
                self.stop("request_failed")
            raise
        finally:
            self.lock.release()

    def observe(self) -> Observation:
        def execute() -> Observation:
            if self.observations >= self.max_observations:
                raise DesktopError("Observation limit reached.")
            if self.frame is not None:
                raise DesktopError("Decide on the current frame before observing again.")
            context = self.client.describe()
            if self.context is not None:
                assert_context(self.context, context)
            else:
                if context.get("state") != "ready":
                    raise DesktopError("Enable a ready camera before binding a goal session.")
                # Bind before the request can fail; cleanup must never use global Stop.
                self.context = validate_goal_context({key: context[key] for key in CONTEXT_KEYS})
            frame = self.client.observe(context)
            if frame.metadata["frame_id"] == self.last_frame_id:
                raise DesktopError("Observation reused a consumed frame.")
            assert_context(self.context, frame.metadata)
            self.observations += 1
            write_observation(frame, self.output / f"observation-{self.observations}.png")
            self.frame = frame
            self.last_frame_id = frame.metadata["frame_id"]
            self.record("observe", {"observation": self.observations, "metadata": frame.metadata})
            return frame
        return self._run(execute)

    def decide(self, frame_sha256: str, summary: str, action: str, ticks: int) -> dict[str, Any]:
        def execute() -> dict[str, Any]:
            if self.frame is None or self.steps >= self.max_steps:
                raise DesktopError("A fresh observation and remaining step budget are required.")
            if action not in ("forward", "brake") or type(ticks) is not int or not 1 <= ticks <= 30:
                raise DesktopError("Only forward/brake for 1–30 physics ticks is supported.")
            token = os.environ.get("SSOK_AGENT_TOKEN", "")
            if not isinstance(summary, str) or not summary.strip() or len(summary) > 240 or any(ord(c) < 32 for c in summary):
                raise DesktopError("Supply a concise public observation summary, at most 240 characters.")
            if token and token in summary:
                raise DesktopError("Summary must not contain authentication data.")
            metadata = self.frame.metadata
            if frame_sha256 != metadata["sha256"]:
                raise DesktopError("Decision hash does not match the current camera PNG.")
            assert_context(metadata, self.client.describe(), include_frame=True)
            self.client.trace_dispatch(metadata["frame_id"], metadata["sha256"], metadata["control_generation"],
                                       summary, self.provider, self.max_steps, episode_id=metadata["episode_id"])
            self.record("decision", {"step": self.steps + 1, "metadata": metadata, "summary": summary,
                                     "action": action, "ticks": ticks})
            self.frame = None  # A sent action is never retried, even if its reply is lost.
            self.steps += 1
            result = self.client.drive_step(metadata["frame_id"], metadata["revision"],
                                           metadata["control_generation"], ticks, action,
                                           episode_id=metadata["episode_id"])
            self.record("action_result", {"step": self.steps, "result": result})
            return result | {"steps_remaining": self.max_steps - self.steps,
                             "observations_remaining": self.max_observations - self.observations}
        return self._run(execute)
