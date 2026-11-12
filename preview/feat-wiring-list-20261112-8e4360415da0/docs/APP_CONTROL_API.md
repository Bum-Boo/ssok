# App control API and MCP boundary (#32)

The first transport is an **in-process AppController plus an isolated headless JSON runner**.
It works with the same GDScript model in desktop and Web exports. The old motion-lab MCP keeps
its separate trial-session scope; it does not acquire control of an open workshop.

`AppController.invoke(tool, args, expected_revision)` exposes:

| Tool | Result / behavior |
|---|---|
| get_scene | Current graph, source, board profile and mode |
| list_parts | Catalog IDs and compatible mechanical/electrical ports |
| place_part / remove_part | Existing assembly and bounded catalog/transform rules |
| connect_parts | Mechanical snap, undo history and graph notification |
| connect_wire | Compatible free electrical ports, no relocation, undoable |
| set_program | Explicit source application, preserving any pending block draft |
| run / stop | Existing run-code ownership and immediate local interruption |
| get_result | Observed servo angles, motor speed/torque, current line and stage measurements |

Read-only is the default. Mutations require the operator's edit capability and the exact current
revision. Human scene/code/mode changes invalidate stale commands. Edits during physics are
rejected. Stop bypasses edit capability and revision checks and requires no network or model.
A bounded local event journal is off by default; opting in records tool, origin (agent/user),
physics frame and revision, without source text or personal identifiers. There is no telemetry.

Offline use (requests and output are operator-supplied files, not web filesystem access):

```sh
godot --headless --path . --script tools/app_control/run_requests.gd -- \
  requests.json results.json --allow-edits
```

The request array accepts `tool`, `args`, `expected_revision` and optional `observe_ticks`
(up to 3600). At most 100 requests / 1 MiB input are accepted. Results never treat a commanded
angle or generated proposal as observed success. Use `get_scene` after human edits to obtain a
fresh revision. Scene replacement/loading stays with the user's normal project/stage flow.

## Rendered desktop camera loop — local draft, 2026-10-10

The separate [ADR 0029](adr/0029-rendered-desktop-agent-camera-loop.md) draft adds an opt-in
transport to the **open rendered desktop workshop**. It never substitutes the headless runner
for a robot camera. The AI tab is available in Lab/legacy sessions; Stage and example sessions
retain their existing tools. Only the graph-wired two-wheel car is supported. Enable transfers
command ownership from code/manual input, mounts a virtual front camera and captures after rest.
This fixture is not a catalog camera part and is not saved in a project document.

Start the desktop with `-- --ssok-agent-bridge` and the same operator-only `SSOK_AGENT_TOKEN`
environment variable (at least 32 characters) in the app and external client. The listener binds
only `127.0.0.1:8127`. Neither Web nor ordinary startup creates it. Do not put the token in a
command argument, project, MCP configuration JSON or log. No browser-to-desktop transport is added.
For a developer demo, use `godot --path . --script tools/app_control/run_desktop.gd -- --ssok-agent-bridge`.

```sh
# In the same environment, from the project directory:
python -m tools.app_control.desktop_client describe
python -m tools.app_control.desktop_client observe --out /operator/output/frame.png
python -m tools.app_control.desktop_client step --frame /operator/output/frame.json --ticks 8
python -m tools.app_control.desktop_client observe --out /operator/output/next.png
python -m tools.app_control.desktop_client stop
```

`observe` saves a CRC/SHA-256/dimension-verified PNG and its JSON sidecar; stdout contains only
metadata. The camera uses a 640×480 SubViewport sharing World3D, bound to the graph body rather
than the editor viewpoint. Capture waits for 12 consecutive settled physics ticks (chassis
linear speed ≤0.001 m/s, angular speed ≤0.1 rad/s and both wheel speeds ≤0.05 rad/s), then actual
`frame_post_draw`. Failure to settle in 240 ticks cancels. The app keeps simulating normally.

The TCP protocol is one authenticated NDJSON request/reply per connection: `{id, token, tool,
args}` → `{id, data}` or `{id, error}`. Requests are ≤1 MiB, responses ≤4 MiB and the connection
deadline is 15 seconds. Reads/writes are nonblocking and chunked. Supported tools are `describe`,
`observe`, `drive_step`, `stop` and `trace_dispatch`; no arbitrary object methods, code execution,
scene metrics, scene edits or provider calls are exposed. A separate bounded authenticated Stop
connection can interrupt a pending capture/action. The same bounded lane accepts authenticated
read-only `describe`, so a foreground runner can monitor human Stop without colliding with a camera reply.
If a short monitor request took the primary slot first, one authenticated complete actor request
(`observe`, `drive_step`, `trace_dispatch`, at most4096 bytes) may wait separately for up to5seconds.
It frees the priority lane immediately, then moves to the ordinary primary validator/dispatcher once
that slot closes. This is one dispatch, not a client retry. A pending operation or already occupied
waiting slot returns `busy`; unknown tools still receive `priority_tool_required`. Queue expiry or
disconnect before dispatch drops only the waiting request. A pending primary disconnect revokes ownership.
Stop invalidates context before any waiting request can execute. The rendered acceptance-order and
queued-Stop regression is `python -m tools.app_control.verify_bridge_race --godot GODOT --out NEW_DIR`.

