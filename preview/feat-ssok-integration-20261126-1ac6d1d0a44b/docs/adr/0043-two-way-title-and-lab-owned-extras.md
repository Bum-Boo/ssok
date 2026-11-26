# 0043 — Two ways in from the title; the Lab holds projects, examples and experiments

- Status: accepted
- Date: 2026-11-26
- Implements: the owner's stage 1 simplification request of 2026-11-26: the title spread four entries (Play stages, Free building, Explore examples, Open my project) where a game or simulator offers two, and research features must stay out of the stage flow. It follows section 3 of [ssok-redesign-20261111](../design/ssok-redesign-20261111.md): the title chooses between the course and free building only, and a stage keeps its own "show the finished build" (its solution).
- Partially supersedes: [0028](0028-game-screen-flow-and-stage-levels.md), only the examples menu scene and the `example` workshop session. Routing, level scenes, stage outcomes and the standalone empty-session workshop remain accepted.
- Extends: 0030 and 0041. The Lab Help menu still opens projects, examples, controls, authoring and AI; this record orders it and groups the experiments.

## Context

The title showed four large buttons. Two of them led to places a learner could also reach from free
building: saved projects were already under Help → Projects, and the examples screen loaded the same
six robots that Help → Load an example loads. The examples screen opened its own `example` session,
which kept the legacy header with the AI motion lab button, so an experiment was one click from a
menu meant for beginners. Free building itself had no path to the AI motion lab or the pickup lab.

## Decision

- **Two ways in.** The title has two main buttons: Play stages (primary, focused on start) and Free
  building. The language picker and Settings stay at the bottom. The Free building caption says that
  saved projects and examples open from Help. Korean labels are 플레이 and 자유 제작.
- **The Lab owns the extras.** Free building's Help menu starts with Projects and Load an example,
  then the everyday help (Tutorial, Build this arm yourself, Controls, Stages, Settings), then an
  Experiments submenu with AI camera (the existing AI tab) and AI motion lab (the motion lab, or the
  pickup lab for a humanoid, as before). Project save, open, import and JSON export are unchanged.
- **Stages stay focused.** A stage's Help menu keeps its items (Tutorial, Settings, Projects and
  the inactive arm practice), with no examples and no experiments. Its AI tab and motion lab button
  stay hidden, as in 0028.
- **One fewer session.** The examples menu scene (`scenes/screens/examples.tscn`, `ExamplesScreen`)
  and the `example` session are removed. Leaving free building returns to the title; leaving a
  stage returns to the stage list. A stage's solution stays in its own goal-strip menu.

## Consequences

- The router knows three menu scenes: title, stage select and loading.
- Strings used only by the removed title buttons and the examples screen leave the three catalogs
  and the game-flow inventory. Two strings are new: the Free building caption and "AI camera".
- Packaged evidence that drove Title → Open my project describes the earlier source and stays as
  history. New drivers reach projects through Free building → Help → Projects (or Ctrl+S).
- The legacy empty-session workshop keeps its header buttons, including the AI motion lab, for the
  existing integration checks.
