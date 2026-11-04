# M2c — rejected fixed-caster merge experiment

2026-11-05, native Windows / Godot `4.7.2.stable.official.ed1daf0bf`,
GodotPhysics3D / 60 Hz; rendered camera checks use GL Compatibility / RTX 4060.
The detailed contract, tables and interpretation are in
[WORK_SUMMARY_M2, M2c](../../WORK_SUMMARY_M2.md).

Baseline: `55ac0d251b67d9aa493d42d91497395ca8690573`, branch
`feat/modular-build-20261105`, initially clean. The [candidate patch](candidate.patch)
changes only the caster's resource flag and its generator. RunMode, presets, answer
programs, stage thresholds and global physics stay unchanged. The
[source manifest](source-manifest.json) records baseline and candidate SHA-256 values.
Candidate results must not be presented as results of an adopted implementation.

## Same-condition diagnostic

```powershell
& $env:GODOT --headless --path . --language en --fixed-fps 60 --script tools/ci/diagnose_kit_car.gd
```

The tool is identical for both phases; it adds friction and shared-body observations
to M2b's diagnostic, without changing physics. Both cars start BRAKE_CODE immediately,
with floor top y=0.05 m and wall x=0.8 m, and run until two seconds after VM completion.
The source still prints `M2B_DIAGNOSTIC` for compatibility. JSON is extracted losslessly
from that payload except samples, which move to linked CSVs with hashes and row counts.
The CSV vector/contact cells retain Python list syntax from `csv.DictWriter`.

| Phase | Summaries | Legacy time series | Kit time series |
|---|---|---|---|
| Before | [before.json](before.json) | [before-legacy.csv](before-legacy.csv) | [before-kit.csv](before-kit.csv) |
| Candidate | [after.json](after.json) | [after-legacy.csv](after-legacy.csv) | [after-kit.csv](after-kit.csv) |

`result.measurements.robot_speed` is the evaluator's maximum across robot parts.
CSV speeds describe only the body mapped to the caster; after merging, that is the
whole carrier. Its contacts do not identify which constituent shape touched the floor.
The whole carrier uses friction 0.01; both separate wheels retain 0.8. A merged
`mass_ratio=1` is not a ratio to a separate 5 g body.

Kit maximum-part speed falls from 0.06228759 to 0.00043388 m/s, but wall gap
falls from 0.07365817 m to zero and wall contact becomes 1. Both kit diagnostic
results have `status=running, success=false` at the observation cutoff. This
means acceptance was not observed; the diagnostic does not finish the evaluator
with a terminal `not_met` status. Legacy remains successful.

## Verification evidence

Before mutation, 24 legacy-car checks pass: [summary](before-SUMMARY.md),
[results and exact commands](before-results.json), [console](before-console.log).
The selected numeric source logs are retained with a `before-` prefix.
The runner isolates application data and uses its existing mock HTTP service;
no real provider request, billing or publication is part of this experiment.

Required candidate target command (41 checks):

```powershell
python tools/ci/verify.py --godot "$env:GODOT" --match '^(kit_robot_runtime|stage_own_build|game_flow|stage_authoring|robot_car|sonar_stage|parts_pack_.*|stage_contract|parts_tray|agent_camera_.*|camera_evaluator_.*|construction_kit|humanoid.*)_check' --output build/verification-m2c-target
$env:PYTHONUTF8='1'
python tools/ci/verify.py --godot "$env:GODOT" --output build/verification-m2c-full
```

Target: **36 PASS / 5 FAIL**. Four wall-answer/proof suites remain unsuccessful;
`parts_pack_environment_check` additionally regresses: after Stop, the real pushed
ball's cup count changes from 1 to 0. Ramp trajectories also change substantially.
`agent_camera_rest_check` and `camera_evaluator_lifecycle_check-drive_stop` pass
both before mutation and in the candidate target run. Numeric comparisons are
in M2c; thresholds and tests were not edited.

The candidate is rejected. There is no accepted ADR 0040: the proposed draft is
discarded under the brief's failed-experiment branch, which requires measurement-only
delivery. ADR 0003/0037 and their INDEX entries retain their accepted scope.

Full candidate suite: **114 PASS / 7 FAIL** — [summary](full-SUMMARY.md),
[results/commands](full-results.json), [actual console](full-console.log).
Failures are the same four kit wall suites, the new environment regression,
and the existing missing `mcp` / `mujoco` dependencies. The two named camera
checks also pass in the full run. Failed-suite logs have a `full-` prefix.
Target source logs and actual output: [summary](target-SUMMARY.md),
[results](target-results.json), [console](target-console.log).

After collecting those results, both flag edits were restored. `git diff
--exit-code 55ac0d2 -- src presets assets project.godot tools/godot` passes with
no output. Restored hashes are in the source manifest. Rechecking import,
scene-load, `robot_car_check` and `parts_pack_environment_check` gives **4/4 PASS**;
the cup regression disappears. [Restored summary](restored-SUMMARY.md),
[results](restored-results.json), [console](restored-console.log).
The entire 121-suite run was not repeated after restoration; candidate failures
are retained as failures, and no three-stage acceptance is claimed.

CSV hashes, counts and velocity-vector norms were checked for all four time
series. The [independent review](review.md) covers the experiment and target
evidence; its explicitly unobserved final steps are recorded separately above.
