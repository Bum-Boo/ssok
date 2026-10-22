# Clean browser checkpoint — 22 September 2026

**Two browser gates passed; physical walking failed. This checkpoint does not approve release.**

The detached, clean commit `0b2fe24607b9313646d0825ed8eaf6af000bd7b8` exported successfully to
single-threaded Web and Linux using official Godot `4.7.2.stable.official.ed1daf0bf`. The
[build manifest](build_release.json) records `dirty_worktree: false`; [archive checksums](SHA256SUMS)
and [Web payload hashes](web_payload.json) identify the exact tested bytes. Both exported resource
inventories excluded the uncommitted construction-kit walking scripts. Export/import, resource
audits and Linux startup completed without engine errors. This snapshot is separate from the
earlier [dirty review build](../browser_2026-09-22/README.md).

The three independent gates ran once, sequentially, in fresh Chromium 153.0.8010.12 contexts with
Playwright 1.63.0 and Python 3.14.7 on Linux/WSL. The complete job exited 1. Environment, test-script
hashes and job identity are retained in [verification.json](verification.json), with the exact
[runner](run_browser.sh) and [Python pins](browser-requirements.txt).

| Gate | Result | Evidence |
| --- | --- | --- |
| Load, render, starter, Run/Stop | PASS | [Raw result](smoke_result.json) |
| Actual paste, save, reload/open, JSON import/rejection, block editing | PASS | [Raw result](authoring_result.json) |
| Actual W input and physical walking | FAIL | [Raw result](physics_result.json) |

Authoring preserved the synthetic learner project through browser IndexedDB, reload and JSON
download. A valid shared document imported correctly; an incompatible document left the current
project unchanged. Adding a Wait block, entering 0.2 and applying it preserved the existing source
and updated exported code. The [1152 × 577 workshop capture](authoring_compact.png) was visually
reviewed: its parts palette remained visible and block rows retained their height.

## Physical failure

The actual command began at observer settle frame 83 (global physics frame 112); the first ready
readout had reported settle frame 73. Browser polling did not force a particular start frame.
The frozen walking snapshot covers exactly 720 physics intervals / 12 seconds.

| Measurement | Observed |
| --- | ---: |
| Forward displacement | 0.4216120541 m |
| Lateral displacement | **0.1010639369 m; required ≤ 0.10 m** |
| Heading drift | 10.865577° |
| Minimum uprightness | 0.96235752 |
| Minimum torso height | 0.12928869 m |
| Foot frames above 0.5 mm | 172 / 280 |
| Maximum collision-sole clearances | 8.034 / 12.751 mm |
| Uprightness after 90 released-command intervals | 0.99976313 |

The lateral limit was exceeded by 1.064 mm. It remains a failure. The other numerical observations
do not override that gate. The walk and stop snapshots were finite, stop commands were zero, and
their graph/runtime identities matched the initial state. The [browser console](physics_console.json)
contains no engine errors. The [failure capture](physics_failure.png) shows the upright robot still
in frame with the new following camera; the test failed before its optional Home reframe.

Exact identities from the raw browser result:

- Graph: `c1920876e4044891aef8a9db6dafc91f665711f0070e3ed590066762a2b024d7`
- Runtime: `11a4b8c162d955fd346dbece9ea8a1a8d567f4de56231ce48b4a792d8f1a773d`
- Canonical policy fingerprint: `b1766c23693273f686cc621ec0bed030319195bf782ace761373b16107e196cf`
- Policy file SHA-256: `42246c56f5074b98ddd7b8f9c1b4e243dc1191c6fd5d6d114e1bbaf3df9e8b9e`

The policy fingerprint hashes its canonical representation; it is not the raw JSON file hash.
No retry was selected to replace this failure, and neither success thresholds nor start timing
were changed to obtain a passing result.

## Native start-time diagnosis

Two separate native processes used this same clean source, engine and frozen policy with fresh
temporary XDG data/config/cache directories. Both completed 737 checks with zero failures:

| Requested native settle frames | Forward | Lateral | Yaw | Raw log |
| --- | ---: | ---: | ---: | --- |
| 83 | 0.41935 m | 0.08146 m | 9.250° | [83](settle-83.log) |
| 84 | 0.43595 m | 0.04296 m | 4.557° | [84](settle-84.log) |

[Native exit codes](native_results.json) are retained separately. Frame 84 was an adjacent-start
diagnostic, not an alternative browser result. Native frame 83 did **not** reproduce the Web
failure. The native awaited-frame count and observer count may have different origins; these
results do not establish the cause of the platform/start sensitivity. Native passes cannot
substitute for the failed browser gate.

Reproduce from this exact commit with the pinned environment and export commands in
[BUILD.md](../../BUILD.md), then run each gate independently:

```sh
timeout --signal=INT --kill-after=20s 10m python tools/ci/browser_smoke.py \
  --directory build/web --output build/browser-smoke
timeout --signal=INT --kill-after=20s 10m python tools/ci/browser_authoring.py \
  --directory build/web --output build/browser-authoring
timeout --signal=INT --kill-after=20s 10m python tools/ci/browser_physics.py \
  --directory build/web --output build/browser-physics

godot --headless --path . --language en --fixed-fps 60 \
  --script tests/learned_app_check.gd -- --settle-frames=83
```

Use fresh temporary `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` directories for the
native diagnostic. Preserve new outcomes, including failures. An improved policy needs its own
held-out validation, new clean export identity and all browser gates before release.
