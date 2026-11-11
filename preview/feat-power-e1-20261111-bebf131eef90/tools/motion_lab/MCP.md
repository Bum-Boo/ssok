# Optional local MCP adapter

This adapter exposes the same bounded Motion Lab service through the official
Python MCP SDK 2.2.0. It is operator-side tooling, not part of the Godot runtime.
MCP supplies tool discovery and invocation; it does not train GPT or replace the
Responses API client. This adapter supports **stdio only**, not a remote MCP URL.

## Install and run

From the ssok repository root:

```sh
python3 -m venv .venv-motion
.venv-motion/bin/python -m pip install -r tools/motion_lab/requirements-mcp.txt
.venv-motion/bin/python -m tools.motion_lab.mcp_server
```

An MCP host launches that final command as a subprocess with its working directory
set to the ssok repository. This default uses offline/mock proposals; it still
runs isolated Godot physics trials when a search is started. No MCP host settings
are installed or changed automatically.

For live model proposals, configure `OPENAI_API_KEY` securely in the server's
environment, then add `--live`. Do not paste keys into tool arguments, repository
files or screenshots. This slice is fixed to the requested model
`gpt-5.6-luna`; there is no automatic fallback or alternate model selection. Live mode also
requires `allow_paid: true` on each requested search. It does not establish that
the account has access to that model.

## Tool surface

| Tool | Arguments | Effect |
|---|---|---|
| `describe_motion_lab` | none | Read provider, policy bounds and limits; no model call |
| `start_motion_search` | `request` object | Start an isolated bounded search; may incur cost in explicitly enabled live mode |
| `get_motion_search` | `job_id` | Read history and best measured candidate |
| `cancel_motion_search` | `job_id` | Stop future work; an in-flight API call may still be billed |

Example start arguments:

```json
{
  "request": {
    "goal": "Walk forward while staying upright and reducing sideways drift",
    "command": [0, 1],
    "rounds": 2,
    "allow_paid": false
  }
}
```

`command` is `[turn, forward]`, not per-joint values. `graph` and `policy` may be
included using the service's validated snapshot/policy formats. Omitting them
uses its documented defaults. No tool accepts model credentials, arbitrary source
code, executable options, URLs or file paths, and no tool applies a candidate to
the user's current assembly. Apply remains an explicit action in ssok.

The SDK negotiates current 2026-07-28 or compatible legacy protocols. Do not add
prints to stdout: it is reserved for MCP messages. The service owns validation,
request budgets, fixed trial invocation and cancellation; protocol tool annotations
are hints for hosts, not security enforcement.

## Verification

```sh
.venv-motion/bin/python -m unittest tests.motion_mcp_check -v
```

Verified locally on 2026-09-15 with Python 3.14.7 and MCP SDK 2.2.0:
**14 tests passed** (25.307 seconds). `pip check` reported no broken requirements.

These checks use the actual official SDK, including subprocess stdio discovery,
current and legacy negotiation, malformed arguments, the restricted tool surface,
redacted errors, real-service start/read/cancel, and isolated adapter tests with
an explicitly fake service. They never make paid API calls. Desktop tool tests do
not verify a deployed browser, a real API model response or physical-robot safety.
