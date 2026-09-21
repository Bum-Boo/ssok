"""Walking environment for an exported ssok robot, in the style of Isaac Lab's manager-based envs.

Observation, action, reward terms and terminations are declared separately. Luna only picks
reward-term *weights* (tools/rl_lab/luna.py); the term functions and the task success check
(tasks/*.json, LIBERO-style) are fixed code, so a proposal cannot redefine success.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import json
import math
from pathlib import Path

import mujoco
import numpy as np

from tools.rl_lab.robot_to_mjcf import actuated_joints, fingerprint, load_robot, to_mjcf

ROOT = Path(__file__).resolve().parent
CONTROL_HZ = 30
# Same fall rule as the Godot motion evaluator (docs/MOTION_LAB.md).
FALL_UPRIGHT = 0.5
FALL_HEIGHT_M = 0.06
UP = np.array([0.0, 1.0, 0.0])
FORWARD = np.array([0.0, 0.0, 1.0])  # Godot body +Z

# name -> (description for Luna, sign hint). Positive weights reward, negative penalise.
REWARD_TERMS = {
    "forward_velocity": "body velocity along the commanded forward axis (m/s), clipped to 0.15",
    "alive": "constant 1 per control step while not fallen",
    "upright": "dot(body up, world up), 1 when perfectly upright",
    "lateral_velocity": "absolute sideways body velocity (m/s)",
    "yaw_rate": "absolute body yaw angular velocity (rad/s)",
    "action_rate": "squared change of joint targets between control steps (rad^2)",
    "joint_effort": "squared actuator torque (N*m)^2",
}
DEFAULT_WEIGHTS = {"forward_velocity": 20.0, "alive": 0.2, "upright": 0.5, "lateral_velocity": -2.0,
                   "yaw_rate": -0.2, "action_rate": -0.5, "joint_effort": -1.0}
WEIGHT_BOUNDS = {"forward_velocity": (0.0, 100.0), "alive": (0.0, 2.0), "upright": (0.0, 5.0),
                 "lateral_velocity": (-20.0, 0.0), "yaw_rate": (-5.0, 0.0),
                 "action_rate": (-5.0, 0.0), "joint_effort": (-20.0, 0.0)}


@dataclass
class EnvConfig:
    robot_json: str = str(ROOT / "robots" / "biped.json")
    task_json: str = str(ROOT / "tasks" / "walk_forward.json")
    weights: dict = field(default_factory=lambda: dict(DEFAULT_WEIGHTS))
    action_scale_deg: float = 30.0
    gait_hz: float = 1.0
    init_noise_rad: float = 0.02


def load_task(path: str | Path) -> dict:
    task = json.loads(Path(path).read_text())
    for key in ("name", "language", "command_forward", "horizon_s", "success"):
        if key not in task:
            raise ValueError(f"task is missing {key}")
    return task


class WalkEnv:
    def __init__(self, config: EnvConfig):
        self.config = config
        self.robot = load_robot(config.robot_json)
        self.robot_fingerprint = fingerprint(self.robot)
        self.task = load_task(config.task_json)
        self.model = mujoco.MjModel.from_xml_string(to_mjcf(self.robot))
        self.data = mujoco.MjData(self.model)
        self.substeps = round(1.0 / (CONTROL_HZ * self.model.opt.timestep))
        self.horizon = round(self.task["horizon_s"] * CONTROL_HZ)
        self.joint_pins = [j["pin"] for j in actuated_joints(self.robot)]
        # Actuator order in the MJCF is pin order; map each to its joint's qpos/qvel address.
        self.qpos_adr = np.array([self.model.jnt_qposadr[self.model.actuator_trnid[i, 0]] for i in range(self.model.nu)])
        self.qvel_adr = np.array([self.model.jnt_dofadr[self.model.actuator_trnid[i, 0]] for i in range(self.model.nu)])
        self.slew_rad = math.radians(180.0) / CONTROL_HZ  # ServoDrive speed, per control step
        self.obs_dim = len(self.observe_zero())
        self.act_dim = self.model.nu

    # --- observation manager -------------------------------------------------------------
    def observe_zero(self) -> np.ndarray:
        return np.zeros(self.model.nu * 3 + 3 + 3 + 1 + 2)

    def _body_frame(self):
        quat = self.data.qpos[3:7]
        rot = np.zeros(9)
        mujoco.mju_quat2Mat(rot, quat)
        return rot.reshape(3, 3)

    def observe(self) -> np.ndarray:
        rot = self._body_frame()
        gravity_in_body = rot.T @ -UP
        angvel_body = self.data.qvel[3:6]  # free joint angular velocity is already body-frame
        phase = 2.0 * math.pi * self.config.gait_hz * self.step_count / CONTROL_HZ
        return np.concatenate([
            self.data.qpos[self.qpos_adr], self.data.qvel[self.qvel_adr] * 0.1, self.prev_action,
            gravity_in_body, angvel_body * 0.1, [self.task["command_forward"]],
            [math.sin(phase), math.cos(phase)],
        ])

    # --- episode -------------------------------------------------------------------------
    def reset(self, seed: int) -> np.ndarray:
        rng = np.random.default_rng(seed)
        mujoco.mj_resetData(self.model, self.data)
        noise = rng.uniform(-self.config.init_noise_rad, self.config.init_noise_rad, self.model.nu)
        self.data.qpos[self.qpos_adr] = noise
        self.target = noise.copy()
        self.data.ctrl[:] = noise
        mujoco.mj_forward(self.model, self.data)
        self.start_xyz = self.data.qpos[:3].copy()
        self.step_count = 0
        self.prev_action = np.zeros(self.model.nu)
        self.min_upright = 1.0
        self.fallen = False
        return self.observe()

    def step(self, action: np.ndarray):
        action = np.clip(action, -1.0, 1.0)
        goal = action * math.radians(self.config.action_scale_deg)
        # Slew like ServoDrive: bounded degrees per second toward the commanded angle.
        self.target = self.target + np.clip(goal - self.target, -self.slew_rad, self.slew_rad)
        self.data.ctrl[:] = self.target
        for _ in range(self.substeps):
            mujoco.mj_step(self.model, self.data)
        self.step_count += 1
        terms = self._reward_terms(action)
        reward = sum(self.config.weights[name] * value for name, value in terms.items())
        self.prev_action = action
        timeout = self.step_count >= self.horizon
        return self.observe(), float(reward), self.fallen or timeout, terms

    # --- reward manager ------------------------------------------------------------------
    def _reward_terms(self, action: np.ndarray) -> dict:
        rot = self._body_frame()
        upright = float(rot[:, 1] @ UP)
        velocity = self.data.qvel[:3]
        self.min_upright = min(self.min_upright, upright)
        height = self.data.qpos[1] - self.robot["floor_y"]
        if not np.all(np.isfinite(self.data.qpos)) or upright < FALL_UPRIGHT or height < FALL_HEIGHT_M:
            self.fallen = True
        delta = (action - self.prev_action) * math.radians(self.config.action_scale_deg)
        return {
            "forward_velocity": float(min(velocity @ FORWARD * self.task["command_forward"], 0.15)),
            "alive": 0.0 if self.fallen else 1.0,
            "upright": upright,
            "lateral_velocity": abs(float(velocity[0])),
            "yaw_rate": abs(float(self.data.qvel[4])),
            "action_rate": float(delta @ delta),
            "joint_effort": float(self.data.actuator_force @ self.data.actuator_force),
        }

    # --- task metrics (LIBERO-style success, independent of reward weights) ---------------
    def metrics(self) -> dict:
        moved = self.data.qpos[:3] - self.start_xyz
        rot = self._body_frame()
        heading = rot[:, 2]
        yaw_deg = math.degrees(math.atan2(heading[0], heading[2]))
        return {"forward_m": float(moved @ FORWARD * self.task["command_forward"]),
                "lateral_m": float(moved[0]), "yaw_deg": yaw_deg, "fallen": bool(self.fallen),
                "min_upright": float(self.min_upright), "seconds": self.step_count / CONTROL_HZ}


def is_success(task: dict, metrics: dict) -> bool:
    rule = task["success"]
    return (all(math.isfinite(float(metrics.get(key, float("nan")))) for key in ("forward_m", "yaw_deg", "lateral_m", "seconds"))
            and metrics["seconds"] >= task["horizon_s"]
            and not metrics["fallen"] and metrics["forward_m"] >= rule["forward_m_min"]
            and abs(metrics["yaw_deg"]) <= rule["abs_yaw_deg_max"]
            and abs(metrics["lateral_m"]) <= rule["abs_lateral_m_max"])
