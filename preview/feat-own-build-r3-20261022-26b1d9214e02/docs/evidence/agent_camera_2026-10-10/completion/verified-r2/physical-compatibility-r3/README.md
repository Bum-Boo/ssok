# Physical/image boundary diagnosis r3 — developer evidence

Checkpoint 2026-10-11T03:19:44+09:00; source HEAD `12a92983a120d6dc49d266e421490e131377e488`, unchanged application/package source `f31f8d5`.
Godot4.7.2/GL/GodotPhysics3D, native Windows rendered robot camera640×480. No AI/provider call or
application input change. This diagnostic is separate from the frozen AI study **image9/9, physical0/9**.

The original near-wall tape30/10/12 reproduces a red combined result in approximately19seconds.
Existing motor actions, settling, actual captures and Stop are used; image24–38px and independent
gap4–14cm/minimum travel3cm/no contact/rest/Stop criteria remain unchanged.

| Developer replay | Final floor strip | Final Stop gap | Image | Full physical | Combined |
|---|---:|---:|---|---|---|
|30/10/12 |26px |14.0431cm |pass |fail: gap |fail |
|same tape repeat |26px |14.0858cm |pass |fail: gap |fail |
|30/10/13 |22px |13.7652cm |fail |pass |fail |
|30/10/12/1, separately settled |23px |13.9811cm |fail |pass |fail |

Raw results: [recovered](recovered/combined-check.json), [repeat](repeat12/combined-check.json),
[one extra tick](tick13/combined-check.json), [split extra tick](segmented12-1/combined-check.json).
The unchanged image-only calibrator exits0 for26px despite physical failure. The outside combined
wrapper exits1 for all four; neither image-only exit0 nor physical-only pass means full success.

The additional [same tape with repeated observations](jitter/result.json) captures22,24,22,24,22px
after its final action, with capture-time gap14.0651–14.1306cm (0.655mm range). Native Astra
actually viewed these five PNGs plus recovered post-3/final-idle: [seven-image inspection](astra-inspection.json).
Boundary uncertainty is approximately±1px;24px is a nominal lower-edge pass. Goal thresholds are
not relaxed. All five paired image/gap flags fail; those flags test only the frame image and gap,
not the complete final physical predicate. Final Stop gap14.0033cm still exceeds14cm.

The recovered post-action frame is23px at gap14.0775cm; two seconds later it is26px at14.0872cm.
Chassis orientation changes with only0.098mm of gap change. Post-Stop gap14.0431cm is **closer**,
so Stop drift does not explain the excessive final gap in that replay. Small orientation changes
and pixel changes are correlated. The experiment does not isolate their cause or prove that the
two predicates are globally incompatible. Identical tick totals also do not guarantee identical
positions under this native solver/observation timing.

Capture-time physics pairs are developer-only derivatives matched by PNG SHA and actual physics
tick. They are never actor inputs: [recovered pairs](recovered/frame-physics-pairs.json),
[tick13 pairs](tick13/frame-physics-pairs.json), [split pairs](segmented12-1/frame-physics-pairs.json).
The [summary](summary.json) preserves the ranked hypotheses and untested limits.

The first [prerequisite failure](initial-prerequisite-failure/replay.log) occurs before actions because
the locked native Python3.14.7 environment lacks Pillow. Existing Python3.13.3/Pillow12.2.0 recovers
the probe without installation. The bounded outer runner uses90seconds and only its owned process
tree on timeout; no case timed out. The jitter fixture completed22.738seconds with owned cleanup.
[Developer launcher](developer-helpers/ssok-camera-gap-replay-r3.py) and
[observation probe](developer-helpers/ssok-camera-jitter-r3.py) are external verification helpers,
not application code or new actor tools. The prerequisite failure is not a physical-goal failure.

No camera/robot transform, body velocity, finite torque, goal, evaluator or disclosed model inputs
were changed.426 application/test/tool/core and10 camera-study hashes plus the goal SHA remain
identical. No extra application CI/export/browser/installer run was needed for this evidence-only
follow-up; the prior r2 runtime receipts remain version-specific. No localization/catalog change.

Next: preserve the frozen study. Any controller repair first needs an isolated red seam and the
existing motor/observation/ownership contract. A changed goal or additional real sensor would need
a separate disclosed study; these measurements do not authorize one. Mac native/Arch recovery,
human merge and the pending reviewed-version/scope publication decision remain separate.
Latest Fable owns actual rebase of this documentation commit; the human merges. Generated task
revision16 is not edited manually. Recovery/record: existing backup physical-compatibility-r3 and
the canonical ssok joint-development report. [Parent reviewed draft](../README.md).

[Selected raw copy manifest](copy-manifest.json) includes only explicit public file names, no
isolated user-data/config or private provider transcripts. Original runtime directories and
failures remain local; derived summaries are not represented as byte-exact raw copies.
