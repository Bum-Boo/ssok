# 0029 — Graph-mounted camera and bounded desktop agent ownership

- Status: proposed; local implementation draft
- Date: 2026-10-10
- Implements: issue #32 and the owner's instruction to develop the camera/action loop with Claude design ownership.
- Extends: 0007's exclusive control ownership, 0008's optional external tooling and 0023's AppController boundary. No accepted scope is replaced.

## Decision

Add a third exclusive controller, `AgentCameraLoop`, for the existing graph-wired two-wheel car. A virtual front-camera fixture identifies the graph part and local transform; it is not a catalog part or another robot. `RunMode.part_global_transform` determines its pose. A separate 640×480 SubViewport shares the rendered workshop World3D. Editor UI and editor-camera images are never observations. Capture waits for measured settling and `frame_post_draw`; metadata binds PNG hash, physics/draw counts, episode, body instance, part, revision and control generation. The camera itself has interpolation disabled.

Forward/brake actions have 1–30 physics ticks; forward uses fixed 25% motor duty. Channels resolve through graph wiring. Actuator physics/torque remains unchanged. At the tick bound motors brake; actual chassis linear/angular and wheel speeds must remain below the documented thresholds for 12 ticks. Failure to settle within 240 ticks stops the session. No whole-app pause, body teleport, arbitrary code, hidden scene-distance input or automatic provider retry is added.

The precision follow-up adds bounded wheel-speed PI holding while this controller owns
settling/ready/capture or an explicit brake step. Passive back-EMF braking allowed about
15mm of forward creep in 10 seconds during AI latency, making an image stale. Holding
uses the same graph motors and unchanged finite-torque `DriveMotor` implementation,
with duty capped at 25%; it never sets body poses/velocities or reads evaluator distance.
Forward steps retain fixed 25% duty. Stop/context revocation clears holding and restores
ordinary zero-duty braking before another owner can act. Existing physical target/contact
evaluation thresholds and the frozen pixel goal remain unchanged. Capture/ready now requires
12 ticks at ≤0.001m/s chassis speed and ≤0.05rad/s wheel speed (angular ≤0.1rad/s retained),
strictly stronger than the unchanged independent physical evaluator. This is a proposed control change,
not a claim that passive braking or arbitrary robots are now motionless.

Stop and control/mode/source/graph changes revoke the generation. Old or consumed frames cannot act. Local Stop requires no model/network; the decision watchdog is 60 seconds. The camera trace shows the same PNG bytes, concise supplied decision summary and actual tool/result events. A reported outgoing-image receipt validates the supplied hash; it cannot prove a provider's preprocessing or cognition.

An opt-in desktop TCP listener binds 127.0.0.1:8127 only with `--ssok-agent-bridge` and a token of at least 32 characters in `SSOK_AGENT_TOKEN`. It uses bounded nonblocking NDJSON, one request per connection, authenticated observation/finite actions/Stop only. Web starts no listener. A pending disconnect cancels; there is no reconnect/resume. The Python CLI/MCP adapter is external developer tooling, distinct from the existing isolated headless runner and motion-lab trials.

## Consequences

The 2026-10-10 follow-up adds an external foreground goal runner using the existing Codex ChatGPT login
and requested Astra model, directly connected to three camera-only MCP tools. A session binds image hashes,
context, public summaries and bounded actions; action/image/time budgets are enforced separately from model
request/billing counts, which the CLI does not attest. The app's secondary authenticated control lane permits
read-only describe alongside Stop for noninterfering cancellation monitoring. Provider login remains outside the app.

The next local draft adds a1000-character raw goal and one intentional app Run click to an opt-in
foreground operator inbox. The app still performs no provider call or process launch. The authenticated
operator claims once after ready, forwards the bound episode/revision/generation through child preflight
and MCP's first/every observation, then exits after one job. Stop/fault/context change removes the goal.
The model receives only observe/decide/stop, never inbox/operator methods. Disclosure precedes Run;
8actions/9images/300seconds are tool/time bounds, not a model-request/billing cap. Web and unconnected
operators disable Run. Account onboarding, packaging and background integration remain separate.

The packaging follow-up provides a separate allowlisted foreground operator ZIP.
Git-independent archives record their clean source commit and verify eight module hashes
before model launch; altered or missing identity fails through the existing scoped Stop.
Hashes check consistency with the included record, not publisher authenticity. Python,
MCP installation, Codex CLI and existing account login stay external. Godot resources,
actor inputs, action limits, ownership and provider behavior remain unchanged.

The local setup follow-up creates an archive-local Python environment only when
explicitly invoked. A preparation check verifies the pinned MCP server, source
identity, Codex availability and the same supported ChatGPT login-status command
before foreground polling. It never initiates sign-in or inference, reads credential
stores, returns raw auth/token values, changes global settings or starts a service.
The launcher selects that environment by default. Fresh-account sign-in and actual
provider availability remain separate from passing these local checks.

The stabilization follow-up corrects an actual accept-order race: a read-only monitor could occupy
the primary peer and make a legitimate actor receive `priority_tool_required`. At most one complete
authenticated small actor envelope now waits separately (4096bytes,5seconds), frees the priority lane,
and is dispatched once through the normal validators when the primary closes. Pending operations
reject additional actor requests as busy; undispatched expiry/disconnect does not cancel an owner.
Stop still revokes the generation before a waiting request can act. Physics, camera, model inputs,
action limits and independent success thresholds do not change.

Cleanup Stop is bound to the goal's episode/revision/generation and checked synchronously by the
app in both transport lanes. A mismatch confirms the old owner revoked while returning the real
replacement state without cancellation; malformed scoped contexts fail without becoming global Stop.
The session binds before its first observe request, and unbound shutdown sends no app Stop.
Explicit unscoped Stop and the local button retain global emergency interruption. Results distinguish
owner revocation from the current desktop being physically stopped.

This draft covers a rendered car camera/control slice, not universal robot navigation, catalog camera serialization, community, RL training or Isaac Lab. Provider calls remain external and require their own disclosed model/billing/data/request bounds. Actual image-guided model trials and blind controls must be reported separately from deterministic transport and physics checks. Claude authors and independently reviews design code after Astra's actual screenshot inspection. Publishing requires approval of the reviewed version/scope; the integration owner remains Claude Fable and merge belongs to the human.
