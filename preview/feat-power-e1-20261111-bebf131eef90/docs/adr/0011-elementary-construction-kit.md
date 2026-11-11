# 0011 — Elementary, interchangeable construction-kit parts

- Status: accepted
- Date: 2026-09-15
- Extends: 0002, 0003 and 0004. Supersedes the construction-kit interpretation of 0010's robot-specific frame modules; its physics, code and pickup-search boundaries remain accepted.

## Context

The user explicitly rejected calling a humanoid made from joined torso/limb subassemblies a
modular Science Box. Separately selectable large objects are not interchangeable elementary
construction parts. The previous rails' decorative holes were not individual assembly ports.

## Decision

- Add an original virtual construction standard: 20 mm hole pitch, 4 mm mounting holes, explicit
  face normals and separate actuator-shaft interfaces. Do not claim compatibility with any
  commercial Science Box, LEGO, motor, fastener or calibrated hardware standard.
- Elementary bars, flat plates, bent brackets, spacers, couplers, fasteners and contact pads
  remain independent catalog resources and graph instances. A single manufactured bent bracket
  or purchased motor/controller may be one unit. Never join independent structural members,
  limb frames or covers into a robot-specific authored mesh.
- A shared catalog defines the physical geometry and every visible attachment hole. Blender
  meshes and Godot per-hole ports derive from that definition. Multiple mounting positions must
  work; cosmetic hole markers are not sufficient. Bolted fixed links remain an educational
  rigid-attachment abstraction, not simulated screw insertion or thread friction.
- Build the humanoid and a structurally different example from the same elementary catalog.
  Their ConnectionGraphs are authoritative. Export those graphs for Blender's assembled,
  exploded and parts-tray scenes; do not independently hand-author a second robot layout.
- Fixed components may merge only in the runtime solver as permitted by 0003/0010. All editable
  graph identities, geometry, mass and wiring survive. No hidden whole-limb collision proxies,
  physics-only skeleton parts, arbitrary body movement or gravity suppression.
- Generic motor addresses come from wiring. Humanoid control discovers its articulated chains
  from the assembled graph and geometry; it must not require body-part-specific motor SKUs.
- Keep prior assets/presets for compatibility and stored scenarios, but identify them as legacy
  subassemblies rather than presenting them as the new construction kit. Save a new Blender file
  without overwriting the source currently open in the user's editor.
- The larger elementary graph is bounded at 256 parts and 1024 links for local snapshots.
  Pickup proposals still send only fingerprint, bounded policy and measurements to the bridge.

## Consequences

Acceptance requires actual independent components in Blender, common hole/port geometry,
working alternative mounting points and reuse in a second structure—not merely an exploded
render or increased object count. New physical morphology is independently verified; previous
pickup/walking results do not certify it. CJK catalogs, guidance and regression checks must be
updated alongside the new workflow. Stable running and real-world transfer remain unproven.
