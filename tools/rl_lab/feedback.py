"""Fresh-process Godot evaluation for command-relative feedback policies (ADR 0019).

This module uses only the Python standard library. It does not claim MuJoCo parity.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import copy
import json
from pathlib import Path
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[2]


def tracking_template(reference: dict) -> dict:
    """Append three zero-feedback features without changing the periodic carrier."""
    if reference.get("version") != 1 or any(len(row) != 21 for row in reference["weights"]):
        raise ValueError("Expected a version 1 reference policy")
    policy = copy.deepcopy(reference)
    policy["version"] = 2
    policy.pop("runtime_fingerprint", None)
    for row in policy["weights"]:
        row.extend([0.0, 0.0, 0.0])
    policy["obs_mean"].extend([0.0, 0.0, 0.0])
    policy["obs_var"].extend([1.0, 1.0, 1.0])
    return policy


def policy_for(parameters: list[float], template: dict) -> dict:
    if len(parameters) != 6:
        raise ValueError("Expected three common-hip and three opposite-ankle weights")
    policy = copy.deepcopy(template)
    for row in policy["weights"][:2]:
        row[21:24] = parameters[:3]
    policy["weights"][2][21:24] = parameters[3:]
    policy["weights"][3][21:24] = [-value for value in parameters[3:]]
    return policy


def run_episode(godot: str, episode: dict) -> dict:
    with tempfile.TemporaryDirectory(prefix="ssok-feedback-") as directory:
        source = Path(directory) / "episode.json"
        target = Path(directory) / "result.json"
        source.write_text(json.dumps({"episodes": [episode]}))
        process = subprocess.run(
            [godot, "--headless", "--path", str(PROJECT), "--fixed-fps", "60",
             "--script", "tools/godot/evaluate_learned_policy.gd", "--",
             "--input", str(source), "--output", str(target)],
            capture_output=True, text=True, timeout=120,
        )
        if process.returncode or not target.exists():
            raise RuntimeError(process.stdout[-2000:] + process.stderr[-3000:])
        results = json.loads(target.read_text())["episodes"]
        if len(results) != 1 or "error" in results[0]:
            raise RuntimeError(f"Incomplete Godot episode: {results}")
        return results[0]


def evaluate(godot: str, policies: list[dict], cases: list[dict], workers: int = 4) -> list[list[dict]]:
    if not cases or not 1 <= workers <= 16:
        raise ValueError("Expected nonempty cases and 1..16 workers")
    episodes = [{**case, "policy": policy} for policy in policies for case in cases]
    with ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(lambda episode: run_episode(godot, episode), episodes))
    return [results[index:index + len(cases)] for index in range(0, len(results), len(cases))]


def reward(result: dict) -> float:
    return (100 * result["relative_forward_m"] - 120 * abs(result["relative_lateral_m"])
            - 0.2 * abs(result["relative_yaw_deg"]) - 50 * result["fallen"]
            - 10 * (1 - result["min_upright"]))


def deployment_success(result: dict) -> bool:
    """Keep the physical task and add the existing actual-app standing/foot-motion gate."""
    return (result["relative_success"] and result["min_upright"] >= 0.85
            and result["minimum_height"] > 0.09 and min(result["foot_air_frames"]) > 0)


def ranking(results: list[dict]) -> tuple:
    scores = [reward(result) for result in results]
    return (sum(deployment_success(result) for result in results),
            -sum(result["fallen"] for result in results),
            sum(scores) / len(scores) + 0.25 * min(scores))
