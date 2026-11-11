# Rendered robot camera/action draft — 2026-10-10

User outcome: external AI observes the robot's own image, takes a finite action, brakes, waits
for measured rest and observes again. Human assembly/wiring/code and graph-derived physics
remain the authority. This is a local draft, **not integrated or published**.

Base: `4eb059f6432bebbbc8db94896cac56cbb8bb2927`; branch `feat/32-robot-camera-loop`, issue #32.
Windows editing mirror: `C:/Users/Hojun/Projects/ssok-ai-loop`. Actual tested worktree:
`/home/bumboo/Projects/ssok-ai-loop`. Runtime: Godot 4.7.2.stable.official.ed1daf0bf,
GL Compatibility, GodotPhysics3D, Intel HD Graphics 530/Mesa 26.2.1. Source hash manifest
identifies the application files actually tested; documentation hashes do not certify semantics.

Follow-up: [direct MCP goal runner](direct/README.md) adds an external actor without coordinator
image/action relay. That record owns the newer source hashes and actual 4-action/5-image and Korean-goal
runs. The source manifest and verification below remain the earlier panel/camera slice's historical evidence.

## Implemented and observed

- A virtual 640×480 front camera follows the graph-derived car body, with frame/episode/body/
  revision/generation/render metadata. The exact PNG shown in the panel is verified by the CLI/MCP.
- Forward/brake actions use wired motors, fixed 25% duty and 1–30 physics ticks. Rest requires
  actual chassis/wheel velocity thresholds for 12 ticks. Frames are consumed once. Local Stop,
  stale context, human takeover, decision timeout and settle failure revoke control.
- Opt-in authenticated loopback TCP and external stdlib CLI; optional official MCP SDK 2.2.0
  stdio wrapper, read-only by default, action capability explicit. A second Stop lane interrupts
  pending work. App/provider keys and arbitrary generated code are not introduced.
- Claude-authored AI panel has camera, bounded action controls, pinned Stop and supplied summary/
  tool/result history. English/Korean/Chinese/Japanese catalogs were updated together.

Commands (from the actual Arch worktree, using the pinned executable):

```sh
godot --path . --script tests/agent_camera_loop_check.gd
python tools/ci/verify.py --godot /home/bumboo/.local/bin/godot --output build/ai-loop-evidence/related-final --match '^(import|scene-load|localization_check|manual_control_check|game_flow_check|learner_language_check|app_controller_check|robot_car_check|agent_camera_loop_check|tests-desktop_client_check.py)$'
python -m tools.app_control.verify_desktop --godot /home/bumboo/.local/bin/godot
python -m tools.ci.browser_smoke --directory build/ai-loop-evidence/web --output build/ai-loop-evidence/browser-r5
```

The final rendered check passed **29/0**, including real PNG decoding, graph body identity,
post-settle capture, episode/context guards, finite physical travel, consumed/stale-frame
rejection, Stop, source/mode takeover and decision/settle failure. A 20-tick check advanced
0.067462489 m and settled to 0.001848274 m/s; this is a fixture measurement, not general navigation.
The selected related suite passed 10 check programs; Python protocol suite passed 29 unit cases
with the installed MCP SDK. TCP/MCP smoke passed including Korean receipt, split invalid-token
request with correlated ID, stale receipt rejection, actual MCP image/action and pending Stop
at about 21 ms. The exported Web app loaded/rendered and ran/stopped its existing servo-arm
flow in Chromium 153.0.8010.12, with no captured browser errors. Web does not expose the desktop
camera bridge; this smoke is regression coverage, not Web parity for agent control.

## Actual image-guided pilot

The native `gpt-6-astra` worker was isolated from code/editor/scene metrics. It directly viewed
verified robot-camera PNGs. The coordinator relayed two decisions to the already rendered app:
`forward, 8 ticks` → brake/settle → new image → `brake, 1 tick` → local Stop. Both receipts and
actions succeeded. [Pilot events](pilot-events.jsonl) and two PNG/metadata pairs are retained.
Two image decisions were used within the eight-call bound; model transport was the native worker,
not an app-integrated provider or MCP registered directly with that worker. No hidden reasoning
was recorded. A matching receipt verifies a supplied hash, not provider cognition. The worker
explicitly could not determine contact from the image; no collision-free goal success is claimed.

## Design authorship and review

The design code SHA-256 is `de153a7416075838af864387f87e12e1d1325babe2fa6bf316989c154e11352f`.
Actual Claude CLI 2.1.296, requested `opus`, resolved `claude-opus-5-5`: author → independent
fix review (`needs_changes`) → independent final review (`pass`, no changes). Astra directly
viewed the eight R5 captures at 1600×1000 and 1152×648, four languages and light/dark, including
populated fixture trace, scrolling and driving. [Astra report](astra-final.md),
[Claude result](claude-final-result.json) and [review handoff](../../../CLAUDE-REVIEW.md).
Claude reviewed supplied source and Astra findings; it did not independently run Godot/view PNGs.
The compact image has normal vertical scroll clipping. Summary/provider in the UI captures is
explicitly a UI test fixture; the separate pilot above is real image-guided behavior.

## Failures retained and limits

- Initial CLI author call exceeded its 240-second bound. Same-input retry succeeded; subsequent
  author/fix/final calls have actual result/model metadata. List-price estimates are not billing.
- Initial screenshot helper accidentally captured Code instead of AI. Tab selection was fixed.
  The first actual AI compact capture placed prose before the image and its Stop scrolled.
  Claude's revised component and fresh R5 inspection resolved those observed issues.
- Early settle-failure fixture did not induce motion; the fixture was corrected. Translation
  singleton use in a SceneTree script initially failed parsing and was corrected. Production
  actuator code does not contain the fixture's force injection.
- Earlier interactive pilot stopped at ID mismatch before action. The exact pre-dispatch cause
  was not recovered. Rejection ID correlation was fixed and verified without weakening client
  ID checking. A later pilot's second receipt arrived after the 60-second decision bound and
  was correctly rejected; the session braked. A fresh pilot completed both decisions.
- A desktop startup probe missed its ready deadline while another browser run was active;
  the precise cause is unconfirmed. The developer startup wait was bounded to 30 seconds and
  the serial final probe passed. App action/decision deadlines were unchanged.

Full release suite, Windows/macOS packages, enlarged-font/keyboard accessibility, nine
layout/model trials, blind controls and broad navigation success are untested for this draft.
There is no serialized catalog camera, generic robot support, app-integrated provider login/
billing, community implementation or new walking/RL work. Original main and published builds
remain unchanged. Next owner: Claude Fable for integration review; human merges. Public release
requires approval of this reviewed version and scope. Canonical agent-task:
`ssok/robot-camera-loop-20261010`; ownership is released with this branch as the handoff.

Large raw logs, unsuccessful trials and worker briefs stay under the ignored
`build/ai-loop-evidence/` task output. This directory contains a concise durable evidence subset.
