# 0024 — Progressive contributor context and source-backed documentation

- Status: accepted
- Date: 2026-09-30
- Extends: [0000](0000-use-adrs.md). Directory review uses an ADR index followed by applicable records and their superseding/extension links. Accepted decision protections remain in force.

## Context

The user requested file trees, ERDs, flowcharts and update rules so additional developers and AI
sessions can join without repeatedly loading historical technical notes and unrelated decisions.
Current implementation is spread across branches; diagrams must not present a live worktree as
verified integrated code. The preexisting AGENTS instruction to reread the entire ADR directory
after compaction makes this cost grow with the history.

## Decision

- AGENTS is the compact mandatory rule set. START_HERE routes tasks to documents, code and ADRs.
  STATUS separates dated product decisions, baseline implementation, work in progress and evidence.
- Review the complete generated ADR index on entry/resumption, then read decisions relevant to
  the task and linked extensions/supersessions. If the boundary is unclear, expand the reading.
  Never silently reverse or re-decide an accepted decision.
- Keep source-backed DATA_MODEL and FLOWS separate from proposed Stage/community contracts.
  Generate the code map and ADR index from this checkout, without build logs or vendor internals.
- Maintain a small machine-readable documentation registry. Check local links, source symbols,
  generated maps and explicit source-review fingerprints in a lightweight CI job. Fingerprints
  flag review needs; they do not prove diagrams match behavior or that app tests passed.
- The author of a change reviews its affected documentation in the same change. Only explicit
  review updates a contract fingerprint. Preserve dated evidence and technical history.
- Agent-private context contains pointers. Local shared task records complement repository
  issues/PRs; the repository onboarding path must work without access to a private vault.

## Consequences

New contributors get bounded entry context and expandable task routes. Structural drift and
unreviewed changes to documented contracts become visible. Semantic/visual review still belongs
to contributors. A new subsystem needs routes, diagrams/contracts as appropriate and its own
acceptance checks; regenerating maps cannot certify it. Documentation-only work does not require
rerunning expensive physics or browser suites when application code and assets are unchanged.
