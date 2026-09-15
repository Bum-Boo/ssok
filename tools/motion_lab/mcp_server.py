"""Optional stdio-only MCP adapter for the bounded motion service.

Run from the repository root with ``python -m tools.motion_lab.mcp_server``.
The official SDK owns protocol negotiation and framing; stdout is protocol-only.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import TYPE_CHECKING, Annotated, Any

from mcp.server import MCPServer
from mcp.server.mcpserver.exceptions import ToolError
from mcp.types import ToolAnnotations
from pydantic import BaseModel, ConfigDict, Field, StrictBool, field_validator

if TYPE_CHECKING:
    from .service import MotionService


class SearchRequest(BaseModel):
    """Only data accepted by the motion service, never code or process options."""

    model_config = ConfigDict(extra="forbid", strict=True, allow_inf_nan=False)

    goal: Annotated[str, Field(min_length=1, max_length=2000)]
    graph: dict[str, Any] | None = None
    policy: dict[str, Any] | None = None
    command: Annotated[list[float], Field(min_length=2, max_length=2)] | None = None
    rounds: Annotated[int, Field(ge=1, le=4)] = 2
    allow_paid: StrictBool = False

    @field_validator("goal")
    @classmethod
    def nonempty_goal(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("goal must not be blank")
        return value

    @field_validator("command")
    @classmethod
    def bounded_command(cls, value: list[float] | None) -> list[float] | None:
        if value is not None and any(abs(axis) > 1.0 for axis in value):
            raise ValueError("command axes must be between -1 and 1")
        return value


def create_server(service: MotionService) -> MCPServer:
    """Bind an already-configured service without creating a network listener."""
    from .service import LabError, MAX_BODY, validate_request

    server = MCPServer(
        "ssok-motion-lab",
        version="0.1.0",
        instructions=(
            "Bounded simulated biped parameter search, not model training or real robot control. "
            "Describe first; start only at the user's request. Paid requests require explicit "
            "user consent and operator-enabled live mode. Results are proposals: applying them "
            "requires a separate human action in ssok. Never request API keys or source execution."
        ),
        log_level="WARNING",
    )

    def invoke(method: str, *args: Any) -> dict[str, Any]:
        try:
            return getattr(service, method)(*args)
        except LabError as exc:
            raise ToolError(str(exc)) from None
        except (ValueError, KeyError, RuntimeError):
            # Unexpected exception text can contain paths, request bodies or credentials.
            raise ToolError("Motion request rejected; check the documented input and job state.") from None
        except Exception:
            raise ToolError("Motion service failed; inspect the operator-side diagnostics.") from None

    read_only = ToolAnnotations(
        read_only_hint=True, destructive_hint=False, idempotent_hint=True, open_world_hint=False
    )

    @server.tool(annotations=read_only)
    def describe_motion_lab() -> dict[str, Any]:
        """Read policy bounds, model/provider status and session limits; never makes a model call."""
        return invoke("describe")

    @server.tool(
        annotations=ToolAnnotations(
            read_only_hint=False,
            destructive_hint=False,
            idempotent_hint=False,
            open_world_hint=True,
        )
    )
    def start_motion_search(request: SearchRequest) -> dict[str, Any]:
        """Start a bounded isolated search after user request; live mode may incur API charges.

        request.command is [turn, forward], each in [-1, 1]. Omitted graph/policy use
        the service's documented defaults. Poll get_motion_search for results. Never
        sets API credentials, executes source, edits an assembly, or applies a result.
        """
        payload = request.model_dump(exclude_none=True)
        try:
            if len(json.dumps(payload, allow_nan=False).encode("utf-8")) > MAX_BODY:
                raise ToolError("Motion request exceeds the 64 KiB limit.")
            validate_request(payload)
        except LabError as exc:
            raise ToolError(str(exc)) from None
        except (ValueError, RecursionError):
            raise ToolError("Motion request must contain bounded, finite JSON data.") from None
        return invoke("start", payload)

    @server.tool(annotations=read_only)
    def get_motion_search(job_id: Annotated[str, Field(strict=True, min_length=1, max_length=128)]) -> dict[str, Any]:
        """Read one search's measured history and best candidate without applying it."""
        return invoke("get", job_id)

    @server.tool(
        annotations=ToolAnnotations(
            read_only_hint=False,
            destructive_hint=False,
            idempotent_hint=True,
            open_world_hint=False,
        )
    )
    def cancel_motion_search(job_id: Annotated[str, Field(strict=True, min_length=1, max_length=128)]) -> dict[str, Any]:
        """Cancel future work; an already-sent model request may still be billed."""
        return invoke("cancel", job_id)

    return server


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true", help="Enable paid OpenAI calls with per-search consent")
    parser.add_argument("--model", choices=["gpt-5.6-luna"], default="gpt-5.6-luna", help="Requested API model; no fallback")
    parser.add_argument("--max-calls", type=int, default=8, help="Session-wide live-call limit")
    parser.add_argument("--godot", default="godot", help="Operator-selected Godot executable")
    args = parser.parse_args()
    if not 1 <= args.max_calls <= 32:
        parser.error("--max-calls must be between 1 and 32")
    api_key = os.environ.get("OPENAI_API_KEY") if args.live else None
    if args.live and not api_key:
        parser.error("Live mode requires OPENAI_API_KEY in the server environment")

    from .service import MotionService

    service = MotionService(
        project=Path(__file__).resolve().parents[2],
        provider="openai" if args.live else "mock",
        model=args.model,
        max_calls=args.max_calls,
        godot=args.godot,
        api_key=api_key,
    )
    try:
        create_server(service).run(transport="stdio")
    finally:
        service.close()


if __name__ == "__main__":
    main()
