# Learning locomotion

> **Actuator corrected (2026-09-22):** [ADR 0020](adr/0020-whole-step-actuator-torque-budget.md) enforces the motor budget across the whole physics step. The current bundled policy has separate corrected-model native and Web validation below. Historical sections retain the earlier per-pass results, whose nominal torque settings did not enforce the stated physical limits.

ssok includes an offline reinforcement-learning laboratory and a small GDScript policy runner.
Training never calls a paid API unless both `--live` and `--allow-paid` are supplied. The shipped
application needs neither Python nor an API key to evaluate a policy.

## Current bundled policy with the corrected torque budget

The bundled `yaw_biped_heading_v2.json` uses the corrected whole-step 0.25 N·m motor model.
It retains the CEM-learned periodic carrier and corrected-model position/velocity feedback,
while selecting the heading coefficient from the earlier learned policy. The three single-component
variants were compared on 128 already observed development conditions. This is post-training
coefficient recombination, not a new CEM run; provenance records both stages.

The selected candidate was frozen before a new paired 256-condition evaluation. It passes
**127/128 fresh starts and 128/128 restarts, with one fall**. The previous corrected-model policy
passes **127/128 fresh starts and 124/128 restarts, with five falls**, on the same conditions.
Five failed cases improve and one previously successful case regresses. The remaining candidate
fall and all other outcomes remain in [the full report](evidence/heading_feedback_2026-09-22/README.md).
This is an observed cohort improvement, not a guarantee for arbitrary starts or assemblies.

The identical frozen candidate passes twelve actual native-app flows and six declared Chromium
WebAssembly flows. The preceding integrated `389f817` policy/build passes 59 native checks and
all three browser gates; the new integration requires its own clean build verification. No public
release is claimed. The [previous corrected-model cohort](evidence/bounded_feedback_2026-09-22/README.md)
and old-runtime results below remain separate historical evidence.

## Historical version 2 under the old actuator

The earlier v2 policy passed64/64 fresh starts and63/64 restarts, with one fall; its paired v1
passed55/64 and59/64 with four falls. The old-runtime native app12/12 and Web6/6 results remain
in [the historical feedback report](RL_FEEDBACK.md). They do not certify declared physical torque
because the actuator defect had not yet been corrected. Do not merge those counts with the new cohort.

## Historical version 1 Godot result — 22 September 2026

A policy learned directly in Godot completed **31 of 32 held-out episodes (96.9%)**, with
**zero falls** and **0.422 m mean forward travel**. Each episode launched a fresh Godot process;
start delays covered 0, 1, 2 and 3 seconds. This narrow held-out test used the same native Linux
binary and only ±0.003 m/s initial x/z velocity perturbations; it does not establish broad domain robustness. The policy operates the separate graph-derived yaw-hip
biped with a nominal 0.25 N·m motor setting under the earlier per-pass implementation. That setting
did not enforce a whole-step 0.25 N·m limit. These trajectories describe the historical simulator.

| Shipping-engine check | Successes | Falls | Mean forward travel |
|---|---:|---:|---:|
| Zero-action validation baseline | 0 / 8 | 0 | −0.0008 m |
| Hand-designed periodic initialization | 0 / 8 | 0 | 0.185 m |
| Learned checkpoint, validation seeds 1001–1008 | 8 / 8 | 0 | 0.426 m |
| Frozen policy, held-out seeds 2101–2132 | 31 / 32 | 0 | 0.422 m |

The one held-out failure, seed 2102, traveled 0.416 m but drifted sideways 0.115 m, exceeding
the unchanged 0.10 m limit. It stayed upright. Both feet physically leave the floor in every
episode: maximum left-foot clearance ranges 5.5–8.3 mm and right-foot clearance 11.8–13.5 mm;
at least one foot remains in contact throughout. Clearance uses the actual foot's transformed
collision-box corners, with a 0.5 mm contact tolerance.

The cross-entropy optimizer learned twelve periodic coefficients and a clock frequency. It began
from a disclosed hand-designed periodic policy, then used measured returns to update the sampling
distribution. It does **not** learn state feedback. There were **zero paid API calls**. The selected
checkpoint was frozen at iteration 35 before evaluating the held-out seeds. Later iterations did
not replace the frozen checkpoint.

