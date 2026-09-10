# AGENTS.md — rules for every contributor (human, Claude, Codex, Hermes, Antigravity)

ssok is an educational 3D robot simulator: drag parts together (they snap "쏙" into ports),
wire motors to a board, then drive the robot with code modeled on real boards.
Read `docs/ARCHITECTURE.md` before touching `src/`.

## Stack (fixed)

- Godot **4.7.2**, **GDScript only**. No C# — its web export is not reliable and web is a target.
- Renderer: **GL Compatibility** (the only one that runs on web). Do not switch to Forward+/Mobile.
- Physics: default GodotPhysics3D for now. Jolt is a candidate; evaluate in an issue, don't flip it silently.
- Targets: web *and* desktop from the same project. Avoid anything unsupported on web export:
  threads, `OS.execute`, filesystem outside `user://`, blocking network calls.

## Layout

```
scenes/          composed scenes (.tscn) — edited in the Godot editor by humans
src/core/        data model: PartDef, Port, ConnectionGraph
src/assembly/    assembly mode: drag, port detection, snap
src/runtime/     run mode: ConnectionGraph -> RigidBody/Joint, sim loop
src/profiles/    boards/ (pin maps, capabilities) and languages/ (interpreters)
src/blocks/      block-coding layer generated from a board profile's API
presets/         prebuilt robots ("answer keys")
assets/parts/    part meshes
tests/           automated tests (GUT — see issues)
docs/            architecture and decisions
```

## Non-negotiable design rules

1. **Three layers stay separate**: board profile / language runtime / block set. A runtime never
   knows a specific board; a board profile never contains interpreter code; blocks are derived
   from a board profile's API, not hand-written per language.
2. **Pin numbers come from the wiring graph**, never from constants in runtime code. If the user
   plugs the servo into pin 9, the code sees pin 9 because of the `ConnectionGraph`.
3. **Assembly mode is kinematic, run mode is physics.** Both are derived from the same
   `ConnectionGraph`; nothing in run mode should be authored by hand.
4. `ConnectionGraph` is the single source of truth and the only thing presets serialize.

## GDScript conventions

- Follow the official GDScript style guide: tabs, `snake_case` members/files, `PascalCase` classes.
- Static typing everywhere (`var x: int`, `-> void`). One `class_name` per file; file name is the
  snake_case of the class name.
- No comments that restate the code. One short line only when the *why* is non-obvious.
- Do not hand-edit `.tscn` beyond trivial property tweaks; scene composition is done in the editor.

## Verify before you hand work over

```sh
godot --headless --path . --import       # must finish without errors
godot --headless --path . --quit         # scene must load
```
Run GUT tests when they exist (`tests/`). Say explicitly if you could not run something.

## Workflow

- One GitHub issue per task. Labels `owner:human` / `owner:claude` / `owner:codex` say who does it.
- Branch `feat/<issue#>-<slug>`, PR back to `main`. Claude reviews, the human merges.
- Commits: short imperative subject, why in the body if needed.
- Code, identifiers and comments in English. Issues, docs and PR text may be Korean.
