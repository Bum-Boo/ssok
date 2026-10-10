# Motor-only chassis angular feedback diagnostic r9

2026-10-11T06:55:22+09:00; issue32, source HEAD `f86fadd184129f88ced525c6def2a0ca574cc0ae`, local diagnostic only.
App input426, camera10, goal and immutable **fa868ca / 0.3.1-projects-r7** remain unchanged.
No app repair, model-navigation call, merge or publication. The global ssok goal is incomplete.

The [r8 original red signal](../control-feedback-r8/README.md) remains simultaneous image24–38px
and independent valid/travel≥3cm/gap4–14cm/no contact/positive minimum gap/rest12ticks/Stop.
Three [ranked falsifiable predictions](provenance/hypotheses.json) precede these probes.
The same actual rendered30/10/12, four30-tick idle/capture intervals and original Stop132ticks
run once stock and once with only a per-instance angular feedback term K0→16 added to holding.
Both use identical read-only observers. P8/I16,25% duty cap, fixed forward25%,12stableticks,
240timeout and original DriveMotor callback/physical torque limits are unchanged. The added term
reads only existing housing angular velocity along the graph motor axis; no distance/contact
or target pose is control/actor input, and no transforms/velocities are assigned.

| Probe | Final five pixels | Span | Final stopped gap | Physical | Final image | Both |
|---|---|---:|---:|---|---|---|
|stock|23/25/27/23/23|4px|14.106308cm|fail|fail|fail|
|K16|22/24/21/22/21|3px|13.850644cm|pass|fail|fail|

[Exact summaries](summary.json), [original runtime/PNG/source hashes](copy-manifest.json).
Native stock19.356s and K16 19.051s both exit0; this means bounded diagnostic completion,
not acceptance. Every motor has actual powered callbacks30/10/12. Last five signed housing-axis
rates remain about0.0040–0.0044rad/s in both runs. K16 does not clearly reduce that rate; one-pixel
span reduction in one run is insufficient evidence of a jitter fix. Stop gap reduction changes
from0.930mm to2.018mm. The candidate is **not applied** and its causal hypothesis is unproved.

The observer records actual assigned camera transform and later `frame_ready` chassis pose.
In these final five samples, inferred chassis pitch from the assigned camera and callback
matches to floating precision (≤9.4e-10rad). This does not establish every frame/provider/render
stage has identical timing or exclude all timing effects. Seven SHA/tick-matched post-initial
callbacks per run are observed; the initial image precedes observer attachment and is explicitly
unobserved for this pitch/rate sampler. All eight real PNGs in each run are retained.

The original stock wrapper incorrectly asserted eight observer callbacks instead of seven.
Its native run completed normally, but whole wrapper exit1 is retained. A first postprocessing
recovery then had a missing local `case` variable and failed. The failed script before-copy and
original driver are preserved; a postprocessing-only recovery reads original files and matches
callbacks by SHA, without rerunning native or changing original result/PNG/log/receipt. The K16
wrapper uses that corrected binding. This is a tool recovery, not an app fix.

Astra actually viewed six original640×480 PNGs, stock/K16 post3/idle2/idle4.
[Actual findings](provenance/astra-inspection.json), [coordinator-bound hashes](viewed-input-hashes.json).
Visual estimates and exact classifier outputs stay separate; screenshots alone do not prove
physical distance, cause, motion rates, broad reliability or backend identity.

No user text, localization, layout, style, provider, physical solver, camera or package changed.
App import/fullnative/Web/installer are not rerun for this docs/evidence follow-up; r7 gates
remain dated history. Documentation maintenance/10unit/ZIP1 checks accompany this new evidence.
FLOWS/API/ADR0029/CONTROLS/data/storage behavior is unchanged. Existing Opus UI review is preserved.

Next Codex: current r7 actual Run-with-AI/operator end-to-end, and a separately scoped control
or calibration decision supported by evidence. Further uncontrolled gain sweeps are not a fix.
Frozen AI image9/9 versus physical0/9 and r8 deterministic13tick3/3physical/0/3image remain
separate. Mac native, Arch originals/formal task CLI release, human merge and exact-version
publication approval are pending. Claude Fable reviews the bounded docs integration; human merges.
Canonical existing project records/Now/readback/recovery receipts are under
`C:/Users/Hojun/.agents/backups/ssok-completion-20261010/angular-feedback-r9/` outside this commit.
