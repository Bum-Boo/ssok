# 0003 — Hybrid physics: kinematic while assembling, real physics while running

- Status: accepted
- Date: 2026-09-10

## Context

Real physics during assembly (gravity, collisions) makes parts fall over or fly apart while the
learner is still placing them. But the whole educational point of "run mode" is that the robot
behaves like a real one — it needs gravity, joints and motor limits once it's running.

## Decision

- **Assembly mode**: parts are kinematic (no gravity, no collision response between parts being
  placed).
- **Run mode**: `ConnectionGraph` is converted to `RigidBody3D` nodes with joints (servo-axis
  ports become `HingeJoint3D`, rigid mechanical links use a fully-locked joint or a merged body),
  gravity on.
- The conversion is one-directional and mechanical: nothing in run mode is hand-authored: it is
  always derived from the graph produced in assembly mode.
- Toggling modes must not leak nodes: switching run → assembly removes the physics nodes and
  keeps the graph; repeated toggling must not duplicate or leave orphaned bodies.

## Consequences

- Assembly-time visual feedback (e.g. a part wobbling under its own weight) is explicitly not a
  goal — that would require assembly-time physics, contradicting this decision.
- The run-mode converter is a single well-tested chokepoint (see issue for RigidBody/Joint
  generation) — bugs there affect every preset and every future part.
