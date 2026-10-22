# 0001 — Godot 4.7.2, GDScript only, GL Compatibility, web + desktop

- Status: accepted
- Date: 2026-09-10

## Context

The product must run for learners with no install (web) and eventually as a full desktop app,
from one codebase, without a second team maintaining a native rewrite.

## Decision

- Engine: **Godot 4.7.2**, pinned exact (not "4.7 or later").
- Scripting: **GDScript only**. No C# — its web export is unreliable and web is a hard target.
- Renderer: **GL Compatibility** — the only renderer that runs on web export. Do not switch to
  Forward+/Mobile without a new ADR.
- Avoid anything unsupported on web export: threads, `OS.execute`, filesystem outside `user://`,
  blocking network calls.

## Consequences

- Some native-only features (advanced rendering, native threads) are off the table unless a
  future ADR narrows the web target.
- Upgrading the Godot minor version is a deliberate act, not automatic: do it on a dedicated
  branch, let the editor re-save affected files, review that diff, land it as a single
  "migration" commit, and bump the pin in this ADR and in `AGENTS.md`.
