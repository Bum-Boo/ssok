# 0015 — Separate construction-kit legs with lateral balance joints

- Status: accepted
- Date: 2026-09-22
- Extends: 0002, 0003, 0009 and 0011. The ten-joint pickup assembly remains unchanged.

## Context

The ten-joint elementary kit can lift and hold cargo under bounded motor torque, but all of its
hinges rotate about the pitch axis. Its stable default displacement is mostly foot sliding.
Larger leg swings can lift feet but do not reliably control lateral weight transfer or heading.
Calling that motion verified walking would conceal a morphology limitation.

## Decision

- Add an independent `KitWalkingPreset` using the same elementary beams, plates, brackets,
  fasteners, pads and torque-limited motors. Add physical hip-roll and ankle-roll joints on
  both sides, giving fourteen independently wired axes including the existing arms.
- Add a generic sixteen-channel controller as a separate catalog resource. Its visible electrical
  connectors and graph ports derive from the shared catalog. Keep the existing ten-channel
  controller and the validated pickup assembly unchanged.
- Derive every motor axis, mount, rigid body and collision shape from the editable graph.
  Additional joints are actual mounted motor housings and output brackets, never invisible
  stabilizers or solver-only degrees of freedom.
- Resolve controller joint roles from graph topology, shaft directions and mount geometry.
  Controller addresses continue to come from actual electrical connections.
- Apply balance corrections through bounded joint targets. Do not move feet or torso directly,
  alter gravity, hide supporting surfaces or relax contact and displacement measurements.
- Verify alternating contact loss with positive sole clearance, commanded forward displacement,
  lateral drift, uprightness, joint limits and graph immutability. A new assembly alone does not
  establish successful walking, running, cargo handling or hardware transfer.

## Consequences

The new robot is a separate original virtual mechanism. Saved ten-joint assemblies and their
pickup evidence keep their original identity. Until motion tests pass, the fourteen-joint
assembly remains an experimental morphology rather than a verified learner starter.
