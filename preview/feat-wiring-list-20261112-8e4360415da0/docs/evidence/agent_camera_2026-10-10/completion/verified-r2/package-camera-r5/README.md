# Actual packaged Windows camera gate r5

Checkpoint 2026-10-11T04:09:05+09:00. Immutable Windows portable ZIP0.3.1-camera-r2 from app sourcef31f8d5;
exact SHA matches the exported/installed PE and PCK in [package inputs](inputs/package-inputs.json).
No app, layout, style, physics, goal, evaluator, provider or model input change.

The actual exported app starts its default Title. Native Windows input opens **Open my project**,
selects Import/export, pastes a standard ssok-project made from the existing graph-car preset,
and confirms import in the visible dialog. No release scene override, --script or hidden graph
prepopulation. The source-only [layout fixture](driver/layout.gd.txt) produces geometry and
the [project JSON](inputs/project.json); it is not package-runtime verification.

In Lab, actual native input selects AI and clicks Enable. Authenticated loopback observation
returns a real640×480 PNG; hash, dimensions, context and capture/settle ordering are checked.
Native Forward consumes the current frame (configured20ticks); the next observation differs.
An external finite8tick action returns ready and reobserves, then native Stop increments the
generation/disables ownership. Late observe and action reject with agent_disabled/agent_not_ready.

**Final runtime11/0 in32.130seconds**, normal native close and actual exit0, no engine/script
errors, bridge port released; [checks](final-native-focus-retry/checks.json),
[receipt](final-native-focus-retry/run-receipt.json), [Stop](final-native-focus-retry/bridge-stopped.json).
All426fixed application/test/tool inputs,10camera inputs and frozen goal SHA remain unchanged.
Clipboard restoration and original APPDATA/LOCALAPPDATA/token environment restoration completed
in the isolated driver. Actual token stays in process memory/environment and is not recorded.
No provider call or AI goal was performed by this package gate. The previous source-level
AI image9/9 and independent strict physical0/9 stay separate and unchanged.

| Attempt | Actual result | Scope of recovery |
|---|---|---|
|Initial35.099s | Import cancelled; camera gate unrun | Source headless OK anchor810,484 landed in actual Cancel region. Astra actual OK588,498; driver anchor corrected. |
|Corrected31.695s | All four camera/control phases pass; close-code check fails | Windows PowerShell Start-Process exposes null ExitCode without a live retained handle. Minimal uncached/refresh/cached probe gives null/null/0. Actual app exit code in this attempt unproven. |
|Final16.545s | Foreground ownership guard stops input | No bypass; owned app cleaned up. One fresh retry. |
|Focus retry32.130s |11/0, actual native ExitCode0 | Same guard retained; live handle cached, app unchanged. |

[First visual inspection](astra-initial.json), [corrected inspection](astra-corrected-native.json),
[final inspection](astra-final.json): native Astra actually viewed20images across these scopes.
Final six actual inputs show the car/10parts/16connections, AI Ready then Stopped, preview,
disabled Capture/Forward after Stop and three differing sensor views. Visual findings do not
attest physics, billing, process exit or frozen pixel-goal completion.

The initial inspection also observed truncated Projects button labels and low-contrast
confirmation text. Those remain an **Opus design review/fix handoff**, not newly reviewed or
fixed UI. Final helper copies are post-recovery; the first original helper versions were not
snapshotted, so their hashes are not retrospectively certified. All original attempt outputs
and source-layout anchors are retained, excluding isolated userdata and portable binaries.

Next coordinator: verify packaged **Run with AI→foreground operator** through actual UI as
a separate bounded contract; this gate covers manual/bridge control only. Keep strictphysical0/9,
native Mac, Arch original raw/task CLI release, human merge and exact-version publication
approval open. Claude Opus owns any dialog design draft; Fable owns actual feature rebase.
No main merge, push, publication, automatic retry, background service or schedule.
