# Legacy biped calibration and integration evidence

This is the versioned four-parameter experimental manual controller from [ADR 0018](../../adr/0018-calibrated-biped-motion-family.md). It is separate from the yaw-hip learned-walking task. The original research failure, numerical mapping, controller selection and final production checks are separate records.

## Calibration provenance

`calibration-reference-policy.json` is the frozen Godot CEM seed-68, iteration-59 checkpoint; SHA256 `9ca25bba163f5cfd8cd68f34f0f4a69a8daaecc5c52d6c0f8d799ebba4d70673`. Its original graph fingerprint is recorded in `forward-mapping/provenance.json`. Eight fresh-process episodes failed the original 0.30 m forward research gate (0/8, no falls; mean forward 0.10346 m). See `calibration-reference-cold-evaluation.json` for every outcome. Reusing its curve is calibration, not a retroactive research success.

The parameter mapping passed 13,200 numerical checks. All 10,800 default command vectors exactly matched the reference. Eight paired fresh-process physical comparisons passed with identical printed metrics; output precision is documented in `forward-mapping/verification.json`. This validates the mapping, not arbitrary parameter choices or complete manual control.

## Rejected controller experiments

`rejected-experiments/` retains per-condition successes and failures. All use Godot 4.7.2 native Linux at 60 Hz; the forward carrier updates at 30 Hz. Different startup timing, link order, actual application input and controller variants are intentionally distinguished. A successful process exit from the batch harness only means all cases were collected; each case's `code` determines its result.

| Experiment | Passed / collected cases | Decision |
|---|---:|---|
| Raw 3D heading, gain −60 / rate 0.08 | 32/32 direct motion; 15/16 actual app | Rejected: actual-app turn fall |
| Raw 3D heading, gain −10 / rate 0.15 | 30/32 direct motion; 16/16 actual app | Rejected: wrong direction / fall |
| Raw 3D heading, gain −30 / rate 0.08 | 45/48 combined | Rejected |
| Raw 3D heading, gain −10 / rate 0.15, trim ±6° | 46/48 combined | Rejected |
| Horizontal heading, gain −10 / rate 0.15 | 46/48 combined | Rejected |
| Horizontal heading, gain −60 / rate 0.08 | 44/48 combined | Rejected |

The earlier raw-heading calculation incorrectly included body pitch in its signed 3D angle. The horizontal projection corrects that measurement; independent pitch/roll invariance checks cover the regression. A coordinate fix alone did not establish stable control, as the retained failures show.

## Forward release and restart

`restart-probe/` records 12 actual-main-scene keyboard sequences: initial neutral 60 frames; W for 60/120/300 frames; release for 1/6/18/90; W again for 720; release for 90. All 180 assertions passed. The second walk advanced 0.077847–0.119591 m in the command-start body frame; minimum body height was 0.119179 m; minimum stopped upright dot product was 0.989773. Every joint target returned to zero and the assembly remained unchanged.

These results bind to controller SHA256 `1164dd5d62d86a46426b1e02023c141ebaa92ea4b29d050fe137a7faf1de0902`, before horizontal-heading integration. Pure W does not enter the heading branch. The exact source manifest, harness and all case metrics are retained; this is a source snapshot, not a clean release export.

## First frozen validation

After selection, the first frozen horizontal-heading/turn-balance candidate (`c7619c41247ee80b67ba168cd0c7f799fa949c391c62f8c634089bf1860f1e8b`) passed 106/112 collected cases. Selection confirmation was 47/48; unseen conditions were 59/64. The new horizontal yaw measurement exposed one marginal left turn, and unseen starts exposed five falls (three direct-motion, two actual-app backward cases). This candidate is not certified. The full predeclared plan, outcomes and source hashes are retained in `rejected-experiments/frozen-first/`.

## Second frozen validation and stop continuity

The second frozen candidate (`8aed021bb7ead5c49aee79c41214b22901c2aea19fb9513e4c0e599c3536cd7d`) uses gain −60 / rate 0.08 and doubles bounded body feedback in backward/turning motion. It passed 169/176 cases: 107/112 development confirmations and 62/64 newly selected start conditions. All 48 actual-app cases passed, but direct-motion checks still found six insufficient/wrong left turns and one backward fall. See `rejected-experiments/frozen-second/`. Those previously unseen cases become development data for subsequent changes.

Independent review found that the captured `ServoDrive.current_deg` is a slew-limited command, not a joint measurement. It already includes balance correction. Adding a fresh correction while blending that command to zero duplicates the feedback at release. Three stop variants (baseline, no added feedback, continuous corrected feedback) each passed 11/11 selected cases, with identical movement-period minimum heights. This does not establish a success-rate advantage. Their exact prototypes and outcomes are in `stop-ablation/`.

The continuous variant removes the initially captured balance term before blending and applies the evolving balance term with the previous movement gain. Thus the first stop target is continuous with the captured command. A regression check tilts the test body and verifies that release does not add another balance offset to its joint targets. Wider physical verification remains required.

## Third frozen validation and command changes

The continuous-stop candidate (`2b2894d045f05107c8ebf929df075e1f5118367ca66d73a00e20b85329d6bc38`) increases backward/turn feedback to a bounded ±45°. It passed 234/240 cases (171/176 development confirmations, 63/64 new conditions). All64 actual-app cardinal cases passed; six reversed-link direct-motion cases still failed, including two falls. The complete outcomes remain in `rejected-experiments/frozen-third/`.

A separate actual-keyboard review passed all eight diagonal cases and all standing, stop, finite-state and graph checks. Four no-idle command sequences failed direction: the final A in W→D→W→A rotated right, and the middle S in W→S→W still translated forward. `command-transition-review/` retains the exact sequence and phase measurements. The stored heading target can survive an intervening straight segment and pull a later turn in the old direction. These are unresolved behavior defects, not successful steering evidence.

## Command-transition diagnostics

Clearing stale yaw targets at a change of turn sign improves the last A's error but does not solve the
no-idle review. Isolated neutral command blends of 0/0.3/0.6/1.0 seconds passed respectively
4/8, 4/8, 5/8 and 6/8 selected actual-app cases; the one-second variant resolves both tested turn
sequences, but both backward sequences still move forward. Reversing the calibrated carrier in time
passes 9/12 expanded cases, versus 8/12 for the neutral-blend baseline; reflecting hip angles instead
passes 5/12 and introduces falls. None is applied to production. Exact sources, predeclared plans and
all phase outcomes are in `command-transition-review/command-blend/` and `reverse-path/`.

The current integrated controller clears stale heading targets without adopting these failed path
variants. Ten focused suites pass, including actual-app cardinal movement, fixture directions,
parameter/messaging contracts, localization and mock HTTP/MCP. Their current source hashes and actual
results are in `local-focused/integration-*`. Passing those checks does not resolve the wider failures.

## Production status

Final production direction validation and clean exported-browser checks are pending. No threshold was relaxed and no failed condition was silently retried to certify this controller.
