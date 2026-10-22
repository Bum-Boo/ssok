# 0036 — Start stages empty and evaluate learner builds against the environment

- Status: accepted
- Date: 2026-10-22
- Implements: owner's work D decision: assemble, wire and program a personal robot from an empty workbench.
- Partially supersedes: [0028](0028-game-screen-flow-and-stage-levels.md), only preloaded stage robots/code, hidden assembly tools, graph-owned built-in wall and clear-only progress storage.
- Partially supersedes: [0025](0025-stage-targets-proofs-and-outcomes.md), only the claim that every -1 selector must match a unique kind; the added aggregate metrics explicitly select sets.
- Extends: 0002, 0003, 0004, 0022, 0030–0034. Graph authority, physics parameters, runtime APIs, outcome/proof isolation and presentation remain accepted.

## Decision

New stage entries have empty graph/source and the full Lab part catalog. An empty level.parts
means unrestricted, not hidden. Keep Blocks, Code, Wiring, Controls, the parts tray and viewport
tools. Existing scene-first strip, typography, goal annotations, themes and planned courses remain.

Extend stage v2 without rewriting old v1/v2 definitions. The pair part_id="*", target_index=-1 denotes
the robot set, excluding legacy stage_wall props. min_x is the lowest transformed part-bound X,
max_height the highest Y, robot_speed the maximum body linear speed, wall_distance the
minimum nonnegative separation in metres between transformed part bounds and environment wall
bounds. Bounds are conservative world AABBs derived from mesh bounds, not sonar or body origins.
wall_contact remembers any actual robot-to-wall collision for the entire attempt. Empty robot,
missing wall and nonfinite physics cannot certify a clear. New aggregates require v2 and index -1.

max_height also accepts a catalog selector (for example flag), selecting all matching parts.
Other old catalog selectors keep unique-kind/explicit-token semantics. Valid/parse/serialize and
fingerprints use the same rules; all old six metric names and authored indexed tasks remain valid.

The task flag is a real 1 g part with a standard mechanical mount. Extend the arm's attachment
interface with one tip mount; retain its mesh, mass and actuation. Append a flag to the original
answer graph without changing its program. Any support/mechanism can carry it; no servo, pin,
upright or arm predicate gates success. The lowered pose is applied only when loading the answer.

Finish requires every robot bound past X=0.5 m, regardless of orientation. Wall braking requires
5–10 cm surface separation and maximum linear speed <=0.015 m/s for 0.3 s, with no prior contact.
The built-in level owns its wall as a StaticBody3D on the existing sensor/robot collision layers.
Legacy author answers/imported tasks retain graph walls in Lab; stage loading removes those
duplicate props. Wall geometry participates in the local proof context.

Answer/reset actions share a compact HUD menu and require explicit replacement confirmation.
Answer use persists with the workspace and annotates clears. A later independent clear removes
the badge; later answer exploration does not erase an earlier independent clear.

Progress v2 retains old v1 cleared booleans and adds solutions and workspaces keyed by stage:<id>.
Workspaces contain validated ProjectStore documents plus answer-use state. Atomic temporary-file
replacement preserves unrelated stages/clears. Back/list/next save before routing; a block conflict
or write failure keeps the editor open. Restore never starts code or stores run-mode transforms.
No provider, billing, dependency, engine or physics-model change.

## Consequences

Built-in answer physics, empty entry, alternate composition, negative goals, answer confirmation,
legacy stage compatibility and persistence have automated checks. These are source-specific local
results, not public release, arbitrary-robot solvability or GPU glyph verification. Commands and
unavailable checks are recorded in [work D](../WORK_SUMMARY_D.md).
