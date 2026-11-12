# 0023 — Bounded learner VM, graph-wired DC motors and declarative tasks

- Status: accepted
- Date: 2026-09-30
- Implements: issues #31–#36 and the user's instruction to apply them.
- Extends: 0002, 0003, 0004, 0020. Existing servo and renderer decisions remain intact.

The learner language now parses a bounded Python subset to AST and compiles statements and
expressions into stack bytecode. An explicit PC and operand stack execute at most 128 bytecode
operations per physics tick. No runtime recursive evaluator, external Python, wall-clock sleeps,
threads or native processes are needed. `sleep` conversion is declarative board-profile data;
existing generic/Uno examples retain seconds and micro:bit uses milliseconds. `running_time`
is simulated milliseconds. AST parsing is bounded to 32 levels, 256 tokens per expression,
2048 lines and 64 KiB. Unsupported module imports are rejected; nonvisual statements are
preserved as code cards, not executed by arbitrary host APIs.

DC motors use a separate DriveMotor, not a positional ServoDrive. Only graph electrical links
through a DRV8833/TB6612 driver and its paired board inputs enable an address. Both motor
terminals are represented as one two-contact connector in the graph. A simplified voltage drop
and linear torque/speed curve supply a once-per-tick, equal/opposite angular impulse to wheel
and housing, capped to the torque budget and relative inertia's target-speed impulse. The hinge
only constrains the axle: its motor stays disabled. This extends the per-step actuator principle
without changing the existing servo model or multiplying torque by solver passes.

Bolted car parts reuse the existing graph-derived fixed-body clustering. Cylindrical tires and a
low-friction ball caster are collision approximations. The caster is ahead of the driven axle so
the center of mass is inside the support triangle. No body-position override or translation force
moves the car. Default physics stays GodotPhysics3D; Jolt is tested in an isolated project copy.

Sonar casts a center ray and eight perimeter rays with a 7.5-degree half angle (the sheet's
ambiguous 15 degrees is taken as full width), excludes the mechanically connected robot,
and queries scene-part layer 2. The workbench floor stays layer 1, so grazing floor returns do
not masquerade as forward obstacles. Reflective scene parts keep layers 1+2. Readings are valid
at 2–400 cm; the wrapper returns 401 cm on invalid/no echo and pulse API returns -2/no echo or
-1/timeout. Noise is off by default; opt-in seeded Gaussian noise is a simulation hypothesis.

A stage file holds scene, declarative metrics, constraints and an author solution using the
existing project schema. The evaluator reads physics observations, never executable judge
code or commanded target values. Export requires a fresh successful result for the current
stage conditions, exact graph and source; edits invalidate the proof. Imported solutions carry
no trusted certification. Server galleries, accounts and community moderation stay behind the
explicit roadmap gates in #33. No personal analytics or paid AI calls are added.