`stop({})` remains global emergency Stop. Goal/session/runner cleanup instead sends exactly
`episode_id`, `revision`, `control_generation`. The bridge validates that context atomically on the
app thread in both primary and priority lanes. A match invokes local Stop; a mismatch leaves the
replacement untouched and returns its real current state plus `owner_revoked: true` and
`stop_scope: context_replaced`. Matching/global results use `matched_context`/`global`. Malformed
scoped args return `invalid_stop_context`, never global Stop. Old cleanup can confirm that its
owner was revoked without claiming that the current desktop is stopped. The rendered regression
is `godot --path . --script tests/bridge_stop_owner_check.gd -- --ssok-agent-bridge` in the same token environment.

`drive_step` accepts exactly `episode_id`, `frame_id`, `revision`, `control_generation`, `ticks`
(integer 1–30), and `action` (`forward` or `brake`). Forward uses fixed 25% duty through actual
graph wiring. During settling/ready/capture and brake steps, bounded wheel-speed PI holding
uses those same motors at at most 25% duty to oppose creep during model latency. It does not
change motor torque, set body poses/velocities or read evaluator distance. Stop/context revocation
clears holding and restores ordinary zero-duty braking. A frame is consumed once; another action
needs a fresh observation. After the tick
bound, brake and measured settling finish before reply. A new episode, human graph/source/mode
change or local Stop invalidates older context. Invalid action bounds cancel. The ready decision
watchdog is 60 seconds; operation timeout is 10 seconds. No automatic retry/resume is performed.

The optional official Python MCP SDK wrapper runs via `python -m tools.app_control.desktop_mcp`.
Read-only is default (`describe`, `observe`, `stop`); add `--allow-actions` to expose `drive_step`.
Observe returns metadata plus the verified PNG as MCP image content. The SDK is external tooling,
not an exported-app dependency. The tested installed SDK was 2.2.0. The wrapper does not launch
an isolated simulation or call a provider. An external agent must enforce its own model/data/
billing/call bounds. The operator-side `trace-dispatch` CLI reports an image-hash receipt and a
short summary; the panel labels it as a report, not proof that a provider received/read the image.

Source-specific tests, model pilot and design review: [2026-10-10 evidence](evidence/agent_camera_2026-10-10/README.md).
Merge/publication and full navigation acceptance remain pending.

## Direct camera goal runner — local draft

The external foreground runner now connects a Codex CLI actor directly to MCP image content.
The coordinator does not relay images or choose actions. Enable the rendered desktop camera first,
use the same operator environment, and run from this repository using the optional MCP Python environment:

```sh
python -m tools.app_control.run_goal \
  --goal "Approach the visible wall in short steps, reobserve, then stop before touching it." \
  --out /operator/new-goal-evidence
```

This route explicitly requests `gpt-6-astra` on OpenAI through the existing Codex **ChatGPT login**.
It refuses API-key login and removes `OPENAI_API_KEY` from the child environment; there is no paid fallback.
The account's quota/credits apply. Before the first model request it prints provider, requested model,
authentication mode, sent data and limits. The goal, camera PNGs, positive frame metadata, concise public
summaries and tool results are sent; scene coordinates, sonar, source/graph and evaluator answers are excluded.

The defaults are **one CLI launch, four actions, five images and 240 seconds**. `--max-steps` permits 1–8,
`--max-observations` must reserve a final image (up to9), and `--seconds` permits 15–600.
These are enforced tool/time bounds, **not a hard model-request or billing cap**. The CLI does not expose
every underlying model request; reported token usage is retained without estimating a bill.
The custom OpenAI CLI provider sets HTTP/stream retry counts to zero. There is no application retry/resume.
CLI JSON does not independently attest the resolved backend model, so evidence distinguishes requested identity.

