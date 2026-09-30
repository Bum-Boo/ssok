# ssok product release — acceptance and evidence

Owner: Bum-Boo. Delivery issue: [#29](https://github.com/Bum-Boo/ssok/issues/29).
Started 2026-09-22. Current publication: **v0.2.0 learning-workshop delivery, owner authorized 2026-09-30**.

Current delivery is complete: [public Web workshop](https://bum-boo.github.io/ssok/), [v0.2.0 downloads](https://github.com/Bum-Boo/ssok/releases/tag/v0.2.0) and public repository. App source `af1973b`, exact six artifact hashes, native71/0, actual Windows17/0, same-payload browser gates and anonymous storage/settings/download checks are in the [publication record](evidence/public_release_2026-09-30/README.md). Research limitations below remain historical/current research requirements, separate from this delivered learning-workshop scope.

[ADR 0027](adr/0027-current-workshop-public-release.md) records the current scope: PR40/41 integration, full native/browser gates, four rebuilt platforms, anonymous Pages and Release access, history audit and retained original rights. [Publication evidence](evidence/public_release_2026-09-30/README.md) is the current delivery record. The research-product objectives and dated rows below remain historical; unresolved sustained Kit locomotion is disclosed as an exhibit and is not silently marked complete.

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
| Genuine learned locomotion | Reproducible training, held-out task metrics, artifact provenance and successful Godot re-evaluation | Selected heading policy:255/256 new paired conditions with one fall, versus preceding bundle251/256 with five falls. Actual-app12/12 and declared Web6/6 pass; exact committed policy also passes both clean CI browser physics gates at `170417b`. Previous results and every failure remain disclosed |
| Clear onboarding, accessible controls and four-language UI | First-use walkthrough, keyboard/error states, rendered en/ko/zh_CN/ja inspection | Eleven-step guide, keyboard workflows and four-language authoring checks pass; clean6470757 browser paste and compact viewport verified; final integrated revision still requires visual review |
| Reproducible build and automated verification | Clean checkout CI, all required checks, pinned dependencies, downloadable artifacts | Exact `170417b` [push CI](https://github.com/Bum-Boo/ssok/actions/runs/35706168449) and [PR CI](https://github.com/Bum-Boo/ssok/actions/runs/35706172447) each pass 59 native checks with zero engine errors, clean Web/Linux exports, Linux startup and all three real browser gates. Downloaded archive hashes match their manifests; Pages/release-assets skipped. [Original-artifact audit](evidence/release_ci_2026-09-30/README.md) |
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
