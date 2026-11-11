# App goal button — local desktop draft, 2026-10-10

The AI tab now accepts a raw goal and one deliberate Run click for an explicitly started foreground
operator. The operator uses the existing Codex ChatGPT login and requests Astra; the app itself
does not launch/log into a provider. One queued goal, one claim, one CLI launch,8actions/9images/
300seconds; Enter does not dispatch. Stop is always local. Restart the operator for another job.

Claude Opus5-5 authored the layout and four-language strings. Existing theme/colors/type and4:3
camera are preserved. Provider, data and usage/limits precede the full-width Run button. Stop is
pinned outside scrolling content. Current panel SHA:
`f8afbc47a236e33d7f0f919bfc2b0693e80628af7c863b91450db57c11d54da5`.

## Actual observations and earlier failures

- First operator smoke failed before any provider dispatch because the default Python client
  rejected operator endpoints. Explicit operator capability fixed it; actor/default client remains
  unable to invoke poll/leave and its MCP list is only observe/decide/stop.
- R2 actual test-simulated app-button click connected to a real foreground operator/actor,
  produced1action/2camera images, final reobservation/Stop and CLIexit0. This verifies connectivity,
  not navigation success. R3 repeated the actual smoke after context binding:1action/2PNGs,
  final reobservation/Stop, CLIexit0 and exact queued/preserved-goal click receipt passed.
- Initial localization check failed1/52490 because the test initialized a job without rendering
  its history before choosing its already-current English locale. The fixture now renders history
  explicitly; fresh52490checks0failures. No unrelated motion-lab UI code was changed.
- Astra opened R1/R2 actual24screens each. Full-width Run/disclosure order improved; English200%
  manual buttons still clipped. Claude's R3 patch disabled both clipping and text trimming and
  Astra saw full Enable/Capture with Forward wrapping to its own row.40R3screens were directly viewed.
- R3/R4 English large scrolled captures hid Run. Actual widget rects exposed a fixture error:
  both follow-focus and a second immediate ensure-visible call used pending layout coordinates,
  scrolling past the button. R4's new visibility assertion failed2/66. The fixture now uses actual
  keyboard focus with follow-focus only. R5 passed66checks including all24focused Run viewport bounds.

Before/after captures remain under `after`, `after-r2`, `after-r3` and later revisions; they are
UI fixtures, not screenshots proving actor cognition. Compact1152×648, wide1600×1000, large
1600×1000 at200%;4languages×2themes, paired initial/keyboard-focused scrolled states.
The goal is preserved across languages; glyphs/clipping and actual Stop are inspected by Astra.

## Functional review and scope

Latest Claude Fable5-1 found a real stale-goal gap between parent claim checking and the child's
first observation. Claimed episode/revision/generation now flows parent→child preflight→MCP session,
checks both first describe/frame and later observations, and monitor cancels changed running context.
The inbox also explicitly clears on stopped/fault; actual loop Stop already disabled/incremented
generation.49Python regressions pass on actual Arch with MCP2.2.0, and on Windows with2optional SDK
cases skipped. Latest independent Fable5-1 source review **pass**, B1/B2 resolved; it did not rerun tests.
Four new cases cover changed first context, changed
first frame, normal bound action/reobserve and absent operator capabilities.

Actual latest import/load and localization52490/0 passed; the earlier unchanged camera29/0 is retained.
Final independent Opus5-5 design-source review **pass**, no blocking findings, exact panel SHA above.
Astra directly viewed40R3images and2R5English-large scrolled images, resolving the missing Run label/focus
evidence. Full R5capture set is48files; Astra did not view all48R5or the full CJK200% middle disclosure
between static captures. Opus read source and Astra observations, not the images or runtime.
Actual findings: [Astra](reviews/astra-actual-final.json), [Opus](reviews/opus-final-independent.json),
[Fable](reviews/fable-integration-r2.json), [capture hashes](capture-sha256.json).
This remains an uncommitted local draft, not main/public release. Claimed operator connection can
persist up to310seconds after a crash. Goal argv is visible locally; Windows forced termination may
omit a result file while the parent attempts app Stop. No packaged account onboarding/service/Web AI.

Fable nonblocking limits: conservative final Stop may interrupt a user-created newer episode;
60second camera decision watchdog includes CLI startup; all local holders of the same token can
open independent camera clients (single-use frames prevent duplicate frame actions, not two-client
alternation). Detached-loop teardown without bridge state signal can retain an inbox until deadline.
These remain explicit desktop draft limits; no claim of per-client session exclusivity or navigation reliability.

Source-specific results, capture hashes and actual model findings are retained beside this note.
Review/publish handoff: [CLAUDE-REVIEW](../../../../CLAUDE-REVIEW.md).
Independent physical results: [repeated trials](../repeated/README.md).
