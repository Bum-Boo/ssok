# Attitude reference-timing diagnosis r17

2026-10-11T09:22:54+09:00; issue32; runtime **89889ecb43627950df5b6491700ebf01c031825d**. Developer-only probes, no applied
repair, merge, push or publication. Source426+operator7/r14ZIP/immutable app
fa868ca/0.3.1-projects-r7 PE/PCK and frozen original goal remain unchanged.

| Actual reference policy | Last5 floor pixels | Span | Final gap | Last image | Physical | Joint |
|---|---|---|---|---|---|---|
| current | 23,25,26,25,26 | 3px | 14.113560cm | PASS | FAIL | FAIL |
| prior-observation | 23,23,25,26,23 | 3px | 14.118288cm | FAIL | FAIL | FAIL |
| brake-entry | 23,24,23,24,26 | 3px | 14.071068cm | PASS | FAIL | FAIL |
| brake-entry-rate16 | 21,24,24,22,23 | 3px | 13.922507cm | FAIL | PASS | FAIL |

Current attitude32 reproduces r16's exact measured image/gap failure after adding
the same targeted latch audit to all policies. Retaining the preceding observation
through forward settling (prior) fails both final criteria. Latching at actual
powered-forward brake entry preserves26px and improves the gap by about0.425mm,
but still misses14cm by0.711mm. Neither reference policy is an applied repair.

After that actual result and before execution, one additional comparison was
preregistered in the existing plan: add the already-tested positive housing-axis
rate16 term to unchanged brake-entry attitude32. A fresh nested fixture/output
preserves the original three inputs/results. This yields13.922507cm physicalPASS
but only23px on the last image, below24: jointFAIL and unapplied. No gain search,
target relaxation, causal/jitter/reliability or incompatibility claim follows.
Its intermediate idle-1/idle-2 images have24px. They were not followed immediately
by Stop; their eventual final physical result cannot prove an intermediate joint
pass. Next test must bind the observed image to an actual scoped Stop, using
camera-only decisions rather than evaluator distance.

Same coefficient32/P8I16/25% duty cap/forward25%, graph-derived finite DriveMotor,
torque/backend/camera mount/FOV,12stable240timeout and30/10/12 replay. The initial
pair changes reference timing only; adaptive comparison adds one existing rate16
term. No body pose/velocity setter, distance/contact evaluator as control input,
actor/model input change or model call. [Predictions](provenance/hypotheses.json),
[adaptive inputs](provenance/combo16-inputs.json).

[Actual latch/evaluation audit](provenance/latch-audit.json): each run has9 frame_ready
events (including one initial internal frame before8 archived captures),3 accepted
forward events. Current/brake unbind on forward, prior stays bound; brake policies
record3 actual brake-entry binds. Raw rotation strings measure the body at the
event; they are not separate quaternion setpoint receipts. Actual independent
travel/contact/minimumgap/rest/stopped fields are preserved beside final gaps.
Every run has8 actual640×480PNG/7 postinitial SHA-tick pairs, actual powered motor
counts30/10/12 on both motors, four idle captures30frames apart, then132frames
after Stop. Native exit0/Stop18.337/19.810/18.712/19.124s certifies diagnostic
completion; the unchanged joint-target CLI returns1 all four times. All3 candidate
headless check-only preflights exit0. No compile/runtime timeout occurred.

Astra actually viewed8 original post-3/idle-4 stills. Exact observations, hashes,
dimensions and uncertainty are in [inspection](provenance/astra-inspection.json).
Classifier final26/23/26/23 and visual estimates stay separate. Stills do not
certify physical distance, continuous jitter, ticks, runtime, cause, success or
backend identity; requested Astra role is recorded, serving identity unexposed.
Camera assignment and callback physics may differ in time. All93 namedraw/32PNG
source-copy bytes are preserved by [manifest](copy-manifest.json).

Archived fixtures/drivers require this Windows checkout/toolchain/private receipts;
they are evidence, not portable product launchers. Production UI/style/localization/
provider/auth/action bounds unchanged. Docs maintain/10tests apply to this handoff.
Appimport/fullnative/Web/installer/exports/r14SDKsetup and existing Opus review
remain dated history, not rerun. Existing3layouts×3AI image9/9/physical0/9 unchanged.
Separate12–20px calibration remains an unadopted/unrun proposal. Original precision,
fresh-account/navigation, nativeMac, powered-offArch raw/formal task16CLI release,
Fableintegration/humanmerge/exactversion-scopepublication remain incomplete.
