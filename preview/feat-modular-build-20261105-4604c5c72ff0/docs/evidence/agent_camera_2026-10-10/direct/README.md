# Direct camera MCP goal runner — 2026-10-10 local draft

User problem: the previous real-image pilot needed the coordinator to relay every image/action.
The new external foreground runner connects a Codex CLI actor directly to the already rendered
robot-camera MCP. Godot does not launch a provider. This is **uncommitted local work**, not integrated
or published. Issue32 and existing task `ssok/robot-camera-loop-20261010` remain the ownership record.

Source: branch `feat/32-robot-camera-loop`, base `4eb059f6432bebbbc8db94896cac56cbb8bb2927`.
Actual runtime `/home/bumboo/Projects/ssok-ai-loop`; Windows mirror
`C:/Users/Hojun/Projects/ssok-ai-loop`. [Current input hashes](source-sha256.json) identify 23 inputs;
the parent manifest identifies the earlier slice. Godot4.7.2/GL Compatibility/GodotPhysics3D,
Intel HD530/Mesa26.2.1, Python MCP SDK2.2.0, actual Arch Codex CLI0.150.1.

## Change and observed behavior

`desktop_session.py` binds each public summary/action to the exact verified PNG hash and episode/
revision/control generation. Forward/brake remain 1–30 ticks at the existing duty; brake and measured
rest precede a new image. Duplicate observation, stale context, wrong hash, excess action, lost reply,
deadline and concurrent work reject/stop without an action retry. Stop bypasses the session action lock.

`desktop_mcp.py --goal-output <new-dir> --allow-actions` exposes exactly three goal tools:
observe, decide, stop. EOF releases control. `run_goal.py` uses the existing Codex ChatGPT login,
requests `gpt-6-astra`, discloses sent data/bounds before dispatch, monitors human Stop and terminates
its owned foreground CLI tree on cancellation. Defaults: one CLI launch, four actions, five images,
240 seconds. Underlying model request counts are not exposed; this is **not a hard billing cap**.
HTTP/stream retry settings are zero; no API-key or model fallback is added.

The first live trial failed before an image/action: runner state polling collided with a pending camera
reply on the old secondary Stop-only lane. Stop was confirmed. The bounded authenticated lane now also
returns read-only describe and correlated rejection errors; no physical actuator or UI styling changed.
The regression observed describe in `settling` while capture was pending, then Stop in about31ms.

## Actual direct actor runs

| Evidence | Completed actions / exact PNGs | Observed ending |
|---|---|---|
| [First failed result](first-failed-result.json) | 0 / 0 | runner failed, Stop confirmed; no automatic retry |
| [Direct R2](direct-r2/result.json) | forward8, forward8, forward8, brake1 / 5 | all action replies ready; final reobserve; actor Stop; CLI exit0 |
| [Final Korean goal](direct-ko-final/result.json) | forward3 / 2 | actual image/action/reobserve; actor Stop; CLI exit0 |

The final Korean goal asked the actor to move briefly toward the visible wall, reobserve and stop.
The coordinator did not select the actions or relay the images. Exact PNG/sidecar pairs, public summaries,
action results, sanitized CLI event types and dispatch manifests are linked in the run directories.
Raw assistant text/private reasoning/credentials/session IDs are omitted. A reported image receipt verifies
the supplied hash, not provider cognition or preprocessing. The result does **not certify goal success**.
An intermediate one-action English run also passed; it stays in ignored `build/ai-loop-evidence/direct-final`.

R2 token usage: input123455/cached109440/output482. Final Korean: input50524/cached46592/output208.
These are CLI-reported usage counters, not a bill or underlying request count.

Native Astra independently viewed all five R2 PNGs and both final Korean PNGs, checking their sidecar hashes.
[Image inspection](astra-observations.md) records visible wall changes/floor and absence of editor UI;
metric distance, no contact, physical rest and goal attainment are not certified by still images.
The actual external backend model identity is not attested by CLI JSON; `gpt-6-astra` is the requested model.

## Source-specific checks

Commands from the actual Arch worktree (rendered commands use the existing display/X authority):

