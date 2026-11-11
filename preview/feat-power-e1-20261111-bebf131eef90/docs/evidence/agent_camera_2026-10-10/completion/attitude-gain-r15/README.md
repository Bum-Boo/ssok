# Bounded attitude-gain diagnosis r15

2026-10-11T08:53:46+09:00; issue32, runtime source **93d10e49e2e1582a651a9e67e0ef367c6fd98938**. Local developer probes;
no production source change, merge, push or publication. Immutable Godot remains
**fa868ca / 0.3.1-projects-r7**; all426 current manifest entries plus7 additional
operator sources and the r14 ZIP are byte-identical. Original24–38px camera goal
and4–14cm physical bounds remain authoritative. [Exact source](source-identity.json).

| Actual probe | Last5 floor pixels | Span | Final gap | Last image | Physical | Combined |
|---|---|---|---|---|---|---|
| Stock | 23,25,27,23,23 | 4px | 14.106308cm | FAIL | FAIL | FAIL |
| Coefficient32 | 23,25,26,25,26 | 3px | 14.112754cm | PASS | FAIL | FAIL |
| Coefficient64 | 24,25,27,24,23 | 4px | 14.111730cm | FAIL | FAIL | FAIL |

Stock reproduces the previous failure. K32's one-pixel span reduction and last
image pass do not repair the physical criterion; K64 does not preserve that
image improvement. Signed housing/body rates remain similar; no monotonic gain
benefit or causal precision repair is established. Both candidates are rejected
and **unapplied**. Negative16 was neither prepared nor run: its preplanned condition
required no span reduction in both positive probes, which K32 did not satisfy.
[Pre-test hypotheses](provenance/hypotheses.json), [target checks](runtime/k32/target-check.json).

Only a single coefficient changes from the recovered r13 attitude prototype in
each new per-instance controller. Current frame_ready body orientation is latched,
accepted forward invalidates it, and ordinary P8/I16 settling precedes a new latch.
Same graph-wired finite motors,25% duty cap, fixed25% forward,12/240 settling,
camera mount/FOV and independent evaluator. No body pose/velocity assignment,
evaluator feedback, extra actor input or production controller change.

Actual rendered Windows Godot4.7.2 probes use the same wall0.35/30,10,12 actions,
four idle captures30frames apart and132frames after Stop. Powered callbacks are
exactly30/10/12 for both motors. Each run preserves8actual640×480PNGs and7post-initial
SHA/tick-paired samples. Native exits are0/confirmed Stop, taking19.552/18.500/20.991s.
The target-check CLI deliberately returns1 for each unchanged joint-target failure;
native exit0 means the diagnostic ran, not that the goal passed. Both prototypes
also passed actual headless script check-only before native execution.
This is deterministic developer replay, **not** the3layout×3AI study; historical
image9/9 and physical0/9 remain unchanged.

Astra actually viewed6original640×480stills (post-3/idle-4 per variant). Estimated
stock22/23px, K32 22/25px, K64 23/22px, all±2px; central bands unobstructed. Classifier
23/26/23 final and visual23/25/22±2 remain separate evidence. Still estimates do not
prove physical distance, continuous jitter, ticks, cause, runtime or goal success.
[Actual inspection](provenance/astra-inspection.json). Camera pose assignment and
frame_ready callback physics can differ; K32's last assigned/callback pitch delta
is retained in raw samples, not treated as a cause. [All67 raw copies](copy-manifest.json).

The debug fixtures/archived drivers are evidence requiring the documented Windows
checkout/toolchain/private receipt paths, not portable product launchers.24PNGs and
named original bytes are preserved without normalization. No UI/style/localization,
provider/auth/cost/action-contract edit. Existing Opus design review is unchanged.
App import/fullnative/Web/installer/exports and r14 SDK/setup smoke are dated history,
not rerun for these unchanged production bytes. Docs maintain and its10tests apply
to this handoff. Separate12–20px calibration remains an unadopted/unrun proposal.

Next Codex: test an approach that changes the failure mechanism instead of further
unplanned coefficient search, retaining original targets and finite graph motors.
Original precision, fresh-account onboarding, general navigation, native Mac,
powered-off Arch raw/formal task16 CLI release, human merge and exact-version/scope
publication remain incomplete. Fable reviews/rebases the final branch; human merges.
Whole goal remains incomplete.
