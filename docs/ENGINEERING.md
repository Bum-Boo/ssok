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
the reproduction commands in [the RL evidence](RL_LAB.md). Closing that discrepancy is ongoing work;
the policy is not advertised as a working in-app learned controller.

## Product engineering beyond the demo

The authoring workflow preserves source and graph together. Imported documents cannot specify
arbitrary Godot resources, paths or executable scenes. Loading a saved project stops existing
control and does not execute stored learner code. Immutable snapshots, explicit replacement and
stale-block detection address common ways an attractive demo loses a learner's work.

Web exports revealed a defect that source-level tests missed: on a short browser viewport, the
starter buttons consumed the entire parts panel and collapsed the catalog scroll area. Compact
starter menus and a scrolling block editor fixed the actual exported application. Dedicated
viewport checks now cover this condition across all four languages.

CI discovers the functional checks, supplies an authenticated mock service for transport tests,
isolates saved data, preserves individual logs and fails on any failed gate. Exports are audited
for accidentally packed developer tools or environment files. The public release checklist also
requires actual browser interaction and desktop startup, not merely successful archive creation.

## Deliberate limits

The current language is a small servo teaching subset. The construction geometry is an original
virtual standard. The gripper uses contact-triggered constraints instead of finger-friction
planning. Stable running and Godot-compatible learned walking remain unfinished release gates.
These boundaries are recorded in the product and its decision records so future work has an
explicit starting point and reviewers can distinguish demonstrated behavior from ambition.
