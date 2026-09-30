# Completed branch integration — 2026-09-30

Requested by the user: commit completed work and merge branches into main.

Sources: learning integration `ed6ed32` (including release `3806a1f`); contributor and settings-audit docs `0bf8b54`; stage follow-up `e6242c8` reapplied as `63deb15`. The older `ce33694` snapshot was not reapplied. Core and flag fixes already incorporated by the learning branch remain intact.

Stage merge retains latest diagnostics, block drafts, goal picker, actual Web download and footer feedback. It resolves goal sensors before fingerprinting the run. ADR IDs are 0023 (learning VM), 0024 (contributor context), and 0025 (stage contracts).

Historical product research and the source-specific prelaunch UX audit are committed as documentation, not implemented visual redesign. Active settings UI and halted walking WIP are preserved outside this integration. Main pushes do not publish Pages; deployment now requires explicit manual dispatch with deploy enabled.

Fresh combined verification is recorded below when completed. Historical PR 37 CI run 36689914558 passed its test step but failed artifact upload because repository Actions storage quota was exhausted.
