# 0032 — Bound compact workshop overlays and name the primary action consistently

- Status: accepted; goal-summary hint priority partially superseded by [0033](0033-goal-label-space-and-observation-states.md); typography roles partially superseded by [0034](0034-correct-workshop-type-roles.md)
- Date: 2026-10-22
- Implements: owner task A-3, fixed Astra findings from actual RTX 4090 captures.
- Extends: [0030](0030-scene-first-workshop-guidance.md), [0031](0031-workshop-presentation-corrections.md).
- Partially supersedes: [0031](0031-workshop-presentation-corrections.md), only the guarantee that
  normal-size hints always remain visible. Width takes precedence over displaying every hint.

> [0034](0034-correct-workshop-type-roles.md) corrects only typography roles: the goal sentence
> is large, its category tag small/dim, and panel headings middle/bold. Other rules remain.

## Decision

Keep two nonwrapping strip rows, at most 96 px at the default three-tier typography. Measure
translated content before assigning space. Omit the hint before reducing chips to icons and status;
retain full names and instructions in tooltips. A tool label appears in full or becomes an icon
with a tooltip. The primary action retains its complete label. Editor overlays occupy at most
60% of the viewport height and scroll internally, preserving their existing controls and drafts.

Use the existing Run translation for the primary action, distinct from Code tabs. Instructions
quote that label. Titles use the large type tier, goals the middle tier, hints the small dim tier.
Execution highlights use outlines; one filled primary action remains visible per screen.

Road paint and goal markings remain visual geometry. Any shadow correction must leave collision,
graph state and measured success unchanged. Retain A-2 framing, screen goal labels, dark scene
colors and the finite workbench edge. No new renderer, runtime, board API or dependency.

## Consequences

Headless compact geometry and label checks complement existing regression checks. Actual glyph,
GL shading and hardware captures remain separate evidence, recorded in the task A-3 handoff.
