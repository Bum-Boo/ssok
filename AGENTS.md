# AGENTS.md — rules for every contributor (human, Claude, Codex, Hermes, Antigravity)

ssok is an educational 3D robot simulator: drag parts together (they snap "쏙" into ports),
wire motors to a board, then drive the robot with code modeled on real boards.
Read `docs/ARCHITECTURE.md` before touching `src/`.

## Decisions are recorded — read before you propose one

`docs/adr/` holds every accepted architecture decision (MADR-lite: Context/Decision/Consequences).

- You MUST read `docs/adr/` before proposing a change that touches an existing decision.
- You MUST NOT re-litigate, silently reverse, or "improve past" an accepted ADR in code or in a
  PR. If a decision genuinely needs to change, write a new ADR that supersedes it (mark the old
  one superseded, link the new one) and say so explicitly in the PR description — do not just
  change the code and hope it's noticed.
- After any context compaction/summary, re-read `docs/adr/` and this file before resuming work —
  drift happens most often right after context is compressed.

## Stack (fixed — see ADR 0001)

- Godot **4.7.2**, exact pin, **GDScript only**. Never use C# — its web export is unreliable and
  web is a hard deployment target.
- Renderer: **GL Compatibility** (the only one that runs on web). Never switch to Forward+/Mobile
  without a superseding ADR.
- Physics: default GodotPhysics3D for now. Jolt is a candidate; it needs its own ADR (confirm web
  export support first) — never flip it silently.
- Targets: web *and* desktop from the same project, always. Never use anything unsupported on web
  export: threads, `OS.execute`, filesystem outside `user://`, blocking network calls.

### Upgrading the Godot version

Never bump the engine version as a side effect of another change.

1. Do it on its own branch, nothing else in the diff.
2. Open the project in the new editor version once and let it re-save whatever it touches.
3. Review that re-save diff like any other PR — it is not a no-op to skip reading.
4. Land it as a single "migration" commit.
5. Bump the pin here and in `README.md`, and write an ADR recording the new version and anything
   that broke.

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

## Non-negotiable design rules (see ADRs 0002–0004)

1. **Three layers always stay separate**: board profile / language runtime / block set. A runtime
   must never know a specific board; a board profile must never contain interpreter code; blocks
   must always be derived from a board profile's API, never hand-written per language. (ADR 0004)
2. **Pin numbers always come from the wiring graph**, never from constants in runtime code. If the
   user plugs the servo into pin 9, the code sees pin 9 only because of the `ConnectionGraph`.
   (ADR 0002)
3. **Assembly mode is always kinematic, run mode is always physics.** Both must be derived from
   the same `ConnectionGraph`; never hand-author anything in run mode. (ADR 0003)
4. `ConnectionGraph` is always the single source of truth and the only thing presets serialize.
   (ADR 0002)

## GDScript conventions

- Follow the official GDScript style guide: tabs, `snake_case` members/files, `PascalCase` classes.
- Static typing everywhere (`var x: int`, `-> void`). One `class_name` per file; file name is the
  snake_case of the class name.
- Never write a comment that restates the code. One short line only when the *why* is non-obvious.
- Never hand-edit `.tscn` beyond trivial property tweaks — scene composition is always done in the
  editor, by a human.

## Keep language packs current with every update

For settings/theme/text-scale/audio work, read `docs/INTERFACE_PREFERENCES.md` and ADR 0026.
Keep personal preferences outside project records; preserve drafts and running code when applying them.
Record actual four-language/light-dark/compact screenshots and run the preference regression check.

- Every update MUST review localization impact. New, changed or removed user-facing text
  (including part names, help, tooltips, dialogs, status/error messages and AI-lab warnings)
  MUST update Korean (`ko`), Simplified Chinese (`zh_CN`) and Japanese (`ja`) together
  with the English source in the same change. Do not defer translations to a later task.
- Translation sources are `assets/locales/{ko,zh_CN,ja}.po`; follow `docs/LOCALIZATION.md`.
  Preserve placeholders, units and safety/cost warnings. Never translate learner input,
  credentials, code syntax or protocol identifiers.
- For localization-affecting updates, run
  `godot --headless --path . --language en --script tests/localization_check.gd` and
  check changed screens in all three languages for missing glyphs and clipped text.
  Existing catalog parity tests do not discover every new UI string: explicitly check
  that new source strings are present in all three catalogs.
- Report localization updates and verification in the handoff/PR. If no user-facing text
  or UI changed, explicitly record that language-pack changes were not needed.

## Definition of done for an agent PR

A PR is not done just because the code compiles. Before handing it over:

- Run the verify commands below and paste their actual output/result in the PR description —
  never just assert "tests pass" without having run something.
- If the issue's "완료 기준" (acceptance criteria) describes a testable behavior, either add an
  automated test for it or, if that's genuinely not possible yet (e.g. no test framework wired up
  for that layer), say so explicitly in the PR and state exactly what you verified manually
  instead. Silence on this point is treated as "not verified."
- Confirm you did not touch a decision recorded in `docs/adr/` without writing a superseding ADR.
- Confirm the PR stays inside the linked issue's scope — no drive-by refactors of unrelated code.
- Confirm the language-pack review above is complete; untranslated new or changed UI is not done.

## Verify before you hand work over

```sh
godot --headless --path . --import       # must finish without errors
godot --headless --path . --quit         # scene must load
```
Run GUT tests when they exist (`tests/`). Always say explicitly, in the PR, when you could not run
something — never imply it passed if you didn't run it.

## Workflow

- One GitHub issue per task. Labels `owner:human` / `owner:claude` / `owner:codex` /
  `owner:cheap-llm` say who does it.
- Branch `feat/<issue#>-<slug>`, PR back to `main`. Claude reviews, the human merges — never
  self-merge.
- Commits: short imperative subject, why in the body if needed.
- Code, identifiers and comments always in English. Issues, docs and PR text may be Korean.
