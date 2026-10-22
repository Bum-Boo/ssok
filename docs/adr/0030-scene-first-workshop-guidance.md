# 0030 — Scene-first workshop guidance and a light workbench

- Status: accepted
- Date: 2026-10-22
- Implements: owner task A, Claude's explicit design decision of 2026-10-22.
- Partially supersedes: [0028](0028-game-screen-flow-and-stage-levels.md), only the opening
  briefing, fixed stage goal/program layout and hidden example access in Stage/Lab.
- Partially supersedes: [0026](0026-interface-preferences.md), only the default appearance.
  All preference storage, explicit light/dark/system choices, draft and execution preservation remain.
- Extends: 0002, 0003, 0004 and 0025. Graph, physics, board API, VM and outcome contracts remain.

## Decision

Stage and Lab sessions use the full-window scene with collapsible parts/program overlays. The
opening frame starts with both closed; the next state refresh opens the relevant editing panel.
An assembled, wired robot with valid code leaves both overlays closed, ready for Run. Running
closes an automatically or manually opened panel. Manual opening/closing persists until the actual phase changes.
The four chips reflect current facts, including regression after deletion, disconnection or invalid
source. Unapplied blocks are validated without applying them; conflicts remain unresolved drafts.

The top task strip contains the goal, four steps and short hints, labeled tool toggles, Help and
one primary run/reset action. Result cards offer retry and, after success with an available next
stage, next. The result card sits at the bottom; the scene remains visible. Goal decorations show
thresholds, assembly pose previews and exact evaluator samples/hold times. Missing sonar data
stays unavailable. Display text and illustrations never certify completion.

Help contains tutorial/settings/projects and explicit starter examples, using the existing replace
confirmation. Loading a reference during a stage retains its goal. Lab remains a separate card
in stage selection. Stage cards include a goal illustration, difficulty and the existing learning topic.

New preferences default to light. Saved explicit preferences remain authoritative. Three UI type
sizes, translucent panels and a mint accent share the existing theme and CJK fonts. Blocks use
inline descriptor-derived argument controls with wrapping at enlarged sizes. Executing never
forces a code-tab switch. The mat/grid and background are visual decoration; existing collisions
and the graph-derived robot remain unchanged.

## Consequences

Legacy empty-session/standalone example entry points remain available for existing integration
checks. Only the three existing stages are playable. No new renderer, library, catalog or provider
is introduced. Current validation, rendering limitations and source identity belong in
[task A's work summary](../WORK_SUMMARY_A.md), separate from historical release evidence.
