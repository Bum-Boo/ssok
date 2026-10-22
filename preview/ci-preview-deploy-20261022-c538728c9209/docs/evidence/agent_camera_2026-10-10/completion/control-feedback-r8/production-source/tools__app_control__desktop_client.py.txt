"""Bounded stdlib client for an opt-in, rendered ssok desktop session.

This connects to the open desktop app; it never launches the isolated headless
runner, invokes a provider, or retries an action. SSOK_AGENT_TOKEN is read only
from the operator's environment and is never returned or saved.
"""

from __future__ import annotations

import argparse
import base64
import binascii
from dataclasses import dataclass
import hashlib
import ipaddress
import json
import math
import os
from pathlib import Path
import re
import socket
import struct
import sys
import time
from typing import Any, Mapping
import uuid
import zlib

DEFAULT_PORT = 8127
MAX_REQUEST_BYTES = 1024 * 1024
MAX_RESPONSE_BYTES = 4 * 1024 * 1024
MAX_TIMEOUT = 15.0
TOOLS = frozenset({"describe", "observe", "drive_step", "stop", "trace_dispatch"})
METADATA_KEYS = frozenset({
    "episode_id", "robot_instance_id", "part_id", "camera_id", "frame_id",
    "revision", "control_generation", "settle_confirmed_tick",
    "capture_requested_tick", "draw_frame", "physics_tick", "width", "height",
    "sha256", "interpolation_enabled",
})
CONTEXT_KEYS = ("episode_id", "revision", "control_generation")


class DesktopError(Exception):
    """An operator-safe error, without request bodies or credentials."""


class DesktopServerError(DesktopError):
    """The app rejected a request; its raw error payload is never printed."""

    def __init__(self, code: str = "request_rejected") -> None:
        self.code = code
        super().__init__(f"Desktop request rejected ({code}); obtain fresh state or stop locally.")


def _integer(value: Any, label: str, minimum: int = 0, maximum: int | None = None) -> int:
    if type(value) is not int or value < minimum or (maximum is not None and value > maximum):
        raise DesktopError(f"Invalid {label}.")
    return value


def _identifier(value: Any, label: str) -> Any:
    if type(value) is int and value >= 0:
        return value
    if isinstance(value, str) and 0 < len(value) <= 256 and value.strip():
        return value
    raise DesktopError(f"Invalid {label}.")


def _episode(value: Any) -> str:
    if not isinstance(value, str) or not 0 < len(value) <= 256 or not value.strip():
        raise DesktopError("Invalid episode_id.")
    return value


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


def _constant(_: str) -> None:
    raise ValueError("Nonfinite JSON")


def _json(data: bytes) -> Any:
    try:
        return json.loads(data.decode("utf-8"), object_pairs_hook=_pairs, parse_constant=_constant)
    except (UnicodeError, ValueError, RecursionError):
        raise DesktopError("Invalid JSON response or frame metadata.") from None


def _contains_secret(value: Any, secret: str) -> bool:
    pending = [value]
    while pending:
        item = pending.pop()
        if isinstance(item, str) and secret in item:
            return True
        if isinstance(item, dict):
            pending.extend(item.keys())
            pending.extend(item.values())
        elif isinstance(item, list):
            pending.extend(item)
    return False


