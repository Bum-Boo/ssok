# 0021 — Keep the standalone controller beside the legacy biped

- Status: accepted
- Date: 2026-09-22
- Extends: 0002, 0003 and 0007. Partially supersedes 0018's unchanged-layout requirement only for the independent Uno board in newly created legacy biped starters.

## Context

The legacy biped starter places its stationary controller directly behind the feet. Its real
collider begins about 72 mm behind their rear edges. In paired 60-second backward diagnostics,
the feet contacted the board while the torso was still upright, then fell. Moving only the
board's authored position to the side removed these contacts and both observed falls with
the same candidate controller. That isolates an obstacle in the starting lane; it does not
certify the candidate or fix its separate direction-transition and turning failures.

## Decision

- Place the standalone Uno at x=0.5 m, retaining its original y and z, when `BipedPreset.build()`
  creates a new starter graph. Keep the articulated robot, all part definitions, masses, motor
  limits, graph links, board pins, engine, gravity and collisions unchanged.
- The board remains visible, selectable, movable and collidable. RunMode reads its graph
  transform normally. Do not relocate it at runtime or remove its collision response.
- Keep saved graphs at their authored positions. Importing an old assembly must preserve its
  rear obstacle; the learner can move it in edit mode. Graph-bound result fingerprints change
  for the new starter, so old measurements cannot certify the new graph automatically.
- Keep `YawBipedPreset`, its separate board placement, learned policy and graph/runtime identity
  unchanged. The four-parameter legacy movement program retains its existing identity because
  its controller implementation and parameter meaning do not change in this layout correction.
- Frame the complete assembly in the usable workspace, including compact windows. The existing
  Frame robot action and camera navigation must keep the remote board reachable for editing.

## Verification and limits

Use the actual RunMode board collider and both foot collision shapes to sweep a 0.5 m backward
lane. The new starter must have no board obstruction; reconstructing the original placement
must detect both obstructions. This counterexample also verifies that the board collision is
still active. Verify graph round trips, ordinary biped control and the separate learned biped.

This is clear initial working space, not obstacle avoidance or a guarantee of unlimited travel.
Saved assemblies, extended turns and arbitrary trajectories can encounter scene objects.
Continuous manual-control acceptance remains a separate release gate, including all recorded
failures. No user-facing strings change; the four language packs retain their existing labels.
