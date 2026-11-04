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
`-1` keeps builtin stages open to any single matching part kind. Multiple matches block these legacy selectors. The aggregate extension below deliberately selects a set.
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

## Own-build aggregate extension (2026-10-22)

Stage v2 additionally accepts part_id="*", target_index=-1 for min_x, max_height, robot_speed,
wall_distance and wall_contact. min_x/max_height use conservative transformed mesh bounds;
robot_speed is maximum body linear speed; wall_distance is shortest AABB surface separation in
metres from any robot part to environment walls. Legacy stage_wall graph props are excluded from
the robot set and remain usable as walls. max_height also supports a catalog-kind set (task flags).
All new aggregates require v2/index -1. The original six metrics, indexed tokens, v1 parsing,
fingerprint invalidation and terminal outcomes remain valid.

Built-in stages start empty or restore a validated local workspace; answer loading is an explicit
confirmed replacement. Flag success observes task flags rather than servo readiness. Finish success
observes all parts rather than one upright chassis. Wall success observes environment geometry,
stationary hold and persistent actual contact history rather than requiring a sonar sensor.
See [ADR 0036](adr/0036-own-build-stages-and-aggregate-goals.md) and [work D](WORK_SUMMARY_D.md).

### Kit answers and curated tray (2026-11-05)

ADR 0039 replaces the full-catalog tray and chassis/arm answer composition. Lab and all three
stages share the ordered 48-part `PartTray` allowlist. A nonempty `level.parts` further restricts
that list; hidden parts remain in the snapshot catalog for legacy projects and presets.
`KitCarPreset` builds its chassis from kit plates/beams and attaches the two TT motors, wheels,
caster, micro:bit, driver and sonar with mechanical graph links. The original car and braking
programs retain their pin/channel wiring and +X travel. `KitFlagArmPreset` connects a weighted
kit plate base, servo, kit beam and hole-mounted flag; its original `Servo(pin0)` program remains.
Answer loading lowers the moving arm about the new graph output shaft, without changing stage
metrics, limits, physics parameters or runtime conversion. Legacy presets and camera checks
remain available. Source-specific measurements and test output are in [work M2](WORK_SUMMARY_M2.md).

All three author solutions use only curated tray parts. The wall-brake answer is
`KitCarPreset.build(0.8)` with the unchanged `BRAKE_CODE`: a 60 × 40 mm deck on a 140 mm axle
beam, two TT motors with 65 mm wheels, a microbit and driver bolted to the deck, the sonar as the
front-most part, and a 20 g ball caster on a 60 mm beam and spacer. `parts_tray_check` requires
every answer to contain no hidden part. Measurements and test output are in the M2d and M2e
sections of [work M2](WORK_SUMMARY_M2.md); the caster mass is recorded in
[ADR 0039](adr/0039-hole-targeted-snap-building.md).

D-2 adds `cup_count` only for v2, `part_id="*"`, `target_index=-1`. It observes
`RunMode.cup_object_count()`: unique movable bodies with `environment_role="object"` wholly
inside any cup, independent of SKU and cup orientation. Cups and robot/structural bodies are
excluded, as are object bodies mechanically connected to any non-object part. A merged free
object body counts once and all its members must fit. Zero is valid; unavailable/nonfinite physics cannot clear. Existing min/max
and hold rules apply. No built-in stage is added.
