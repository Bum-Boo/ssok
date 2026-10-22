# 0000 — Use lightweight ADRs

- Status: accepted
- Date: 2026-09-10

## Context

Multiple agents (Claude, Codex, cheap LLMs) and one human touch this repo over years, not weeks.
Without a record, an agent re-derives and silently re-decides settled architecture — the most
common way a multi-agent codebase rots.

## Decision

Every decision in this file's numbered siblings uses the MADR-lite shape: Context / Decision /
Consequences. An ADR is **accepted** or **superseded** — never edited in place once accepted.
To change a decision, write a new ADR that supersedes it and say so in both files.

**Any contributor — human or agent — MUST read `docs/adr/` before proposing a change that touches
an existing decision, and MUST NOT re-litigate an accepted ADR in code or in a PR without writing
a superseding ADR first.**

## Consequences

- Small overhead per decision (one file).
- A future agent asking "why is this like this" gets an answer instead of guessing or reverting it.
- The Obsidian vault (`ssok 결정 기록`) mirrors this list for human context (the "why it matters
  to the business"); this directory stays the source of truth for what agents must obey.
