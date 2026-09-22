# ssok product release — acceptance and evidence

Owner: Bum-Boo. Delivery issue: [#29](https://github.com/Bum-Boo/ssok/issues/29).
Started 2026-09-22. Status: **in progress; not released**.

The objective is a complete, usable educational robot construction product that a hiring team
can evaluate through its public repository, working application, engineering decisions and
reproducible evidence. A polished README alone is not completion. Employment is not a measurable
software acceptance criterion; product quality and demonstrated engineering are.

## Required outcomes

| Requirement | Completion evidence | Current status |
|---|---|---|
| Assemble, inspect, transform, snap and wire independent reusable parts | User-flow checks on actual graph state and rendered application | Graph/assembly checks pass locally; clean CI physics regressions under review |
| Code and profile-derived blocks control the wired robot | Round-trip conversion, invalid input, control handoff and physical actuation checks | Implemented; physical code/block checks pass, draft-saving regression fixed |
| Save, reopen and share a project without losing assembly or learner code | Cross-session round-trip, invalid file rejection, browser persistence and explicit replacement | Complete exported browser flow passes twice, including real clipboard and blocks; clean0b2fe24 also passes; final release recheck pending |
| Credible elementary-kit humanoid pickup and locomotion | Real contact, gravity, motor limits, original lift/hold/stability gates and measured runs | Pickup ~48 cm / 1 s passes; robust locomotion validation ongoing |
| Genuine learned locomotion | Reproducible training, held-out task metrics, artifact provenance and successful Godot re-evaluation | Bundled v2: native fresh64/64, restart63/64 with one fall; actual-app12/12 and declared WASM6/6 pass. V1 clean-browser failure and rejected candidates retained; final clean-release recheck remains |
| Clear onboarding, accessible controls and four-language UI | First-use walkthrough, keyboard/error states, rendered en/ko/zh_CN/ja inspection | Eleven-step guide, keyboard workflows and four-language authoring checks pass; actual browser paste and compact viewport verified; clean-revision recheck pending |
| Reproducible build and automated verification | Clean checkout CI, all required checks, pinned dependencies, downloadable artifacts | Pinned exports work; remote CI regressions being resolved |
| Public browser and desktop release | Anonymous browser smoke test, actual interaction/persistence, desktop startup, checksums | Not deployed |
| Honest, compelling engineering portfolio | Real screenshots/demo, architecture/case study, measured limitations, attribution and no secrets | Real screenshots and engineering case study added; final audit pending |

## Guardrails

- Preserve ConnectionGraph authority, GDScript web compatibility and elementary-part identity.
- Do not replace physical behavior with animation, hidden support, position injection or weaker success gates.
- Tests and past notes are evidence only when their coverage and current execution are verified.
- Keep original dirty worktrees intact; release integration lives in `feat/29-product-release`.
- Paid LLM calls are unnecessary for deterministic demonstrations and must not be invented.
- User-facing changes include Korean, Simplified Chinese and Japanese in the same implementation.

## Work ownership

- Root: integration, complete project/authoring workflows, product review, documentation and publication.
- Physics: elementary-kit pickup and physically credible movement, preserving original success gates.
- RL: integrate the separate experiment, train and evaluate learned policies, Godot runtime inference.
- Delivery: full verification runner, engine/templates, desktop/web exports and CI/CD.

## Release review

Before publication: audit tracked files and history for private material, confirm asset permissions,
record exact versions and checksums, inspect screenshots and exercise the exported application.
Before marking complete: replace every pending row with actual artifact/run/URL evidence and assess
any remaining known defect against the product requirement; do not silently redefine acceptance.
