# 0023 — Explicit stage targets, complete local proofs and terminal attempt outcomes

- Status: proposed; implemented and verified in the isolated stage-contract-hardening branch
- Date: 2026-09-30
- Extends: ADR 0002, 0003, 0004; does not change graph authority or physics

## Context

Catalog IDs identify part kinds, not individual instances. Choosing the first matching kind can
judge the wrong robot part. Local export proofs previously omitted the starting environment and
runtime identity. Cancellation, timeout and unavailable observations require different outcomes.

## Decision

- Stage schema v2 adds `target_index` to each rule. Nonnegative indexes explicitly refer to the
  immutable scene/solution snapshot slots; `-1` means a unique catalog-kind selector. Schema v1
  stays readable with unique-selector semantics. Ambiguous selectors refuse to start.
- Explicit targets bind to a random token on the selected graph entry at goal loading/creation.
  Deletion/replacement or reindexing requires explicit reauthoring/reloading, never silent retargeting.
  Tokens survive edit undo dictionaries but are not credentials or a second assembly model.
  Regular project serialization stays unchanged; stage loading recreates bindings from its snapshot.
- Local proof hashes include the entire stage (scene, solution, rules, constraints and version),
  actual solution graph/source, engine identity, physics settings/tick rate/time scale, board API
  and units, loaded part parameters, sensor noise configuration and seed, and bundled model/runtime
  source identity. The release builder regenerates the identity manifest before export.
- Results are `idle`, `running`, `success`, `not_met`, `cancelled`, or `indeterminate`, with a reason
  and monotonically increasing execution ID. Terminal results cannot be replaced by late callbacks.
- A normal out-of-range sonar reading is missing measurement, never distance zero; it prevents goal
  satisfaction but permits continued simulation. Missing devices/physics are indeterminate; a user
  program error is an unmet attempt with `program_error`, separately from `time_limit`.
- Actual hardware validation happens before stage start. Code errors propagate to the stage panel.
  Motor outputs stop for terminated failed/indeterminate attempts; edit graph/source remain intact.

## Consequences

Old applications cannot read v2 stage files. Local proof is a clear-before-export gate, not signed
server attestation. A file import always requires another observed run; no proof is trusted from JSON.
Editing instance layout may require recreating the task target. Stage condition design stays separate
from graph storage; full persistent object-ID migration and community server attestation remain future
work. Arbitrary meshes replaced in memory outside the product editing API are not a supported action.
