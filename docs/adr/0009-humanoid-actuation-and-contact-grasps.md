# 0009 — Graph-derived humanoid, bounded motors and contact-triggered grasps

- Status: accepted; the humanoid-search exclusion is superseded by [0010](0010-modular-humanoid-and-observable-pickup-search.md). Torque, graph and contact requirements remain accepted.
- Actuator budget implementation and interpretation of earlier measurements are corrected by [0020](0020-whole-step-actuator-torque-budget.md).
- Date: 2026-09-15
- Extends: 0003 and 0007; their assembly/physics and graph-derived wiring rules remain accepted.

## Context

The user requested human-like walking, running and picking up a box, and explicitly selected
real physics rather than an animation demonstration. The four-servo Otto example has neither
knees nor arms. Its ideal moving joint limits are not a torque-limited actuator model.

## Decision

- Add an independent experimental humanoid preset with ten articulated, wired joints and a
  dynamic practice box. Every persistent part, mass, initial transform, port and wiring link
  remains authored in PartDef/ConnectionGraph. Keep existing presets and engine unchanged.
- An opt-in actuator torque limit selects a solver-driven hinge velocity motor with position
  feedback and bounded angular velocity/impulse. The equal/opposite reaction is solved by the
  hinge, not an external torso force. Zero retains the existing ideal servo behavior.
- Humanoid joint roles and numeric addresses resolve from the actual graph. The virtual
  controller's pins are not a claim of Arduino compatibility. No interpreter/board coupling.
- Permit transient grasp constraints derived from bilateral hand/box contact during execution.
  They are an interaction result (like solver contact constraints), never authored robot bodies
  or preset connections. Remove them on release, control handoff, reset and teardown. Persist
  neither a grasp nor the changed runtime pose into the assembly graph.
- Do not teleport/freeze the robot or the box, inject propulsive torso forces, disable gravity,
  or claim that a faster pose cycle alone constitutes running. Measure displacement, stability,
  airborne feet, contact before grasp, lifted box height and gravity after release separately.
- Keep the old four-parameter AI policy family scoped to the four-servo biped. Do not advertise
  these hand-authored humanoid controllers as GPT training or a learned humanoid policy.

## Consequences

This is a simplified rigid-body humanoid with a contact-activated two-point gripper abstraction,
not a finger/contact-friction grasp planner or a calibrated hardware model. Joint morphology,
terrain, lateral balance and motion quality limit the supported demonstrations. Report failures
and actual measured capabilities; do not claim real-world transfer or human-quality motion.

Reference: [SIMBICON](https://www.cs.ubc.ca/~van/papers/Simbicon.htm) motivates pose states and
balance feedback; this implementation is not a reproduction of its full controller.