- [Training, initial baseline, and every checkpoint validation](evidence/rl_2026-09-22/godot_yaw_training.json)
- [Every frozen-policy held-out episode, including the failure](evidence/rl_2026-09-22/godot_yaw_heldout.json)
- [Initial stop/restart stress results](evidence/rl_2026-09-22/godot_yaw_restart_v1.json)

The historical `main.tscn` application also passed five native checks: W immediately after Run,
W after 1, 2 and 3 seconds, and walking for 3 seconds followed by a 1-second stop and W again.
Each passed 734 assertions including real keyboard input, upright stopping, graph immutability,
modified-graph rejection and returning to the original starter. Travel is 0.408–0.427 m and minimum
upright alignment is 0.9577–0.9714. [Per-flow app evidence](evidence/rl_2026-09-22/godot_yaw_app.json)
records these results.

A separate **actual WebAssembly application check passed** in Chromium 153.0.8010.12. Real W input
covered exactly 720 physics intervals (12 seconds): 0.429881 m forward, 0.070111 m lateral drift,
12.807° yaw, minimum uprightness 0.958920 and minimum height 0.128712 m. Both feet lifted above
0.5 mm for 175/274 frames, with maximum collision-sole clearances 7.684/13.230 mm. After releasing
W for 90 intervals, uprightness was 0.999881 and the command was zero. Graph and runtime
fingerprints stayed unchanged. [Raw Web result and exact review-build hashes](evidence/browser_2026-09-22/README.md)
retain the evidence. This one browser episode is separate from native held-out/restart statistics;
the final clean release must repeat the browser gate, and other browsers remain unverified.

The subsequent [clean `0b2fe24` browser run](evidence/browser_clean_0b2fe24_2026-09-22/README.md)
**failed** the unchanged lateral gate: 0.421612 m forward, 0.101064 m lateral and 10.865577° yaw
over 12 seconds. The robot remained upright and both feet lifted, but the 0.10 m lateral limit
still applies. Native fresh-process settle-83 and settle-84 diagnostics passed 737 checks each;
they did not reproduce or replace the Web failure. This historical checkpoint did not qualify
for release. The separately evaluated current policy and clean export are described above.

The first [24-episode stop/restart check](evidence/rl_2026-09-22/godot_yaw_restart_v1.json) passed
22 episodes, with one fall. An expanded characterization used eight walking durations, four pause
lengths and four new seeds (128 episodes). It passed **122/128 (95.3%)** when forward and heading
are measured relative to the robot at restart, with **3 falls**. The stricter original world +Z
measurement passed 101/128; prior turning during warmup affects that measure. Both results and
all failures remain in [the expanded report](evidence/rl_2026-09-22/godot_yaw_restart_extended.json).
The 31/32 initial walking score and restart scores describe different tasks and are never combined.

Bounded joint-target ramps, completing a gait phase before stopping, and preserving phase across
short pauses did not consistently improve restart success. The
[transition ablation](evidence/rl_2026-09-22/godot_yaw_stop_ablation.json) retains every tested episode
and diagnostic source. Those transition experiments did not replace the v1 controller or weights. Version 2 now adds
the separately evaluated feedback described above; arbitrary rapid stop/restart remains a
measured limitation, not a guarantee inferred from selected app checks.

## Earlier MuJoCo experiment

A genuinely trained ARS policy completed the fixed MuJoCo walking task in **25 of 32 held-out
episodes (78.1%)** with **zero falls** and **0.438 m mean forward travel**. Its untrained baseline
held the initial pose and completed **0 of 8 validation episodes**. These are simulator measurements,
not physical-robot results or a general locomotion guarantee.

Success requires the complete **12 seconds**, at least **0.30 m** forward displacement, no fall,
absolute lateral drift at most **0.10 m**, and final yaw at most **30 degrees**. A fall is torso up
alignment below 0.5 or torso height below 0.06 m. The success rule is separate from the optimization
reward and cannot be changed by a reward proposal.

| Check | Episodes | Successes | Falls | Mean forward travel |
|---|---:|---:|---:|---:|
| Untrained MuJoCo baseline (validation) | 8 | 0 | 0 | 0.0004 m |
| ARS round 3 (validation) | 8 | 5 | 0 | 0.434 m |
| Frozen ARS policy (held-out seeds 2001–2032) | 32 | 25 | 0 | 0.438 m |
| Same weights in Godot (transfer seeds 2001–2004) | 4 | 0 | 3 | 0.052 m |

