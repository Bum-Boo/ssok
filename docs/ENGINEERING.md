# Engineering ssok

ssok is an educational robot workshop: a learner assembles and wires reusable parts, programs
that assembly, and observes it under simulated gravity and contact. The engineering challenge
is keeping the editor, code, physics and learning experiments accountable to the same robot.

The integrated application is verified at `6470757`: **55 native verification suites**, clean
Web/Linux exports, Linux startup, and all three actual-browser gates pass. The browser checks
cover controls, complete project/block authoring, and learned walking followed by upright stopping.
This remains a **private release checkpoint**. Continuous legacy direction changes, sustained
construction-kit walking, final publication review and public delivery are unfinished.
[Clean-export evidence](evidence/browser_clean_6470757_2026-09-22/README.md) binds the results to
exact source and served-file hashes; the [release plan](RELEASE_PLAN.md) retains every open gate.

## One graph owns the robot

`ConnectionGraph` stores catalog parts, rigid transforms and port connections. The editor uses it
for placement, snapping and undo. `RunMode` derives rigid bodies and joints from it. Electrical
links determine servo addresses. Project JSON and learning snapshots serialize this same graph.
A separately authored physics skeleton cannot silently diverge from the learner's assembly.

The elementary construction kit uses independent beams, plates, brackets, motors and fasteners.
Every attachment hole comes from the same catalog used to generate Blender geometry and Godot
ports. A humanoid and a bridge reuse those parts. Fixed connected components merge only in the
runtime solver; their editable identities, collision geometry, wiring and summed mass remain.
The catalog is an original virtual standard, not a claim of commercial hardware compatibility.
[Architecture](ARCHITECTURE.md) and [kit construction](CONSTRUCTION_KIT.md) document these boundaries.

Board profiles describe capabilities and APIs, the language runtime interprets a servo teaching
subset, and block cards derive from the board API. Keeping those layers separate lets a new board
change its pin map without embedding board-specific logic in the interpreter or block editor.

## Testing the physical quantity, not just the configured number

A motor parameter that looked correct was not a correct physical torque cap. In the pinned Godot
hinge solver, the cap was available on each solver pass. With 64 iterations, an isolated rotor
accelerated as if a nominal 0.25 N·m motor supplied approximately 16 N·m. Merely asserting that
the joint parameter equalled `torque / physics_hz` would have certified the faulty implementation.

The correction distributes the physical step's impulse budget across the actual solver iterations
and joint priority. A unit-inertia rotor measures angular acceleration for both signs, several
solver counts and priorities, and multiple physics rates. The regression failed before the change
and now passes **385 assertions across 16 physical conditions**. This is a conservative upper
bound: the motor can deliver less torque when it reaches its requested speed early.
[ADR 0020 and the pinned engine sources](adr/0020-whole-step-actuator-torque-budget.md) record why.

This discovery also changed how existing evidence could be described. Earlier motor-driven
trajectories remain available, but their nominal-torque interpretation is invalid. The learned
runtime fingerprint now includes the actuator-model identity, actual iterations and joint
priority. Old bound policies are rejected until separately evaluated under the corrected model.
The ideal-limit four-servo legacy biped remains a distinct physical approximation.

## Recovering pickup within the corrected motor limits

The elementary-kit pickup must make bilateral hand contact, lift the box at least 25 cm, hold it
for one second, stay upright and release it under gravity. A successful predecessor robot or a
higher search reward cannot certify this assembly. The gripper is an explicit contact-triggered
constraint abstraction, not a finger-friction planner.

After the torque correction, the previous lift timing failed. Comparing 2.5, 3.25 and 4.0-second
lifts led to a synchronized **4.0-second default**. The corrected implementation passes **277 kit
assertions and 12 pickup integration suites**, including the previously failing offset, reversed
graph ordering, actual contact, release, UI and mock-service flows. Failed duration comparisons
are retained in [pickup revalidation](evidence/torque_budget_2026-09-22/pickup_revalidation/README.md).

The current native recording reaches approximately **47.7 cm** and holds for one second. Start,
middle and final frames were inspected, and source and media hashes accompany the measurement.
No increased motor specification, torso force, hidden support, gravity suppression or transform
replay produces this outcome. [The recording evidence](evidence/corrected_recordings_2026-09-22/README.md)
keeps the physical measurement separate from the additional time used to display the result.

