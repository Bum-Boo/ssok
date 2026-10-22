# Learning implementation evidence — 2026-09-30

Issues #31–#36 are integrated on `feat/31-issues-integration`, based on the stabilized release
core `3806a1f`. The original dirty release worktree is preserved. This is a review candidate;
it does not establish a public release, classroom effectiveness or real-hardware fidelity.

## Applied scope

| Issue | Result in this candidate | Remaining scope |
| --- | --- | --- |
| #31 | Loose-arm assembly practice, compatible ports, graph wiring/wrong-pin feedback, editable blocks, measured flag-height goal and retry comparison | Lab colleague/professor/student 60-second and five-minute observation has not been conducted |
| #32 | [App-control contract](../../APP_CONTROL_API.md), bounded AppController and isolated developer request runner, edit/revision gates and observed results | Design issue only: no live MCP server, app listener or natural-language robot executor registered |
| #33 | [Stage/Lab plan](../../LEARNING_STAGES.md), three playable declarative stages, local challenge JSON import/export, fresh successful author-solution proof | Remaining 12 stages, classroom observation, community/accounts/server/moderation are gated follow-ups |
| #34 | Graph-wired DRV8833/TB6612 DC motors, bounded linear torque/speed impulses, brake/coast, cylindrical tires and car/caster example | Simplified visual envelopes and physics model; no hardware calibration; Jolt brake comparison fails |
| #35 | Bounded AST/bytecode VM with variables, arithmetic, short-circuit logic, if/elif/else, while, break/continue, physics-tick sleep/time, source diagnostics | for/def and full Python are outside this implemented subset |
| #36 | Nine cone rays, robot/floor exclusions, 2–400 cm, pulse timeout semantics, wrapper/blocks and optional seeded noise | Noise is an internal opt-in API, not a learner-facing Reality-mode setting |

[ADR 0023](../../adr/0023-bounded-learning-vm-and-dc-hardware.md) extends existing contracts;
Godot 4.7.2, GDScript, GL Compatibility, GodotPhysics3D and graph authority remain unchanged.
Task-instance targeting, immutable environment/version certification and stopped/unjudgeable
result separation are being implemented in a separate `ssok-stage-contracts` follow-up. This
candidate does not claim that additional contract or cross-device certification.

## Native verification

| Evidence | Actual result |
| --- | --- |
| [Full retained run](ready-native/results.json) | 66 groups: 65 PASS / 1 FAIL (`pickup_bridge_ui_check`, three assertions) |
| [Focused rerun](final-rerun/results.json) | 4 groups PASS; the bridge check passes 148 checks / 0 failures |
| [Latest code/output checks](outcome/results.json) | 4 groups PASS, including Stage authoring 42 checks, API 14 checks and localization 42,213 checks |
| [Earlier focused acceptance](final-focused/results.json) | 10 groups PASS, including language 14, car 14 and randomized sonar 9 checks |
| [Board/profile follow-up](board-profile/results.json) | 6 groups PASS, including graph-derived palette changes and pending draft preservation |
| [Combined index](verified-checks.json) | All 66 groups have a passing retained result; this is a union, not a single all-green full-suite run |

The bridge failure occurred while software-rendered browser work was running; after closing
those processes, the same check passed. Load-related timing is a hypothesis, not an established
root cause. The failing run and its three assertions remain available. The earlier
[initial native run](final-native/results.json) also retains six failures; resource binding,
updated input/part-count/arithmetic expectations and missing offline documents were corrected
and the relevant [12-group rerun](corrected/results.json) passed.

[Randomized wall comparison](sonar-v2.log): sensor-controlled programs pass 3/3 walls at
0.5333, 0.7634 and 1.0342 m with gaps 7.3679, 7.0279 and 6.7456 cm. The fixed timer passes
0/3 of the same distance criteria (4.0933, 27.1054 and 54.1845 cm). Both are evaluated using
the graph's sensor even if the learner source does not read it.

[Jolt comparison](jolt-car-final.log): 14 checks / 1 failure, wall gap 2.277 cm. Production
GodotPhysics3D passes 14/14. The earlier [35% duty brake failure](initial-brake-failure.log)
is retained; the accepted example uses 25% and a 20 ms sensor loop. Backend results are
separate observations, not interchangeable certification.

## Actual exported browser verification

The final [browser result](browser/result.json) is `passed: true`, five checks, on Chromium
152.0.7977.75 with Intel HD Graphics 530 / Mesa OpenGL through ANGLE. The harness uses actual
canvas interaction, graph identities and expected metric sets; observations are read-only
under `?ssok_verify=1`. It does not actuate the robot through JavaScript.

| Check | Measured result |
| --- | --- |
| [Raise flag](browser/flag-success.png) | Height 0.164958 m; one-second hold; stage cleared at 2.3833 s |
| [Finish line](browser/finish-success.png) | x=0.506463 m; uprightness 0.999931; stage cleared at 1.3 s |
| [Wall braking](browser/sonar-success.png) | Gap 7.162556 cm; speed 0.001618 m/s; zero wall contacts; cleared at 3.8167 s |
| [Challenge download](browser/verified-challenge.json) | Real downloaded portable JSON with 10-part graph and author solution |
| [Infinite loop Stop](browser/loop-stopped.png) | `while True: pass` yields to the UI; Stop interrupts execution |

[Earlier successful browser candidate](browser-initial/result.json) is retained separately.
Harness retries corrected popup initial-focus assumptions, delayed key delivery, stale-stage
checks and clipboard newline comparisons. Software SwiftShader runs were too slow and were
stopped; they are not claimed as passing browser evidence. The final browser console is
retained in [console.json](browser/console.json).

English/Korean/Simplified Chinese/Japanese catalogs were updated together. Sixteen native
screens cover flag and Stage tabs at 960×640 and 1440×900; representative screenshots:
[Korean](screens/ko-960-stage.png), [Chinese](screens/zh_CN-1440-stage.png),
[Japanese](screens/ja-1440-stage.png), [English](screens/en-1440-stage.png).
The changed screens were visually inspected for glyphs/clipping; compact tabs scroll to the
selected tab. Locale-specific code input remains learner source rather than translated syntax.

## Frozen delivery identity

The final clean export uses application-source commit
`d6c3d26d06a0d288950c543985809a5c85a7f463`, `dirty_worktree: false`, exact engine
`4.7.2.stable.official.ed1daf0bf`. This evidence commit adds reports only after that freeze.
[Release manifest](release.json), [checksums](SHA256SUMS),
[import log](export-logs/import.log), [Web export](export-logs/web.log),
[Linux export](export-logs/linux.log) and [Linux startup](export-logs/linux-startup.log)
are retained. Resource reports verify that developer tests, docs, Python and Blender content
are excluded from the runtime pack while licensing/offline documentation remains bundled.

Local artifacts under `build/issues-delivery/`:

- `ssok-issues-31-36-delivery-web.zip` — SHA256 `77a08b41627d5f7d1e4d046f741ed1175e9b20b4372c0bbcba1b9da63931c0a6`
- `ssok-issues-31-36-delivery-linux-x86_64.zip` — SHA256 `6419cc290a511297b2964ee25596bb44b4a5d87c1f746d7ccd328010d73af2e7`

Remote attempts used personal Himmel only. [Python bootstrap mismatch](bootstrap-python-mismatch.log)
and [partial remote results](remote-partial/results.json) remain diagnostic failures, not final
acceptance proof. All related jobs were completed/cancelled and resources released; no private
material went to the shared lab Mac. No paid AI calls or community analytics were introduced.
