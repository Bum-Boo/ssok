# Learning locomotion

ssok includes an offline reinforcement-learning laboratory and a small GDScript policy runner.
Training never calls a paid API unless both `--live` and `--allow-paid` are supplied. The shipped
application needs neither Python nor an API key to evaluate a policy.

## Measured result — 22 September 2026

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

Training seeds and fixed validation seeds are recorded separately in `progress.json`. A best
checkpoint is selected using validation task metrics. Evaluate a frozen selected checkpoint on new
seeds before making a success claim. The trainer records failures and does not relax the task to
make an unsuccessful checkpoint appear complete.

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
