# Corrected physics in the clean integrated export

The exact committed revision `6470757aba1f34afbc30105bf6c77cb117707264` exports Web and Linux
with `dirty_worktree: false`. Both resource audits and Linux startup pass. All **three actual
Chromium 153.0.8010.12 browser gates pass**: loading/run controls, project/block authoring,
and the bundled learned policy's physical walking and stopping. This is a verified private
release checkpoint, not a public deployment or certification of the unfinished kit controller.

The production single-episode observer and all three test drivers are unchanged from that
commit. The complete 491-file Web payload was reconstructed in an isolated Himmel job from
SHA-256-verified identical files and a new delta, then checked against the local clean export.
There are zero payload hash mismatches. No multi-episode observer patch is present.

| Physical measurement | Result |
|---|---:|
| Walking interval | 720 frames / 12 seconds |
| Forward displacement | 0.429205 m |
| Lateral displacement | 0.029757 m |
| Heading drift | 4.3922 degrees |
| Minimum uprightness | 0.962361 |
| Minimum torso height | 0.128904 m |
| Left/right maximum sole clearance | 0.005670 / 0.012337 m |
| Left/right airborne frames | 150 / 272 |
| Uprightness after 90 released-command frames | 0.999834 |

The actual command starts after the observed 69-frame settle; polling was only a threshold,
not a selected favourable frame. All nineteen physical assertions pass, including immutable
completed measurements, unchanged graph/runtime identities and no engine/browser errors.
The policy's two held-out native falls remain documented in the
[wider validation](../bounded_feedback_2026-09-22/README.md).

Authoring passes actual clipboard paste, IndexedDB persistence, page reload/reopen, explicit
replacement confirmation, shared JSON round-trip, invalid import rejection and a Wait block
edit preserved in the exported code. The learned after-stop view, reopened code, Blocks view
and 1152 × 577 compact workshop screenshots were visually reviewed: controls remain usable,
the robot is fully visible, and the measured stopped robot is upright.

`raw/release.json` and `raw/SHA256SUMS` identify both archives. `raw/web-payload.json` binds every
served file. Exact drivers, layout/export logs, console output, JSON comparisons and screenshots
are retained under `raw/`. Job `20260922-124044-ssok-clean-6470757-browser-60c8f21a` completed
with exit 0 and released resources before retrieval. Source/runtime changes after this checkpoint
require their own release validation; this result does not override another build's failure.

No application wording changed, so language-pack changes were unnecessary.