```sh
/home/bumboo/.local/bin/godot --headless --path . --import --quit
/home/bumboo/.local/bin/godot --headless --path . --quit
/home/bumboo/Projects/ssok-release/build/venv/bin/python -m unittest discover -s tests -p 'desktop_*check.py'
/home/bumboo/.local/bin/godot --path . --script tests/agent_camera_loop_check.gd
/home/bumboo/Projects/ssok-release/build/venv/bin/python -m tools.app_control.verify_desktop --godot /home/bumboo/.local/bin/godot
/home/bumboo/Projects/ssok-release/build/venv/bin/python -m tools.app_control.verify_desktop --godot /home/bumboo/.local/bin/godot --goal-contract-check
```

Import/load exit0 ([import](direct-import.log), [load](direct-scene-load.log)).
[Python](direct-python-final.log): **41/0** including12 session cases, with installed SDK.
[Rendered camera](direct-camera-final.log): **29/0**, finite physical travel0.067462489m and settled
velocity0.001848274m/s in the fixture. [TCP/MCP](direct-transport-r2.log): exact image/action smoke,
pending describe/Stop. [Actual goal MCP contract](goal-contract-check.log): three tools, two images,
one finite action, excess decision rejected with app stopped, subsequent observe rejected.
`--goal-contract-check` uses an exclusive fixed evidence directory: archive/select another owned output
before repeating; do not overwrite an unrelated run. Fake-client unit cases are not navigation proof.

An explicit model pilot, separate from deterministic checks:

```sh
/home/bumboo/Projects/ssok-release/build/venv/bin/python -m tools.app_control.verify_desktop \
  --godot /home/bumboo/.local/bin/godot --goal 'Approach briefly, reobserve, then stop.' \
  --goal-output build/ai-loop-evidence/new-manual-goal --goal-max-steps 1 --goal-seconds 180
```

This helper owns a rendered app and ephemeral in-memory token, cleans up in finally and requires a new
goal directory. Ordinary checks call no provider. To control an operator's already-enabled desktop,
use [run_goal/API instructions](../../../APP_CONTROL_API.md#direct-camera-goal-runner--local-draft).

## Known diagnostics, recovery and remaining scope

Final CLI JSON included two nonfatal diagnostics: missing local Astra model metadata (fallback metadata),
and shortened skill descriptions. That older CLI still injects framework/skill metadata despite the
skills-off request. Actual events used only the three goal MCP tools; scene payload excludes source/graph,
coordinates/sonar and evaluator answers. Do not claim an otherwise empty actor context, resolved backend
identity or a silent model substitution. No global configuration/upgrade was made. A separately verified CLI
with Astra metadata and effective skill isolation is required before strengthening those claims.

The pre-dispatch unsupported `--no-daemon` probe and reserved built-in provider override were corrected
using actual Arch help/config behavior; neither dispatched a model. Paid/live failures were not silently
retried: the later runs were fresh bounded manual trials after the transport fix. SDK schema validation
errors happen before session execution; the actor is instructed to stop on any tool error, and the app's
decision watchdog remains active. A cancelled in-flight request may still consume quota.

Recovery: `C:/Users/Hojun/.agents/backups/ssok-direct-development-20261010/source-before-reconstructed`
contains20 baseline files verified against the previous phase's hash manifest. These were reconstructed
after editing, not saved before the code change. Restore only the affected three existing files after
comparing current hashes with this phase's source manifest; reconcile later changes. The three newly added
Python files can be removed only if still equal to their recorded hashes. Preserve the prior camera/panel WIP.
Record backups/current-closeout doc backups and readback validation are in the same backup directory.

Panel SHA stays `de153a7416075838af864387f87e12e1d1325babe2fa6bf316989c154e11352f`; prior Claude
design pass applies to that unchanged component. This functional follow-up has no new UI/localization.
FLOWS/API/CONTROLS were reviewed; graph/VM/Stage/control diagrams retain their meanings because their
boundaries did not change. [Claude integration handoff](../../../../CLAUDE-REVIEW.md).

Full release/Web package suite, Windows/macOS packages, nine independent layout/model trials, blind
controls, navigation success, one-button app provider connection, serialized catalog camera and generic
robots remain unverified or unimplemented. Earlier WebR5 is historical evidence, not a new release check.
Next owner: latest Claude Fable for integration review; human merges; publication requires approval of
the reviewed version/scope. No cron, background provider service, main merge or public deployment added.
