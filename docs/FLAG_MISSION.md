# First playable mission: raise the flag

The workshop opens with a servo-arm challenge and the block editor. A learner can load the finished arm, run its program, change an angle, and retry; the code tab and free assembly stay available. Connecting the servo shaft to the arm and wiring the servo to a board pin moves the mission through assembly, wiring, and ready states. The orange flag is a visual marker on the graph-derived arm tip. It has no mass or collision.

The goal depends on the simulated robot. After a run starts, the powered arm tip must first move at least 2 cm below its starting height, then return within 8 mm of that height and stay there for 0.20 seconds. A command alone cannot complete the mission. Stopping, disconnecting the arm, or removing the wire leaves the relevant state; a run that never reaches the mark stays open for correction. The starter currently uses the existing Uno-style `Servo(9)` teaching profile. The planned micro:bit-first board profile is a separate task and is not implied by this starter.

## Reused components

| Component | Pinned source and license | Use in Ssok |
|---|---|---|
| [Godot State Charts](https://github.com/derkork/godot-statecharts/tree/76d226a3efac66a72aea825382b320c94808f409) | MIT, pinned commit | Intro → assembly → wiring → ready → running → success and interruption transitions. Optional upstream C# wrappers and demos are omitted. |
| [Beehave](https://github.com/bitbrain/beehave/tree/fe589153fa780a3f88989578ceb5f539afffb7c2) | MIT, pinned commit | Ticks a small ready/observed-goal sequence against the actual run state. Two calls to editor debugger APIs are guarded when no debugger is active. |
| [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | CC0 1.0 | Selection, part connection, and success feedback; the same states are also conveyed by text. |

The exact imported asset hashes are in `assets/kenney/SOURCE.json`; source licenses are kept beside the assets, and the release packages include the notices in `licenses/`. These components run inside Godot 4.7.2 on desktop and Web. They do not connect Codex, Claude, or another paid provider.

## Verify

Run `godot --headless --path . --editor --import --quit`, then `godot --headless --path . --script tests/flag_mission_check.gd` and `godot --headless --path . --script tests/localization_check.gd`. The mission test covers the physical raise, retry, a nonwinning program, stop, and wire removal. `python3 tools/ci/build.py --godot godot --version flag-preview` checks both exports and bundled notices. `tools/godot/capture_flag_mission.gd` captures native start, ready, and success views to `build/flag_mission/` when a display is available.

The next natural-language command slice remains a separate implementation: a visible command window, one reachable box, a bounded pickup/release controller, observed results, and a local stop. Bookshelf insertion and room travel still require new scene objects and controllers. Provider connection and any paid calls require a provider-specific cost and data notice before the first call; this mission performs no AI service calls.
