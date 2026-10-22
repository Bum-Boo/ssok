# 0034 — Assign workshop type sizes to the intended content

- Status: accepted
- Date: 2026-10-22
- Implements: owner task A-5, Claude's fixed findings from actual RTX 4090 renders.
- Partially supersedes: [0032](0032-compact-workshop-presentation.md), only the assignment
  of large type to titles and middle type to goals. All layout, Run and emphasis rules remain.
- Extends: [0033](0033-goal-label-space-and-observation-states.md); annotation space and
  observation rules remain unchanged.

## Decision

The strip goal sentence uses the large 28px tier. Its preceding Now category tag uses the
small 14px dim tier. Step chips use 16px and hints 14px. Preserve the two nonwrapping rows,
compact tool/chip rules and full tooltips. Insufficient goal width causes ellipsis at the
chosen text scale, never a smaller font, including at the default scale in a small window.

All editor and help panel headings use the middle 16px bold tier, including code, blocks,
wiring, parts, projects, settings and tutorial headings. Use the existing locale font with
synthetic emboldening; no new font dependency. Result card headings retain the large tier.
The standalone title and stage-selection screens are outside this correction's scope.

## Consequences

No wording, translation keys, graph, physics, runtime, board API, parser, level or outcome
changes. Keep A-2 through A-4 framing, labels, Run behavior, dark colors and cone placement.
[The A-5 handoff](../WORK_SUMMARY_A5.md) records current checks and rendered evidence separately
from the supplied A-3 design findings.
