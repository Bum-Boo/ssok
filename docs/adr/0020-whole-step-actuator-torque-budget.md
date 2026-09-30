# 0020 — Enforce the physical motor budget across solver iterations

- Status: accepted
- Date: 2026-09-22
- Extends: 0009 and 0014. Corrects the implementation of their bounded actuator requirement.

## Context

The pinned Godot hinge solver clips the motor impulse separately in every solver pass, without
accumulating a whole-step motor limit. The old `torque / physics_hz` parameter could therefore
be spent repeatedly. An isolated unit-inertia rotor in the exact shipping engine produced
approximately 16 N·m from a nominal 0.25 N·m setting with 64 iterations. The same diagnostic
measured approximately 0.25 N·m when the budget was divided across those passes.

This invalidates the interpretation that earlier pickup, running and yaw-biped measurements
used their declared physical torque caps. Their observed trajectories remain historical evidence;
they cannot certify the corrected actuator model. The ideal-limit legacy biped is a separate model.

## Decision

- Keep the pinned engine, GodotPhysics3D, hinge velocity motors and graph-derived actuator values.
- Divide the per-step angular impulse budget by the active physics space's solver iterations and
  the hinge's solver priority. The engine solves each priority level for the full iteration count.
  Read the actual space value so isolated simulation worlds and overrides receive the same bound.
- Retain position feedback, slew and velocity limits. No body forces, collision exemptions, mass
  changes, engine migration or increased catalog torque are used to compensate for the correction.
- Version the actuator model and include that identity, actual iterations and joint priority in
  learned-policy runtime fingerprints. Previously bound policies must be rejected until a distinct
  candidate is explicitly re-evaluated in the corrected runtime.
- Verify actual angular acceleration with a unit-inertia free rotor, both signs, multiple solver
  counts/priorities and physics rates. A check of the configured parameter alone is insufficient.
- Preserve previous training and browser records, label their actuator limitation, and repeat
  affected physical acceptance and exported-app checks before publication. Rebinding old weights
  is a transfer candidate, not a newly trained or already validated policy.

## Consequences

The configured torque becomes a conservative whole-step upper bound. Distributing the budget can
deliver less torque when the solver reaches its velocity target early; this is a simplified actuator,
not hardware calibration. Constraint reactions enforcing the hinge's other degrees of freedom remain
solver reactions, distinct from commanded motor torque. No UI strings change in this correction.

Pinned primary sources: [hinge motor implementation](https://github.com/godotengine/godot/blob/ed1daf0bf/modules/godot_physics_3d/joints/godot_hinge_joint_3d.cpp#L294),
[solver iteration and priority loop](https://github.com/godotengine/godot/blob/ed1daf0bf/modules/godot_physics_3d/godot_step_3d.cpp#L122).
