# 0041 — Dock the workshop panels, let the learner move them, and lead stage cards with pictures

- Status: accepted
- Date: 2026-11-12
- Implements: owner feedback of 2026-11-11 and 2026-11-12: the panels "still look complicated", they should be "a simple game, or at most Blender-like" panels that can be minimized to just watch, parts do not seem to stay where they are put, and the stage screen should drop its diagrams for generated pictures.
- Partially supersedes: [0032](0032-compact-workshop-presentation.md), only the cap of editing panels at 60% of the window height and the rule that one overlay closes the other on wide windows.
- Partially supersedes: [0030](0030-scene-first-workshop-guidance.md) where it lets a change of workflow step open or close panels.
- Extends: 0033, 0034, 0036, 0039 and 0040. Goal labels, type roles, own-build stages, hole-targeted assembly and electrical tiers remain accepted.

## Context

The step checklist opened and closed panels by itself: placing one plate closed the parts tray and
opened wiring. The camera reframed whenever a part or a panel changed, so the hole a learner was
aiming at moved. New plates stood on their edge on the bench. The top bar carried the step chips and
also separate buttons for the same panels, and free building showed six tabs. The stage screen drew
small schematic diagrams.

## Decision

- **Docked panels.** The parts tray docks to the left edge and the program panel to the right edge,
  from below the top strip to the bottom of the window. From 1280 px of width both may be open
  together; below that, opening one closes the other.
- **The learner moves panels.** A change of workflow step no longer opens or closes a panel after
  the first view. The step chips toggle the panel of their step (parts; wiring; blocks or code).
  `T` and `N` toggle the tray and the program panel. Run hides both and Stop restores them. A Run
  that fails on the code opens the program panel.
- **Scene-only view.** `H`, or the "Hide panels" button, hides every panel and the top strip so the
  robot can simply be watched; the same key, `Esc` or the button brings them back as they were.
- **Fewer controls.** The top strip keeps Back, the goal, the hint, Help and Run. Free building
  shows the Code, Blocks and Wiring tabs; Controls, Stages and AI open from the Help menu.
- **Steady camera.** The camera is framed on load, on window resize and by the frame button. A
  panel that opens moves it only when the panel would cover the build. Placing a part never does.
- **Parts lie flat.** A new part dropped on the bench rests on its largest face when it is clearly
  flat. Attaching to a hole keeps the alignment of ADR 0039.
- **Picture stage cards.** Stage and free-building cards lead with a generated picture
  (`assets/stages/art`, provenance in its README) instead of a drawn diagram. Stages that are not
  playable yet are named in one line of text rather than as locked buttons.

## Consequences

- `StageGoalPreview` is removed. The parts and program signals of `StageHud` stay for callers.
- Checks that encoded the old rules were updated: the 60% cap, the single overlay on wide windows,
  the automatic reopening of the program panel while typing, and the always-visible Stages tab.
- The wiring tab reads as a to-do list: its first menu holds only the ports that still need a
  wire, signal before power, with learner-facing port names ("Power", "Pin 0") instead of ids.
  Every wire is one line with a disconnect button, and from electrical tier 1 the tab names the
  parts that still have no power. Power ports are offered only from tier 1. The two menus and the
  connect button keep their place for the browser checks.
