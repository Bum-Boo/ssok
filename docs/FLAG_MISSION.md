# First playable mission: raise the flag

The workshop opens with a servo-arm challenge and the block editor. A learner can load the finished arm, run its program, change an angle, and retry; the code tab and free assembly stay available. Connecting the servo shaft to the arm and wiring the servo to a board pin moves the mission through assembly, wiring, and ready states. The orange flag is a visual marker on the graph-derived arm tip. It has no mass or collision.

On a wide empty workspace, one centered invitation starts the arm challenge; the detailed mission card appears after a starter is loaded. Compact windows use the mission card as the single starting instruction. Other robot examples, saved projects, and non-flag stages hide the mission card and its flag marker. The card is capped at 500 px on wide screens so it leaves room for the 3D workspace. The initial block editor uses code control, matching the selected learning path.

The goal depends on the simulated robot. A declarative rule requires the powered arm's measured height to reach 0.155 m for 0.20 seconds. A command alone cannot complete the mission. Stopping, disconnecting the arm, or removing the wire leaves the relevant state; a run that never reaches the mark stays open for correction. The starter uses micro:bit V2, `Servo(pin0)` and millisecond sleeps. Existing Uno/generic examples retain their seconds-based interface. The separate Stage challenge holds its height criterion for one second and accepts any assembly that achieves its measured conditions.

"Build this arm yourself" starts with a loose arm and an unwired servo. The mission action connects the compatible mechanical ports using the normal snap/undo path, then opens the Wiring tab. Ready feedback names the actual connected pin; repeated successful runs compare observed peak heights. See [Stages and learner hardware](LEARNING_STAGES.md). The 60-second/5-minute user study remains to be conducted with lab colleagues and a professor.

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
