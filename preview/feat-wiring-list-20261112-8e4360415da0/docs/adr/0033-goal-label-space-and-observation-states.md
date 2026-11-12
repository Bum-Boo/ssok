# 0033 — Preserve goal label width and simplify unobserved targets

- Status: accepted
- Date: 2026-10-22
- Implements: owner task A-4, fixed Claude findings from actual RTX 4090 captures.
- Extends: [0031](0031-workshop-presentation-corrections.md) and [0032](0032-compact-workshop-presentation.md).
- Partially supersedes: [0032](0032-compact-workshop-presentation.md), only hint omission when
  the goal annotation cannot fit; its summary occupies the hint slot instead.
- Partially supersedes: [0030](0030-scene-first-workshop-guidance.md), only assembly pose
  previews in the screen goal annotation. Unobserved rules now show targets only.

## Decision

Screen goal labels use nonwrapping natural content width with a minimum of 260 UI pixels
scaled with interface text. Edge clamping preserves that size. If the scene area excluding
open panels and the strip cannot fit either dimension, hide the annotation and leader line.
Show the primary rule's current value / target in one strip hint line; all rules and hold
details remain in its tooltip. Compact step names before trimming this summary. A fixable
error retains priority. Restore the ordinary hint and annotation as soon as space returns.

Before an evaluator observation, each rule shows a single target line. Assembly transforms
are not execution measurements. An observed rule adds its current value and hold time in
the existing two-line format; a missing observed sensor stays unavailable. The world anchor
does not move when the label height changes. No display state can certify completion.

Finish-line roadside cones have twice the spacing and at most half the visible count.
Retain the pair closest to the finish line. Change decoration only, preserving any collision.

## Consequences

No graph, physics, runtime, board API, parser, stage condition, dependency or provider changes.
Keep framing, strip formatting, themes and Run labels from A-2/A-3. Source identity, headless
checks and separate rendering limitations belong in [the A-4 handoff](../WORK_SUMMARY_A4.md).
