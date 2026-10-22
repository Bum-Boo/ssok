# Frozen ankle-feedback v2: six actual browser episodes

The predeclared three fresh starts and three stop/restart cases passed **6/6, 123 checks,
0 errors** in Chromium 153.0.8010.12. This is an isolated candidate snapshot based on
`7c602972d8c33ea7a6bac715afc0df173c9ac0db`, not approval of an integrated release.
The source manifest deliberately records `dirty_worktree: true`: exact candidate and
read-only observer changes are retained here. No production controller was changed by this test.

| Case | Actual initial settle frames | Warmup intervals / actual released frames | 12 s forward (m) | Lateral (m) | Yaw (degrees) |
|---|---:|---:|---:|---:|---:|
| fresh-60 | 84 | — | 0.426968 | 0.032050 | 3.7188 |
| fresh-90 | 110 | — | 0.424663 | 0.023353 | 12.0676 |
| fresh-150 | 161 | — | 0.418329 | -0.006300 | 2.1768 |
| restart-21-18 | 79 | 39 / 48 | 0.438102 | 0.019252 | -10.8178 |
| restart-120-60 | 78 | 143 / 79 | 0.421199 | 0.039136 | 3.1452 |
| restart-222-180 | 82 | 244 / 202 | 0.415833 | -0.011616 | 10.4172 |

Case names describe predeclared polling thresholds, not forced input frames. Real browser input
and polling overshoot remain in the raw records. Warmup intervals exclude the initial command
sample; released frames are the difference between the first zero-command frame and the next
command start. No simulator timing, pose, velocity or commands were set through the observer.

Every measured walk contains exactly 720 physics intervals at 60 Hz. Minimum uprightness was
0.961564; minimum body height above the floor was 0.128920 m. Both actual collision soles exceeded
0.5 mm clearance and had airborne frames in every case. Per-foot maximum clearance ranged from
5.3375 to 13.0754 mm. After 90 released intervals, uprightness was at least 0.999810. The unchanged
gate also requires forward >= 0.30 m, |lateral| <= 0.10 m, |yaw| <= 30 degrees, finite trajectories,
minimum uprightness >= 0.85 and height > 0.09 m. All six original `after-stop.png` screenshots were
visually inspected: upright robot, complete body visible, camera framing retained.

The candidate still has **one fall in the independent 128-case native held-out cohort**:
restart seed 6307, settle 2.75 s, warmup 0.1 s, pause 1 s, fall at 9.9 s. Its complete metrics are
preserved in [summary.json](summary.json). These six browser cases do not establish universal
restart stability. The earlier v1 clean-browser drift failure remains in
[the original evidence](../browser_clean_0b2fe24_2026-09-22/README.md).

The policy file SHA-256 is `9518b2f31040b1c6bd1d5328c0cc4015f100633683ed60bedaad289cf9387f76`.
Its canonical Godot JSON fingerprint is
`e3de204ce74e93ce38bdca4342224b402bd1cc6508832998024e805938433cd8`; these hash different
representations of the same policy. All six canonical, runtime and graph identities were checked
against the exact candidate. [Build identity](raw/build-release.json) retains both Web/Linux
archive hashes. [Source identity](raw/probe-source.json) retains every changed source hash and
the frozen schedule; its "Web pending" text is the unmodified pre-run record.

The observer variant adds version-aware runtime fingerprints and read-only episode history for
natural W release/repress events. It remains Web/query gated, exposes no setters and leaves physics
running. Two native actual-app comparisons (fresh and 3 s walk / 1 s pause restart) had identical
raw metrics with this observer disabled/enabled, each 737 checks / 0 failures. The observer suite
passed 16 checks. Those logs are under [raw/native-parity](raw/native-parity/).

To reproduce, create a detached checkout at the base commit, apply `source.patch`, and copy
`source/assets/policies/yaw_biped_v2.json` into its corresponding project path. Build with official
Godot `4.7.2.stable.official.ed1daf0bf`:

```sh
python tools/ci/build.py --godot /path/to/godot --version probe-v2-9518b2f3 --output build
python /path/to/this/evidence/tools/browser_matrix.py \
  --directory build/web --output build/browser-matrix --schedule /path/to/this/evidence/raw/schedule.json
```

The browser driver uses the freshly generated sibling `build/export-logs/browser-layout.json`.
Install the pinned [browser requirements](tools/browser-requirements.txt) and Chromium through
Playwright first. [run_browser.sh](tools/run_browser.sh) records the exact isolated Himmel runner,
including job-local system libraries and a 15-minute process deadline. Its source staging paths
refer to the original upload layout. The managed job was
`20260922-071716-ssok-v2-wasm-six-cases-ab31c8f5`, exit 0; all results were fetched and reviewed.

Full raw per-case results, consoles and screenshots are under [raw/browser](raw/browser/).
Source snapshots use `.gd.txt` to avoid duplicate Godot global classes. No user-facing text changed;
language-pack changes were not needed. `sha256.json` covers the preserved evidence files.
