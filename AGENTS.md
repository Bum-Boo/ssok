# AGENTS.md: rules for every contributor

ssok is an educational 3D robot workshop: assemble parts, wire a board, program and observe
graph-derived physics. These rules apply to humans and all AI agents.

## Entry and resumption

- Read [START_HERE](docs/START_HERE.md), [STATUS](docs/STATUS.md), then only the route for your task.
- Before touching `src/`, read the relevant sections of [ARCHITECTURE](docs/ARCHITECTURE.md).
- Review [the complete ADR index](docs/adr/INDEX.md), then the applicable decisions and linked
  extensions/supersessions. Expand this scope if the affected decision is unclear. See ADR 0024.
- After compaction, reread this file, STATUS, the task handoff and relevant ADRs. Confirm actual
  cwd/branch/HEAD/dirty files; summaries do not establish source identity or test results.
- Check issue/PR ownership. Where available, use `agent-task` for bounded ownership/checkpoints.
  Never take a live owner's task or edit another task's worktree. Preserve existing WIP.

## Decisions and fixed stack

- Never silently reverse or re-litigate an accepted ADR. Write a superseding ADR, identify the
  exact replaced scope in both records and the PR, and retain unaffected decisions.
- Godot **4.7.2**, GDScript only, **GL Compatibility**, default **GodotPhysics3D**, Web and desktop
  from the same project. No C#, threads, `OS.execute`, app filesystem outside `user://`, or
  blocking network calls. Jolt/renderer changes need a superseding ADR and Web verification.
- Engine upgrades are a separate branch and migration commit. Review the new editor's resave
  diff; update the pin here/README and the ADR. Do not bump the version incidentally.

## Data and control boundaries

1. ConnectionGraph is the assembly authority. Editor, physics, wiring and presets derive from
   it; presets serialize the graph. Project documents separately include learner source.
2. Mechanical snaps align ports. Electrical links preserve placement (ADR 0022). Pins come
   from graph wiring, never runtime constants. Move keeps wires; delete/Undo update the graph.
3. Assembly is kinematic; run mode is graph-derived RigidBody/Joint physics. Do not hand-author
   a second robot or write physical trial results back into the editor graph.
4. Board profile, language runtime and block set remain separate (ADR 0004). Profiles declare
   APIs; blocks derive from them; runtimes must not special-case a board.
5. Code/manual/experiments have exclusive command ownership. Stop/mode changes invalidate
   old asynchronous work. Imported projects never execute code automatically.

The generated [code map](docs/generated/CODE_MAP.md) locates files. [DATA_MODEL](docs/DATA_MODEL.md)
documents Resource/JSON relationships; [FLOWS](docs/FLOWS.md) documents current calls and states.

## Product, UI and AI

- Read [POLICIES](docs/POLICIES.md) before UI, onboarding, task or AI work. If present in the
  working branch, also read relevant sections of `docs/PRODUCT_EXPERIENCE.md` and
  `docs/NATURAL_LANGUAGE_TASKS.md` for their dated research and requested command behavior.
- Feedback and success follow actual graph state/observations. Distinguish proposal, implemented
  behavior, source-specific verification and release. Preserve current product decisions in STATUS.
- Natural-language tasks use current scene objects and supported bounded actions, with observed
  completion and local cancellation. Never execute arbitrary generated code as an action contract.
- Before implementing/releasing a provider, recheck official auth/billing policies. Show provider,
  billing mode, sent data and request limits before generation. Reuse confirmed scope; no silent
  paid fallback. Changes to saved assembly/code need an intentional user action.
- Record user problem, dated sources, adopted principle, actual before/after evidence,
  validation/localization/cost impact and remaining work in the development note or PR.

## Localization

- Review localization impact in every change. New/changed/removed user text includes part names,
  help, tooltips, dialogs, errors and AI warnings. Update English and `assets/locales/{ko,zh_CN,ja}.po`
  together. Preserve placeholders/units/cost warnings; never translate input, secrets or syntax.
- Follow [LOCALIZATION](docs/LOCALIZATION.md). For UI text changes, run
  `godot --headless --path . --language en --script tests/localization_check.gd`, explicitly check
  new strings in all catalogs, and inspect glyphs/clipping on changed screens in all languages.
- Record results, or explicitly state no localization changes were needed for documentation work.

## Implementation and verification

- Follow official GDScript conventions: tabs, snake_case files/members, PascalCase classes,
  static typing, one class_name per file. Comments explain why, not obvious code.
- Humans compose `.tscn` in Godot; only trivial property tweaks may be edited as text.
- For application changes, run import and scene-load checks:
  `godot --headless --path . --import --quit` and `godot --headless --path . --quit`.
- Run the checks appropriate to acceptance criteria, including GUT if available. If automation
  is unavailable, explain why and report actual manual verification. See [BUILD](docs/BUILD.md).
- Every change reviews affected docs using [MAINTENANCE](docs/MAINTENANCE.md).
  Documentation/tooling-only changes run `python3 tools/docs/maintain.py --check` and the
  documentation tool's tests. Report app tests as not run; do not imply new app verification.
- Handoff/PR must state commands, results, source identity, evidence, failures/unrun checks,
  ADR/scope and localization impact. Historical results are not current passing checks.

## Workflow

- One GitHub issue per implementation task; use existing `owner:human/claude/codex/cheap-llm` labels.
- `feat/<issue#>-<slug>` for implementation, `docs/<slug>` for scoped documentation preparation.
  PR to main; Claude reviews and the human merges. Agents never self-merge.
- Short imperative commit subjects. Code/identifiers/comments are English; docs/issues/PRs may
  be Korean. No credentials, private transcripts or large raw logs in onboarding documents.
- Finish or release task ownership with an explicit checkpoint. Update STATUS when integrating
  features/directions, and this user's Now/project pointers for meaningful local work.

Detailed contributor procedure: [CONTRIBUTING](CONTRIBUTING.md).
