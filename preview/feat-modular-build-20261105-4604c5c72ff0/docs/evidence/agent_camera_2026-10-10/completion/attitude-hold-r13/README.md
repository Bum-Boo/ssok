# Body-attitude holding diagnostic r13

2026-10-11T08:13:06+09:00; issue32; runtime input **008f7ea0bf3dd2c8a8113eb3431f4793ad072ece**.
Developer-only prototype; no production source change, merge, push or publication.
Immutable app **fa868ca / 0.3.1-projects-r7** and all426 current source inputs remain
unchanged. The frozen image goal24–38px and independent physical gap4–14cm are retained.

| Actual native probe | Last5 center-floor pixels | Span | Final gap | Image | Physical | Combined |
|---|---|---|---|---|---|---|
| Original holding | 23,25,27,23,23 | 4px | 14.106308cm | FAIL | FAIL | FAIL |
| Body-attitude coefficient16 | 22,23,25,26,24 | 4px | 14.079912cm | PASS | FAIL | FAIL |

These two rendered probes replay the same graph/wall0.35 and30/10/12 actions, with
four30-frame-spaced idle observations and132frames after Stop. Actual powered motor
callbacks are30/10/12 on **both** motors. Each run preserves8actual640×480PNGs and
7post-initial pose samples paired by capture SHA/tick. Native runs exit0 in
19.461s/19.528s, with confirmed Stop. These are developer physics probes, not AI trials.
The historical camera-only3layout×3AI study remains image9/9, strictphysical0/9.
[Original receipt](runtime/stock/receipt.json), [candidate receipt](runtime/attitude-hold-v2/receipt.json).

Only the ignored per-instance prototype adds a fixed16 small-angle world-quaternion
attitude-error term to ordinary P8/I16 holding, through the same graph-wired finite
motors and25% duty cap. It latches current body orientation at actual frame_ready,
invalidates that reference on accepted forward, and retains original settling
before the next capture. Fixed forward25%, DriveMotor, physics engine/backend,
graph, camera mount/FOV,12/240 settling, actor inputs and evaluators are unchanged.
No pose or velocity assignments, hidden evaluator input or gain sweep. The candidate
is **rejected and unapplied**: unchanged4px span and similar signed body rates do not
establish a precision repair. Its0.264mm single-run gap difference is not reliability
or causal evidence. [Ranked pre-test hypotheses](provenance/hypotheses.json).

The first prototype omitted the base cancel default argument and failed to compile.
No physics trial or PNG started; the bounded wrapper timed out at90.413s and reaped
only its owned process tree. Original error, inputs and receipt are retained under
failed-compile/failed-prototype-inputs. Recovery restores the matching default,
passes actual headless check-only, adds an explicit load-null guard, and writes a
fresh attitude-hold-v2 output; feedback law/gain and production source are unchanged.
[Recovery](provenance/recovery.json), [original error](runtime/failed-compile/godot.log).
The debug fixtures are archived evidence and are not production controllers.

Astra actually viewed4selected640×480stills. Both pairs show approximately22px
post-3 and23px idle-4, ±2px, central band unobstructed. Classifier candidate-last24px
and visual23±2px remain separate observations. No continuous-jitter, causal,
physical-distance, backend identity or success claim follows from these stills.
[Actual inspection](provenance/astra-inspection.json). Camera pose assignment and
frame_ready callback physics can occur at different ticks; SHA/tick pairing does
not prove their simultaneity or explain the pixel drift.

[Separate calibration proposal](calibration-v2-proposal.json) describes12–20px
with the same physical criteria, layouts and original3CLI/8step/9image/180s limits.
It is **not adopted or run**, and does not replace or pass the old benchmark.
Prior18px/13.800904cm deterministic points motivate measurement but do not prove
global goal incompatibility or a robust calibration. Product adoption needs a
decision; until then the original target remains authoritative.

Runtime commands are in each preserved plan.json. The archived driver requires
the documented Windows checkout/toolchain and original private receipt paths;
it is evidence, not a portable product launcher.16PNGs/named raw bytes are retained
without normalization; copy-manifest identifies their source and SHA. Full app
import/native suite/Web/installer/exports were not rerun because production input
bytes did not change. Existing r7 app gates and Opus UI review remain dated history.
Only documentation maintain and its10tests are run for the curated handoff.
No localization, UI, provider, account, cost or action-contract change.

Next: retain the failed frozen study; measure a versioned calibration only if its
target is selected, otherwise continue falsifiable original-target control work.
Account onboarding, general navigation, native Mac, powered-off Arch raw recovery/
formal task16 CLI release, human merge and exact-version publication remain incomplete.
Claude Fable owns functional review/rebase; human owns merge/publication.
Whole requested goal remains incomplete.
