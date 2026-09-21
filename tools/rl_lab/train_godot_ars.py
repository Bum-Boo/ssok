"""ARS with state feedback in the actual Godot environment.

Observation scaling is fixed and recorded. Every perturbation pair sees the same initial
conditions; validation only selects checkpoints and does not change the training reward.
"""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path

import numpy as np

from tools.rl_lab.train_godot import blank_policy, evaluate, ranking, reward


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--initial", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--iterations", type=int, default=100)
    parser.add_argument("--directions", type=int, default=16)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--seed", type=int, default=91)
    parser.add_argument("--noise", type=float, default=0.03)
    parser.add_argument("--step-size", type=float, default=0.03)
    args = parser.parse_args()
    if not 1 <= args.iterations <= 1000 or not 4 <= args.directions <= 64 or not 1 <= args.workers <= 16:
        parser.error("iterations1..1000, directions4..64, workers1..16")
    args.out.mkdir(parents=True, exist_ok=True)
    original = json.loads(args.initial.read_text()) if args.initial else blank_policy()
    policy = copy.deepcopy(original)
    # Recorded physical-unit scales: joint angles, joint velocities*0.1, previous actions,
    # body-frame gravity, angular velocity*0.1, command, periodic phase.
    scale = np.array([0.3]*4 + [0.3]*4 + [1.0]*4 + [0.2,0.1,0.2] + [0.2]*3 + [1.0]*3)
    mean = np.zeros(21); mean[13] = -1.0
    raw = np.array(original["weights"]) / np.sqrt(np.array(original["obs_var"]) + 1e-8)
    bias = raw @ (mean - np.array(original["obs_mean"]))
    weights = raw * scale
    weights[:,18] += bias  # command is one during this fixed forward task
    policy["obs_mean"], policy["obs_var"] = mean.tolist(), (scale**2).tolist()
    policy["weights"] = weights.tolist()
    validation_seeds = list(range(1001,1009))
    baseline = evaluate(args.godot,[policy],validation_seeds,args.workers)[0]
    best_results = baseline
    policy["graph_fingerprint"] = baseline[0]["graph_fingerprint"]
    policy["runtime_fingerprint"] = baseline[0]["runtime_fingerprint"]
    (args.out/"best_policy.json").write_text(json.dumps(policy,indent=2))
    history = []
    rng = np.random.default_rng(args.seed)
    for iteration in range(args.iterations):
        deltas = rng.standard_normal((args.directions,4,21))
        candidates = []
        for delta in deltas:
            for sign in [1.,-1.]:
                p = copy.deepcopy(policy)
                p["weights"] = (weights + sign*args.noise*delta).tolist()
                candidates.append(p)
        seeds=[int(rng.integers(1,999)),int(rng.integers(3000,1000000))]
        outcomes=evaluate(args.godot,candidates,seeds,args.workers)
        returns=np.array([np.mean([reward(r) for r in group]) for group in outcomes]).reshape(args.directions,2)
        top=np.argsort(-returns.max(axis=1))[:args.directions//2]
        spread=returns[top].std()
        if spread>1e-8:
            weights += args.step_size/(len(top)*spread)*sum((returns[i,0]-returns[i,1])*deltas[i] for i in top)
        policy["weights"]=weights.tolist()
        validation=evaluate(args.godot,[policy],validation_seeds,args.workers)[0]
        if ranking(validation)>ranking(best_results):
            best_results=validation
            saved=copy.deepcopy(policy)
            saved["graph_fingerprint"]=validation[0]["graph_fingerprint"]
            saved["runtime_fingerprint"]=validation[0]["runtime_fingerprint"]
            saved["provenance"]={"algorithm":"ARS with fixed observation scaling", "engine":"Godot 4.7.2", "training_seed":args.seed,
                                  "iteration":iteration+1, "validation_seeds":validation_seeds,"live_calls":0}
            (args.out/"best_policy.json").write_text(json.dumps(saved,indent=2))
        history.append({"iteration":iteration+1,"training_seeds":seeds,"mean_return":float(returns.mean()),
                        "best_return":float(returns.max()),"validation":validation,"best_rank":ranking(best_results)})
        (args.out/"progress.json").write_text(json.dumps({"baseline":baseline,"best_validation":best_results,"history":history},indent=2))
        print(f"iteration={iteration+1} return={returns.mean():.2f} best={ranking(best_results)}",flush=True)
    (args.out/"completed.json").write_text(json.dumps({"iterations":args.iterations,"best_validation":best_results},indent=2))


if __name__ == "__main__":
    main()
