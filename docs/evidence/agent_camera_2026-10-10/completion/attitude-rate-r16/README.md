# Attitude plus housing-rate diagnosis r16

2026-10-11T09:05:34+09:00; issue32; runtime **5c8c41708e4126798256412ccc0345383054c365**. Developer probes, no applied
production repair, merge, push or publication. All426 current original inputs,
seven additional operator sources, r14ZIP and immutable appfa868ca/0.3.1-projects-r7
PE/PCK remain byte-identical. Original24–38px and4–14cm criteria are retained.

| Actual probe | Last5 floor pixels | Span | Final gap | Last image | Physical | Combined |
|---|---|---|---|---|---|---|
| Attitude32 | 23,25,26,25,26 | 3px | 14.113560cm | PASS | FAIL | FAIL |
| Attitude32 + housing-rate16 | 21,21,23,24,24 | 3px | 14.012836cm | PASS | FAIL | FAIL |
| Attitude32 + housing-rate18 | 22,23,22,23,22 | 1px | 13.986363cm | FAIL | PASS | FAIL |

The current K32 baseline reproduces the joint failure; its final gap differs by
about0.008mm from r15 and is reported separately. Adding rate16 preserves the last
image criterion but misses14cm by **0.128mm**. That near miss remains a failure.
Based on that actual result, one additional fixed16→18 comparison was preregistered
in the existing plan, before execution. It uses a fresh nested fixture/output,
preserving the original two inputs/results. Rate18 passes the physical criteria
but leaves only22px, below24. **Neither candidate is applied.** No target relaxation,
joint pass, causal repair, broad reliability or incompatibility claim follows.
The one-pixel span in one rate18 probe is not a validated jitter repair; signed
housing/body rates remain similar. [Exact summaries](summary.json).

The original pair adds only the existing r9 positive housing-axis angular-rate
term16 to the recovered attitude32 prototype. The additional comparison changes
only that coefficient to18. Same P8/I16 wheel holding,25% cap/forward25%, finite
graph-wired DriveMotor/torque,12stable/240bound, observed frame_ready attitude latch
and accepted-forward invalidation. No body pose/velocity setter, physical distance/
contact control input, extra actor input or camera/FOV/mount change.
[Ranked initial predictions](provenance/hypotheses.json), [extra comparison](provenance/rate18-inputs.json).
Initial plan/language before-copies and dated adaptive prediction remain in the
canonical task backup; private plan bodies are excluded from this public evidence.

Each actual rendered Windows Godot4.7.2 replay uses wall0.35 and30/10/12, four idle
captures30frames apart, then132frames after Stop. Both motors have powered callbacks
exactly30/10/12; each case preserves8actual640×480PNG/7post-initial SHA-tick samples.
Nativeexit0/Stop in18.411/21.124/19.685s certifies diagnostic completion. The original
joint-target check CLI returns1 in all three cases. Candidate16 and18 actualheadless
check-only each exit0. Model calls in probes0; this is not the3layout×3AI benchmark.
Historical camera9/9/strictphysical0/9 remains unchanged.

Astra actually viewed6original post-3/idle-4 images: approximate22/25px for K32,
20/23px for32+16,21/21px for32+18, all±2px and central band unobstructed. Classifier
last26/24/22 and visual25/23/21±2 remain separate evidence. Stills do not certify
physical distances, continuous jitter, ticks, cause, runtime, success or reliability.
[Inspection](provenance/astra-inspection.json). All73 named raw files/24PNG
are byte-preserved; [manifest](copy-manifest.json). Camera assignment/callback
physics may differ in time; sampling does not establish exact simultaneity.

Debug fixtures and archived drivers require this Windows checkout/toolchain and
private receipt paths; they are evidence, not portable product launchers. No
production UI/style/localization/provider/auth/action-limit change. Existing Opus
review and appimport/fullnative/Web/installer/exports/r14SDKsetup are dated history,
not rerun. Documentation maintain and10tests apply to this handoff.

Next Codex: investigate a different original-target control mechanism, preserving
these failed combinations instead of further unplanned gain search. Original
precision, fresh-account onboarding/navigation, nativeMac, powered-offArch raw/
formal task16 CLI release, humanmerge/exactversion-scopepublication remain.
Separate12–20px calibration is still a proposal, not adopted/run. Fable reviews/
rebases the branch; humanmerges. The whole goal remains incomplete.
