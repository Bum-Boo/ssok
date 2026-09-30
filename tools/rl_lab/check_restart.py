"""Measure a frozen Godot policy under explicit walking, stopping and restarting cases."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path

from tools.rl_lab.train_godot import run_batch


CASES = [
    {"case": "immediate", "settle_seconds": 0},
    {"case": "idle-three-seconds", "settle_seconds": 3},
    {"case": "early-stop-quick-restart", "settle_seconds": 1,
     "warmup_walk_seconds": 0.35, "restart_pause_seconds": 0.3},
    {"case": "two-second-walk-restart", "settle_seconds": 1,
     "warmup_walk_seconds": 2, "restart_pause_seconds": 1},
    {"case": "mid-step-stop-restart", "settle_seconds": 1,
     "warmup_walk_seconds": 3.7, "restart_pause_seconds": 1},
    {"case": "mid-step-long-stop-restart", "settle_seconds": 1,
     "warmup_walk_seconds": 3.7, "restart_pause_seconds": 3},
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("policy", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--seed-start", type=int, default=2201)
    parser.add_argument("--seeds-per-case", type=int, default=4)
    parser.add_argument("--extended", action="store_true", help="Eight warmup lengths by four pause lengths; each seed runs 32 cases")
    args = parser.parse_args()
    if not 1 <= args.workers <= 16 or not 1 <= args.seeds_per_case <= 128:
        parser.error("workers must be 1..16 and seeds-per-case 1..128")
    policy_bytes = args.policy.read_bytes()
    policy = json.loads(policy_bytes)
    cases = ([{"case": f"walk{warmup}-pause{pause}", "settle_seconds": 1,
               "warmup_walk_seconds": warmup, "restart_pause_seconds": pause}
              for warmup in [0.1, 0.35, 0.7, 1.3, 2, 2.8, 3.7, 4.6]
              for pause in [0.1, 0.3, 1, 3]] if args.extended else CASES)
    episodes = [{**case, "policy": policy, "seed": seed}
                for case in cases
                for seed in range(args.seed_start, args.seed_start + args.seeds_per_case)]
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        results = list(executor.map(lambda episode: run_batch(args.godot, [episode])[0], episodes))
    for episode, result in zip(episodes, results):
        result["case"] = episode["case"]
    summary = []
    for case in cases:
        selected = [result for result in results if result["case"] == case["case"]]
        summary.append({"case": case["case"], "episodes": len(selected),
                        "successes": sum(result["success"] for result in selected),
                        "relative_successes": sum(result["relative_success"] for result in selected),
                        "falls": sum(result["fallen"] for result in selected)})
    report = {"policy_sha256": hashlib.sha256(policy_bytes).hexdigest(),
              "episode_isolation": "fresh Godot process", "cases": cases,
              "scope": "Global +Z task and command-start body-heading task are reported separately. "
                       "Both require 12 seconds, 0.30 m forward, <=0.10 m lateral, <=30 degrees yaw and no fall. "
                       "Warmup and pause use real joint commands without pose resets.",
              "summary": summary, "episodes": results}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
