# Flag mission integration evidence, 2026-09-30

This directory retains the existing results of the servo-arm flag integration. Copying them here did not rerun the checks. The implementation was subsequently committed as `521d171` on `feat/31-flag-mission-reuse`. The original export metadata reports base `3a142eb` and `dirty_worktree: true`; it is not a clean-commit build of `521d171`.

- [Native summary](verification-summary.md) and [raw results](verification-results.json): 10 selected suites, zero failures. This is not the whole historical release suite. Individual logs are under `native/`.
- [Flag observations](native/flag_mission_check.log): 10 assertions, actual initial/minimum height and successful hold. [Localization](native/localization_check.log): 36,959 assertions, zero failures.
- [Original export metadata](export-release.json): Web/Linux ZIP sizes and SHA-256. The ZIPs remain in local `build/flag-release/`; this directory does not publish those applications.
- [Browser smoke](browser-smoke-result.json) and [console](browser-console.json): Chromium 154.0.8037.92, single-threaded WebGL, no console errors. The automated smoke verifies loading and input; the success state was checked by reviewing the actual [result screenshot](03-flag-result.png).
- [Browser authoring partial result](browser-authoring-result.json): persistence, reopen, valid import and invalid-import preservation completed. The local execution session ended at `07-blocks`; `passed: false` is retained. The final block-edit segment did not finish. The native block suite passed separately.
- [File manifest](manifest.json): source locations, sizes and hashes of the copied evidence.

Reproduction entry points are `tests/flag_mission_check.gd`, `tools/ci/verify.py`, `tools/ci/build.py` and `tools/ci/browser_smoke.py`. The Korean overview and source boundaries are in [the technical note](../../TECHNICAL_NOTE_2026-09-30.md).

![Actual WebGL success state after the servo program](03-flag-result.png)
