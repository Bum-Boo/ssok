# Whole-step motor torque correction

The exact shipping engine is `4.7.2.stable.official.ed1daf0bf`. A unit-inertia rotor with no gravity,
contact or damping isolates motor torque as `I * delta_angular_velocity / delta_time`. This test
fixture is not a locomotion demonstration and does not alter production gravity or collisions.

The original direct hinge diagnostic (`isolated_hinge.gd.txt`, `isolated_hinge.log`) measures about
16 N·m from a nominal 0.25 N·m cap at 64 solver iterations. Dividing the same input budget by64
measures about0.25N·m. The pinned engine clips motor impulse per solver pass, without a motor
accumulator; its priority loop can repeat those passes.

The production regression then uses actual `ServoDrive`, not a copied budget calculation.
It covers16 cases: both signs,1/16/64 solver iterations, priorities1/3, plus30/120Hz with priority2.
The old source fails112 of385 assertions and exits1 (`baseline_servo.log`, `baseline_result.json`).
The corrected source passes385/385; maximum measured torque0.25000334N·m, within0.0001N·m numeric
tolerance. Solver-count and priority variations no longer multiply the physical cap.

Five focused suites pass after correction: the physical torque budget, learned schema/numerical
parity, changed-runtime rejection, wired relative commands and run-mode construction. These are
contract checks, not renewed pickup/running/learned-walking acceptance. The historical bound v2
policy is rejected; changing actual world iterations or a motor's priority is also rejected.

Hashes and commands are in `manifest.json` and `results.json`. Prior locomotion and pickup results
remain historical. No success threshold was relaxed.
The model decision and pinned primary source links are in [ADR0020](../../adr/0020-whole-step-actuator-torque-budget.md).

## First corrected-runtime evaluation

`corrected_transfer/` retains every outcome, including failure, from personal Himmel job
`20260922-114329-ssok-torque-correction-transfer-042024a4` (completed, exit 0). The runner's exit
code means the batch finished; individual check exit codes and episode metrics determine success.
The source manifest identifies the working-tree inputs, including the separate kit topology WIP.

The existing v2 weights, unchanged and explicitly unbound for this **transfer experiment**, pass
11 of 12 previously used development conditions. Fresh start seed 6120, settling 121 frames with
initial velocity noise 0.004 m/s, falls after 10 seconds. It travels 0.22018 m, below the unchanged
0.30 m task. This is neither new training nor held-out evidence. All episodes report runtime
`0a269bde27b83ce81d78c5fa745237ab960316f4660e6714b624b0a85c6361ae`.

Five of six physical suites pass: the torque regression (385 checks), legacy humanoid pickup
(62), legacy running (36), modular pickup (435), and isolated pickup trials (415). Legacy and
modular pickup lift 0.393 m and 0.417 m; legacy running travels 1.243 m with 23 airborne frames
and 0.453 m lateral drift. These are the specific rerun conditions, not the historical expanded
validation matrices.

The kit suite fails 2 of 275 assertions. Base pickup and three of four offset conditions pass,
but box offset x=-0.005 m, z=-0.010 m reaches only a transient 0.455 m lift, no one-second hold,
and minimum uprightness 0.480. Its bilateral contact and grasp succeed; its lift stability does
not. The complete failing log is preserved. Corrected-model pickup robustness, newly bound
learning, actual application and Web acceptance remain release work.
