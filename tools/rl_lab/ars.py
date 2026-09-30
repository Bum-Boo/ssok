"""Augmented Random Search (ARS V2-t, Mania et al. 2018) with a linear policy.

Chosen for the smallest honest RL slice: numpy only, CPU parallel, known to learn MuJoCo
locomotion, and a linear policy is trivial to run later in GDScript (ADR 0001 web target).
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from multiprocessing import get_context
import os

import numpy as np

from tools.rl_lab.env import EnvConfig, WalkEnv, is_success


@dataclass
class ArsConfig:
    iterations: int = 40
    directions: int = 16
    top_directions: int = 8
    step_size: float = 0.02
    noise: float = 0.03
    workers: int = min(4, max(1, (os.cpu_count() or 2)))
    seed: int = 0


class LinearPolicy:
    def __init__(self, obs_dim: int, act_dim: int):
        self.weights = np.zeros((act_dim, obs_dim))
        self.mean = np.zeros(obs_dim)
        self.var = np.ones(obs_dim)
        self.count = 0

    def act(self, obs: np.ndarray, weights: np.ndarray | None = None) -> np.ndarray:
        w = self.weights if weights is None else weights
        return np.tanh(w @ ((obs - self.mean) / np.sqrt(self.var + 1e-8)))

    def update_stats(self, observations: np.ndarray) -> None:
        if len(observations) == 0:
            return
        n = len(observations)
        total = self.count + n
        new_mean = self.mean + (observations.sum(0) - n * self.mean) / total
        self.var = (self.count * (self.var + (self.mean - new_mean) ** 2)
                    + ((observations - new_mean) ** 2).sum(0)) / total
        self.mean, self.count = new_mean, total

    def to_dict(self) -> dict:
        return {"weights": self.weights.tolist(), "obs_mean": self.mean.tolist(),
                "obs_var": self.var.tolist(), "obs_count": self.count}

    @classmethod
    def from_dict(cls, data: dict) -> "LinearPolicy":
        weights = np.array(data["weights"], dtype=float)
        policy = cls(weights.shape[1], weights.shape[0])
        policy.weights = weights
        policy.mean = np.array(data["obs_mean"], dtype=float)
        policy.var = np.array(data["obs_var"], dtype=float)
        policy.count = int(data["obs_count"])
        return policy


_ENV: WalkEnv | None = None


def _worker_init(env_config: dict) -> None:
    global _ENV
    _ENV = WalkEnv(EnvConfig(**env_config))


def rollout(policy_state: dict, weights: np.ndarray, seed: int, collect: bool = False):
    env = _ENV
    policy = LinearPolicy.from_dict(policy_state)
    obs = env.reset(seed)
    total, observations, term_sums = 0.0, [], {}
    while True:
        if collect:
            observations.append(obs)
        obs, reward, done, terms = env.step(policy.act(obs, weights))
        total += reward
        for name, value in terms.items():
            term_sums[name] = term_sums.get(name, 0.0) + value
        if done:
            break
    return total, np.array(observations), env.metrics(), term_sums


def _rollout_job(args):
    return rollout(*args)


def evaluate(pool, policy: LinearPolicy, seeds: list[int], task: dict) -> dict:
    results = pool.map(_rollout_job, [(policy.to_dict(), policy.weights, s, False) for s in seeds])
    metrics = [r[2] for r in results]
    steps = sum(m["seconds"] for m in metrics) * 30
    terms = {}
    for r in results:
        for name, value in r[3].items():
            terms[name] = terms.get(name, 0.0) + value / max(steps, 1)
    return {
        "episodes": len(metrics),
        "success_rate": sum(is_success(task, m) for m in metrics) / len(metrics),
        "fall_rate": sum(m["fallen"] for m in metrics) / len(metrics),
        "mean_forward_m": float(np.mean([m["forward_m"] for m in metrics])),
        "mean_abs_lateral_m": float(np.mean([abs(m["lateral_m"]) for m in metrics])),
        "mean_abs_yaw_deg": float(np.mean([abs(m["yaw_deg"]) for m in metrics])),
        "mean_seconds_survived": float(np.mean([m["seconds"] for m in metrics])),
        "mean_return": float(np.mean([r[0] for r in results])),
        # Eureka-style reward reflection: per-step mean of each unweighted term.
        "mean_reward_terms": {k: round(v, 6) for k, v in terms.items()},
    }


def train(pool, policy: LinearPolicy, config: ArsConfig, log=print, cancelled=lambda: False) -> list[dict]:
    rng = np.random.default_rng(config.seed)
    curve = []
    for iteration in range(config.iterations):
        if cancelled():
            break
        deltas = rng.standard_normal((config.directions, *policy.weights.shape))
        seed = int(rng.integers(0, 2**31 - 1))
        jobs = []
        for d in deltas:
            for sign in (1.0, -1.0):
                # Antithetic pair shares a seed so the difference isolates the perturbation.
                jobs.append((policy.to_dict(), policy.weights + sign * config.noise * d, seed, True))
        results = pool.map(_rollout_job, jobs)
        returns = np.array([r[0] for r in results]).reshape(config.directions, 2)
        policy.update_stats(np.concatenate([r[1] for r in results if len(r[1])]))
        order = np.argsort(-returns.max(axis=1))[:config.top_directions]
        spread = returns[order].std() + 1e-8
        step = sum((returns[i, 0] - returns[i, 1]) * deltas[i] for i in order)
        policy.weights += config.step_size / (config.top_directions * spread) * step
        entry = {"iteration": iteration + 1, "mean_return": float(returns.mean()),
                 "best_return": float(returns.max())}
        curve.append(entry)
        log(f"  iter {entry['iteration']:3d}  mean_return {entry['mean_return']:9.2f}  best {entry['best_return']:9.2f}")
    return curve


def make_pool(env_config: EnvConfig, workers: int):
    return get_context("fork").Pool(workers, initializer=_worker_init, initargs=(asdict(env_config),))