The goal MCP exposes only `observe`, `decide(frame_sha256, summary, action, ticks)` and `stop`.
`decide` checks the current image hash/context, records the <=240-character public summary through the
existing panel receipt, then sends one finite action and waits for measured settling. Each action requires
a new image, including before finishing. The legacy receipt `max_calls` value is a reported decision bound;
it does not certify provider call counts. Session bounds/context failures revoke their bound owner and close the session.
Human Stop is monitored through read-only state polling; the runner terminates its owned CLI process tree
and attempts a context-bound final Stop. MCP EOF also releases that bound owner. Ownership is bound
before the first observe request; closing an unbound session or failing unbound login sends no app Stop.
Runner results distinguish `owner_revocation_confirmed` from the current desktop state being
`stopped` (`stop_confirmed`) and
retain `final_desktop_state`/`stop_scope`. An in-flight model request may still consume quota.

Evidence is a new exclusive output directory with verified PNG/JSON pairs, positive tool/result events,
sanitized CLI event types/diagnostics and token usage. It omits assistant text, hidden reasoning, credentials
and session IDs. A runner exit0 confirms its observed tool loop/Stop, never navigation-goal success.
The app now queues a goal from its AI Run button for an explicitly started foreground operator, described below.
It does not launch/login a provider itself. The virtual camera and two-wheel-car restriction remain.
SDK-side schema errors are distinct from session execution rejection;
the actor must stop on any tool error and the app watchdog remains active.

Actual Arch verification used Codex CLI 0.150.1. It emitted two nonfatal diagnostics: missing local
`gpt-6-astra` model metadata (fallback **metadata**, not an observed model substitution), and shortened
skill descriptions. That CLI still injects framework/skill descriptions despite the requested skills-off
configuration; the scene input boundary does not imply an otherwise empty model context. Actual recorded
calls used only the three goal MCP tools. A CLI with verified Astra metadata and effective skill isolation
needs separate verification before claiming stricter actor-context isolation. No global configuration or
model fallback was changed to hide these warnings. [Direct-loop evidence](evidence/agent_camera_2026-10-10/direct/README.md).

Official policies checked 2026-10-10: [authentication and billing modes](https://learn.chatgpt.com/docs/auth),
[stdio MCP](https://learn.chatgpt.com/docs/extend/mcp?surface=cli),
[configuration/retry controls](https://learn.chatgpt.com/docs/config-file/config-reference).

## App goal button and foreground operator — local desktop draft

With the same opt-in app/token environment and the existing Codex ChatGPT login, explicitly start:

```sh
python -m tools.app_control.run_operator --out /operator/new-app-goal-evidence
```

The operator waits up to900 seconds for **one** intentional AI-tab Run click, then exits after that job.
The raw goal is limited to1000 characters. Enter does not dispatch. Provider/model/login, sent data,
8actions/9images/300seconds and account-usage/no-fixed-cost/no-model-request-cap appear before Run.
Disconnected/unsupported/Web/empty/busy states disable Run; the local Stop stays available.
This is developer tooling, not a packaged account-login or background service. Restart the foreground
operator intentionally for a second goal. A goal passed to the external child is visible in local argv.

Authenticated `operator_poll({operator_id})` and `operator_leave({operator_id})` are operator-only,
also allowed on the bounded priority lane. Python requires explicit `DesktopClient(allow_operator=True)`;
the actor MCP uses the default client and exposes only observe/decide/stop. The inbox permits one operator,
claims a queued job once after the camera is ready and binds episode/revision/generation. The parent,
child preflight and first/every MCP observation preserve this claimed context, so Stop followed by Enable
cannot adopt an old goal into a new episode. Stop/fault/context changes clear the queue immediately.
Idle operator heartbeat expires in3seconds, queued goals in20seconds, claimed goals in310seconds.
During a claim, an absent operator can retain the connected indicator until cancellation/deadline.
On Windows forced child termination may prevent a result file; the parent first attempts Stop scoped to its claimed goal.

Independent physical evaluation and original/live/frozen/blank trials are developer-only and never sent
through actor MCP. A stopped run or runner exit0 does not certify goal success. Results and initial failures:
[repeated trials](evidence/agent_camera_2026-10-10/repeated/README.md),
[goal-button UI and operator](evidence/agent_camera_2026-10-10/goal_ui/README.md).
Later transport/ownership fixes and separate frozen-goal follow-ups are recorded in
[stabilization evidence](evidence/agent_camera_2026-10-10/stabilization/README.md).

Current Windows follow-up used CLI0.159.0-alpha.9 with the existing ChatGPT login. It warns that
`features.skills` is unrecognized/ignored; actual tool events used only observe/decide/stop.
Requested Astra/backend-identity and broader actor-context limitations remain. See the dated
stabilization record for latest source-specific runtime results; older CLI diagnostics above are history.
