"""Learn six command-relative feedback weights over a frozen periodic policy, without paid calls."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import random
import statistics

from tools.rl_lab.feedback import evaluate, policy_for, ranking, reward, tracking_template


def validation_cases() -> list[dict]:
    cases = [{"seed": 1101 + index, "settle_seconds": frames / 60,
              "initial_velocity_noise": 0.004}
             for index, frames in enumerate([0, 37, 79, 83, 137, 241])]
    cases.extend([
        {"seed": 1107, "settle_seconds": 53 / 60, "warmup_walk_seconds": 0.35,
         "restart_pause_seconds": 0.3, "initial_velocity_noise": 0.004},
        {"seed": 1108, "settle_seconds": 167 / 60, "warmup_walk_seconds": 3.7,
         "restart_pause_seconds": 1, "initial_velocity_noise": 0.004},
    ])
    return cases


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--reference", type=Path, default=Path("assets/policies/yaw_biped_v1.json"))
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--iterations", type=int, default=20)
    parser.add_argument("--population", type=int, default=20)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--seed", type=int, default=117)
    args = parser.parse_args()
    if not 1 <= args.iterations <= 100 or not 8 <= args.population <= 64 or not 1 <= args.workers <= 16:
        parser.error("iterations 1..100, population 8..64, workers 1..16")
    args.out.mkdir(parents=True, exist_ok=True)
    template = tracking_template(json.loads(args.reference.read_text()))
    validation = validation_cases()
    rng = random.Random(args.seed)
    mean = [2.0, 0.0, -0.2, 0.0, 0.0, 0.0]
    sigma = [0.6, 0.2, 0.15, 0.6, 0.2, 0.15]
    floor = [0.06, 0.02, 0.015, 0.06, 0.02, 0.015]
    initial = evaluate(args.godot, [policy_for([0.0] * 6, template), policy_for(mean, template)],
                       validation, args.workers)
    best_parameters, best_results = list(mean), initial[1]
    if ranking(initial[0]) > ranking(best_results):
        mean, best_parameters, best_results = [0.0] * 6, [0.0] * 6, initial[0]
    best_iteration = 0
    history = []

    def save(completed_iterations: int) -> None:
        policy = policy_for(best_parameters, template)
        for key in ["runtime_fingerprint", "graph_fingerprint"]:
            policy[key] = best_results[0][key]
        policy["provenance"] = {
            "algorithm": "cross-entropy episodic optimization of six tied state-feedback weights",
            "reference_oscillator": args.reference.name,
            "training_seed": args.seed, "iteration": best_iteration,
            "completed_iterations": completed_iterations, "live_calls": 0,
            "active_feedback_features": ["command-start lateral position (m)",
                                         "command-start lateral velocity (m/s)",
                                         "command-start heading deviation (rad)"],
            "actuator_tying": "common hips; opposite ankles",
            "episode_isolation": "fresh Godot process", "validation_cases": validation,
        }
        (args.out / "best_policy.json").write_text(json.dumps(policy, indent=2) + "\n")
        (args.out / "progress.json").write_text(json.dumps({
            "initial": initial, "validation_cases": validation, "best_validation": best_results,
            "best_parameters": best_parameters, "history": history,
        }, indent=2) + "\n")

    save(0)
    print("BASELINE", ranking(initial[0]), "INIT", ranking(initial[1]), flush=True)
    for iteration in range(1, args.iterations + 1):
        samples = [[max(-6, min(6, rng.gauss(m, s))) for m, s in zip(mean, sigma)]
                   for _ in range(args.population)]
        samples[0], samples[1] = list(mean), list(best_parameters)
        cases = []
        for index in range(4):
            case = {"seed": rng.randint(10000, 999999), "settle_seconds": rng.randrange(301) / 60,
                    "initial_velocity_noise": 0.004}
            if index == 3 and iteration % 2 == 0:
                case.update(warmup_walk_seconds=rng.choice([0.1, 0.35, 0.7, 1.3, 2.0, 2.8, 3.7, 4.6]),
                            restart_pause_seconds=rng.choice([0.1, 0.3, 1.0, 3.0]))
            cases.append(case)
        results = evaluate(args.godot, [policy_for(theta, template) for theta in samples], cases, args.workers)
        scores = [sum(map(reward, group)) / len(group) + 0.25 * min(map(reward, group))
                  - 0.02 * sum(value * value for value in theta)
                  for theta, group in zip(samples, results)]
        order = sorted(range(len(samples)), key=lambda index: scores[index], reverse=True)
        elite = [samples[index] for index in order[:max(4, args.population // 4)]]
        mean = [0.25 * value + 0.75 * statistics.mean(item[index] for item in elite)
                for index, value in enumerate(mean)]
        sigma = [max(floor[index], 0.3 * value + 0.7 * statistics.pstdev(item[index] for item in elite))
                 for index, value in enumerate(sigma)]
        candidate = samples[order[0]]
        measured = evaluate(args.godot, [policy_for(candidate, template)], validation, args.workers)[0]
        improved = ranking(measured) > ranking(best_results)
        if improved:
            best_parameters, best_results, best_iteration = list(candidate), measured, iteration
        history.append({"iteration": iteration, "training_cases": cases,
                        "training_parameters": samples, "training_results": results, "scores": scores,
                        "candidate_parameters": candidate, "validation": measured,
                        "improved": improved, "sigma": sigma})
        save(iteration)
        print("ITER", iteration, "validation", ranking(measured), "best", ranking(best_results), flush=True)


if __name__ == "__main__":
    main()
