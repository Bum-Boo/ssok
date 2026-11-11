# Observation continuity hypothesis r4 — rejected as a repair

Checkpoint 2026-10-11T03:41:44+09:00; unchanged application/package sourcef31f8d5, source HEAD2f7bd23.
Two native Godot4.7.2/GL/GodotPhysics3D developer fixtures use the actual graph car,
camera640×480, existing bounded motor tape30/10/12/1, four repeated idle observations,
then actual Stop. No model/provider call, actor hint or production source change.

The single variable is the ready-to-observe transition. Stock calls stop_motors once
before re-settling; a per-instance subclass preserves the existing holding command
only for that transition. Forward/brake actions, PI gains/duty limits, motor torque,
body/scene/camera transforms, rest/timeout/context/Stop and evaluator are unchanged.

| Actual developer case | Final five strip sizes | Span | Capture-time gap range | Final Stop gap | Full physical | Final image | Combined |
|---|---|---:|---:|---:|---|---|---|
|Stock,19.924s |24,23,24,25,22px |3px |0.7191mm |14.0208cm |fail |fail |fail |
|No pulse,19.734s |22,22,23,25,22px |3px |0.6898mm |13.9988cm |pass |fail |fail |

[Stock summary](stock/summary.json), [variant summary](no-pulse/summary.json),
[comparison/limits](comparison.json). The variant changes the observable request-time
duties as intended: stock resets both to zero, variant retains the previous small
holding duties. This does not prove that a physics step applies zero motor force.
Both retain3px variation and fail the joint final predicate. **Do not apply this
prototype to production.** One pair of fixtures does not exclude all contributions
from this transition, network timing or solver dynamics, nor prove global incompatibility.

Native Astra actually opened stock and variant idle-3/idle-4, all original640×480:
25±1px then22±1px in each case; center x312–328 is unobscured.
[Four-image inspection](astra-inspection.json) is visual evidence, not physics or
causal attestation. The other automated pixel measurements use the fixed fixture
classifier; no certification for changed materials, lighting or occlusion.

For each PNG, [stock measured frames](stock/measured.json) and
[variant measured frames](no-pulse/measured.json) pair the original evaluator's
frame_ready callback by PNG SHA and actual physics tick. The prototype's raw
result sampled capture_physics later when its coroutine returned. That later
sample is retained as post_return_physics and is not used for the aligned gap
comparison. First post-return gap-span1.3267mm is retained in
[initial derivation](stock/post-return-summary.json); aligned actual callback
samples give0.7191mm. Raw result/log/receipts and original PNGs are preserved.

The [launcher](developer-prototype/launcher.py) has explicit90second subprocess
bounds and owns only its launched process tree on timeout; neither case timed out.
[SceneTree probe](developer-prototype/probe.gd.txt) and
[single-variable subclass](developer-prototype/no_pulse_loop.gd.txt) are marked
DEBUG-r4 developer prototypes, never actor tools or an applied controller repair.
Their .txt copies preserve exact source bytes while avoiding incidental script import.
Original build prototypes are retained in their clearly marked diagnostic directory.

426 app/test/tool/core inputs,10 camera-study inputs and the frozen goal SHA
remain identical. The baseline's first plan predates fixture-hash fields; the
variant plan binds both unchanged prototype files. Original scene/goal/physics
were not changed to obtain the variant's physical-only nominal boundary pass.
This is separate from the frozen AI3×3 **image9/9, physical0/9**; no new AI trial
or improved model reliability is claimed. Immutable r2 packages and their
source-specific native81/0/Web5/5/Windows17/0 receipts remain as before.

Next owner: coordinator retains the negative candidate and isolates any actual
defect before further controller changes. Latest Fable rebases this docs-only
follow-up, then human review/merge. Exact r2 publication approval remains pending;
native Mac interaction and powered-off Arch raw/task CLI recovery remain open.
Generated task revision16 is untouched; recovery uses its own CLI after owner/lease
inspection. No user strings/localization, design or graph/VM diagram changes.
No app CI/export/browser/installer rerun for this evidence-only follow-up.

[Copy manifest](copy-manifest.json) has explicit top-level outputs only, no isolated
userdata/config/private provider transcript. [Parent review](../README.md) and
[earlier boundary diagnostic](../physical-compatibility-r3/README.md) retain failures.
Canonical record: existing joint-development report/project state/plan; selected
recovery in C:/Users/Hojun/.agents/backups/ssok-completion-20261010/observation-continuity-r4.
