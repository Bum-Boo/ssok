# 0012 — Offline policy learning and an explicit deployment gate

- Status: accepted; extends ADR 0008's offline research scope
- Date: 2026-09-22
- The single inference-class requirement is partially superseded for the versioned legacy four-parameter calibration family by [0018](0018-calibrated-biped-motion-family.md). Other learned-policy requirements remain accepted.

- The periodic-only direct-Godot policy scope is extended by [0019](0019-learned-command-frame-feedback.md) for versioned command-relative feedback. Its deployment gates remain unchanged.

## Context

ADR 0008's motion lab searches four hand-written gait parameters. The user requested actual learned
locomotion policies and subsequently authorized completing and shipping the product. The initial
MuJoCo/ARS experiment established a compact portable policy format, but equal numerical inference
alone does not establish successful locomotion in Godot.

## Decision

- Keep the deployed client **Godot 4.7.2, GDScript, GL Compatibility, web and desktop**. Training
  remains optional external Python tooling under `tools/rl_lab/`, like existing motion-lab tooling.
- Derive the MuJoCo robot from `RunMode`'s `ConnectionGraph`: masses, geometry, joints, pins and
  transforms are exported by `tools/godot/export_rl_robot.gd`. JSON and MJCF are derived artifacts.
- Use **ARS with a normalized linear policy** for the CPU MuJoCo experiment. Optional bounded
  reward proposals affect seven fixed reward terms and two knobs; they never redefine success.
- Provide **direct Godot episodic policy optimization** to measure the shipping physics. The
  cross-entropy optimizer learns the coefficients of a compact periodic linear policy from returns.
  Record this distinct method honestly: its periodic policy does not learn sensor feedback.
- Run inference through `LearnedBipedMotion`, which extends `RobotMotionProgram`. The offline Godot
  evaluator and exported application use that same class. Commands only reach graph-wired servos;
  controllers do not teleport bodies, disable gravity, inject locomotion forces or replay transforms.
- Bind a deployable policy to its exact graph fingerprint, validate all numbers/dimensions/action
  bounds, and reject mismatches. Keep numerical parity tests separate from physical success tests.
- Keep **training**, **checkpoint validation**, and **frozen-policy held-out evaluation** separate.
  Success requires the full predeclared task horizon, displacement, no fall and bounded drift/yaw.
  Persist per-episode outcomes including failures. Reward value alone never certifies walking.
- A policy that only passes MuJoCo remains a clearly labeled research artifact. In-app walking is
  described as verified only after evaluation in the shipping Godot physics.
- ADR 0008's external-call boundary remains: explicit `--live --allow-paid`, terminal-only key,
  bounded call count, `store:false`, no automatic paid retry, no model fallback and no generated
  executable code. Rule proposals remain labeled `mock`; they are not represented as Luna calls.

## Consequences

- This replaces only ADR 0008's statement that general RL is a future scope. The board/runtime/block
  separation, graph authority, physics modes, optional-service boundary and deployment targets remain.
- Linear inference is inexpensive enough for the browser and has no Python, native extension, network
  or API-key dependency at runtime.
- Policy learning and successful simulator transfer are different deliverables. A measured failed
  transfer stays visible in the evidence instead of being hidden behind a successful MuJoCo score.
- Results apply to one graph and one task. Turning, backward movement, other robots, contact-force
  fidelity and real hardware transfer need independent training and evaluation.
- The legacy biped ideal hinge servo and MuJoCo torque model currently differ. This ADR records that
  limitation; it does not silently change existing servo physics.
