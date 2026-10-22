# 0010 — Modular humanoid and observable parallel pickup search

- Status: accepted; its robot-specific frame modules are superseded as the construction-kit design by [0011](0011-elementary-construction-kit.md). Physics, coding and pickup-search boundaries remain accepted.
- Date: 2026-09-15
- Extends: 0002, 0003, 0004, 0007, 0008 and 0009. Supersedes only the humanoid-search exclusion in 0009; the original four-parameter biped policy remains separate.

## Context

The user rejected the integrated BoxMesh humanoid as insufficiently modular and requested
Blender-authored mechanical modules, programmable joints, and Luna-assisted box pickup search
whose parallel experiments can be watched, selected and saved. A model proposal is not evidence
of a successful grasp, and concurrency must not silently multiply API spending.

## Decision

- Add a separate modular catalog/preset: motor housings, output brackets, passive frames,
  hands, feet, shells and controller are distinct ConnectionGraph parts with real ports.
  Blender-authored mesh/material resources and editable source are generated offline. Keep
  the earlier block humanoid and biped as separate examples and compatibility tests.
- Allow opt-in graph-derived fixed-component rigid-body merging, already permitted by 0003.
  Preserve graph-index-to-body mappings, each part's mesh/collision transforms and summed mass.
  Motor ports specify whether the housing drives its connected output body; wiring still owns
  numeric addresses. Never remove module identity from the editable graph.
- Add a generic signed relative servo command for learner code. It follows the same wired
  pin resolution and actuator limits as internal joint programs, without board-specific syntax.
  Existing write(0..180) remains supported. Never execute model-generated source code.
- Introduce a separate seven-parameter pickup policy family. Local Godot trials own independent
  physics worlds and observable SubViewports. Users can increase/decrease concurrent evaluation
  lanes from 1 to 4 during a bounded batch; lowering the count drains existing work.
- Luna proposes bounded candidates through the optional authenticated bridge. One API request
  may return a bounded candidate batch. The client submits measured feedback for later rounds.
  Reserve against the same server-session API-call budget as biped search. Require explicit
  consent for a fixed round limit, never automatically retry paid requests, and surface unknown
  submission outcomes and possible in-flight billing. Local mock mode is clearly not GPT.
- Score actual bilateral contact, lifted box height, stable holding and uprightness. Retain
  failed/cancelled trials separately; faster playback or pose animation is not success evidence.
  Once an episode's measurements are finalized, pause its isolated physics space and preserve
  the last render for inspection. Never pause bodies during evaluation to manufacture success.
- Save selected scenarios explicitly under user:// using unique IDs, validated graph snapshots,
  bounded policy, provenance and measured metrics. Exclude credentials and prompts. Loading
  never executes code, changes the workshop or certifies saved metrics; replay is a fresh
  physics evaluation. Applying requires an eligible fresh result and exact current graph.

## Consequences

This is feedback-guided controller parameter search, not GPT weight training or universal
robotics RL. Parallel means multiple isolated simulations scheduled together, not guaranteed
multicore acceleration. Running stability, finger-friction grasping and real-world transfer
remain unproven. UI, tutorials and ko/zh_CN/ja language packs must explain these limitations.

Sources: [GPT-5.6 Luna](https://developers.openai.com/api/docs/models/gpt-5.6-luna),
[Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs).
