# Independent camera trials — 2026-10-10 local draft

Branch `feat/32-robot-camera-loop`, base `4eb059f6432bebbbc8db94896cac56cbb8bb2927`,
owned Arch checkout `/home/bumboo/Projects/ssok-ai-loop`. Godot4.7.2 GL Compatibility,
GodotPhysics3D, Intel/Mesa; Codex0.150.1 requested `gpt-6-astra` using existing ChatGPT login,
Python MCP2.2.0. No API-key fallback, automatic retry, merge or publication.

## Contract and frozen inputs

Before model dispatch, [the original plan](live-suite/plan.json) fixed3wall layouts (.35/.50/.60m),
3live runs each and3frozen/3blank controls, max8actions/9images/300seconds per run.
[Input manifest](source_snapshot/manifest.json) and source copies identify original tool/runtime inputs,
before the later app-goal UI/operator changes. Source copies end in `.gd.txt`/`.py.txt` so Godot
does not scan snapshot classes. The source manifest uses original source paths.

The actor gets only camera PNG, public frame context, public summaries/tool results and the goal.
It never receives the independent evaluator, coordinates, wall gap, sonar, graph/source or scores.
The developer-only evaluator samples actual graph-derived physics/contact signals and analytical
world-X bounds of supported collision primitives, with a fixed X-normal wall. Unsupported shapes
make evaluation invalid. After Stop it waits30ticks and12consecutive rest ticks, up to120ticks.
This evaluator is scoped to these layouts, not a universal contact/navigation assessor.

Success requires valid evaluation, forward travel>=.03m, final gap .04–.14m, no wall contact,
positive minimum gap,12rest ticks, stopped state and final actor reobservation/confirmed Stop.
No model success statement, Stop alone or runner exit0 substitutes for these conditions.
Frozen/blank wrappers retain real image/context internally but return separately hashed delivered
PNG bytes; delivered-vs-real pairs and delivery journals remain in each trial. The app's receipt
labels experimental control and binds real frames; it is not delivery/cognition proof.

## Actual results, including negatives

| Run | Physical success | Observed limit |
|---|---|---|
| Original live | **0/9** | All9acted/reobserved/stopped without contact; gap14.027–17.316cm exceeded upper bound |
| Frozen | **0/3** | Two stopped early; first run had a reobservation request failure, so not3valid causal comparisons |
| Blank | **0/3** | All3issued0actions then stopped; small idle physics drift is not commanded navigation |
| Fixed4×20tick baseline | **1/3** | Near contact, middle passed, far stopped too early |
| Separate clarified visible goal | **2/3** | Middle/far gaps12.604/12.575cm passed; near issued0actions and stopped |

[Original results](live-suite/results.json), [summary](live-suite/summary.json),
[clarified-goal plan](refined-visual-goal/plan.json), [results](refined-visual-goal/results.json).
The3additional runs changed the goal to a center floor strip of5–8% of image height (24–38px),
keeping layouts/physical thresholds/action bounds unchanged. This is exploratory, not part of
the original9or evidence of reliable navigation. No post-hoc threshold relaxation was used.

Initial [calibration](calibration-suite/calibration.json) failed before provider calls: far .65m was
0.789mm beyond target and the old fixed snapshot caught only3rest ticks. The corrected
[calibration](calibration-suite-r2/results.json) used .60m and waited for physical rest;
3/3layouts were reachable with different deterministic actions. A deliberate-contact trial
latched contact/minimum penetration and failed as required. Both attempts are retained.

The first frozen run predates public request-error journaling, so its exact request-error cause
cannot be recovered from this evidence. New MCP error journals improve subsequent diagnostics;
they do not retroactively establish that cause. The old CLI also emitted missing Astra model
metadata/skill-description diagnostics: requested model is known, resolved backend is unattested,
and the actor context is not proven free of injected framework/skill text. Tool events used only
the3goal MCP tools. Action/image/time limits are not a hard model-request or monetary cap.

## Reproduce and next owner

Use separate, new output directories and an actual supported rendered desktop/display. Inspect
the frozen plan before explicitly allowing new model sessions; there is no automatic retry.

```sh
python -m tools.app_control.repeat_camera_trials --help
python -m tools.app_control.refine_camera_goal --help
```

The current foreground operator and changed source have separate [app-goal evidence](../goal_ui/README.md).
Latest Claude Fable owns integration review; human merge and reviewed-version publication approval
are still required. Broader robots, catalog camera serialization, learning, Web AI, packaged login,
Windows/macOS packages and full release checks remain outside this desktop experiment.
