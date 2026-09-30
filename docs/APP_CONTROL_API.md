# App control API and MCP boundary (#32)

The first transport is an **in-process AppController plus an isolated headless JSON runner**.
It works with the same GDScript model in desktop and Web exports. The old motion-lab MCP keeps
its separate trial-session scope; it does not acquire control of an open workshop.

`AppController.invoke(tool, args, expected_revision)` exposes:

| Tool | Result / behavior |
|---|---|
| get_scene | Current graph, source, board profile and mode |
| list_parts | Catalog IDs and compatible mechanical/electrical ports |
| place_part / remove_part | Existing assembly and bounded catalog/transform rules |
| connect_parts | Mechanical snap, undo history and graph notification |
| connect_wire | Compatible free electrical ports, no relocation, undoable |
| set_program | Explicit source application, preserving any pending block draft |
| run / stop | Existing run-code ownership and immediate local interruption |
| get_result | Observed servo angles, motor speed/torque, current line and stage measurements |

Read-only is the default. Mutations require the operator's edit capability and the exact current
revision. Human scene/code/mode changes invalidate stale commands. Edits during physics are
rejected. Stop bypasses edit capability and revision checks and requires no network or model.
A bounded local event journal is off by default; opting in records tool, origin (agent/user),
physics frame and revision, without source text or personal identifiers. There is no telemetry.

Offline use (requests and output are operator-supplied files, not web filesystem access):

```sh
godot --headless --path . --script tools/app_control/run_requests.gd -- \
  requests.json results.json --allow-edits
```

The request array accepts `tool`, `args`, `expected_revision` and optional `observe_ticks`
(up to 3600). At most 100 requests / 1 MiB input are accepted. Results never treat a commanded
angle or generated proposal as observed success. Use `get_scene` after human edits to obtain a
fresh revision. Scene replacement/loading stays with the user's normal project/stage flow.

MCP registration and a live desktop transport are follow-ups, not required to decide this
boundary. A future stdio MCP wrapper can launch an isolated headless session, map these tools,
and carry capabilities/revisions without exposing arbitrary object methods. It must keep that
session distinguishable from the current editor. For an open desktop editor, a local-only token
and Origin-checked asynchronous bridge is a separate opt-in adapter; no listener is installed
by this change. A public Web page must not silently access a desktop bridge. Provider login,
paid requests, cloud keys and natural-language planning are outside this design issue.
