# 0039 — Build by targeting holes and show only elementary parts in the tray

- Status: accepted
- Date: 2026-11-05
- Implements: owner feedback of 2026-11-05 that the workshop "is not modular at all": learners place a few large objects instead of joining small parts hole to hole.
- Partially supersedes: [0002](0002-connection-graph-single-source-of-truth.md), only proximity snapping as the primary assembly gesture.
- Partially supersedes: [0036](0036-own-build-stages-and-aggregate-goals.md), only "the full Lab part catalog" in stages, answer robots built on `car_chassis`/`arm_link`, and the flag's arm-tip mount.
- Extends: 0007, 0011 and 0003. Graph authority, run-mode physics, wiring-derived pins, board APIs and stage goals remain accepted.

## Context

The graph already records joints per hole (20 mm pitch, 4 mm holes, 8 mm shafts; ADR 0011), but the
interaction hides it. A tray click drops a part on a floor grid; the learner moves it with G/R and,
on confirm, it links to whichever free port is nearest within 25 mm, ignoring the cursor and the
port normals, with no twist about the hole axis and only one link. Hole markers are identical dots
shown for the selected part only. The tray mixes 93 definitions, including monolithic chassis, torso
and limb subassemblies that ADR 0011 already said must not be presented as the construction kit.
Board, driver, motor, sonar, caster and flag parts have only legacy slot ports, so they cannot be
bolted to kit beams, and the stage answers depend on `car_chassis` named slots.

## Decision

- **Primary gesture: place by hole.** Pressing or clicking a tray part starts a placement with a
  translucent ghost under the cursor. Over an existing part, the ghost's anchor port aligns to the
  nearest free compatible port at the ray hit (normal alignment as in `AssemblyMode.snap()`), with
  90° twists about that normal, a selectable anchor port and a face flip. Over empty space it rests
  on the floor without links. Release (drag) or a second click commits; right click or Esc cancels.
- **All coincident holes join.** On commit, the anchor link and every other free, compatible,
  opposite-facing port pair within 0.5 mm become links. Adding the part and all its links is one
  undo step. One link per port remains the rule.
- **Re-placing.** Dragging a placed part more than 4 px detaches its mechanical links and enters the
  same placement. A short click still selects. Moving a connected group at once is out of scope.
- **Visible holes.** During placement every free port is drawn as a ring; occupied ports are hidden;
  the targeted port is emphasized; rotating shaft ports use a distinct colour. Placement is refused,
  with a reason, when the ghost would penetrate another part by more than 2 mm.
- **Blender-style G/R/numeric editing (0007) stays** as an advanced path with its existing proximity
  snap. It is no longer the gesture the guidance teaches.
- **Tray is a curated list, not the catalog.** The tray shows elementary kit structure, actuators,
  boards, drivers, sensors and environment objects that can be mounted by kit holes or shafts.
  Monolithic or robot-specific subassemblies (`car_chassis`, `biped_body`, legacy `base`/`arm_link`
  family, humanoid and modular-humanoid frames, learning-biped parts) and parts without a usable code
  profile or electrical port are hidden. They stay in the loadable catalog so saved projects and
  presets open. A regression check fails if a hidden id appears in the tray.
- **Legacy electronics gain kit holes.** `microbit`, `arduino_uno`, `motor_driver`, `tb6612_driver`,
  `hc_sr04`, `tt_motor`, `servo`, `ball_caster` and `flag` keep their ids, existing ports, pins and
  runtime behaviour and add `kit_m4` front/back hole ports on the 20 mm pitch.
- **Stages use the same tray.** Stage answers are rebuilt from tray parts only, keep the wiring that
  makes the existing answer programs valid, and attach the flag by a kit hole.

## Consequences

Until a kit car passes the wall stage without changing the legacy car's checks, the wall-brake
answer alone temporarily uses `RobotCarPreset`. With the 5 g ball caster the kit car keeps a
residual caster jitter (about 0.06 m/s); a 20 g caster passed all three kit answers but made the
legacy car miss its camera settle budgets on Linux CI, so it was not kept.

Saved graphs that use legacy parts still load and run. Tests that counted tray buttons or relied on
the floor-grid spawn change. New placement logic is exposed as testable `AssemblyMode` calls so
headless checks do not need real mouse events. The design specification with states, colours and
copy is [docs/design/modular-build.md](../design/modular-build.md).
