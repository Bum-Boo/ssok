# 0005 — First slice: thin end-to-end (assembly + code) over depth-first on either axis

- Status: accepted
- Date: 2026-09-10

## Context

The full vision spans assembly UX, board-accurate code, and eventually a curriculum layer. Building
any one axis to depth first risks discovering late that it doesn't fit the others (e.g. a rich
assembly system whose data model can't express what the code layer needs).

## Decision

- The first milestone ("Slice 1: servo arm end-to-end") builds the thinnest possible path through
  every layer at once: 1–2 joints of assembly, a few lines of code, one preset.
- First preset / "answer key": a single servo arm (base + servo + arm link) — one joint, matching
  the minimal scope above.

## Consequences

- Early milestones will look unimpressive in any single dimension (assembly UX will be rough,
  language support minimal) — that is expected, not a shortfall.
- Every subsequent slice should still cut through all layers rather than perfecting one.
