# Completed branch integration — 2026-09-30

Requested by the user: commit completed work and merge branches into main.

Sources: learning integration `ed6ed32` (including release `3806a1f`); contributor and settings-audit docs `0bf8b54`; stage follow-up `e6242c8` reapplied as `63deb15`. The older `ce33694` snapshot was not reapplied. Core and flag fixes already incorporated by the learning branch remain intact.

Stage merge retains latest diagnostics, block drafts, goal picker, actual Web download and footer feedback. It resolves goal sensors before fingerprinting the run. ADR IDs are 0023 (learning VM), 0024 (contributor context), and 0025 (stage contracts).

Historical product research and the source-specific prelaunch UX audit are committed as documentation, not implemented visual redesign. Active settings UI and halted walking WIP are preserved outside this integration. Main pushes do not publish Pages; deployment now requires explicit manual dispatch with deploy enabled.

Fresh combined verification is recorded below when completed. Historical PR 37 CI run 36689914558 passed its test step but failed artifact upload because repository Actions storage quota was exhausted.

## Verification identity

The clean exported application is `f6ddc43a346084226c6e06ff3d40ba738994309f` (`dirty_worktree: false`). Its application source is unchanged by the following evidence/workflow commit. [release.json](release.json) and [SHA256SUMS](SHA256SUMS) identify Web/Linux ZIPs; import, export resource audits and Linux startup passed. The artifacts stay in the local integration worktree's `build/` folder.

Himmel job: `20260930-175742-ssok-merged-native-66cbbd24`, isolated source snapshot of this candidate, 2,393 files / 95,154,893 bytes. No private vault or credentials were uploaded. The verification uses official Godot 4.7.2 and Python 3.14.7.

Documentation checks and 10 documentation unit tests pass. All six Mermaid blocks render ([metadata](diagram-render.json)); unchanged ERD diagrams still describe Project v1, while Stage v2 is documented separately. The release documentation extraction/link test passes after including all newly linked code/reference files.

Native GL localization UI: 36 checks, zero failures; 16 screenshots captured at 1440×900 with Dummy audio. Four representative screens were opened and checked for readable recovery text and glyphs: [English](en_program_error.png), [Korean](ko_target_ambiguous.png), [Chinese](zh_CN_sensor_missing.png), [Japanese](ja_user_stop.png). Narrow-window settings/layout improvements remain the separate settings task.

Intermediate failures are preserved under `intermediate/`. The first Stage test assumed a wired sensor was unavailable until learner code initialized it; it now removes a real wire to test unavailable sensors. The timer-only regression confirms Stage prepares a graph-wired sensor before fingerprinting. A new Stop assertion exposed the generic footer overriding cancellation; the integration places Stage feedback last. A temporary test typo (`status_label` instead of `status`) was corrected before the candidate, not an app defect. The initial local browser launch lacked Playwright's full Chromium executable; the subsequent run explicitly selects the installed browser.

## Full native result and corrected tooling test

The Himmel command completed with **68/69 groups passing**. Every Godot/app/physics check passed (including Stage contract 31/31, Stage UI 36/36); the failed group was the new documentation test's `import maintain`, which worked under discovery but failed when the full runner loaded it as a module. [Original full summary](native-SUMMARY.md), [results](native-results.json) and [failure](native-tools-docs-test_maintain.py.log) are retained.

The import now uses `from tools.docs import maintain`. All 10 tests pass both discovery and module invocation. The same `verify.py --match tools-docs` entrypoint also passes ([recheck](docs-recheck-results.json)). Thus all 69 groups have passing coverage, with the original full-run tooling failure explicitly preserved; this is not described as a single green full run. No application source changed after `f6ddc43`.

The workflow now runs `browser_learning.py` after export and retains its evidence, alongside the existing browser gates. Pages publication requires an explicit manual workflow with `deploy` enabled; merging source does not publish the product.

## Actual Web learning acceptance

The clean export passes **5/5 browser learning flows**: measured flag success, finish line, sonar stopping before the wall, actual portable Stage v2 download, and UI Stop interrupting an infinite loop. Chromium 153.0.8010.12 / Intel HD 530 OpenGL rendered the application; error-console entries: zero. [Results](web-learning-result.json), [console](web-learning-console.json), [sonar success](web-learning-sonar-success.png), [downloaded challenge](web-learning-verified-challenge.json). These are actual application controls and physics, not fabricated API results. No AI or paid service calls were used.
