"""Luna x RL loop: propose reward weights -> ARS training -> task evaluation -> feedback.

    .venv-rl/bin/python -m tools.rl_lab.run --rounds 3 --iterations 25            # mock, free
    .venv-rl/bin/python -m tools.rl_lab.run --live --allow-paid --max-calls 3      # gpt-5.6-luna
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, replace
import datetime as dt
import json
import os
from pathlib import Path
import sys

from tools.motion_lab.service import LabError
from tools.rl_lab.ars import ArsConfig, LinearPolicy, evaluate, make_pool, train
from tools.rl_lab.env import EnvConfig, WalkEnv
from tools.rl_lab.luna import MODEL, LunaProposer, MockProposer

RUNS = Path(__file__).resolve().parent / "runs"


def rank(result: dict) -> tuple:
    # Task metrics only: a proposal cannot win by inflating its own reward.
    return (result["success_rate"], -result["fall_rate"], result["mean_forward_m"] - result["mean_abs_lateral_m"])


def policy_record(policy: LinearPolicy, env: WalkEnv, knobs: dict, provenance: dict) -> dict:
    return {"format": "ssok-linear-policy", "version": 1, "robot_fingerprint": env.robot_fingerprint,
            "graph_fingerprint": env.robot.get("graph_fingerprint", ""),
            "task": env.task["name"], "control_hz": 30, "joint_pins": env.joint_pins,
            "observation": ["joint_pos_rad x4 (pin order)", "joint_vel_rad_s*0.1 x4", "prev_action x4",
                            "gravity_in_body x3", "body_angvel*0.1 x3", "command_forward", "sin(phase)", "cos(phase)"],
            "action": "tanh output * action_scale_deg, relative to assembly pose, slewed 180 deg/s",
            **knobs, **policy.to_dict(), "provenance": provenance}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--iterations", type=int, default=25, help="ARS iterations per round")
    parser.add_argument("--workers", type=int, default=min(4, os.cpu_count() or 2))
    parser.add_argument("--live", action="store_true", help=f"call {MODEL} (paid)")
    parser.add_argument("--allow-paid", action="store_true", help="explicit consent for paid requests")
    parser.add_argument("--max-calls", type=int, default=3)
    parser.add_argument("--seed", type=int, default=0)
    args = parser.parse_args(argv)
    if not 1 <= args.rounds <= 8 or not 1 <= args.iterations <= 500 or not 1 <= args.max_calls <= 16:
        parser.error("rounds 1..8, iterations 1..500, max-calls 1..16")

    try:
        if args.live:
            if not args.allow_paid:
                raise LabError("--live needs --allow-paid; no request was sent")
            proposer = LunaProposer(os.environ.get("OPENAI_API_KEY", ""), args.max_calls)
        else:
            proposer = MockProposer()
    except LabError as exc:
        print("error:", exc, file=sys.stderr)
        return 2

    run_dir = RUNS / dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    run_dir.mkdir(parents=True)
    base_config = EnvConfig()
    env = WalkEnv(base_config)
    task = env.task
    print(f"task: {task['language']}\nprovider: {proposer.provider}  run: {run_dir}")

    best_policy = LinearPolicy(env.obs_dim, env.act_dim)
    history: list[dict] = []
    with make_pool(base_config, args.workers) as pool:
        baseline = evaluate(pool, best_policy, task["eval_seeds"], task)
        print("baseline (untrained, holds assembly pose):", json.dumps({k: v for k, v in baseline.items() if k != "mean_reward_terms"}))
        best = {"round": 0, "eval": baseline, "knobs": {"action_scale_deg": 30.0, "gait_hz": 1.0}}
        status = "completed"
        for round_index in range(1, args.rounds + 1):
            try:
                proposal = proposer.propose(task, history)
            except LabError as exc:
                print("proposal failed:", exc, file=sys.stderr)
                status = "stopped: " + str(exc)
                break
            print(f"\nround {round_index}: {proposal['reason']}\n  weights {proposal['weights']}\n  knobs {proposal['knobs']}")
            config = replace(base_config, weights=proposal["weights"], **proposal["knobs"])
            # Workers hold the env; rebuild the pool so they see this round's weights and knobs.
            pool.close(); pool.join()
            pool = make_pool(config, args.workers)
            policy = LinearPolicy.from_dict(best_policy.to_dict())
            curve = train(pool, policy, ArsConfig(iterations=args.iterations, workers=args.workers,
                                                  seed=args.seed + round_index))
            result = evaluate(pool, policy, task["eval_seeds"], task)
            print("  eval:", json.dumps({k: v for k, v in result.items() if k != "mean_reward_terms"}))
            entry = {"round": round_index, "weights": proposal["weights"], "knobs": proposal["knobs"],
                     "reason": proposal["reason"], "eval": result,
                     "training": {"iterations": len(curve), "first_mean_return": curve[0]["mean_return"],
                                  "last_mean_return": curve[-1]["mean_return"]}}
            history.append(entry)
            (run_dir / f"round{round_index}_policy.json").write_text(json.dumps(
                policy_record(policy, env, proposal["knobs"], {"provider": proposer.provider, "round": round_index,
                                                               "eval": result}), indent=1))
            if rank(result) > rank(best["eval"]):
                best, best_policy = entry, policy
        pool.close(); pool.join()

    summary = {"task": task["name"], "provider": proposer.provider, "model": MODEL if args.live else None,
               "status": status, "baseline": baseline, "best_round": best["round"], "best_eval": best["eval"],
               "history": history, "args": vars(args),
               "usage": getattr(proposer, "usage", None), "live_calls": getattr(proposer, "calls", 0)}
    (run_dir / "summary.json").write_text(json.dumps(summary, indent=1))
    if best["round"]:
        (run_dir / "best_policy.json").write_text((run_dir / f"round{best['round']}_policy.json").read_text())
    print(f"\nbest round: {best['round']}  success {best['eval']['success_rate']:.2f}  "
          f"forward {best['eval']['mean_forward_m']:.3f} m  falls {best['eval']['fall_rate']:.2f}  -> {run_dir}")
    return 0 if status == "completed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
