# 0031 — Frame subjects and theme the workbench presentation

- Status: accepted
- Date: 2026-10-22
- Implements: owner task A-2, the fixed Claude design findings of 2026-10-22.
- Extends: [0030](0030-scene-first-workshop-guidance.md), only its presentation.
- Partially supersedes: [0026](0026-interface-preferences.md), only the exclusion of decorative
  3D materials from appearance changes. Learner part materials and physics remain untouched.

## Decision

Frame the current graph meshes and the level's goal marker meshes after panel layout. Exclude
scenery and ground. Stage entry/reset/retry and Lab entry/preset loading use the same calculation.
Opening panels or resizing can update the automatic frame until the learner navigates the camera.
User navigation suspends automatic framing until the next explicit reset or preset load.

Goal annotations project a world marker onto the UI layer with a translucent panel and a single
leader line. Clamp offscreen anchors and labels to the available scene area. Only current values,
target conditions and hold times appear there; evaluator authority and missing observations remain.

The task strip uses two nonwrapping rows: goal/actions, then four small step pills and the current
step hint. Detailed stage hints remain tooltips. Fixable errors replace the current hint. Enlarged
text can trim the goal/hint with the full text in its tooltip; normal sizes retain the whole text.

Appearance changes update the decorative sky gradient, mat/grid and fog color immediately. Keep
light colors. The mat has finite edges and thickness; its visual extent never changes collisions.

## Consequences

No graph, stage rule, physics, runtime, hardware API, project schema, dependency or provider changes.
The previous design review is the input; current headless and rendered evidence are recorded
separately in [task A-2](../WORK_SUMMARY_A2.md). No release or integration is implied.
