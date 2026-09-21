"""Episodic policy optimization in the shipping Godot engine, with no simulator-transfer assumption.

The cross-entropy method learns twelve weights of the same bounded linear policy used by
MuJoCo/app inference. The active observations are command and sinusoidal phase. Simulation
feedback, never a hand-written sequence, updates their Gaussian sampling distribution.
Validation seeds select a frozen checkpoint; test seeds are evaluated separately afterwards.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import copy
import json
from pathlib import Path
import subprocess
import tempfile

import numpy as np

PROJECT = Path(__file__).resolve().parents[2]


def blank_policy() -> dict:
    return {"format": "ssok-linear-policy", "version": 1, "control_hz": 30,
            "joint_pins": [j["pin"] for j in sorted(json.loads((PROJECT / "tools/rl_lab/robots/biped.json").read_text())["joints"], key=lambda j: j.get("pin", -1)) if j.get("pin", -1) >= 0],
            "weights": np.zeros((4, 21)).tolist(), "obs_mean": [0.0] * 21, "obs_var": [1.0] * 21,
            "obs_count": 0, "action_scale_deg": 40.0, "gait_hz": 1.0,
            "godot_joint_signs": [-1.0] * 4}


def policy_for(parameters: np.ndarray, template: dict, symmetric: bool = False) -> dict:
    policy = copy.deepcopy(template)
    weights = np.zeros((4, 21))
    if symmetric:
        hip_bias, hip_sin, hip_cos, ankle_bias, ankle_sin, ankle_cos = parameters[:6]
        weights[:, 18:21] = [[hip_bias, hip_sin, hip_cos], [-hip_bias, hip_sin, hip_cos],
                            [ankle_bias, ankle_sin, ankle_cos], [ankle_bias, -ankle_sin, -ankle_cos]]
    else:
        weights[:, 18:21] = parameters[:12].reshape(4, 3)
    policy["weights"] = weights.tolist()
    policy["gait_hz"] = float(np.clip(parameters[-1], 0.3, 2.5))
    return policy


def run_batch(godot: str, episodes: list[dict]) -> list[dict]:
    with tempfile.TemporaryDirectory(prefix="ssok-policy-") as folder:
        source, target = Path(folder) / "batch.json", Path(folder) / "results.json"
        source.write_text(json.dumps({"episodes": episodes}))
        run = subprocess.run([godot, "--headless", "--path", str(PROJECT), "--fixed-fps", "60",
                              "--script", "tools/godot/evaluate_learned_policy.gd", "--",
                              "--input", str(source), "--output", str(target)],
                             capture_output=True, text=True, timeout=240)
        if run.returncode or not target.exists():
            raise RuntimeError(f"Godot evaluation failed: {run.stdout[-2000:]} {run.stderr[-2000:]}")
        results = json.loads(target.read_text())["episodes"]
        if len(results) != len(episodes) or any("error" in r for r in results):
            raise RuntimeError(f"Incomplete Godot results: {results}")
        return results


def reward(result: dict) -> float:
    # Fixed reward, physically measured. Full-duration task success is a separate gate.
    return (100.0 * result["forward_m"] - 40.0 * abs(result["lateral_m"])
            - 0.05 * abs(result["yaw_deg"]) - 15.0 * (1.0 - result["min_upright"])
            - 50.0 * result["fallen"])


def evaluate(godot: str, policies: list[dict], seeds: list[int], workers: int) -> list[list[dict]]:
    episodes = [{"policy": p, "seed": seed} for p in policies for seed in seeds]
    chunks = [episodes[i:i + 16] for i in range(0, len(episodes), 16)]
    with ThreadPoolExecutor(max_workers=workers) as executor:
        flat = [r for results in executor.map(lambda chunk: run_batch(godot, chunk), chunks) for r in results]
    return [flat[i:i + len(seeds)] for i in range(0, len(flat), len(seeds))]


def ranking(results: list[dict]) -> tuple:
    return (sum(r["success"] for r in results), -sum(r["fallen"] for r in results), float(np.mean([reward(r) for r in results])))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--iterations", type=int, default=120)
    parser.add_argument("--population", type=int, default=32)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--symmetric", action="store_true", help="Tie contralateral periodic coefficients using robot mirror symmetry")
    args = parser.parse_args()
    if not 1 <= args.iterations <= 1000 or not 8 <= args.population <= 128 or not 1 <= args.workers <= 16:
        parser.error("iterations 1..1000, population 8..128, workers 1..16")
    args.out.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(args.seed)
    template = blank_policy()
    dimensions = 7 if args.symmetric else 13
    mean, sigma = np.zeros(dimensions), np.full(dimensions, 0.6)
    mean[-1], sigma[-1] = 1.0, 0.35
    best_policy = policy_for(mean, template, args.symmetric)
    validation_seeds = list(range(1001, 1009))
    best_results = evaluate(args.godot, [best_policy], validation_seeds, args.workers)[0]
    baseline = copy.deepcopy(best_results)
    best_policy["graph_fingerprint"] = best_results[0]["graph_fingerprint"]
    best_policy["runtime_fingerprint"] = best_results[0]["runtime_fingerprint"]
    (args.out / "best_policy.json").write_text(json.dumps(best_policy, indent=2))
    history = []
    for iteration in range(args.iterations):
        samples = mean + rng.normal(size=(args.population, dimensions)) * sigma
        samples[0] = mean
        samples[:, -1] = np.clip(samples[:, -1], 0.3, 2.5)
        policies = [policy_for(p, template, args.symmetric) for p in samples]
        training_seeds = [int(rng.integers(1, 999)), int(rng.integers(3000, 1000000))]
        results = evaluate(args.godot, policies, training_seeds, args.workers)
        scores = np.array([np.mean([reward(r) for r in group]) for group in results])
        order = np.argsort(-scores)
        elite = samples[order[:max(4, args.population // 4)]]
        mean = 0.25 * mean + 0.75 * elite.mean(axis=0)
        sigma = np.maximum(0.08, 0.3 * sigma + 0.7 * elite.std(axis=0))
        candidate = policies[int(order[0])]
        validation = evaluate(args.godot, [candidate], validation_seeds, args.workers)[0]
        if ranking(validation) > ranking(best_results):
            best_policy, best_results = candidate, validation
            best_policy["provenance"] = {"algorithm": "cross-entropy episodic policy optimization", "engine": "Godot 4.7.2",
                                         "training_seed": args.seed, "iteration": iteration + 1, "live_calls": 0,
                                         "active_features": ["command", "sin(phase)", "cos(phase)"], "symmetric": args.symmetric,
                                         "validation_seeds": validation_seeds}
            best_policy["graph_fingerprint"] = best_results[0]["graph_fingerprint"]
            best_policy["runtime_fingerprint"] = best_results[0]["runtime_fingerprint"]
            (args.out / "best_policy.json").write_text(json.dumps(best_policy, indent=2))
        entry = {"iteration": iteration + 1, "training_seeds": training_seeds, "best_training_reward": float(scores.max()),
                 "mean_training_reward": float(scores.mean()), "validation": validation, "best_rank": ranking(best_results)}
        history.append(entry)
        (args.out / "progress.json").write_text(json.dumps({"baseline": baseline, "best_validation": best_results, "history": history}, indent=2))
        print(f"iter={iteration+1} reward={scores.max():.3f} best={ranking(best_results)} sigma={sigma.mean():.4f}", flush=True)
    (args.out / "completed.json").write_text(json.dumps({"iterations": args.iterations, "seed": args.seed, "best_validation": best_results}, indent=2))


if __name__ == "__main__":
    main()
