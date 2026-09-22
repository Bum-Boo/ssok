# ssok product release — acceptance and evidence

Owner: Bum-Boo. Delivery issue: [#29](https://github.com/Bum-Boo/ssok/issues/29).
Started 2026-09-22. Status: **in progress; not released**.

**New release blocker:** the motor impulse cap was spent once per solver pass, exceeding its nominal
physical torque. ADR 0020 corrects the whole-step budget. Earlier motor-driven pickup, running and
learned-walking results are historical; their acceptance rows below require fresh verification under
the corrected runtime. The ideal-limit legacy biped does not use this torque model.

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
| Credible elementary-kit humanoid pickup and locomotion | Real contact, gravity, motor limits, original lift/hold/stability gates and measured runs | Corrected torque model: default 4 s lift passes 277 kit assertions and 12 pickup integration suites (~47.7 cm / 1 s); sustained kit locomotion unresolved |
| Genuine learned locomotion | Reproducible training, held-out task metrics, artifact provenance and successful Godot re-evaluation | Corrected-model frozen policy integrated:126/128 held-out with two falls, actual-app12/12 and declared Web6/6 pass. Historical policy remains rejected. Final clean-release verification pending |
| Clear onboarding, accessible controls and four-language UI | First-use walkthrough, keyboard/error states, rendered en/ko/zh_CN/ja inspection | Eleven-step guide, keyboard workflows and four-language authoring checks pass; actual browser paste and compact viewport verified; clean-revision recheck pending |
| Reproducible build and automated verification | Clean checkout CI, all required checks, pinned dependencies, downloadable artifacts | Corrected actuator/pickup/learned candidate passes55/55 suites in isolated9cdd259+policy checkout; final committed CI and clean export remain |
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
