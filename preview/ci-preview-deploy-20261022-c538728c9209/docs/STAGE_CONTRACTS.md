# Stage target, proof and result contracts

User request: implement the three additions from the 2026-09-30 system design review.
Integrated from follow-up `e6242c8` onto learning source `ed6ed32` on 2026-09-30.
The intermediate parent `ce33694` was not reapplied. Integration retains the latest block-draft
checks, diagnostics, stage picker synchronization and browser download behavior. Goal sensors are
resolved from graph wiring before recording the proof context, including timer-only learner programs.
See [the integration record](evidence/merge_2026-09-30/README.md) for fresh verification.

## Target selection

The challenge author picker lists every instance with its part number. It no longer collapses
multiple instances into one part-kind entry. Rules exported in schema v2 include `target_index`;
`-1` keeps builtin stages open to any single matching part kind. Multiple matches block the attempt.
A chosen indexed target is bound at goal loading; deleting it and inserting the same kind does not
redirect scoring. Index layout changes require choosing the target again and recreating the challenge.
Previous v1 documents remain readable; all numbers are normalized through JSON on creation.

## Clear-before-export proof

The proof includes starting environment, author solution, actual current graph and source, task
version/conditions, engine/runtime/model identity, physics settings, board API/time units, model
parameters and sensor noise seed. Changing any covered context makes export require another clear.
Returning to edit mode without changing the build keeps the successful proof exportable. Exported
files contain no trusted certificate; imported challenges must be cleared again. This is local
validation, not a community server signature or an anti-cheating guarantee.

`tools/ci/stage_identity.py` writes the source/model identity included in Web and desktop packs;
`tools/ci/build.py` refreshes it before export. Loaded program/resource identity is cached for the
process; changing source files requires restarting the application to load the new implementation.

## Exceptions

`StageEvaluator.result()` preserves old `success` and `expired` fields and adds `status`, `reason`
and `execution_id`. Timeout and code error are distinct unmet-goal reasons; stop is cancellation;
unavailable physics/target/sensor or changed execution contract is indeterminate. Out-of-range sonar
continues running with a null measurement and `out_of_range` state. It does not manufacture a zero.
Terminal attempts ignore late completion; execution IDs reject results belonging to older attempts.
The UI shows the relevant recovery action and keeps the learner's edit graph/source.

## Verification

`tests/stage_contract_check.gd` exercises duplicate targets, replacement, legacy import, malformed
indexes, environment/engine/sensor changes, stale completions, cancellation, timeouts, unavailable
physics, program-error propagation and actual measured success/export. Additional existing checks
cover authoring, project storage, localization and application API. See the evidence report for
actual counts, baseline failures and remaining integration work; no public deployment is implied.

English, Korean, Simplified Chinese and Japanese messages change together. No AI service or paid
call is used by this change. The scene graph, rendering engine and physical actuator model are unchanged.
