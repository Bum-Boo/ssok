# 0018 — Versioned calibrated motion for the legacy biped

- Status: accepted
- Initial standalone board placement is superseded by [0021](0021-clear-legacy-biped-starting-lane.md); the controller and articulated robot geometry remain unchanged by that layout correction.
- Date: 2026-09-22
- Extends: 0008 and 0014. Partially supersedes 0012's single inference-class requirement only for the named legacy four-parameter family below.

## Context

The legacy sinusoidal controller fails signed forward and left-turn checks in clean CI. A frozen
periodic curve from direct Godot CEM calibration gives useful forward motion when combined with
measured body feedback. Its original research policy failed the separate 0.30 m walking gate;
reusing that curve does not change the research result or certify a complete manual controller.
Replacing the four public parameters with an unrelated fixed sequence would also break the motion
lab's contract, and old saved measurements cannot certify a new controller family.

## Decision

- Keep the exact four keys and bounds from 0008. Use `BipedGait` as a frozen periodic calibration
  curve inside `BipedMotion`, with the program identity `pitch_biped_periodic_v2` stored outside
  those four numeric parameters. Raw learned policies, including the separate yaw-hip robot,
  continue to use `LearnedBipedMotion` and their exact graph/runtime fingerprints.
- Calibrate the forward defaults to cycle 1.655731680962178 s, hip carrier peak 32.39478715279682°,
  ankle carrier peak 25.736307930089378° and additional posture offset 0°. The cycle is a full
  period; stride and lean scale the respective joint curves; posture adds opposite hip offsets.
  Zero amplitude removes that joint group's carrier, while balance feedback remains separate.
- Backward and turn trajectories use independently measured reference amplitudes and cadence,
  scaled by each public parameter relative to its forward default. Posture offsets affect
  forward/backward stance; pure turning has no fore/aft posture command, as in the earlier family.
- Use measured body pitch/roll/angular velocity for bounded servo corrections and measured yaw
  for turning. Blend the current slew-limited servo commands to neutral over 0.3 s when movement is released.
  Subtract the captured balance offset before adding evolving feedback during that blend, so release
  does not count the same correction twice. This uses command continuity, not a measured-joint claim.
  Only graph-wired servos receive targets. Preserve geometry, gravity, collisions and the engine.
- Record and require the exact program identity on motion-lab results, including saved metrics.
  Reject unversioned or different-program results as apply evidence without overwriting their
  source files. Their four numeric parameters may be evaluated afresh under the current family.
- Keep Godot and Python defaults synchronized. Preserve the reference coefficients and source
  policy hash in evidence, separately from the new complete controller's measured outcomes.

## Consequences

This is a calibrated experimental manual controller with four bounded search parameters, not a
new claim of learned state feedback or success on the stricter yaw-hip walking task. Native tests
must cover graph rewiring, signed directions, immediate start, release, reversal and varied initial
settling/link order. The actual application and exported build require their own checks. Arbitrary
parameters and analog steering do not inherit default-controller success evidence.

The default forward mapping was numerically identical to its reference for 10,800 vectors; all
13,200 mapping/boundary checks passed. Eight paired fresh-process physical comparisons also matched.
The integrated prototype passed 32 start/link-order conditions before production integration; final
production results are recorded separately. No criterion is relaxed to fit the new controller.

The save/load help now explicitly includes controller identity in the stored record; English,
Korean, Chinese and Japanese change together. Field labels and existing invalid-result messages
remain applicable. Numeric defaults and documentation change together.
