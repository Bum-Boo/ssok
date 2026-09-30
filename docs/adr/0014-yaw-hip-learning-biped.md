# 0014 — A separate yaw-hip biped for physical policy learning

- Status: accepted
- Actuator budget implementation and interpretation of earlier measurements are corrected by [0020](0020-whole-step-actuator-torque-budget.md).
- Date: 2026-09-22
- Extends: 0002, 0003, 0009 and 0012. The existing pitch-hip assembly geometry remains unchanged.

## Context

The first learned pitch-hip policy succeeds in MuJoCo at 240 Hz but fails at the application's
60 Hz physics rate. Holding policy weights and the 30 Hz control rate fixed while changing only
MuJoCo's physics timestep produces 16 falls in 16 episodes at 60 Hz, versus zero at 240 Hz.
Training at the wrong rate therefore cannot establish app behavior. Direct Godot searches also
found slow movement that did not satisfy the unchanged walking task.

Small four-servo biped designs can use vertical hip yaw axes with ankle roll. The existing
`BipedPreset` instead uses horizontal hip pitch axes. Changing axes inside an evaluation script
would disconnect its evidence from the editable robot and its rendered motor shafts.

## Decision

- Add a separate `YawBipedPreset` with its own catalog IDs under `assets/learning_biped/parts/`.
  The existing biped, parts, ports and evidence remain available independently. Its manual gait
  can be calibrated separately without changing this learning robot.
- Derive actual motor orientations, transforms, opposed ports and every physical joint from its
  graph. Hip output shafts point down; ankle output shafts point forward/backward. Keep four
  separately wired servos, existing foot geometry and the existing part masses.
- Use the existing opt-in motor model with a 0.25 N·m torque limit. Never move the torso directly,
  disable gravity, prescribe foot transforms or substitute an animation for physical locomotion.
- Opt in to graph-derived fixed-component merging for the new body, motor housings, legs and
  sensor mount. Keep their separate editable identities and collider transforms. The existing
  engine computes compound inertia approximately: an isolated direct-state audit found 11.3%
  tensor difference for the torso and 4.1% for legs against summed separate-body tensors using
  the parallel-axis theorem. Mass differed by less than 4e-9 kg. COM differed by at most 0.54 mm:
  separate bodies use collision-derived centers, while current compounds mass-weight part origins.
  These are quantified modeling approximations, not exact inertia preservation or hardware calibration.
- Train and evaluate at the application's native 60 Hz physics / 30 Hz policy rate using the same
  `LearnedBipedMotion` inference class. Record `robot_id`, graph and runtime fingerprints.
- Keep the 12-second, 0.30 m forward, 0.10 m lateral and 30-degree yaw success gate. Adding a
  morphology does not certify walking; only frozen-policy held-out Godot evaluation does.

## Consequences

The new graph is an original educational mechanism, not an exact hardware replica or a claim of
real-robot transfer. Its basic axis arrangement was checked against the
[Otto DIY assembly manual, page 6](https://robu-prod-media.s3.ap-south-1.amazonaws.com/uploads/2020/10/DIY-OTTO-Programmable-Robot-Kit.pdf).
No upstream controller source, mesh or firmware is copied. Sinusoidal policy features are generic
mathematical functions; their coefficients are learned from measured simulation returns.

The catalog adds three names and therefore requires English, Korean, Chinese and Japanese entries.
Until the physical evaluation passes, this is a research robot and is not a verified app policy.
