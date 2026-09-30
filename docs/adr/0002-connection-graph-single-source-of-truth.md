# 0002 — ConnectionGraph is the single source of truth; ports cover mechanical and electrical links

- Status: accepted; assembly-placement scope partially superseded by [0007](0007-blender-edit-and-manual-control.md), and electrical placement alignment by [0022](0022-electrical-links-preserve-placement.md). The graph and port decisions remain accepted.
- Date: 2026-09-10

## Context

Assembly needs to feel like snapping parts together ("쏙"), and the user explicitly wants to wire
motors to the board themselves, not just bolt meshes together. Free-form snapping (drop anywhere
on a mesh) makes collision, alignment and joint-axis inference hard to get right and hard to teach.

## Decision

- Parts connect through **ports**: fixed points with a `kind` (MECH or ELEC), a local
  position/normal, a `tag`, and an `accepts` list of compatible tags. Assembly is proximity-snap
  onto a compatible port.
- Electrical wiring (motor connector → board pin) is modeled as ports too, using the same
  mechanism as mechanical joints — not a separate subsystem.
- `ConnectionGraph` (parts + links) is the **only** thing that gets hand-created by assembly, and
  the **only** thing presets serialize. Assembly mode, run-mode physics, and wiring→pin mapping
  are all derived from it — never authored separately.
- Pin numbers used by code come **only** from the graph. If the user wires a servo to pin 9, the
  code sees pin 9 because of the wiring, never from a constant in runtime code.

## Consequences

- Free-form placement (rotate/position anywhere) is out of scope unless a later ADR adds it as an
  advanced mode layered on top of ports.
- Any new subsystem (physics, wiring, presets, undo) must read from `ConnectionGraph`, not keep
  its own copy of the assembly state.
