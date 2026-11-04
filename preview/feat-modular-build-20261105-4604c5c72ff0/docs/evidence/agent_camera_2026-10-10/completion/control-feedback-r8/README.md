# Camera/physical boundary diagnosis r8

2026-10-11T06:41:11+09:00; issue32, `feat/32-robot-camera-loop`, source HEAD `dd9c81494487e20e145e2ab9502daf1a36974770`.
Current426 inputs, camera10 and frozen goal are unchanged. Immutable reviewed package
fa868ca / **0.3.1-projects-r7** and its [r7 gates](../release-current-ui-r7/README.md) remain
separate. This follow-up applies **no app repair**, performs no model-navigation call,
and does not merge or publish. The global ssok objective is incomplete.

The actual user goal is a reliable camera/action loop. The bounded bug signal combines
the unchanged nominal image goal24–38px with the complete independent physical criterion:
valid geometry, forward travel≥3cm, final support gap4–14cm inclusive, no wall contact,
positive minimum gap, rest≥12ticks and stopped state. Neither side alone is success.
The [ranked hypotheses](provenance/hypotheses.json) were recorded before probes/source theory.

Original rendered TCP/calibrator30/10/12 was freshly reproduced twice:

| Replay | Final nominal pixels | Final stopped gap | Image | Physical | Combined |
|---|---:|---:|---|---|---|
| baseline |25|14.0000701cm|pass|fail|fail|
| repeat |23|13.9928192cm|fail|pass|fail|
| reduced30/22 |1|12.6100540cm|fail|pass|fail|

[Receipts/raw output](copy-manifest.json), [case summary](summary.json).
The baseline excess is0.7µm and still fails the unchanged strict limit. Combined failure
reproduced2/2; the individual failed subcriterion changes. Removing one intermediate
capture/settle while preserving52total forward ticks does not preserve the near-boundary
symptom: three action partitions are load-bearing for that replay. Minimization is limited
to these actual cuts, not proof that every remaining item was independently eliminated.

SHA/tick pairing uses the actual `frame_ready` evaluator callback. Camera pose is assigned
at `capture_requested_tick`, which may precede that callback: this pairing does not prove
image pose equals callback physics. [Aligned comparisons](provenance/capture-comparison.json).
Original final captures already exceed14cm; Stop moves closer by1.0014/1.4068mm in the
two original replays. Stop alone is therefore not sufficient cause for their excess gap.

Direct in-process/frame-counted stock (no TCP) still has final five floor heights
23/25/27/23/23px, gap span0.9587mm and nonzero angular rates. Eliminating external transport
does not remove variation; it does not prove transport never contributes.

Two one-gain developer interventions and one admission intervention were rejected:
angular gate0.1→0.003rad/s fails initial settling within240ticks; P8→24 with I16 unchanged
fails after the first forward30; P8→4 completes but still has4px variation and final
14.1215cm physical failure. No candidate was applied. Fault receipts prove ownership
revocation/native exit, not an independently evaluated physical stop for those failed probes.
Body/camera transforms, velocities, motor physics/torque, independent criteria and frozen
goal never change. Per-instance scripts are retained solely as labeled debug fixtures.

Adding allowed brake1 or forward1 as a fourth partition also fails combined acceptance.
An initial post-controller duty sampler appears to show N−1 active outputs. That is a
measurement seam error: the final command is already braked when the sampler reads duty,
although its motor impulse was applied earlier. An exact callback wrapper delegates to the
unchanged production `DriveMotor._physics_process` and observes **30/10/12/1 powered
callbacks for each motor**, matching the requests. All motor parameters/state are preserved.
[Actual callback rows](runtime/direct/motor-callback-trace/result.json),
[observer source](fixtures/motor_callback.gd.txt). Original misleading post-controller trace
is retained; no off-by-one controller repair is warranted.

Increasing the last original partition12→13 (30/10/13), without changing controller or goal,
has three fresh deterministic replays: each13.800904cm and final18px, with final five
19/21/22/20/18px. **Physical3/3, image0/3, combined0/3** applies only to this exact diagnostic
fixture; no AI reliability score or global impossibility follows. Moving one tick within
an existing partition differs from adding a new one-tick partition/capture/settle.

Astra actually inspected12 original640×480 PNGs across two bounded reports. The center
strip is unobstructed: originals are near the boundary, while reduced/tick13 captures
are below the goal. [First six](provenance/astra-repro-inspection.json),
[stock/partition13 six](provenance/astra-partition-inspection.json),
[coordinator hashes](viewed-input-hashes.json). Visual estimates are separate from the
fixed classifier; partition13 idle4 has16±1px versus classifier18px, retained disagreement.
Both fail24px. Still inspection does not establish distance, causation or backend identity.

No new strings, localization, layout, style, physics, provider or app input changed.
Existing unchanged Opus Projects review remains dated r6. Source import/fullnative/Web/
installer gates were not rerun for these documentation-only changes; r7 results remain
source-specific history. Documentation maintain/10unit/ZIP1 checks run on this follow-up.
FLOWS/API/ADR0029/CONTROLS/data/storage semantics are unchanged, so existing diagrams remain.

Next owner Codex: a bounded motor-only angular-damping prototype may test residual chassis
pitch motion, with original combined red signal and exact motor-callback sampling. Keep
camera/physics/goal/evaluator/actor inputs frozen; apply a repair only after causal evidence
and meaningful regression. A separately versioned image-goal calibration is a proposal,
not a silent replacement of this frozen study. Historical AI nominalimage9/9 versus strict
physical0/9 remains unchanged. General navigation, native Mac, Arch originals/formalCLI,
current-package AI end-to-end, human merge and exact-version publication approval remain.

Claude Fable owns the bounded docs integration review/actual rebase; human merges.
Canonical records/Now/readback/recovery receipts remain outside this docs commit under
`C:/Users/Hojun/.agents/backups/ssok-completion-20261010/control-feedback-r8/`.
Generated taskrev16 is not manually edited. No new task ledger, service or schedule.
