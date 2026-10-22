# 0030 — Bounded ranges and graph-derived passive bearings

- Status: accepted
- Date: 2026-10-22
- Implements: the user's work B request for runtime control structures and functional parts.
- Extends: 0002, 0003, 0004, 0011 and 0023. No existing decision is superseded.

The learner VM adds `for name in range(...)` with one, two or three arguments without allocating a list.
One, two or three integral arguments are evaluated once per loop entry; zero steps are errors.
Bounds are limited to absolute value 1,000,000,000 and at most 10,000 planned iterations.
Constant bounds are checked during whole-source preflight. Dynamic bounds are checked when reached.
`break` and `continue` target the nearest loop; changing the loop variable does not change the iterator.

All while/for bodies share a 10,000-entry budget per execution. Simulated time and monotonic wall
execution time each have a 60-second limit, including sleeps. A limit failure brakes DC motors,
emits the existing runtime error signal and cannot continue the old bytecode. The 128-operation
per-tick budget and Stop/mode ownership semantics remain. These are educational limits, not a
claim to execute arbitrary Python; def, collections and external calls remain unsupported.

Hardware aliases preserve the existing drive and observation models. Ordered `Motor(a, b)` inputs
must resolve to one graph-wired driver channel. `Motor(a)` remains compatible. Forward/backward
use percent power and `distance()` returns the existing centimetre sonar observation.

A `PartDef.passive_hinge` rotating connection creates only a limited HingeJoint3D. It does not
create a ServoDrive, motor command address, electrical connector or hidden actuator. Its resource's
angle bounds are catalog data; positive connected-body rotation follows the bearing output
normal, independent of link endpoint ordering. Godot hinge limits reverse this sign internally; per-instance angle editing/serialization is outside this increment.
The elementary catalog can generate simple primitive meshes using shared materials while keeping
its existing 20 mm mounting pitch and 4 mm/8 mm interfaces. Existing Blender-authored stock remains.

This increment exposes only tested hinge, wheel and weight definitions. Gears, grippers, new
sensors, LED and environment parts remain unexposed until their own behavior is implemented and
verified. Game-stage tool visibility is retained under the user's separate UI work boundary.
