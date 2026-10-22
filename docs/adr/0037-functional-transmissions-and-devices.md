# 0037 — Graph-derived transmissions and functional devices

- Status: accepted
- Date: 2026-10-22
- Implements: the user's B-2 functional parts request.
- Extends: 0035, 0002, 0003, 0004, 0011, 0020 and 0023. No accepted scope is superseded.

A reducer is a purchased mechanical assembly with a housing and two derived shaft bodies.
Its catalog input/output ports route rigid mechanical attachments to the appropriate rotor,
without welding that rotor to the housing. The graph remains the assembly authority.
Rigidly attached axles/loads share the rotor body so their actual inertia enters the constraint.
A 1:2 or 1:3 external gear enforces `wi + r*wo = (1+r)*wh`. One angular impulse with
Jacobian `[1, r, -(1+r)]` gives opposite rotation, r-fold output reaction and a housing reaction;
it conserves angular momentum and does not generate mechanical power. Velocity comes from the
physics server after the motor's same-step impulse. No transform animation substitutes for physics.
The simplified ideal gear omits tooth contacts, backlash and efficiency losses. It has no API.
The motor retains its 0.078 N·m input torque cap; passive output reaction can be 2 or 3 times
input reaction. This is a transmission advantage, not an increase in actuator torque.

Shaft interfaces remain 8 mm; mounting pitch is 20 mm with actual 4 mm openings. Compound
manufactured-device internals derive from PartDef, and teardown removes them with the runtime.
Unverified devices are not exposed merely to increase the catalog count.

LineSensor uses three downward rays over 150 mm, excluding the mechanically connected robot.
All profiles return integer reflectance 0..1023 (black..white), with `is_dark()` below 512.
No hit is 1023 with `last_valid=false`. Catalog hit material luminance determines the value;
unmarked workbench floor defaults to white. Optional seeded Gaussian noise (sigma 0.01 normalized)
follows sonar's opt-in `realistic` convention. Black line paint occupies observation layer 4,
with no physical response; rays include floor layer 1 and paint layer 4. This prevents marker
thickness from becoming an unintended obstacle to a small caster. Environment stock is anchored
through the existing anchored_part_ids path. No runtime pins are hard-coded.

The current UI category selector is a fixed list in scenes/main.gd. Catalog `categories.environment`
and prefixed translated names describe workbench objects, but metadata cannot create a selector
entry. That UI follow-up stayed with the separate owner under the user's B-2 file boundary.
D-2 now adds Environment for surface markers/environment roles and classifies the three new devices as Electronics; Construction kit access remains.

Button observes solver contact indices on its own front plunger collision shape. A merged
chassis's wheel/floor contacts cannot press it. `is_pressed()` reflects that contact; the runtime
also exposes `held_seconds` for continuous-press observations, resetting on separation. It adds
no motor or invented electrical pin. The single signal uses the existing digital_io port contract.
The contact switch has a 50 ms release debounce for solver chatter. A sustained separation
clears both state and held time; a one-tick contact omission does not simulate a release.

LED uses the existing single digital signal. `on()`, `off()` and normalized `set(0..1)`
change a per-instance copy of the emitter surface material; the shared part resource and other
LEDs stay unchanged. MiniRuntime maps learner `set` to the bounded brightness method rather than
Object.set. Stop, execution failure and global stop turn LEDs off through the existing stop path.
GL Compatibility shows emissive material color/energy; this does not claim dynamic light or bloom.

Environment ramps use convex wedges at 10°/20°, balls use sphere collisions, and cups use five
separate walls/base boxes with an open mouth. Ramps/cups join anchored_part_ids; balls stay free.
`RunMode.cup_object_count()` counts unique movable solver bodies wholly inside any cup's local
interior, irrespective of object SKU and cup orientation. Sphere extents are analytic rather than
rotated AABB corners. Other parts use conservative transformed mesh bounds; merged parts must
all fit. The existing allowed solver penetration (1 mm in this project) is the containment tolerance.
This is a runtime observation for later stage integration, not a new StageEvaluator metric.

The 20° slope requires a suitable robot: the verified fixture uses 90 mm wheels; the stock
65 mm-wheel chassis catches its nose there. A sideways cup exposes its mouth to a floor-level
pushing robot. The upright cup has a rim and cannot accept a ball pushed through its walls.

Integration note (2026-10-22): B-2 originally allocated 0031 independently. Renumbered to 0037 alongside A-5/B/D; its B extension is now 0035. Decision scope is unchanged.
