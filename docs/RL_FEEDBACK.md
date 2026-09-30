# Historical command-relative feedback experiment

> **Historical actuator results:** [ADR 0020](adr/0020-whole-step-actuator-torque-budget.md) corrected the per-pass impulse budget on 2026-09-22. The measurements on this page predate that correction and do not certify the stated physical torque limits. The current policy's corrected-model validation is linked below.

The current corrected-torque policy and its independent evaluation are documented in
[the current heading-feedback report](evidence/heading_feedback_2026-09-22/README.md). All results below
use the earlier actuator implementation and remain historical evidence.

The frozen version 2 candidate passes **64/64 fresh starts and 63/64 restarts** in native
Godot 4.7.2, with one fall. Version 1 passes 55/64 and 59/64 on those same conditions, with
four falls total. These are simulator results for the unchanged yaw-biped graph; the candidate
was bundled in that earlier runtime after passing six declared actual Web start/restart checks.

| Independent frozen evaluation | Version 1 | Version 2 | V2 falls | V2 mean forward | V2 maximum lateral |
|---|---:|---:|---:|---:|---:|
| Fresh starts, seeds 6101–6164 | 55/64 | 64/64 | 0 | 0.42282 m | 0.06019 m |
| Restarts, seeds 6301–6364 | 59/64 | 63/64 | 1 | 0.42034 m | 0.05008 m |

Each episode runs in a fresh native Linux process, at 60 Hz physics and 30 Hz inference. Start
delays are predeclared integer frame counts from 0 through 300; initial x/z velocity noise is
±0.004 m/s. Restarts cross eight warmup durations (0.1–4.7 seconds) and four pauses
(0.1, 0.3, 1 and 3 seconds), with two seeds per pair. Success keeps the 12-second, 0.30 m,
0.10 m and 30-degree task, plus the actual app's minimum uprightness 0.85, torso height above
0.09 m and both feet physically leaving the ground. There is no gate relaxation.

The remaining failure, seed 6307, starts after 2.75 seconds, walks for 0.1 seconds, pauses
for one second and restarts. It falls at 9.9 seconds after moving 0.20346 m. Version 1 passes
that particular case, so the aggregate improvement does not imply superiority in every state.
All cases, including failures, are in [the raw comparison](evidence/feedback_2026-09-22/ankle_heldout.json).
The earlier v1 31/32 held-out and 122/128 restart results use different conditions and remain
separate evidence in [RL_LAB.md](RL_LAB.md).

## What was learned

The v1 oscillator's twelve coefficients and frequency stay frozen. Three new observations
measure command-start-relative lateral position (metres), lateral velocity (metres per second)
and horizontal heading deviation (radians). The reference is captured at the first active
physics tick and renewed after idle. Heading is projected onto the floor plane, so body pitch
does not masquerade as turning. These are internal simulator observations, without a claim
that real hardware has equivalent localization.

A 20-iteration cross-entropy search learned six tied weights: three common-hip and three
opposite-ankle weights. Seed 117, population 20, four fresh-process training cases per iteration
and eight distinct checkpoint-validation cases are retained in
[the complete training record](evidence/feedback_2026-09-22/training.json.gz). Checkpoint 14
won validation; its six-weight policy was frozen before the first held-out evaluation.

That first candidate was **rejected**. Fresh-start success fell from v1's 59/64 to 56/64,
with eight falls; restart success stayed at 58/64 but falls rose from one to six. Its lower
lateral drift did not compensate for lost stability. See
[every rejected episode](evidence/feedback_2026-09-22/rejected_heldout.json) and
[the rejected weights](evidence/feedback_2026-09-22/rejected_policy.json).

An eight-way ablation then used 31 prior failure/representative cases as development data.
The full feedback passed 17/31 with 14 falls; hip-only passed 19/31 with three falls;
ankle-only passed 31/31 with zero falls. Quarter-strength and half-strength variants still
fell. [All ablation candidates and episodes](evidence/feedback_2026-09-22/ablation.json.gz)
are retained. The selected candidate removes hip feedback and retains the three learned
opposite-ankle weights. Those 31 selection cases are not counted as held-out success.

The candidate was frozen again before the new 6101/6301 evaluations above. Its file SHA256 is
`9518b2f31040b1c6bd1d5328c0cc4015f100633683ed60bedaad289cf9387f76`.
No further weight selection uses those results. There were zero paid calls.

## Application and inference checks

The actual `main.tscn` app passes all 12 declared native cases, each with 737 assertions:
starts at 0, 1, 14, 79, 83, 137, 241 and 300 frames, plus a three-second walk / one-second
stop / restart at 0, 14, 83 and 241 frames. Forward travel is 0.41274–0.43813 m, maximum
lateral drift is 0.04850 m and minimum uprightness is at least 0.9575. This checks actual W
input, stopping, unchanged assembly, incompatible-graph rejection and returning to the
original starter. [Native app results](evidence/feedback_2026-09-22/native_app.json) are
separate from the seeded standalone evaluation.

The same frozen candidate passes **6/6 actual WebAssembly cases (123 checks)** in pinned
Chromium: three fresh starts and three restarts, with observed frame counts retained instead
of forcing favourable timing. Forward travel is 0.415833–0.438102 m, maximum lateral drift
is 0.0391363 m, maximum absolute yaw is 12.0676°, minimum uprightness is 0.961564 and
minimum height is 0.128920 m. Both feet lift and the robot stops upright. The
[Web evidence](evidence/browser_v2_2026-09-22/README.md) records every case, exact export hashes,
and the isolated base `7c602` plus candidate/observation changes. Native observer-on/off
comparisons preserve every measured trajectory value. This candidate-build verification does
not replace the final clean release export gate or certify other browsers. The earlier clean
v1 browser failure (0.101064 m lateral drift) remains a failure.

Version 1 remains supported. Zero-feedback v2 reproduces v1 forward/lateral/yaw/uprightness
exactly on [four paired diagnostic episodes](evidence/feedback_2026-09-22/zero_feedback_parity.json),
including two drift failures. The new
`learned_tracking_check.gd` passes 29 checks for Python/Godot numerical parity with nonidentity
normalization, dimensions, finite weights, graph/runtime binding, coordinate invariance,
pitch-independent heading and restart reference capture. Numerical parity is not physical
transfer evidence. The simulator model and runtime fingerprint are recorded in
[the manifest](evidence/feedback_2026-09-22/manifest.json).

## Reproduction

Use Godot 4.7.2 and run its import step once. These new tools require only the Python standard
library. The CEM search reproduces the original six-weight experiment; the rejected outcome
is part of that experiment. The final policy additionally applies the documented hip ablation.

```sh
godot --headless --path . --import
python3 -m tools.rl_lab.train_feedback --godot godot --out /tmp/feedback-training \
  --iterations 20 --population 20 --seed 117 --workers 4
python3 -m tools.rl_lab.evaluate_feedback --godot godot \
  --policy assets/policies/yaw_biped_v2.json \
  --cases docs/evidence/feedback_2026-09-22/ankle_cases.json \
  --reference assets/policies/yaw_biped_v1.json --out /tmp/feedback-evaluation.json
```

Evaluation rejects a policy whose file hash differs from the predeclared case file. It saves
every episode and does not retry failed physics. [ADR 0019](adr/0019-learned-command-frame-feedback.md)
records the observation contract and scope. No user-facing text changes are required by the
schema or tooling; the existing forward-only controls and original-assembly requirement remain.
