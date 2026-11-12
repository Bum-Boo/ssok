# 0040 — Require connected power in free building (electrical tier 1)

- Status: accepted
- Date: 2026-11-11
- Implements: owner feedback of 2026-11-11 that "electricity does not flow", that the workshop does not feel like a simulator, and that parts must correspond to purchasable products; design in [ssok-redesign-20261111](../design/ssok-redesign-20261111.md).
- Extends: 0002, 0003, 0022 and 0039. Graph authority, run-mode physics, wiring-derived pins and hole-targeted assembly remain accepted. No accepted scope is superseded.

## Context

Boards, servos and sensors always worked, and DC motors read a fixed supply voltage from the driver
definition. No part supplied power, so wiring was only a pairing of signal pins and a run could not
fail for an electrical reason. The redesign makes that reason the centre of the loop: a robot moves
only when its electricity is connected, and a failed run says why.

## Decision

- **Tiers.** `RunMode.power_tier` selects the electrical model. Tier 0 is the previous always-powered
  behaviour. Tier 1 is connectivity only. Voltage, capacity and current limits are later tiers.
- **Power cable.** One ELEC link between a `power_source` port and a `power_sink` port stands for a
  two-pin power cable carrying supply and ground together. Separate supply and ground wires, and the
  missing-ground diagnosis that depends on them, are deferred to a later tier.
- **Source and consumers.** A part with `power_source_voltage > 0` is a source. A part with
  `needs_power` works only while its `power_in` port leads back, cable by cable, to a switched-on
  source; boards and drivers pass power on through their `power_out` ports. A DC motor is powered
  when the driver it is wired to is powered. One link per port remains the rule.
- **Battery holder.** `battery_holder_4aa` (4xAA with a built-in switch, 6 V) is the first source. Its
  mesh is built from primitives by `tools/godot/make_power_parts.gd` and lives under `assets/power/`,
  because `assets/parts/` is reserved for Blender-sourced parts with OBJ sources.
- **Switch.** The holder's switch is one workshop-level state shown in the Wiring tab. It is not
  saved with the project.
- **Run.** Entering run mode evaluates `PowerNet`. Motors and servos without supply ignore commands.
  Pressing Run shows the first problem; if the board has no power the program does not start.
- **Where tier 1 applies.** Free building uses tier 1. A stage uses its level's `power_tier`
  (default 0), so the three existing stages and their answers are unchanged. A loaded example or
  saved build that contains no source keeps tier 0 until a source is added.

## Consequences

- Existing checks and battery-free builds behave as before; `power_net_check` covers tier 1.
- The workflow chips do not yet look at power, sensors still return readings without supply, and the
  power message stays until the next run. These are tracked in the redesign document.
- Stage answers need a battery and cables before any stage can move to tier 1.
