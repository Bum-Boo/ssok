# Projects and block programs

## Preserve an assembly

Open **Projects** or press **Ctrl/Cmd+S**. Give the project a name and select **Save a snapshot**.
Each save creates a separate version, so saving a mistake does not overwrite the previous version.
Select a version under **Saved projects** and open it. Confirming replacement restores both the
assembly graph and learner code, returns to edit mode and leaves code execution stopped.

When loading a starter over modified work, the application offers **Save and switch**, explicit
replacement without saving, or cancellation. The current assembled pose—not a fallen robot's
runtime pose—is the state saved in a project.

Storage is local to the application/browser profile. Export a copy before changing devices or
clearing browser data. **Export project** exposes portable JSON for copying; the browser also
downloads `ssok-project.json`. Paste the document under **Import / export** and select **Import project**.
Invalid files leave the workshop unchanged. A project never includes service credentials,
learning-service settings or an automatically executable scene/resource.

Documents have a versioned `ssok-project` envelope, a title, a graph snapshot, learner source and
a UTC save timestamp. The graph retains catalog IDs, rigid transforms and validated mechanical
and electrical links. Limits are 256 parts, 1024 links, 64 KiB of learner source, 512 KiB per
document and 128 saved snapshots. Catalog IDs are allowlisted; arbitrary resource paths are rejected.
Writes use a temporary file and rename, and snapshots have independent generated IDs.
The editor refuses a 257th part and transforms beyond 100 m on any axis, matching snapshot limits.

## Wire the assembled robot

Open **Wiring**, choose a motor signal and a compatible board pin, then select **Connect wire**.
Connections use the actual electrical ports in the current graph. Occupied ports are unavailable;
use **Disconnect wire** before reassigning a motor. Both operations support Ctrl/Cmd+Z and redo.
Connecting a wire preserves every part's position and rotation. Moving a part retains its wires
while detaching mechanical mounts; deleting it removes all incident links. Cancel and undo restore
the graph together. Wiring controls are disabled during a transform or run mode.

Wires are logical connections: cable geometry, length and tension are not simulated.

## Code and blocks

**Blocks → Read from code** reads the supported servo subset. Each card is generated from the
board API descriptors in `src/core/board_profile.gd`. Edit its named inputs or add/remove a command,
then use **Apply blocks to code**. Applying does not start physics; **Run code** remains explicit.
**Run code**, saving and exporting validate and apply pending blocks. Invalid values or independently
changed code stop the action and retain both drafts. Starter replacement and **Read from code**
ask before discarding unapplied blocks. Numeric fields preserve fractional values such as `0.05`.

```python
from servo import Servo

arm = Servo(9)
arm.write(90)
sleep(0.5)
arm.write_relative(-20)
```

Supported operations are servo binding, absolute angle, signed rest-relative angle and timed wait.
The teaching runtime resolves pin 9 through the current wiring graph. An unwired pin produces an
error. Before sending any motor command, the runtime checks the whole program for supported syntax,
defined servo names, connected pins and finite values. A later invalid line cannot partly actuate
the robot. Programs are limited to 2048 lines and 64 KiB; each wait is at most 60 seconds.
`write` clamps to 0–180 degrees; relative commands clamp to the joint's bounded signed offsets. This language is
not full Python and does not compile or upload real-board firmware.

Comments, imports, whitespace and trailing newlines survive an untouched code/block round-trip.
An unsupported line is reported instead of being discarded. A restricted board API removes the
corresponding block operations. If the source changes after blocks are read, stale blocks cannot
overwrite it: read the updated source explicitly.

## Verification

- `tests/project_store_check.gd`: large-kit round-trip, Unicode source, snapshots, path/resource
  rejection, malformed/oversized documents, mode ownership and unsaved-work replacement.
- `tests/block_program_check.gd`: lossless conversion, API limits, actual runtime motor binding,
  physical hinge targets and protection against stale block application.
- `tests/authoring_ui_check.gd`: four languages, compact browser viewport, project/transfer views,
  rendered screenshots and usable catalog/block scrolling areas.
- `tests/core_authoring_check.gd`: actual wiring controls, placement-preserving graph edits,
  undo/redo, saved snapshots, code preflight, pending-block execution and saveable workspace limits.

Run these through the isolated [verification runner](BUILD.md); personal saved projects stay untouched.
