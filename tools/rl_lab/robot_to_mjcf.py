"""Godot RunMode export (tools/godot/export_rl_robot.gd) -> MuJoCo MJCF.

Coordinates stay Godot's Y-up metres; gravity is set along -Y instead of rotating the robot.
Like a cuRobo robot config, joint limits and actuator bounds come from the exported robot,
never from hand-edited XML. The ConnectionGraph remains the source of truth (ADR 0002).
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from xml.sax.saxutils import quoteattr

import numpy as np

PHYSICS_TIMESTEP = 1.0 / 240.0
# SG90-class micro servo: ~0.18 N*m stall torque. Godot locks the hinge to the slewed target
# with a hard limit (effectively unbounded torque); matching that is issue #19, not this slice.
SERVO_KP = 4.0
SERVO_KV = 0.04
SERVO_TORQUE_NM = 0.25


def load_robot(path: str | Path) -> dict:
    data = json.loads(Path(path).read_text())
    if data.get("version") != 1:
        raise ValueError("Unsupported robot export version")
    return data


def fingerprint(robot: dict) -> str:
    physics = {key: value for key, value in robot.items() if key != "graph_fingerprint"}
    return hashlib.sha256(json.dumps(physics, sort_keys=True).encode()).hexdigest()


def _matrix(transform: dict) -> np.ndarray:
    m = np.eye(4)
    m[:3, 0] = transform["basis_x"]
    m[:3, 1] = transform["basis_y"]
    m[:3, 2] = transform["basis_z"]
    m[:3, 3] = transform["origin"]
    return m


def _quat(rotation: np.ndarray) -> np.ndarray:
    # Orthonormalise first: exported bases carry float noise.
    u, _, vt = np.linalg.svd(rotation)
    r = u @ vt
    w = np.sqrt(max(0.0, 1.0 + r[0, 0] + r[1, 1] + r[2, 2])) / 2.0
    x = np.copysign(np.sqrt(max(0.0, 1.0 + r[0, 0] - r[1, 1] - r[2, 2])) / 2.0, r[2, 1] - r[1, 2])
    y = np.copysign(np.sqrt(max(0.0, 1.0 - r[0, 0] + r[1, 1] - r[2, 2])) / 2.0, r[0, 2] - r[2, 0])
    z = np.copysign(np.sqrt(max(0.0, 1.0 - r[0, 0] - r[1, 1] + r[2, 2])) / 2.0, r[1, 0] - r[0, 1])
    q = np.array([w, x, y, z])
    return q / np.linalg.norm(q)


def _fmt(values) -> str:
    return " ".join(f"{float(v):.9g}" for v in values)


def build_tree(robot: dict, root: int = 0):
    """Returns (parent_of, joint_of) over the mechanically connected, non-frozen bodies."""
    bodies = {b["index"]: b for b in robot["bodies"]}
    parent_of, joint_of = {root: None}, {root: None}
    frontier = [root]
    while frontier:
        current = frontier.pop(0)
        for joint in robot["joints"]:
            if current not in (joint["a"], joint["b"]):
                continue
            other = joint["b"] if joint["a"] == current else joint["a"]
            if other in parent_of or bodies[other]["frozen"]:
                continue
            parent_of[other], joint_of[other] = current, joint
            frontier.append(other)
    return parent_of, joint_of


def actuated_joints(robot: dict) -> list[dict]:
    """Hinges wired to a board pin, ordered by pin number (the learner-visible address)."""
    hinges = [j for j in robot["joints"] if j["type"] == "hinge" and j.get("pin", -1) >= 0]
    return sorted(hinges, key=lambda j: j["pin"])


def to_mjcf(robot: dict, physics_hz: int = 240) -> str:
    bodies = {b["index"]: b for b in robot["bodies"]}
    parent_of, joint_of = build_tree(robot)
    children: dict[int, list[int]] = {}
    for child, parent in parent_of.items():
        if parent is not None:
            children.setdefault(parent, []).append(child)
    world = {i: _matrix(b["transform"]) for i, b in bodies.items()}

    def body_xml(index: int, depth: int) -> list[str]:
        body = bodies[index]
        pad = "  " * depth
        parent = parent_of[index]
        local = world[index] if parent is None else np.linalg.inv(world[parent]) @ world[index]
        name = f"{body['part_id']}_{index}"
        lines = [f'{pad}<body name="{name}" pos="{_fmt(local[:3, 3])}" quat="{_fmt(_quat(local[:3, :3]))}">']
        if parent is None:
            lines.append(f'{pad}  <freejoint name="root"/>')
        joint = joint_of[index]
        if joint is not None and joint["type"] == "hinge":
            to_local = np.linalg.inv(world[index])
            anchor = (to_local @ np.array([*joint["anchor"], 1.0]))[:3]
            axis = to_local[:3, :3] @ np.array(joint["axis"])
            limit = np.deg2rad(joint.get("relative_limit_deg", 90.0))
            lines.append(f'{pad}  <joint name="pin{joint.get("pin", -1)}_{name}" type="hinge" '
                         f'pos="{_fmt(anchor)}" axis="{_fmt(axis / np.linalg.norm(axis))}" '
                         f'range="{-limit:.9g} {limit:.9g}" damping="0.002" armature="0.0001"/>')
        if "full_inertia" in body:
            lines.append(f'{pad}  <inertial mass="{body["mass_kg"]:.9g}" pos="{_fmt(body["center_of_mass"])}" '
                         f'fullinertia="{_fmt(body["full_inertia"])}"/>')
        if "collision_boxes" in body:
            for collider in body["collision_boxes"]:
                shape = _matrix(collider["transform"])
                lines.append(f'{pad}  <geom type="box" size="{_fmt(np.array(collider["size"]) / 2)}" '
                             f'pos="{_fmt(shape[:3, 3])}" quat="{_fmt(_quat(shape[:3, :3]))}" class="robot"/>')
        else:
            half = np.array(body["box_size"]) / 2.0
            lines.append(f'{pad}  <geom type="box" size="{_fmt(half)}" pos="{_fmt(body["box_center"])}" '
                         f'mass="{body["mass_kg"]:.9g}" class="robot"/>')
        for child in sorted(children.get(index, [])):
            lines.extend(body_xml(child, depth + 1))
        lines.append(f"{pad}</body>")
        return lines

    gravity = robot["gravity"]
    floor_y = robot["floor_y"]
    xml = [
        f'<mujoco model={quoteattr("ssok_" + robot["preset"])}>',
        f'  <option timestep="{1.0 / physics_hz:.9g}" gravity="{_fmt(gravity)}" integrator="implicitfast"/>',
        "  <default>",
        # Robot geoms touch only the floor: self-collision between welded parts is out of scope.
        '    <default class="robot"><geom contype="1" conaffinity="2" friction="0.9 0.01 0.001" rgba="0.85 0.87 0.9 1"/></default>',
        "  </default>",
        "  <worldbody>",
        f'    <geom name="floor" type="plane" size="2 2 0.05" pos="0 {floor_y:.9g} 0" zaxis="0 1 0" '
        'contype="2" conaffinity="1" friction="0.9 0.01 0.001" rgba="0.8 0.8 0.78 1"/>',
        '    <light pos="0.3 1.2 0.6" dir="-0.3 -1 -0.5"/>',
        *body_xml(0, 2),
        "  </worldbody>",
        "  <actuator>",
    ]
    for joint in actuated_joints(robot):
        child = joint["b"] if parent_of.get(joint["b"]) == joint["a"] else joint["a"]
        name = f"pin{joint['pin']}_{bodies[child]['part_id']}_{child}"
        torque = joint.get("actuator_torque_nm", 0.0) or SERVO_TORQUE_NM
        xml.append(f'    <position name="{name}" joint="{name}" kp="{SERVO_KP}" kv="{SERVO_KV}" '
                   f'forcelimited="true" forcerange="{-torque} {torque}"/>')
    xml += ["  </actuator>", "</mujoco>", ""]
    return "\n".join(xml)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("robot_json")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    Path(args.out).write_text(to_mjcf(load_robot(args.robot_json)))
    print("wrote", args.out)
