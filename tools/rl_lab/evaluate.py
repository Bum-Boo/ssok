"""Evaluate a frozen policy on explicit held-out seeds without training or selection."""
from __future__ import annotations

import argparse
from dataclasses import replace
import hashlib
import json
from pathlib import Path

import numpy as np

from tools.rl_lab.ars import LinearPolicy
from tools.rl_lab.env import EnvConfig, WalkEnv, is_success


def validate_policy(record: dict, env: WalkEnv) -> LinearPolicy:
    if record.get("format") != "ssok-linear-policy" or record.get("version") != 1 or record.get("control_hz") != 30:
        raise ValueError("Unsupported policy format")
    if record.get("robot_fingerprint") != env.robot_fingerprint:
        raise ValueError("Policy robot fingerprint differs from current exported physics")
    if record.get("joint_pins") != env.joint_pins:
        raise ValueError("Policy actuator order differs from graph wiring")
    policy = LinearPolicy.from_dict(record)
    if policy.weights.shape != (env.act_dim, env.obs_dim) or policy.mean.shape != (env.obs_dim,) or policy.var.shape != (env.obs_dim,):
        raise ValueError("Policy dimensions differ from environment")
    if not all(np.isfinite(x).all() for x in (policy.weights, policy.mean, policy.var)) or (policy.var < 0).any():
        raise ValueError("Non-finite policy or negative observation variance")
    return policy


def evaluate_record(record: dict, seeds: list[int], noise: float = 0.02, config: EnvConfig | None = None) -> dict:
    env = WalkEnv(replace(config or EnvConfig(), action_scale_deg=record["action_scale_deg"], gait_hz=record["gait_hz"], init_noise_rad=noise, physics_hz=record.get("simulation_hz", 240)))
    policy = validate_policy(record, env)
    episodes = []
    for seed in seeds:
        obs = env.reset(seed)
        while True:
            obs, _, done, _ = env.step(policy.act(obs))
            if done:
                break
        metrics = env.metrics()
        episodes.append({"seed": seed, **metrics, "success": is_success(env.task, metrics)})
    return {"engine": "mujoco", "simulation_hz": env.config.physics_hz, "task": env.task, "initial_joint_noise_rad": noise,
            "robot_fingerprint": env.robot_fingerprint, "episodes": episodes,
            "success_rate": sum(e["success"] for e in episodes) / len(episodes),
            "fall_rate": sum(e["fallen"] for e in episodes) / len(episodes),
            "mean_forward_m": float(np.mean([e["forward_m"] for e in episodes]))}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("policy", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--seed-start", default=2001, type=int)
    parser.add_argument("--episodes", default=32, type=int)
    parser.add_argument("--noise", default=0.02, type=float, help="MuJoCo initial joint noise, radians")
    parser.add_argument("--engine", choices=["mujoco", "godot"], default="mujoco")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--workers", default=4, type=int)
    parser.add_argument("--vary-start", action="store_true", help="Godot starts after seed modulo4 seconds of settling")
    args = parser.parse_args()
    if not 1 <= args.episodes <= 1000 or not 0 <= args.noise <= 0.2:
        parser.error("episodes must be 1..1000 and noise 0..0.2 rad")
    policy_bytes = args.policy.read_bytes()
    record = json.loads(policy_bytes)
    seeds = list(range(args.seed_start, args.seed_start + args.episodes))
    if args.engine == "mujoco":
        result = evaluate_record(record, seeds, args.noise)
    else:
        from tools.rl_lab.train_godot import evaluate
        if not 1 <= args.workers <= 16:
            parser.error("workers must be 1..16")
        episodes = evaluate(args.godot, [record], seeds, args.workers, args.vary_start)[0]
        result = {"engine": "godot", "initial_velocity_noise_m_s": 0.003,
                  "episode_isolation": "fresh Godot process", "vary_start": args.vary_start,
                  "episodes": episodes, "success_rate": sum(e["success"] for e in episodes) / len(episodes),
                  "fall_rate": sum(e["fallen"] for e in episodes) / len(episodes),
                  "mean_forward_m": float(np.mean([e["forward_m"] for e in episodes]))}
    result["policy_sha256"] = hashlib.sha256(policy_bytes).hexdigest()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k:v for k,v in result.items() if k not in {"episodes", "task"}}, indent=2))


if __name__ == "__main__":
    main()
