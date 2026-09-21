# Engineering ssok

ssok addresses an educational constraint: a learner should be able to inspect, rebuild and program
a robot without first owning a physical kit. The product challenge is making assembly, code,
contacts and learning describe the same robot while keeping failure understandable.

## One graph, several interpretations

`ConnectionGraph` stores catalog parts, rigid transforms and port connections. The assembly editor
uses it to place objects and undo changes. `RunMode` interprets it as rigid bodies and joints.
Electrical connections determine runtime motor addresses. Project JSON and learning snapshots
serialize this same model, preventing a hand-authored physics robot from diverging from the one
the learner assembled.

For the construction kit, fixed connected components can merge in the physics solver, while
editable part identity, collision geometry, transforms, wiring and summed mass remain available.
This keeps 181 individually selectable robot components tractable without introducing an invisible
whole-limb skeleton. A 29-part bridge reuses the same elementary catalog; it is a practical check
that the components are interchangeable rather than robot-shaped prefabs.

## Fixing a physical failure without changing the test

The initial elementary-kit humanoid contacted the box with both hands but fell during lifting.
It reached only about 8.7–8.9 cm and held for zero seconds, below the original 25 cm / 1 second gate.
The former subassembly robot's successful pickup could not certify this new morphology.

The correction smooths the lift targets and uses the articulated robot's measured center of mass
and velocity to adjust its ankle targets. The motors remain torque-limited; no torso force,
teleportation, hidden support, paused evaluation or disabled gravity produces the result.
The gripper constraint still requires actual bilateral contact and is removed on release.

The updated regression recorded approximately 47.8 cm maximum lift, one second held and minimum
uprightness 0.994. Perturbed box positions and reversed graph ordering are separate tests.
[The construction-kit document](CONSTRUCTION_KIT.md) records the full conditions and remaining
locomotion limits. This is evidence for a specified virtual task, not calibration to real hardware.

## Treating simulation transfer as a requirement

The learning experiment exports the assembled biped into MuJoCo and optimizes a policy rather than
renaming a hand-written gait as learning. Reward proposals, optimization, held-out task evaluation
and engine transfer are distinct steps. Improving training reward does not imply walking success.

A trained ARS policy achieved 25/32 successful held-out MuJoCo evaluations with no falls. The same
policy failed the Godot transfer check. The project retains both results, the frozen policy and
the reproduction commands in [the RL evidence](RL_LAB.md). That MuJoCo policy remains a research
artifact rather than the application's learned controller.

A controlled ablation held the policy and 30 Hz action rate fixed while changing the physics
timestep: the policy that stayed upright at 240 Hz fell at the application's 60 Hz rate, even
inside MuJoCo. Matching policy arithmetic was insufficient because the simulator contract differed.
Follow-up experiments therefore use 60 Hz and verify each joint's physical axis and command sign.
A separately identified yaw-hip robot preserves the old assembly and its failed evidence. Direct
Godot optimization learns twelve periodic coefficients and a frequency from episodic returns,
starting from a disclosed hand-designed initialization. The frozen policy passes 31/32 held-out
episodes with no falls and 42.2 cm mean forward travel in 12 seconds. Both feet lose contact with
positive sole clearance; at least one foot stays grounded. This is learned periodic control,
not learned sensor feedback or a general robot policy.

Episode isolation exposed another misleading success: a candidate that passed 8/8 evaluations
after another candidate had run passed 0/8 in fresh engine processes. Training and authoritative
evaluation now launch one process per episode. The failed candidate and ablation remain in the
evidence; the 31/32 result uses the corrected protocol and independent seeds.

The application uses the evaluator's actual inference class and rejects changed graph or runtime
fingerprints. Five native application start/restart flows pass. Broader rapid-restart tests retain
122/128 successes and three falls, while attempted transition smoothing did not consistently
improve them. Native results cover small initial perturbations in one Linux engine. A separate
Chromium WebAssembly episode measures 43.0 cm forward travel, 7.0 cm lateral drift and 12.8 degrees
heading change across exactly 720 physics intervals. Both feet clear the floor, and the robot
remains upright after release. The exported application provides only a query-gated read-only
observer; the browser supplies actual keyboard input. The final clean release repeats this gate.

## Product engineering beyond the demo

The authoring workflow preserves source and graph together. Imported documents cannot specify
arbitrary Godot resources, paths or executable scenes. Loading a saved project stops existing
control and does not execute stored learner code. Immutable snapshots, explicit replacement and
stale-block detection address common ways an attractive demo loses a learner's work.

Web exports revealed a defect that source-level tests missed: on a short browser viewport, the
starter buttons consumed the entire parts panel and collapsed the catalog scroll area. Compact
starter menus and a scrolling block editor fixed the actual exported application. Dedicated
viewport checks now cover this condition across all four languages.

Independent workflow review found two data-loss paths: unapplied block drafts were absent from a
snapshot, and a serialized empty graph disappeared from the library because JSON read its version
as a floating-point number. Saving now validates and includes block drafts, while schema validation
accepts integral JSON numbers without accepting fractional versions. Disk round-trip tests cover
both populated and empty workspaces. Keyboard tests use actual input events to save a snapshot,
leave the code editor, reach offscreen block actions and close modal panels.

CI discovers the functional checks, supplies an authenticated mock service for transport tests,
isolates saved data, preserves individual logs and fails on any failed gate. Exports are audited
for accidentally packed developer tools or environment files. The public release checklist also
requires actual browser interaction and desktop startup, not merely successful archive creation.

## Deliberate limits

The current language is a small servo teaching subset. The construction geometry is an original
virtual standard. The gripper uses contact-triggered constraints instead of finger-friction
planning. The legacy running experiment passes its 14 start/order cases with measured flight, but
retains up to 0.777 m sideways drift. Robust kit locomotion, the remaining legacy-biped regression
and final clean-build browser verification remain release gates.
These boundaries are recorded in the product and its decision records so future work has an
explicit starting point and reviewers can distinguish demonstrated behavior from ambition.