## Learning, simulator transfer and held-out failure

The first MuJoCo/ARS experiment passed 25/32 held-out conditions but failed transfer to Godot.
Holding the policy and 30 Hz action rate fixed exposed a timestep mismatch: a controller that
remained upright at 240 Hz fell at the application's 60 Hz physics rate. Numerical policy parity
was necessary but insufficient. The failed transfer remains a [research artifact](RL_LAB.md).

Direct Godot optimization therefore evaluates the shipping inference class at 60 Hz. A separate
yaw-hip assembly preserves the legacy geometry and its results. The bundled version combines a
frozen periodic carrier with three learned opposite-ankle feedback weights. It observes lateral
position, lateral velocity and heading relative to the current command. These are internal
simulator measurements, not a claim that real hardware has equivalent localization sensors.

Training, checkpoint selection and frozen evaluation remain separate. Every authoritative episode
starts a fresh engine process after an earlier candidate was found to depend on leftover evaluation
state. Candidate rewards never replace the 12-second, 0.30 m forward, 0.10 m lateral, 30-degree yaw
and stability gates. Both feet must physically clear the floor, and release must end upright.

Under the corrected 0.25 N·m actuator model, the frozen bundle passes **126/128** new native
conditions, with **two falls**. The previous weights, explicitly transferred to the same runtime,
also pass 126/128 with different failed episodes. The new bundle therefore does **not** demonstrate
an aggregate robustness improvement. It passes all 12 declared actual-app cases and all six declared
WebAssembly cases; those narrower passes do not erase the wider failures.
[Complete training and validation](evidence/bounded_feedback_2026-09-22/README.md) include rejected
candidates, all episode outcomes, policy hashes, source identities and reproducible tooling.

The clean integrated browser export measures **42.9 cm forward, 3.0 cm lateral and 4.4 degrees
heading drift** over exactly 720 physics intervals. A query-enabled observer reads actual state
without owning commands or modifying simulation. Playwright supplies browser keyboard input.
The native demonstration recording separately measures 41.8 cm; it is not substituted for Web
verification. Neither result proves universal locomotion or real-world transfer.

## Preserving learner work and verifying the exported app

A project preserves the assembly and learner source together. Import accepts validated catalog
IDs and rigid transforms, not arbitrary resource paths or executable scenes. Opening a project
stops current control and never runs the imported source. Immutable snapshots and explicit
replacement protect the existing workspace. Unsupported code and stale block drafts are shown
instead of silently discarded.

Two regression fixes illustrate why complete workflows matter. Unapplied block edits were missing
from saved snapshots, and an empty graph disappeared after JSON read its integral version as a
floating-point number. Saving now includes valid drafts, and schema checks accept integral JSON
numbers while rejecting fractional versions. Disk round trips cover populated and empty projects.

The Web export exposed problems native tests missed. Compact starter menus fixed a short viewport
that collapsed the parts catalog. Godot's asynchronous clipboard cache also lost the first paste.
A narrow bridge now preserves trusted browser paste before handing insertion back to the normal
Godot editor. Tests use the actual clipboard, IndexedDB, reload/reopen, JSON import/export and a
block edit retained in exported code. They do not replace canvas fields through a test-only DOM.
English, Korean, Simplified Chinese and Japanese are maintained together.

CI discovers functional checks, supplies authenticated mock HTTP/MCP services, isolates saved data,
retains failures, exports both platforms and audits packaged resources. The clean browser checkpoint
checks every served file's hash. Corrected demo recordings retain raw measurement output, including
a first capture-metadata mistake that was fixed without changing the application simulation.

## Work still required for release

The kit can lift cargo, but its fourteen-axis walking controller has not demonstrated sustained,
credible locomotion. A few foot landings followed by a fall are diagnostic progress, not a walking
pass. The legacy manual biped also needs reliable continuous direction changes and its own final
Web evaluation. Both remain release blockers; neither inherits the yaw-biped policy's evidence.

The remaining work also includes the final source/history and attribution review, public Web and
desktop publication, and anonymous use of those exact published artifacts. Original project rights
remain reserved. The project's value as an engineering portfolio depends on reviewers being able
to reproduce its demonstrated behavior and identify its limits, rather than infer completion from
screenshots or an attractive README.
