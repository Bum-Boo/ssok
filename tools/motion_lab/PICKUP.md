# Pickup proposal bridge

The humanoid pickup family is separate from the original biped search. GPT-5.6 Luna
proposes controller parameters; the client evaluates them in independent Godot physics
worlds. This is feedback-guided parameter search, **not model-weight training**. The bridge
does not certify client-reported measurements. No generated source code is executed.

Official OpenAI documentation: [GPT-5.6 Luna](https://developers.openai.com/api/docs/models/gpt-5.6-luna)
supports Responses and Structured Outputs but not fine-tuning; the
[Structured Outputs guide](https://developers.openai.com/api/docs/guides/structured-outputs)
documents strict JSON Schema and refusal/incomplete response handling. Account/model
access and live billing were not verified during implementation; all API tests use mocks.

## Startup and security

```sh
python3 -m tools.motion_lab.server
```

Default `mock` mode makes no OpenAI calls. A user-configured `OPENAI_API_KEY` remains in
the backend process. `--live --max-calls 4` enables the exact `gpt-5.6-luna` model and sets
a service-session maximum of four API calls across **both** biped search and pickup.
Every live pickup submission also requires `allow_paid: true`. There is no fallback model
and no automatic retry, including after an unknown submission outcome or timeout.

All routes require the local bearer token, not the OpenAI key. Existing loopback binding,
Host checks, exact Origin allowlisting, body size and read timeouts apply. Browser hosting
still requires a separate authenticated HTTPS gateway. The optional legacy MCP tools and
biped endpoints remain unchanged; pickup is currently exposed through HTTP only.

## Request

`POST /v1/pickup/propose`, JSON body up to 65,536 bytes:

```json
{
  "goal": "Pick up the box and hold it upright",
  "graph_fingerprint": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "count": 4,
  "round": 0,
  "history": [],
  "allow_paid": false
}
```

- `graph_fingerprint`: required lowercase 64-character SHA256 of the client assembly snapshot.
  It identifies an assembly; it does not transmit its geometry or prove any measurement.
- `count`: integer 1..4, default 4. A batch consumes **one** live model call, not one per lane.
- `round`: integer 0..31, default 0. It is feedback context, not an instruction to loop.
- `goal`: 1..2,000 characters. User data is not interpreted as protocol instructions.
- `history`: at most 32 records, each containing exactly `policy` and `metrics`.
  The client should send its latest bounded history; the server rejects oversized history.
- `allow_paid`: boolean, default false. Only effective when the bridge was started live.

Unknown fields, code, scene paths, non-finite numbers and out-of-range parameters are rejected.

The recommended feedback metrics are:

```json
{
  "finite": true,
  "fallen": false,
  "success": true,
  "lift_m": 0.4,
  "hold_seconds": 1.0,
  "min_upright": 0.98,
  "score": 42.0,
  "simulation_seconds": 11.8
}
```

`finite`, `fallen`, and `score` are required. Other accepted numeric/boolean keys and
their limits are advertised in `/v1/status` under `pickup.metric_bounds` and
`pickup.boolean_metrics`; arbitrary strings or metadata are not sent to the model.
`contact_before_grasp` and `cancelled` are optional boolean evidence flags.

## Policies

| Parameter | Default | Allowed range |
| --- | ---: | ---: |
| `crouch_height` | 0.20 m | 0.18..0.26 m |
| `torso_lean_deg` | 25° | 15..32° |
| `reach_seconds` | 2 s | 1.5..3.5 s |
| `lift_seconds` | 2.5 s | 2..4 s |
| `hand_height_offset` | 0.075 m | 0.04..0.095 m |
| `hold_shoulder_deg` | −35° | −45..−25° |
| `hold_elbow_deg` | −60° | −75..−45° |

## Asynchronous response and cancellation

A successful submission returns HTTP 202 with a job snapshot. Poll
`GET /v1/pickup/{id}` for the same schema:

```json
{
  "id": "opaque-job-id",
  "state": "completed",
  "mode": "mock",
  "provider": "mock",
  "model": "gpt-5.6-luna",
  "goal": "Pick up the box and hold it upright",
  "graph_fingerprint": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "count": 4,
  "round": 0,
  "candidates": [],
  "api_calls": 0,
  "usage": {},
  "error": "",
  "cancel_requested": false
}
```

The illustrative empty candidate list above is populated **only on successful completion**
with exactly `count` objects `{ "policy": {seven parameters}, "reason": "short rationale" }`.
Mock rationales explicitly identify fixtures, not GPT output. Rationale text is task data,
not a fixed UI label or a claim that the proposed motion succeeded.

States: `queued`, `proposing`, `completed`, `cancelling`, `cancelled`, `failed`.
`POST /v1/pickup/{id}/cancel` accepts exactly `{}`. Cancellation before dispatch prevents
the model call and budget consumption. Cancellation after dispatch cannot un-send a request:
the call remains counted, any returned usage is retained, and no candidate is exposed.
Failures (including HTTP errors, timeouts, malformed JSON, refusal, or incomplete generation)
are not retried and still consume a call if dispatched. Token usage is unknown if no valid
usage metadata arrived. Returned upstream error bodies and credentials are never exposed.

There is one shared worker slot across biped searches and pickup proposals. A second start
is rejected while either is running. The parent service's shared lock serializes consent,
budget, cancellation and dispatch accounting. At most 32 completed pickup jobs are kept in
memory; scenarios are saved explicitly by the client under `user://`, not by this service.
Shutdown requests cancellation; an in-flight HTTP call may take up to its 45-second timeout.

The model receives strict JSON Schema, no tools, `store: false`, and at most 2,048 output
tokens. Responses are capped at 1 MB. Policy/count/rationale constraints are checked again
locally, independently of Structured Outputs. Proposals alone are never eligible for Apply.

## Verification

```sh
python3 -m unittest discover -s tests -p 'test_pickup*.py' -v
python3 -m unittest tools.motion_lab.test_service tools.motion_lab.test_races -v
```

These tests mock all API calls. They cover schema/range enforcement, exact batch sizes,
shared biped/pickup budget, mixed concurrent HTTP starts, cancellation before/after dispatch,
usage retention, no retries, and existing authentication/Origin/size restrictions. Physics
and native ko/zh_CN/ja UI verification belong to the Godot trial/UI tests. No fixed client
UI strings are added by this backend module; new technical diagnostics should be displayed
under a translated generic failure message rather than treated as translation keys.
