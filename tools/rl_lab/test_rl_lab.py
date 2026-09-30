"""python -m unittest tools.rl_lab.test_rl_lab -v  (inside .venv-rl)"""

from __future__ import annotations

import copy
from pathlib import Path
import unittest
from unittest import mock

import mujoco
import numpy as np

from tools.motion_lab.service import LabError
from tools.rl_lab import run as run_module
from tools.rl_lab.ars import LinearPolicy
from tools.rl_lab.env import DEFAULT_WEIGHTS, EnvConfig, WalkEnv, is_success
from tools.rl_lab.luna import DEFAULT_KNOBS, LunaProposer, MockProposer, validate_proposal
from tools.rl_lab.robot_to_mjcf import actuated_joints, load_robot, to_mjcf


class MjcfTest(unittest.TestCase):
    def setUp(self):
        self.robot = load_robot(EnvConfig().robot_json)

    def test_biped_loads_with_one_actuator_per_wired_hinge(self):
        model = mujoco.MjModel.from_xml_string(to_mjcf(self.robot))
        wired = actuated_joints(self.robot)
        self.assertEqual(model.nu, len(wired))
        self.assertEqual([j["pin"] for j in wired], [3, 5, 6, 9])
        self.assertEqual(model.njnt, 1 + len(wired))  # free root + hinges
        # Frozen, electrically-linked-only parts (the Uno on the table) are not in the tree.
        self.assertEqual(model.nbody, 1 + sum(not b["frozen"] for b in self.robot["bodies"]))

    def test_mjcf_is_deterministic(self):
        self.assertEqual(to_mjcf(self.robot), to_mjcf(copy.deepcopy(self.robot)))

    def test_physics_rate_is_explicit_and_preserves_control_rate(self):
        for hz in (60, 120, 240):
            model = mujoco.MjModel.from_xml_string(to_mjcf(self.robot, physics_hz=hz))
            self.assertAlmostEqual(model.opt.timestep, 1.0 / hz, places=9)
            env = WalkEnv(EnvConfig(physics_hz=hz, init_noise_rad=0.0))
            env.reset(0)
            env.step(np.zeros(env.act_dim))
            self.assertAlmostEqual(env.data.time, 1.0 / 30.0, places=8)

    def test_compound_export_preserves_mass_and_all_colliders(self):
        robot = load_robot(Path(EnvConfig().robot_json).parent / "yaw_biped.json")
        model = mujoco.MjModel.from_xml_string(to_mjcf(robot, physics_hz=60))
        dynamic = [b for b in robot["bodies"] if not b["frozen"]]
        self.assertEqual(len(dynamic), 5)
        self.assertEqual(model.nu, 4)
        self.assertAlmostEqual(model.body_mass.sum(), sum(b["mass_kg"] for b in dynamic), places=8)
        self.assertEqual(model.ngeom - 1, sum(len(b["collision_boxes"]) for b in dynamic))

    def test_holds_assembly_pose_standing(self):
        env = WalkEnv(EnvConfig(init_noise_rad=0.0))
        env.reset(0)
        for _ in range(90):
            _, _, done, _ = env.step(np.zeros(env.act_dim))
        self.assertFalse(done)
        self.assertLess(abs(env.metrics()["forward_m"]), 0.01)


class EnvTest(unittest.TestCase):
    def test_step_is_finite_and_success_uses_task_metrics(self):
        env = WalkEnv(EnvConfig())
        obs = env.reset(1)
        self.assertEqual(obs.shape, (env.obs_dim,))
        obs, reward, _, terms = env.step(np.ones(env.act_dim))
        self.assertTrue(np.all(np.isfinite(obs)) and np.isfinite(reward))
        self.assertEqual(set(terms), set(DEFAULT_WEIGHTS))
        ok = {"forward_m": 0.5, "lateral_m": 0.0, "yaw_deg": 0.0, "fallen": False, "seconds": env.task["horizon_s"]}
        self.assertTrue(is_success(env.task, ok))
        self.assertFalse(is_success(env.task, {**ok, "fallen": True}))
        self.assertFalse(is_success(env.task, {**ok, "yaw_deg": 90.0}))
        self.assertFalse(is_success(env.task, {**ok, "seconds": 1.0}))
        self.assertFalse(is_success(env.task, {**ok, "forward_m": float("nan")}))

    def test_policy_round_trip(self):
        policy = LinearPolicy(21, 4)
        policy.weights[:] = np.arange(84).reshape(4, 21) * 0.01
        policy.update_stats(np.random.default_rng(0).standard_normal((10, 21)))
        again = LinearPolicy.from_dict(policy.to_dict())
        obs = np.linspace(-1, 1, 21)
        np.testing.assert_allclose(policy.act(obs), again.act(obs))


class ProposalTest(unittest.TestCase):
    def valid(self):
        return {"weights": dict(DEFAULT_WEIGHTS), "knobs": dict(DEFAULT_KNOBS), "reason": "ok"}

    def test_accepts_bounded_numbers_only(self):
        self.assertEqual(validate_proposal(self.valid())["weights"], DEFAULT_WEIGHTS)
        for broken in ({"forward_velocity": 1e9}, {"alive": float("nan")}, {"alive": "1"}):
            proposal = self.valid()
            proposal["weights"].update(broken)
            with self.assertRaises(LabError):
                validate_proposal(proposal)
        extra = self.valid()
        extra["weights"]["code"] = 1.0
        with self.assertRaises(LabError):
            validate_proposal(extra)
        with self.assertRaises(LabError):
            validate_proposal({**self.valid(), "python": "import os"})

    def test_mock_reacts_to_drift(self):
        task = WalkEnv(EnvConfig()).task
        first = MockProposer().propose(task, [])
        history = [{**first, "eval": {"fall_rate": 0.0, "mean_abs_yaw_deg": 40.0,
                                      "mean_abs_lateral_m": 0.2, "mean_forward_m": 0.6}}]
        second = MockProposer().propose(task, history)
        self.assertLess(second["weights"]["yaw_rate"], first["weights"]["yaw_rate"])
        self.assertLess(second["weights"]["lateral_velocity"], first["weights"]["lateral_velocity"])
        validate_proposal(second)


class PaidRequestGuardTest(unittest.TestCase):
    def test_live_requires_consent_key_and_respects_call_cap(self):
        with mock.patch("urllib.request.OpenerDirector.open") as opened:
            self.assertEqual(run_module.main(["--live", "--rounds", "1", "--iterations", "1"]), 2)
            with mock.patch.dict("os.environ", {"OPENAI_API_KEY": ""}):
                self.assertEqual(run_module.main(["--live", "--allow-paid", "--rounds", "1", "--iterations", "1"]), 2)
            proposer = LunaProposer("test-key", max_calls=1)
            proposer.calls = 1
            with self.assertRaises(LabError):
                proposer.propose({"language": "x", "success": {}}, [])
            opened.assert_not_called()


if __name__ == "__main__":
    unittest.main()
