# ssok product release — acceptance and evidence

Owner: Bum-Boo. Delivery issue: [#29](https://github.com/Bum-Boo/ssok/issues/29).
Started 2026-09-22. Status: **in progress; not released**.

The motor impulse cap previously exceeded its nominal physical torque by being spent once per solver
pass. ADR 0020 corrects the whole-step budget. Corrected pickup, learned-policy, full native and clean
browser verification now pass as recorded below. Earlier motor-driven results remain historical;
unrepeated broader claims do not inherit these new passes. The ideal-limit legacy biped uses a separate model.

The objective is a complete, usable educational robot construction product that a hiring team
can evaluate through its public repository, working application, engineering decisions and
reproducible evidence. A polished README alone is not completion. Employment is not a measurable
software acceptance criterion; product quality and demonstrated engineering are.

## Required outcomes

| Requirement | Completion evidence | Current status |
|---|---|---|
| Assemble, inspect, transform, snap and wire independent reusable parts | User-flow checks on actual graph state and rendered application | Graph/assembly checks pass in the full native suite and clean CI; final integrated source must retain those passes |
| Code and profile-derived blocks control the wired robot | Round-trip conversion, invalid input, control handoff and physical actuation checks | Implemented; physical code/block checks pass, draft-saving regression fixed |
| Save, reopen and share a project without losing assembly or learner code | Cross-session round-trip, invalid file rejection, browser persistence and explicit replacement | Clean6470757 passes complete actual-browser authoring, clipboard, persistence/reload, JSON safety and block edit/export flow |
| Reliable manual robot control | Signed movement, release, continuous direction changes and actual-app/native/Web checks | Isolated legacy-biped direction checks pass; continuous direction changes remain unreliable and final legacy Web acceptance is pending |
| Credible elementary-kit humanoid pickup and locomotion | Real contact, gravity, motor limits, original lift/hold/stability gates and measured runs | Corrected torque model: default 4 s lift passes 277 kit assertions and 12 pickup integration suites (~47.7 cm / 1 s); sustained kit locomotion unresolved |
| Genuine learned locomotion | Reproducible training, held-out task metrics, artifact provenance and successful Godot re-evaluation | Corrected-model frozen policy integrated:126/128 held-out with two falls, actual-app12/12, declared Web6/6 and clean6470757 browser gate pass. Historical policy remains rejected; known falls remain disclosed |
| Clear onboarding, accessible controls and four-language UI | First-use walkthrough, keyboard/error states, rendered en/ko/zh_CN/ja inspection | Eleven-step guide, keyboard workflows and four-language authoring checks pass; clean6470757 browser paste and compact viewport verified; final integrated revision still requires visual review |
| Reproducible build and automated verification | Clean checkout CI, all required checks, pinned dependencies, downloadable artifacts | 55/55 native suites pass. [Push CI](https://github.com/Bum-Boo/ssok/actions/runs/35687164945) at `961dbff` and [PR CI](https://github.com/Bum-Boo/ssok/actions/runs/35687167964) pass verify/build and all three browser gates; Pages/release-assets are skipped. Clean `6470757` local export evidence separately records Web/Linux resource audits, Linux startup and all three browser gates |
| Public browser and desktop release | Anonymous browser smoke test, actual interaction/persistence, desktop startup, checksums | Not deployed |
| Honest, compelling engineering portfolio | Real screenshots/demo, architecture/case study, measured limitations, attribution and no secrets | Real screenshots, engineering case study and new corrected-budget pickup/learned recordings included with hashes and reviewed frames; final publication audit pending |

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
