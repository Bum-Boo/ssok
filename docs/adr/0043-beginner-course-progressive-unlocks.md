# 0043 — Beginner course: semi-assembled starts, progressive unlocks and tier 1 power

- Status: accepted
- Date: 2026-11-26
- Implements: step E3 of [ssok-redesign-20261111](../design/ssok-redesign-20261111.md) (sections 3, 6 and 7) and the owner's confirmed direction that the course unlocks parts and tools gradually, like an ordinary game or simulator.
- Partially supersedes: [0036](0036-own-build-stages-and-aggregate-goals.md), only "new stage entries have empty graph/source and the full Lab part catalog" and "keep Blocks, Code, Wiring, Controls" for every stage. Course levels now declare their own start, tray and tabs.
- Extends: 0025, 0036, 0039, 0040, 0041 and 0042. Graph authority, aggregate goals, hole-targeted assembly, electrical tiers, docked panels and part cards remain accepted.

## Decision

The stage map is a five-level beginner course, all at electrical tier 1:

| # | id | Start | Tabs | Unlocks (cumulative tray) | Goal |
|---|---|---|---|---|---|
| 1 | light-on | board, LED, battery on a plate, no power cable | Wiring | battery, micro:bit, LED, plate | `led_lit` ≥ 0.5 for 1 s |
| 2 | finish-line | kit car without sensor, no power cables | Wiring | motors, wheels, driver, frame parts | every part past x = 0.5 m |
| 3 | raise-flag | lowered servo arm, no power cables | Blocks, Code, Wiring, Controls | servo motor, bracket, weight, flag | flag height |
| 4 | wall-brake | sensor car, no power cables | Blocks, Code, Wiring, Controls | distance sensor, compact car | 5–10 cm from the wall, still |
| 5 | first-robot | empty workbench | Blocks, Code, Wiring, Controls | everything above | every part past x = 0.5 m |

A semi-assembled start is the stage's answer graph with a battery holder mechanically stacked on
the board (or, for the compact car, the motor driver) and every power cable removed. The learner's
first task is closing the circuit; the program (`starter_code`) is already loaded. Levels 1–2 hide
Blocks and Code and their step chip; the hidden program still runs, so success depends only on
power wiring. "Show solution" adds the power cables (battery → driver → board → sensors).

`level.parts` is the cumulative union of each level's unlocks and limits the tray. The result card
names what the next level unlocks in one line. The new aggregate metric `led_lit` is the brightest
LED whose part and board are powered; it requires stage v2, `part_id="*"` and index −1.

Workshop guidance counts wiring as done at tier 1 only when the power net reports no problem.

## Consequences

- Stage ids `raise-flag`, `finish-line`, `wall-brake` keep their saved progress. Level numbers change.
- The wall-brake answer brakes at 12 cm and pauses 1.5 s: the heavier battery-carrying car coasts.
- The Lab still starts empty with the full tray; imported stages are unaffected.
- Intermediate and advanced courses (tiers 2–3) are later work (E4, E5).