**The MuJoCo policy has not passed the Godot transfer gate.** It is kept as a reproducible research
artifact, not offered as verified in-app walking. Godot uses a different contact solver and the
legacy biped's ideal hinge servo differs from the torque-limited MuJoCo servo. Equal policy outputs
do not imply equal physical trajectories.

Source artifacts:

- [Frozen weights](../tools/rl_lab/reference/biped_mujoco_ars.json)
- [Training rounds and validation](evidence/rl_2026-09-22/ars_training.json)
- [Every held-out MuJoCo episode](evidence/rl_2026-09-22/mujoco_heldout.json)
- [Every Godot transfer episode](evidence/rl_2026-09-22/godot_transfer.json)

The run used 3 rounds × 160 ARS iterations, 16 antithetic directions per iteration, four CPU workers,
MuJoCo 3.13.0 and NumPy 2.5.3. Reward proposals came from deterministic rules (`provider: mock`);
there were **zero Luna calls**. ARS changed real policy weights using observed episodic returns.

## Physics-rate diagnosis

The successful reference policy was trained with 240 Hz MuJoCo physics and 30 Hz control.
Keeping its exact frozen weights and 30 Hz control fixed exposes a strong timestep dependency:

| MuJoCo physics rate | Seeds | Successes | Falls | Mean forward travel |
|---|---:|---:|---:|---:|
| 60 Hz | 2001–2016 | 0 / 16 | 16 | 0.006 m |
| 120 Hz | 2001–2016 | 1 / 16 | 7 | 0.289 m |
| 240 Hz | 2001–2016 | 12 / 16 | 0 | 0.433 m |

[Per-episode timestep ablation](evidence/rl_2026-09-22/timestep_ablation.json) holds all other
policy settings constant. This shows the old policy requires fast simulated dynamics; it does
not identify every remaining contact or actuator difference. A zero-action baseline stays upright
for all 16 full episodes at each rate, including 60 Hz (maximum drift 14.5 mm), as recorded in
[baseline stability](evidence/rl_2026-09-22/untrained_timestep_baselines.json). A fresh
3 × 160-iteration ARS run at 60 Hz did not beat its zero-action baseline.

Direct Godot searches on the original pitch-hip robot also remain below the task gate: unrestricted
periodic optimization reached about 0.100 m with excessive yaw; symmetric optimization reached
0.109 m and 7.64 degrees mean absolute yaw after 100 generations. Both produced 0 / 8 validation
successes. A 35-iteration state-feedback search reached 0.086 m and also failed the gate.

The separate [yaw-hip graph](adr/0014-yaw-hip-learning-biped.md) permits direct learning with real
vertical motor axes and bounded torque. It preserves the original robot and its failed results.
Its generator is `tools/godot/make_yaw_biped_defs.gd`; export with `--preset yaw_biped` and train
with `tools.rl_lab.train_godot --robot yaw_biped`. Its physical result is measured independently in the Godot table above.

The new graph uses the existing opt-in compound-body builder. Every part's mass and collision
transform is retained, but automatic compound inertia is an approximation. The
[direct-state audit](evidence/rl_2026-09-22/compound_inertia_audit.json) records separate and merged
body mass, COM and tensors. The torso tensor differs by about 11.3% and the leg tensors by 4.1%
from the parallel-axis sum of separate bodies; compound COM uses weighted part origins rather
than individual collision-derived centers (up to 0.54 mm difference). Export now includes every
compound collider, measured full inertia and COM, and counts each physical body once.

## Episode isolation

A first yaw-hip search appeared to succeed, but
[the same-weight reset ablation](evidence/rl_2026-09-22/godot_yaw_batch_ablation.json) invalidated
that deployment claim: 8 / 8 successes in a process that had already evaluated another candidate
became 0 / 8 with fresh processes. Both used the same validation seeds and starting delays.
This is an order-sensitive contact-solver result, not robust app walking. The earlier candidate
remains failed evidence. Authoritative training and evaluation now create **one fresh Godot process
per episode**. The new 31/32 result uses this corrected protocol. App hierarchy and
stop/restart checks are additional gates; arithmetic parity alone remains insufficient.