def validate_metadata(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != METADATA_KEYS:
        raise DesktopError("Frame metadata does not match the rendered camera schema.")
    for key in ("episode_id", "robot_instance_id", "part_id", "camera_id", "frame_id"):
        _identifier(value[key], key)
    _episode(value["episode_id"])
    for key in ("revision", "control_generation", "settle_confirmed_tick",
                "capture_requested_tick", "draw_frame", "physics_tick"):
        _integer(value[key], key)
    for key in ("width", "height"):
        _integer(value[key], key, 1, 8192)
    if value["width"] * value["height"] > 16 * 1024 * 1024:
        raise DesktopError("Frame dimensions exceed the camera image limit.")
    if not value["settle_confirmed_tick"] <= value["capture_requested_tick"] <= value["physics_tick"]:
        raise DesktopError("Frame capture precedes confirmed physical settling.")
    if type(value["interpolation_enabled"]) is not bool:
        raise DesktopError("Invalid frame interpolation setting.")
    if not isinstance(value["sha256"], str) or not re.fullmatch(r"[0-9a-f]{64}", value["sha256"]):
        raise DesktopError("Invalid frame SHA-256.")
    return dict(value)


def assert_context(frame: Mapping[str, Any], context: Mapping[str, Any], *, include_frame: bool = False) -> None:
    keys = CONTEXT_KEYS + (("frame_id",) if include_frame else ())
    if any(key not in context or frame.get(key) != context[key] for key in keys):
        raise DesktopError("Frame context is stale; observe the current desktop session again.")


def _png_dimensions(png: bytes) -> tuple[int, int]:
    if not png.startswith(b"\x89PNG\r\n\x1a\n"):
        raise DesktopError("Observation is not a PNG image.")
    offset = 8
    dimensions: tuple[int, int] | None = None
    has_data = False
    while offset < len(png):
        if len(png) - offset < 12:
            break
        size = struct.unpack_from(">I", png, offset)[0]
        end = offset + 12 + size
        if end > len(png):
            break
        kind = png[offset + 4:offset + 8]
        data = png[offset + 8:offset + 8 + size]
        crc = struct.unpack_from(">I", png, offset + 8 + size)[0]
        if zlib.crc32(kind + data) & 0xFFFFFFFF != crc:
            raise DesktopError("PNG chunk checksum mismatch.")
        if dimensions is None:
            if kind != b"IHDR" or size != 13:
                raise DesktopError("PNG has no valid first image header.")
            dimensions = struct.unpack_from(">II", data)
        elif kind == b"IHDR":
            raise DesktopError("PNG contains multiple image headers.")
        if kind == b"IDAT" and size:
            has_data = True
        if kind == b"IEND":
            if size or end != len(png) or not has_data:
                break
            return dimensions
        offset = end
    raise DesktopError("PNG is truncated or has no complete image data.")


@dataclass(frozen=True)
class Observation:
    metadata: dict[str, Any]
    png: bytes

    def verify(self) -> None:
        metadata = validate_metadata(self.metadata)
        if len(self.png) > MAX_RESPONSE_BYTES:
            raise DesktopError("PNG exceeds the response limit.")
        if hashlib.sha256(self.png).hexdigest() != metadata["sha256"]:
            raise DesktopError("PNG SHA-256 does not match the captured frame.")
        if _png_dimensions(self.png) != (metadata["width"], metadata["height"]):
            raise DesktopError("PNG dimensions do not match the captured frame.")

    def wire_data(self) -> dict[str, Any]:
        self.verify()
        return {"metadata": dict(self.metadata), "png_base64": base64.b64encode(self.png).decode("ascii")}


class DesktopClient:
    def __init__(self, host: str = "127.0.0.1", port: int = DEFAULT_PORT, timeout: float = MAX_TIMEOUT, *, allow_operator: bool = False) -> None:
        try:
            if not ipaddress.ip_address(host).is_loopback:
                raise ValueError
        except ValueError:
            raise DesktopError("Desktop host must be a literal loopback IP address.") from None
        _integer(port, "port", 1, 65535)
        if isinstance(timeout, bool) or not isinstance(timeout, (float, int)) or not math.isfinite(timeout) or not 0 < timeout <= MAX_TIMEOUT:
            raise DesktopError("Desktop timeout must be finite, positive and at most 15 seconds.")
        self.host, self.port, self.timeout = host, port, float(timeout)
        if type(allow_operator) is not bool:
            raise DesktopError("Invalid operator capability.")
        self.allow_operator = allow_operator

    def request(self, tool: str, args: Mapping[str, Any] | None = None) -> dict[str, Any]:
        operator_tool = self.allow_operator and tool in ("operator_poll", "operator_leave")
        if (tool not in TOOLS and not operator_tool) or (args is not None and not isinstance(args, Mapping)):
            raise DesktopError("Unsupported desktop tool or arguments.")
        token = os.environ.get("SSOK_AGENT_TOKEN", "")
        if len(token) < 32:
            raise DesktopError("Set SSOK_AGENT_TOKEN in the operator environment (at least 32 characters).")
        if _contains_secret(dict(args or {}), token):
            raise DesktopError("Desktop arguments must not contain authentication data.")
        request_id = uuid.uuid4().hex
        try:
            wire = (json.dumps({"id": request_id, "token": token, "tool": tool, "args": dict(args or {})},
                               allow_nan=False, separators=(",", ":")) + "\n").encode("utf-8")
        except (TypeError, ValueError, RecursionError, UnicodeError):
            raise DesktopError("Desktop arguments must contain finite JSON data.") from None
        if len(wire) > MAX_REQUEST_BYTES:
            raise DesktopError("Desktop request exceeds the 1 MiB limit.")
        deadline = time.monotonic() + self.timeout

        def remaining() -> float:
            seconds = deadline - time.monotonic()
            if seconds <= 0:
                raise TimeoutError
            return seconds

        try:
            with socket.create_connection((self.host, self.port), timeout=remaining()) as connection:
                connection.settimeout(remaining())
                connection.sendall(wire)
                body = bytearray()
                while True:
                    connection.settimeout(remaining())
                    chunk = connection.recv(min(65536, MAX_RESPONSE_BYTES + 1 - len(body)))
                    if not chunk:
                        break
                    body.extend(chunk)
                    if len(body) > MAX_RESPONSE_BYTES:
                        raise DesktopError("Desktop response exceeds the 4 MiB limit.")
        except TimeoutError:
            raise DesktopError("Desktop operation timed out; no automatic retry or resume was performed.") from None
        except OSError:
            raise DesktopError("Desktop connection failed or closed; no automatic retry was performed.") from None
        if not body.endswith(b"\n") or body.count(b"\n") != 1:
            raise DesktopError("Expected one complete NDJSON reply followed by connection close.")
        response = _json(bytes(body[:-1]))
        if _contains_secret(response, token):
            raise DesktopError("Desktop response improperly contains authentication data.")
        if not isinstance(response, dict) or response.get("id") != request_id:
            raise DesktopError("Desktop response ID does not match this request.")
        if set(response) == {"id", "error"}:
            error = response["error"]
            code = error.get("code", "request_rejected") if isinstance(error, dict) else error
            if not isinstance(code, str) or not re.fullmatch(r"[a-z][a-z0-9_]{0,63}", code):
                code = "request_rejected"
            raise DesktopServerError(code)
        if set(response) != {"id", "data"} or not isinstance(response["data"], dict):
            raise DesktopError("Invalid desktop response envelope.")
        return response["data"]

    def describe(self) -> dict[str, Any]:
        data = self.request("describe")
        if not {"state", "revision", "control_generation", "episode_id", "frame_id"} <= set(data):
            raise DesktopError("Incomplete rendered desktop state.")
        if not isinstance(data["state"], str) or not data["state"]:
            raise DesktopError("Invalid desktop state.")
        for key in ("revision", "control_generation"):
            _integer(data[key], key)
        if data["episode_id"] != "" or not (data["state"] == "disabled" or data.get("enabled") is False):
            _episode(data["episode_id"])
        # An idle session may not yet have captured any frame.
        if data["frame_id"] is not None:
            _identifier(data["frame_id"], "frame_id")
        return {key: data[key] for key in ("state", "revision", "control_generation", "episode_id", "frame_id")}

    def observe(self, expected_context: Mapping[str, Any] | None = None) -> Observation:
        data = self.request("observe")
        if set(data) != {"metadata", "png_base64"} or not isinstance(data["png_base64"], str):
            raise DesktopError("Incomplete rendered camera observation.")
        metadata = validate_metadata(data["metadata"])
        try:
            png = base64.b64decode(data["png_base64"], validate=True)
        except (ValueError, binascii.Error):
            raise DesktopError("Invalid camera PNG base64.") from None
        observation = Observation(metadata, png)
        observation.verify()
        if expected_context is not None:
            assert_context(metadata, expected_context)
        return observation

    def drive_step(self, frame_id: Any, revision: int, control_generation: int, ticks: int,
                   action: str = "forward", *, episode_id: str) -> dict[str, Any]:
        _episode(episode_id)
        _identifier(frame_id, "frame_id")
        _integer(revision, "revision")
        _integer(control_generation, "control_generation")
        _integer(ticks, "ticks", 1, 30)
        if action not in ("forward", "brake"):
            raise DesktopError("Action must be forward or brake.")
        data = self.request("drive_step", {"episode_id": episode_id, "frame_id": frame_id, "revision": revision,
                            "control_generation": control_generation, "ticks": ticks, "action": action})
        if data.get("episode_id") != episode_id:
            raise DesktopError("Desktop step reply refers to a different consumed episode.")
        if data.get("frame_id") != frame_id:
            raise DesktopError("Desktop step reply refers to a different consumed frame.")
        if not isinstance(data.get("state"), str) or not data["state"]:
            raise DesktopError("Desktop step reply has no completion state.")
        if "settle_confirmed_tick" in data:
            _integer(data["settle_confirmed_tick"], "settle_confirmed_tick")
        if "success" in data and type(data["success"]) is not bool:
            raise DesktopError("Invalid desktop step success status.")
        return {key: data[key] for key in ("state", "episode_id", "frame_id", "settle_confirmed_tick", "success") if key in data}

    def stop(self, expected_context: Mapping[str, Any] | None = None) -> dict[str, Any]:
        args = {}
        if expected_context is not None:
            if not all(key in expected_context for key in CONTEXT_KEYS):
                raise DesktopError("Incomplete Stop owner context.")
            args = {key: expected_context[key] for key in CONTEXT_KEYS}
            _episode(args["episode_id"])
            for key in ("revision", "control_generation"):
                _integer(args[key], key)
        data = self.request("stop", args)
        if expected_context is not None and (data.get("owner_revoked") is not True
                or data.get("stop_scope") not in ("matched_context", "context_replaced")):
            raise DesktopError("Desktop did not confirm scoped owner revocation.")
        return {key: data[key] for key in ("state", "revision", "control_generation", "episode_id", "frame_id",
                                         "owner_revoked", "stop_scope") if key in data}

    def trace_dispatch(self, frame_id: Any, sha256: str, control_generation: int,
                       summary: str, provider: str, max_calls: int, *, episode_id: str) -> dict[str, Any]:
        _episode(episode_id)
        _identifier(frame_id, "frame_id")
        _integer(control_generation, "control_generation")
        _integer(max_calls, "max_calls", 1, 100)
        if not isinstance(sha256, str) or not re.fullmatch(r"[0-9a-f]{64}", sha256):
            raise DesktopError("Invalid dispatch frame SHA-256.")
        if not isinstance(summary, str) or len(summary) > 240 or not isinstance(provider, str) or not 1 <= len(provider) <= 80:
            raise DesktopError("Dispatch requires a provider and a summary of at most 240 characters.")
        return self.request("trace_dispatch", {"episode_id": episode_id, "frame_id": frame_id, "sha256": sha256,
                            "control_generation": control_generation, "summary": summary,
                            "provider": provider, "max_calls": max_calls})


def write_observation(observation: Observation, output: Path | str) -> Path:
    observation.verify()
    output = Path(output)
    if output.suffix.lower() != ".png":
        raise DesktopError("Observation output must have a .png extension.")
    metadata_path = output.with_suffix(".json")
    try:
        output.write_bytes(observation.png)
        metadata_path.write_text(json.dumps(observation.metadata, indent=2, allow_nan=False) + "\n", encoding="utf-8")
        load_observation(metadata_path)
    except OSError:
        raise DesktopError("Could not write or read back the observation files.") from None
    return metadata_path


def load_observation(frame: Path | str) -> Observation:
    frame = Path(frame)
    if frame.suffix.lower() not in (".png", ".json"):
        raise DesktopError("Frame must name the saved .png or its .json sidecar.")
    try:
        with frame.with_suffix(".json").open("rb") as handle:
            metadata_bytes = handle.read(65537)
        with frame.with_suffix(".png").open("rb") as handle:
            png = handle.read(MAX_RESPONSE_BYTES + 1)
    except OSError:
        raise DesktopError("Could not read the frame PNG and JSON sidecar.") from None
    if len(metadata_bytes) > 65536:
        raise DesktopError("Frame metadata exceeds its size limit.")
    observation = Observation(validate_metadata(_json(metadata_bytes)), png)
    observation.verify()
    return observation


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1", help="Literal loopback address of the open desktop app")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--timeout", type=float, default=MAX_TIMEOUT, help="Total request deadline, at most 15 seconds")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("describe")
    observe = commands.add_parser("observe", help="Wait for settling and actual rendering, then save a verified frame")
    observe.add_argument("--out", type=Path, required=True)
    step = commands.add_parser("step", help="Consume one current observation; wait for finite action and settling")
    step.add_argument("--frame", type=Path, required=True)
    step.add_argument("--ticks", type=int, required=True)
    step.add_argument("--action", choices=("forward", "brake"), default="forward")
    commands.add_parser("stop", help="Release agent control; no revision or action capability required")
    trace = commands.add_parser("trace-dispatch", help="Record an operator-side dispatch receipt; makes no provider call")
    trace.add_argument("--frame", type=Path, required=True)
    trace.add_argument("--summary", required=True)
    trace.add_argument("--provider", required=True)
    trace.add_argument("--max-calls", type=int, required=True)
    args = parser.parse_args(argv)
    try:
        client = DesktopClient(args.host, args.port, args.timeout)
        if args.command == "describe":
            result = client.describe()
        elif args.command == "observe":
            observation = client.observe(client.describe())
            write_observation(observation, args.out)
            result = observation.metadata
        elif args.command in ("step", "trace-dispatch"):
            observation = load_observation(args.frame)
            metadata = observation.metadata
            assert_context(metadata, client.describe(), include_frame=True)
            if args.command == "step":
                result = client.drive_step(metadata["frame_id"], metadata["revision"],
                                           metadata["control_generation"], args.ticks, args.action,
                                           episode_id=metadata["episode_id"])
            else:
                result = client.trace_dispatch(metadata["frame_id"], metadata["sha256"],
                                               metadata["control_generation"], args.summary, args.provider, args.max_calls,
                                               episode_id=metadata["episode_id"])
        else:
            result = client.stop()
        print(json.dumps(result, allow_nan=False))
        return 0
    except DesktopError as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
