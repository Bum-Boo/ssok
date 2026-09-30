# Stages, Lab and learner hardware (#31, #33–#36)

Open the **Stages** tab to load a challenge or stay in free building (Lab). Three stages are
playable: raise the flag, cross the finish line, and brake before a wall. Each accepts measured
outcomes, not one prescribed assembly/code solution. "Try author solution" explicitly replaces
the current work using the normal unsaved-work confirmation. A challenge itself starts with no
learner code; the author solution is a separately selectable reference.

The first flag entry now uses micro:bit V2 (`Servo(pin0)`, milliseconds). Existing generic and
Uno examples remain available, with their original seconds-based examples. "Build this arm
yourself" presents a loose arm and unwired servo. Mechanical connection uses the existing snap
and undo history; wiring choices show compatible graph ports. Ready feedback names the real
wired pin, and repeated success reports measured flag-height change. The action button helps
connect the highlighted arm; drag/keyboard assembly remains available. A human first-five-minute
study has not happened: the 60-second/5-minute goals remain hypotheses.

Learner code supports variables, finite arithmetic, comparisons, Boolean logic, if/elif/else,
while, break/continue/pass, graph-bound Servo/Motor/Sonar and tick-based sleep/running_time.
A flat operand-stack VM budgets **all bytecode operations**, including expressions, at 128 per
physics tick. An infinite loop yields and Stop interrupts it. Board API descriptors generate
block cards; the parsed learner AST is the authoritative syntax. Indented headers/operations
and remaining code cards preserve source; editing a nested card retains its indentation. This
is a card view, not a full drag-and-drop Entry editor. `for range` and `def` remain P4 work.

A Motor address resolves through the driver's paired board inputs and motor connector. V2 uses
P0/P8 and P12/P16, while the Uno TB6612 profile uses D3/D4 and D6/D7. The motor primitive also
exposes brake and coast. No hinge velocity motor or VehicleBody3D is used. Wheels have cylindrical
collisions, and a ball caster supports the front of the car. Stall torque 0.078 N·m is the
conservative lower cited motor value, a simulator parameter rather than measured calibration.

Sonar reads nine rays, 2–400 cm, `distance_cm()` or `machine.time_pulse_us(echo, 1, timeout)`;
µs / 58 approximates cm. Invalid/no echo is 401 cm for the beginner wrapper and negative for the
pulse API; a stage never scores invalid data as a valid clearance. Scene parts are detectable,
the connected robot and workbench floor are excluded. Noise is off by default and opt-in seeded
noise can be compared reproducibly. The stage evaluator resolves graph-wired sonar independently
of whether the learner uses it, so a timer-only solution is judged on the same real distance.

## Authoring and sharing

In Lab, name the challenge, choose a catalog target and a metric/range/hold time, then choose
"Turn my build into a challenge". Run and clear it with your own code before exporting. Export
binds to the exact conditions, graph and source; an edit requires a new observed run. Copy the
JSON to another device and paste it into "Import challenge". Imported files are untrusted and
must be rerun. Project files retain the old schema; stage files use `ssok-stage` v1 with scene,
conditions, constraints and an author solution. Judge scripts and arbitrary resource paths are
rejected. A file's author solution proves nothing about another machine/physics backend.

The #33 roadmap intentionally gates a gallery/server/accounts behind local user observations.
This change implements declarative conditions and local challenge files (stages 0/1), not those
later services. The 15-stage sequence stays in the research/roadmap record; unimplemented stages
are not presented as playable. The login-free school mode stays first. There is no analytics
upload, community account, brand contact or paid AI call.

## Primary implementation sources checked 2026-09-30

- [Godot RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html):
  angular impulse, inertia and physics-step timing.
- [Kitronik V2](https://kitronik.co.uk/products/5620-motor-driver-board-for-the-bbc-microbit-v2):
  DRV8833, 4.5–6 V, P0/P8/P12/P16 and typical 0.3 V drop at 1.5 A.
- [micro:bit machine](https://microbit-micropython.readthedocs.io/en/stable/machine.html):
  time_pulse_us interface. Our Sonar/Servo wrappers are explicit Ssok learner APIs, not claims
  that micro:bit's stock firmware implements those classes.

The physical model and sonar cone/reflector simplifications are recorded in ADR 0023. Jolt is
only a comparison in an isolated copy; production stays on GodotPhysics3D. Any exported build,
user observation and remaining acceptance limit must be reported with its actual source identity.

To regenerate part resources, run `tools/godot/make_learning_parts.gd` **after** the existing
`tools/godot/make_part_defs.gd` generator. On a fresh checkout it writes the six envelope OBJ/MTL
sources; import the project, then run it again to bind persistent ArrayMeshes and existing shared
PBR materials. These are simplified hardware envelopes, not detailed CAD or calibrated devices.
The second generator adds driver, collider and board-profile metadata; omitting it resets the
augmented old parts. Regenerating an envelope's dimensions also requires regenerating its OBJ.

## First-five-minute observation remains human work

With consent, give each lab colleague/professor a fresh workshop and ask them to raise the flag.
Record whether they reach the first Run within 60 seconds, attach the loose arm, identify/correct
an intentionally wrong pin, change an angle in Blocks and compare a second result within five
minutes. Record elapsed time, attempts and where help was required; distinguish prompts from
independent actions. Use anonymous session labels and the optional local journal only when
agreed. Automated success does not count as a participant completing this observation.
