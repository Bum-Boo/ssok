# 0019 — Learned feedback in a command-relative frame

- Status: accepted
- Actuator budget implementation and interpretation of earlier measurements are corrected by [0020](0020-whole-step-actuator-torque-budget.md).
- Date: 2026-09-22
- Extends: 0012 and 0014. Supersedes only the periodic-only restriction for direct Godot policies.

## Context

The first yaw-biped policy learns periodic joint coefficients, without state feedback. Its frozen
native evaluation passed 31/32 narrow start conditions, while a larger restart evaluation passed
122/128 and included three falls. The clean Web build at `0b2fe24` exceeded the unchanged 10 cm
lateral gate by 1.064 mm. These failures remain part of the evidence. A periodic policy cannot
correct accumulated lateral or heading error because neither appears in its active features.

## Decision

- Retain version 1 policies and their 21-feature inference contract. Add a version 2 policy with
  exactly three additional observations: lateral displacement (metres), lateral velocity (metres
  per second), and horizontal heading error (radians), relative to the current forward command.
- Capture the reference position and horizontal heading at the first active physics tick. The
  right axis is `UP.cross(heading)`. Project both headings onto the horizontal plane before
  measuring their signed angle. A new command after idle captures a new reference frame.
- Use actual simulated rigid-body state. These observations are simulator instrumentation;
  they do not claim that a real robot possesses an equivalent localization sensor.
- Learn six tied feedback weights by direct Godot cross-entropy episodic optimization: common
  hip feedback and opposite ankle feedback. Initialize from the frozen v1 periodic coefficients
  and retain those coefficients while learning the feedback head. The first six-weight candidate
  increased held-out falls and was rejected. An ablation removed the hip feedback and retained
  the three learned opposite-ankle weights; those diagnostic cases became validation data, and
  the resulting candidate was frozen before testing new held-out seeds. Record the initialization
  and the selected iteration. This is learned state feedback, distinct from the earlier periodic
  search and from the optional MuJoCo/ARS experiment.
- Keep 60 Hz physics, 30 Hz inference, the measured motor-before-policy timing and all existing
  torque limits. Only graph-wired servo commands actuate the robot. No body force, transform
  replay, collision exclusion, favourable start-frame selection or success-gate relaxation is used.
- Give v2 a distinct runtime fingerprint. Reject a v2 policy bound to the v1 observation contract.
  Verify numerical Python/Godot parity independently from physical success.
- Separate training, checkpoint selection and frozen held-out evaluation. Compare v1 and v2 on
  identical declared conditions, including starts and restarts. Preserve all failed episodes.
  The 12-second / 0.30 m / 0.10 m / 30-degree gate and actual-app standing/foot-motion checks remain.
- Require the same frozen candidate to pass actual application and Web evaluation before changing
  the bundled policy. A native result alone does not certify WASM behavior.

## Verification so far

The ankle-only candidate passed 64/64 fresh starts and 63/64 restarts on previously unseen
seeds, with one fall. The same conditions gave v1 55/64 and 59/64, with four falls total.
Actual native application flows passed all 12 predeclared start/restart cases. The same frozen
candidate subsequently passed all six declared fresh/restart WebAssembly cases (123 checks),
with maximum lateral drift 0.03914 m. The native restart fall remains a limitation. Exact browser
build identity and outcomes are retained in [the Web report](../evidence/browser_v2_2026-09-22/README.md);
a final clean release still requires its own export verification.

## Consequences

Inference remains a small GDScript matrix multiply without runtime Python, networking or paid
services. The graph, morphology and physical approximations in ADR 0014 remain unchanged. A
feedback policy can respond to drift, but its robustness must be measured; adding observations
alone is not evidence of improvement. Turning, backward walking, arbitrary assemblies and real
hardware transfer remain outside this policy's verified scope.

Training and validation results, source fingerprints and the frozen evaluation specification are
retained before integration. No user-facing strings change solely from this schema extension.
