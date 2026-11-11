# Holding speed reference and angular integral diagnostic r11

2026-10-11T07:19:45+09:00; issue32, input HEAD `3070d2fe87d73944b2d5b18e190509b25de39003`. Local diagnostic only.
Immutable app/package **fa868ca / 0.3.1-projects-r7**,426 source inputs, camera10,
frozen raw goal and independent physical thresholds are unchanged. No app repair or AI trial.

Two separate paired comparisons use actual graph motors and rendered camera:

- Stock versus world-wheel changes only PI speed from wheel-minus-housing to wheel world-axis rate.
- K16 angular-reference versus joint-integral retains the same proportional term
  `-8*relative_wheel_rate +16*housing_rate`. Only integral error changes from relative wheel rate
  to `relative_wheel_rate -2*housing_rate`, testing potential integral cancellation.

These are distinct experiments, not one four-case single-variable comparison or a gain sweep.
Each uses P8/I16,25% cap, forward25%, original30/10/12, four30-tick idle/capture intervals,
12stableticks/240timeout and original Stop132ticks. DriveMotor and torque/physics/graph/camera
remain unchanged. No evaluator distance/contact/target-pose inputs or pose/velocity assignments.
The [r8 red loop and minimization limits](../control-feedback-r8/README.md) remain the baseline.
Predictions precede runs in the [original contract and hypotheses](provenance/contract.json).

| Probe | Final five center floor pixels | Span | Final stopped gap | Physical | Final image | Both |
|---|---|---:|---:|---|---|---|
|stock|23/25/27/23/23|4px|14.106308cm|fail|fail|fail|
|world-wheel|25/24/25/27/25|3px|14.121157cm|fail|pass|fail|
|angular-reference|22/24/21/22/21|3px|13.850644cm|pass|fail|fail|
|joint-integral|20/20/22/23/20|3px|13.845751cm|pass|fail|fail|

[Exact summaries](summary.json) and [original hashes](copy-manifest.json).
All four native runs and wrappers exit0 within19.15–20.88s; this is bounded execution,
not acceptance. Each motor has powered callbacks30/10/12 exactly. Physical pass also requires
valid evaluation/travel≥3cm/gap4–14cm/no contact/positive minimum gap/rest12/Stop.
Every candidate still fails the simultaneous24–38px image and independent physical target.
Signed housing rates remain roughly0.0040–0.0045rad/s. Neither comparison demonstrates
a clear chassis-rate reduction or causal jitter fix. One-pixel span changes in these
single runs cannot establish reliability. All candidates are **rejected and not applied**.

There are eight real640×480 PNGs per run,32 retained; seven post-initial frame_ready
samples per run are bound by exact SHA/tick. Initial PNG precedes observer attachment.
Camera pose assignment and later callback samples remain distinct timing claims.
Astra actually viewed exactly two stills per case, `post-3.png` and `idle-4.png`,
eight images total, with findings in
[its receipt](provenance/astra-inspection.json). Visual estimates and classifier results
remain separate. Stills do not prove continuous jitter, physics, causality or backend identity.

No UI, user strings, localization, provider, package or source426 change. Existing Opus design
review remains applicable. Documentation maintenance and existing document tests accompany
this evidence; app import/fullnative/Web/installer are not rerun, with dated r7 history preserved.
AI image9/9 versus physical0/9 remains unchanged; these developer replays do not update it.

Next Codex: identify the camera/physical boundary and a falsifiable observation-only remedy
before further controller candidates. A separately versioned calibration proposal must keep
this frozen benchmark and requires a product decision before adoption. Operator packaging,
Mac native, Arch originals/formal task release and human merge/versioned publication remain.
Fable performs bounded docs/integration review; human merges. No merge/push/publication.
Canonical records/recovery: C:/Users/Hojun/.agents/backups/ssok-completion-20261010/world-wheel-hold-r11/.
Global objective remains incomplete.

Documentation recovery: first entry-context251>250 check failed, then one newly added
blank line and its helper caller were corrected; maintain/10unit/ZIP1 passed. Ordinary
authored-doc diff passed. Exact original CRLF and three fixture EOF blank lines are retained
with command-local whitespace allowances; no global Git configuration or raw runtime bytes
changed. The first Fable Bash call added unallowlisted `--branch` and was denied before
execution; no fetch/rebase occurred. [Recovery record](review-recovery.json).
Runtime input HEAD remains3070d2f; initial diagnostic-evidence commit67482b0; this
document correction is later and does not alter runtime inputs or original92 copies.
