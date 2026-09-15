# 0007 — Blender-style editing and explicit manual/code control

- Status: accepted
- Date: 2026-09-15
- Partially supersedes: [0002](0002-connection-graph-single-source-of-truth.md), only the consequence deferring free-form assembly placement.

## Context

The user requested Blender-style edit controls and keyboard/gamepad operation in run mode.
The previous right-button/WASD flying camera competes with robot control. Selecting a part
currently also detaches it immediately, and a sleeping learner program can resume after its
physics graph has been removed. Both are unsafe interaction semantics for modal editing and
manual/code handoff.

## Decision

- Adopt Blender's object-navigation conventions for the assembly viewport: selection-only
  left click, G/R modal transforms, axis constraints, numeric entry, confirm/cancel and undo.
  Middle-button navigation replaces right-button flying. Godot's existing Y-up coordinate
  system and real part dimensions remain unchanged; no mesh topology editing or part scaling.
- Permit transient unconnected placement as an assembly operation layered on port snapping.
  Committed transforms live in `ConnectionGraph`, and committed connections still require
  compatible ports. Cancellation/undo restores graph transforms and links together.
- Run mode remains graph-derived physics. WASD/gamepad input produces high-level forward/back
  and turning commands consumed by a replaceable movement program containing the joint logic.
  The controller itself knows no joints or board pins. Movement programs resolve their wired
  servo roles from the graph; they never teleport bodies or invent board pins. Unsupported
  assemblies require an appropriate program rather than a fabricated universal locomotion model.
- Internal movement programs may command bounded rest-relative joint angles through
  `ServoDrive.write_relative()` (-90 to +90 degrees). The assembled pose is zero, so backward
  hip swing needs negative offsets. The learner-facing `write()` contract remains 0..180;
  this does not change its clamp or add board-specific behavior to the language runtime.
- Manual keyboard/gamepad control and learner code have exclusive command ownership. Changing
  mode stops the previous program; stopped asynchronous work cannot resume on a newer graph.
  Manual control holds the commanded pose; code-only run mode without commands stays unpowered.
- GUI text input, focus loss and controller disconnection must not leave movement inputs held.
  Camera navigation stays separate from robot commands. Web-compatible GDScript and the pinned
  renderer/engine remain unchanged.

## Consequences

- This is familiar Blender-style **object manipulation**, not a complete Blender mesh editor.
  Numeric movement is entered in millimetres for these small educational parts; angles are degrees.
- The user clarified that joint routines are assumed to be programmed already: the manual
  interface controls the whole robot, not individual joint angles. A biped movement example
  exercises the command boundary; other robot types require their own movement programs.
- DC motor drivers, new board APIs and mesh scaling remain separate work.
- Existing graph, assembly, material and physics regression checks remain required. Input checks
  additionally cover cancellation, mode handoff, keyboard focus, deadzones and controller events.
