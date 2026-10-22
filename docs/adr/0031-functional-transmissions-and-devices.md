# 0031 — Graph-derived transmissions and functional devices

- Status: accepted
- Date: 2026-10-22
- Implements: the user's B-2 functional parts request.
- Extends: 0030, 0002, 0003, 0004, 0011, 0020 and 0023. No accepted scope is superseded.

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
