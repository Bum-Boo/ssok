# Three stage contract additions, 2026-09-30

Scope: explicit scoring targets, environment/runtime-sensitive clear proof and distinct attempt
outcomes. Source is an isolated snapshot (`ce33694`) of live task `ssok/issues-31-36`, followed by
only these additions. The original live worktree was not edited. This is not a released product.

## Behavior and validation

- Target picker lists all instances. Version-2 indexed targets bind to the selected graph entry;
  replacement and ambiguous type selectors cannot silently change the scored part. Version 1 reads.
- Proof covers entire task/environment/solution plus runtime, engine, physics, board API/units,
  part parameters, sensor configuration and seed. Exported Web/Linux packs contain the generated
  runtime/model identity. No trusted proof is imported from a user file.
- Results expose success, unmet goal, cancellation and indeterminate observation, reason and execution
  ID. Code errors propagate to the task UI; late results cannot settle cancelled/newer attempts.
  A range miss stays null with an out-of-range state, distinct from missing sensor/physics.
- `stage_contract_check`: **29 checks, 0 failures**. Includes actual second-instance physics scoring,
  cancellation/code error through UI, real flag success/export, edit-mode export, changed context.
- `stage_ui_check`: **36 checks, 0 failures**, headless and actual GL runs. Sixteen native screenshots
  captured in EN/KO/ZH_CN/JA. Three representative images above were opened and visually reviewed;
  recovery labels wrap and the target picker remains available.
- `localization_check`: **42,812 checks, 0 failures**. Seven new messages in all three translations.
- Import, scene load, app controller, learner language, project store and core authoring pass.
- Related native batch: **9/10 commands pass**. Block-program assertions were 28/28 but the batch
  failed on exit-time resource-leak errors. A separate repeat passed 28/28 with no errors, as did
  another standalone run. The earlier failure is retained; its intermittent cause is not established.
  This report does not claim the complete release gate passed.
- Actual flag, finish-line and wall-brake author solutions cleared in the integration scenario test.
  Stage JSON round-trip checks now pass. The remaining practice-arm assertion also fails on the
  unchanged snapshot; it is preserved as an upstream tutorial issue.
- The unchanged snapshot also reproduces the robot-car stopping assertion failure (12 checks,
  1 failure), with the same observed 4.3571 cm value. This patch does not retune vehicle physics.
- Web and Linux export, Linux startup and export resource audits pass. Both packs contain the
  stage identity manifest. Build metadata records the snapshot commit and dirty follow-up source;
  it must not be presented as an exact clean-commit release artifact.

- Chromium WebGL smoke passes: exported app load, canvas, servo program, actual flag success and stop; console errors zero. Actual success screenshot opened and reviewed. This smoke does not claim Web coverage of every new stage exception.

## Remaining integration

`issues-31-36` is owned by another live session. Integrate only the follow-up patch after reconciling
that session's latest stage files and new ADR numbering. Do not cherry-pick the private WIP snapshot
as though it were an approved upstream baseline. Main/public deployment and server attestation remain
outside this local implementation. Re-indexed authored targets deliberately require reauthoring.

[Contract](../../STAGE_CONTRACTS.md) · [ADR proposal](../../adr/0025-stage-targets-proofs-and-outcomes.md)
