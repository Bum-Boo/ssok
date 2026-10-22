# 0022 — Electrical links preserve assembly placement

- Status: accepted
- Date: 2026-09-30
- Partially supersedes: [0002](0002-connection-graph-single-source-of-truth.md), only the placement alignment shared by electrical and mechanical snapping. Graph authority, port compatibility and graph-derived pin numbers remain accepted.
- Extends: 0007's object editing and undo semantics.

## Context

Connecting a servo signal to a board pin currently rotates and translates the entire servo as
if the electrical connector were a rigid mechanical mount. A reproduced connection moved the
servo by 94 mm and disturbed its assembled pose. Moving a controller or servo also removes its
electrical links along with its mechanical mounts. This prevents reliable assembly and coding.
The learner needs an explicit way to choose a board pin without moving either part.

## Decision

- Mechanical proximity snapping continues to align compatible ports. Electrical proximity
  snapping creates a compatible ELEC link while preserving both parts' positions and rotations.
- Add a Wiring tab for selecting actual electrical endpoints and compatible board pins, and for
  disconnecting existing wires. Occupied ports cannot be silently reassigned. The tab derives its
  choices and current connections from ConnectionGraph; it owns no alternative wiring state.
- Moving or rotating a part detaches its mechanical mounts and retains electrical connections.
  Deleting a part removes all incident links. Cancel and undo restore placement and links together.
- Explicit connect/disconnect operations participate in the existing undo history. Transform and
  run modes block these edits. RunMode and learner code continue resolving numeric pins from the
  same graph. Project snapshots retain this graph without a schema migration.

## Consequences

An electrical link is a logical wire, without cable geometry, cable length or tension simulation.
It can connect distant parts. It never changes mechanical mounting or actuator physics. Existing
projects retain their recorded positions and connections; loading does not realign them.

The English UI and Korean, Simplified Chinese and Japanese translations change together. Verify
graph-derived rewiring, unchanged placement, undo/redo, movement/deletion, run-mode guards and
saved-project round trips in the actual app and exported browser.