## Reproduce

From the repository root:

```sh
python3 -m venv .venv-rl
touch .venv-rl/.gdignore
.venv-rl/bin/pip install -r tools/rl_lab/requirements.txt
.venv-rl/bin/python -m unittest tools.rl_lab.test_rl_lab -v
.venv-rl/bin/python -m tools.rl_lab.run --rounds 3 --iterations 160 --workers 4
.venv-rl/bin/python -m tools.rl_lab.evaluate \
  tools/rl_lab/reference/biped_mujoco_ars.json \
  --seed-start 2001 --episodes 32 --out /tmp/ssok-heldout.json
.venv-rl/bin/python -m tools.rl_lab.evaluate \
  tools/rl_lab/reference/biped_mujoco_ars.json --engine godot \
  --seed-start 2001 --episodes 4 --out /tmp/ssok-transfer.json
godot --headless --path . --script tests/learned_policy_check.gd
```

`tools/godot/export_rl_robot.gd` derives bodies, masses, joints, actuator ordering and graph identity
from the same `ConnectionGraph` used by the app. Re-export after changing the robot, then retrain;
the evaluator rejects a policy whose physics fingerprint does not match.

## Training in the shipping engine

To measure and optimize the actual app dynamics, the optional Godot trainer performs episodic
cross-entropy policy optimization. It learns 12 weights and a clock frequency from contact-physics
returns, with no body translation, scripted pose playback or generated executable code. Its compact
linear policy uses command and sine/cosine phase observations; unlike the ARS policy it does not yet
learn state feedback. The evaluator and app use the same `LearnedBipedMotion` implementation.

```sh
.venv-rl/bin/python -m tools.rl_lab.train_godot \
  --godot godot --out tools/rl_lab/runs/godot --iterations 120 --population 32 --workers 4
```

The recorded yaw-hip run is reproducible with:

```sh
.venv-rl/bin/python -m tools.rl_lab.train_godot \
  --godot godot --robot yaw_biped --out tools/rl_lab/runs/yaw \
  --initial-policy tools/rl_lab/reference/yaw_periodic_initial.json \
  --seed 29 --iterations 35 --population 32 --workers 4 --training-seeds 2 \
  --initial-sigma 0.3 --sigma-floor 0.04 --vary-start
.venv-rl/bin/python -m tools.rl_lab.evaluate \
  assets/policies/yaw_biped_v1.json --engine godot --vary-start \
  --seed-start 2101 --episodes 32 --out /tmp/ssok-yaw-heldout.json
.venv-rl/bin/python -m tools.rl_lab.check_restart \
  assets/policies/yaw_biped_v1.json --extended --seed-start 2301 \
  --seeds-per-case 4 --out /tmp/ssok-yaw-restarts.json
```

Training seeds (3000–999999) and fixed validation seeds (1001–1008) are recorded separately in `progress.json`. A best
checkpoint is selected using validation task metrics. Evaluate a frozen selected checkpoint on new
seeds before making a success claim. The trainer records failures and does not relax the task to
make an unsuccessful checkpoint appear complete.

`--vary-start` trains and validates starts after 0, 1, 2 or 3 seconds of settling, derived from
the episode seed. Optional `--startup-seconds` records a bounded action-amplitude ramp in the policy;
its default is zero. Changing either option requires a fresh physical evaluation. Playback through
`tools/godot/play_rl_policy.gd -- --policy file.json --window` uses `LearnedBipedMotion` directly.

## Runtime boundaries

`LearnedBipedMotion` validates dimensions, finite numeric values, action limits and unique graph-wired
motor addresses before use. Bundled production policies bind to exact graph and runtime fingerprints (masses, collisions,
servo limits, solver settings and engine version). The
controller computes 30 Hz tanh-linear inference in GDScript and sends bounded relative-angle commands
through `ServoDrive`. Physics remains `RunMode`'s graph-derived Godot world. New graphs cannot silently
reuse another robot's weights.

Python/GDScript arithmetic parity and graph-mismatch rejection are covered by
`tests/learned_policy_check.gd`. This numerical check is deliberately separate from the physical
transfer evaluation above. Forward locomotion is the only supported learned command; backward motion,
turning, arbitrary assemblies and sim-to-real deployment require their own training and validation.
