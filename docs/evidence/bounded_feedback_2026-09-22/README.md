# Learned feedback with the corrected 0.25 N·m budget

This frozen candidate was trained and evaluated with `hinge-per-step-budget-v2`, the physical
correction in [ADR 0020](../../adr/0020-whole-step-actuator-torque-budget.md). The previous v2
asset and its old-runtime results remain preserved. Merely replacing that policy's fingerprint
was first tested separately and failed one of twelve development conditions.

Training learns three tied, opposite-ankle feedback coefficients while retaining the previous
periodic carrier and zero common-hip feedback. CEM uses seed 920220, 20 iterations, 20 candidates
per iteration and four generated training conditions per iteration. Twelve previously seen
conditions select the checkpoint; they are not held out. Iteration 14 wins selection, passing
12/12. Every candidate, return, failure and selection decision is in `training/training.json`.
No paid API is used. The final policy SHA-256 is
`d0b91edcee2bf2729ac1392ee3bc19547c9a38d48b96d1a54ea965f614fcf46b`.

The policy and evaluation specification are frozen before 128 new conditions: 64 fresh starts
and 64 restarts, with seed ranges 8100000–8100063 and 8200000–8200063, 0–5-second settling,
initial velocity noise 0.004 m/s, and separately generated warmup/pause durations. Each case
uses a fresh process. The original unchanged 12-second physical success gate and actual-app
standing/foot-motion checks apply.

| Policy under the corrected motor model | Fresh | Restart | Falls |
|---|---:|---:|---:|
| Newly trained frozen candidate | 63/64 | 63/64 | 2 |
| Old v2 weights as an explicit transfer candidate | 64/64 | 62/64 | 2 |

The new candidate does **not** improve aggregate held-out success over the transferred baseline.
Its successful episodes move 0.4058–0.4358 m; the all-episode mean is 0.4135 m, including failures.
Fresh seed 8100016 falls after a 130-frame settle; restart seed 8200050 falls after a 300-frame
settle, 222-frame warmup and 164-frame pause. Complete per-episode outcomes, including the two
different baseline failures, are in `validation/heldout.json`. Neither policy is universally stable.

The same frozen candidate passes all twelve actual native application cases: six initial delays
(0, 1, 60, 121, 180, 257 frames), each fresh and after a three-second walk / one-second pause.
Actual keyboard input, the original displacement/drift/standing gates, upright stop, graph
immutability, camera visibility and incompatible-graph rejection are exercised. This is a
candidate snapshot; its six Web flows subsequently pass as recorded below. Final integrated clean
release verification remains pending.

The graph fingerprint is `c1920876e4044891aef8a9db6dafc91f665711f0070e3ed590066762a2b024d7`;
runtime fingerprint is `0a269bde27b83ce81d78c5fa745237ab960316f4660e6714b624b0a85c6361ae`.
Source scripts, initialization, full training output and frozen specification are retained here.
The managed Himmel jobs in `manifest.json` both completed with exit 0 and released resources.

## Browser harness correction

The first Web job (`20260922-120620-ssok-bounded-policy-wasm-67da7898`) used the production
single-episode observer with the multi-episode test driver. Its `episode`-field wait timed out
even though a 720-frame walking snapshot existed. This was a test-protocol mismatch, not a
completed browser pass. The partial results and screenshots are preserved in
`browser_harness_failure/`; the job was cancelled and its resources released before replacement.

The isolated candidate then receives the exact previously retained read-only multi-episode
observer, which supports natural W release/repress without controlling physics. Two actual
native app pairs, fresh and restarted, have **identical full-precision numeric results** with
the observer enabled or disabled; all four checks pass. Those raw results and the observer
source fingerprint are retained. The complete six-case browser schedule is rerun from a new
isolated export; neither physical gates nor the policy change to address this harness failure.

## Corrected six-case Web result

Job `20260922-121947-ssok-bounded-wasm-observer-8faefe6c` completed with exit 0 and released its
resources. All six predeclared Chromium 153 flows pass with 123 assertions and no engine/browser
errors. Each measured walk lasts exactly 720 physics intervals and each stop exactly 90 intervals.

| Case | Forward (m) | Lateral (m) | Yaw (degrees) |
|---|---:|---:|---:|
| fresh-60 | 0.429205 | 0.029757 | 4.3922 |
| fresh-90 | 0.409571 | 0.004973 | 6.9873 |
| fresh-150 | 0.421040 | -0.008507 | -1.9028 |
| restart-21-18 | 0.431054 | -0.000004 | -10.5269 |
| restart-120-60 | 0.418382 | -0.011975 | 5.3109 |
| restart-222-180 | 0.432972 | 0.001264 | 5.2584 |

Names denote polling thresholds; actual start and restart frames are in `browser/browser/results.json`.
Both collision soles clear 0.5 mm in every case. All six after-stop screenshots were visually
reviewed: the robot remains upright and fully visible between the app panels. Policy fingerprint
`414ea50b0e0996c05aa3e54574f40fb2fb31aa778cb51a94ccfa1985c473f6de` is identical across every case;
it is Godot's canonical JSON representation, distinct from the unchanged file SHA-256 above.

The exact candidate is now bundled as `assets/policies/yaw_biped_bounded_v2.json`. This changes
no UI wording; all four language packs retain the existing forward-only and incompatible-assembly
instructions. The historical v2 file remains available and must fail the corrected runtime binding.
The two independent native falls remain a limitation despite these six browser passes. The browser
build is the explicitly dirty isolated snapshot identified in `browser/release.json` and
`browser/probe-source.json`; it does not replace final clean release verification.

## Integrated native verification

A separate checkout at `9cdd259`, with only the new policy asset and bundled-policy path applied,
passes **55/55 verification suites**. It includes import/scene load, all humanoid walk/back/pick/run
variants, kit pickup, actual-app learned walking, the production observer, localization/layout,
project/block workflows and authenticated mock HTTP/MCP flows. Full output and exact source
identity are under `full_verification/`. The unrelated fourteen-axis kit WIP is excluded from this
checkout. This is full native verification of the integrated candidate; the final committed export
and anonymous public deployment still require independent checks.
