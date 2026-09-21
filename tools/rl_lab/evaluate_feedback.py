"""Evaluate a frozen feedback policy against a predeclared case file and optional reference."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from tools.rl_lab.feedback import deployment_success, evaluate


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--policy", type=Path, required=True)
    parser.add_argument("--cases", type=Path, required=True)
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    specification = json.loads(args.cases.read_text())
    digest = hashlib.sha256(args.policy.read_bytes()).hexdigest()
    if specification.get("frozen_policy_sha256") != digest:
        parser.error("Policy SHA256 does not match the predeclared evaluation specification")
    if not 1 <= len(specification["cases"]) <= 1024 or not 1 <= args.workers <= 16:
        parser.error("Expected 1..1024 cases and 1..16 workers")
    paths = {"candidate": args.policy}
    if args.reference:
        paths["reference"] = args.reference
    policies = [json.loads(path.read_text()) for path in paths.values()]
    results = evaluate(args.godot, policies, specification["cases"], args.workers)
    report = {"specification": specification,
              "policy_sha256": {name: hashlib.sha256(path.read_bytes()).hexdigest()
                                for name, path in paths.items()},
              "results": dict(zip(paths, results))}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    for name, episodes in report["results"].items():
        print(name, "success", sum(map(deployment_success, episodes)), "/", len(episodes),
              "falls", sum(episode["fallen"] for episode in episodes))


if __name__ == "__main__":
    main()
