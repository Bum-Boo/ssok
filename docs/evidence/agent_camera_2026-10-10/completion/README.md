# Camera precision and stabilization — reviewed local draft

Current checkpoint,2026-10-11: [r25 host access/Arch raw recovery](host-raw-r25/README.md), source66188b3.
MacSSH ready/sharedlab restriction; latest57snapshot metadata, final5folders absent in12c49368.
Owned-Mac exactartifact handoff ready, nativeMac app unrun; Arch connection timeout beforeauth.
[r24 task CLI recovery](task-tool-r24/README.md): official release19 verified in coordinator/native receipt.
Original tool/stdlib source restored;20 tests/DrvFS cloned lifecycle/Windows+WSL entry verified.
Canonicaltask officially resumed/checkpointed16→18; finalrelease separately recorded after exact review.
[r23 geometry diagnosis](projection-r23/README.md):9 archivedposes within0.968px; original image/distance criteria unchanged.
[Actual r21 AI](adaptive-ai-r21/README.md)31px/14.5838cm jointFAIL; [r22 candidate](brake-integral-r22/README.md)22px/13.9092cm jointFAIL/unapplied.
Appfa868ca/[r7 verification](release-current-ui-r7/README.md) and [r14 operator](operator-setup-r14/README.md) unchanged/dated verification.
Historical3layouts×3AI image9/9 physical0/9 unchanged;12–20 calibration proposal unadopted/unrun.
Originalprecision/userchoice/freshaccount/nativeMac/latestArchraw/humanmerge/publication open.

## Dated r2 checkpoint

[Verified r2 and preserved failures](verified-r2/README.md).
Windows full81/0 on the current Title draft, four-language actual captures/Astra and independent Opus review pass.
Frozen camera image9/9 remains separate from physical0/9. Blind controls and actual operator are retained.
Latest actual Fable functional review/rebase PASS; clean4exports, same Web5/5 and Windows installer17/0 pass.
Package app source f31f8d5/version0.3.1-camera-r2; final runtime evidence is a separate docs-only follow-up.
Native Mac/Arch raw/task release, physical0/9, human merge and exact-version publication approval remain open.

The following sections are dated history, with their original pending/failure statements preserved.

Checkpoint 2026-10-11T00:14:29+09:00; issue32, existing task robot-camera-loop-20261010/session ssok-stabilize-20261010-1.
Original branch feat/32-robot-camera-loop/base4eb059f. This is ongoing work, not full goal/release completion.

The independent Astra correction in precision-baseline.json supports the penultimate43px estimate.
Developer-only replay separated actions from waiting: 5seconds without action moved the ready body
about8mm and near the wall reduced the image strip11px. Rendered rest regression failed before:
15.3058mm drift over10seconds,6checks/1failure. A bounded wheel-speed PI hold through the existing
graph motors plus stricter capture settling now gives1.1753mm,6/0. No DriveMotor/torque/scene/body
pose/velocity overrides or physics pause. Earlier P8/I4 and loose-threshold P8/I16 failures are retained.
Holding applies only under enabled agent ownership; after Stop, ordinary passive braking resumes.

Goal SHA d372505d199ce2e2ba4b12588487cafe9e722465b65171ca25fcbf8496f632a4 unchanged;
24–38px image goal and original .03m travel/.04–.14m gap/no-contact/rest criteria remain independent.
First low-effort PI pilot: physical0/3; image1/3(38,45,45px), no contact. These failures remain;
the Windows summary reader additionally failed with cp949 decoding of UTF8 public summaries.
The three trial results are complete; recovered-receipt.json is separately labeled offline readback.
The reader now specifies UTF8. A new medium-effort/pixel-coordinate/action-budget pilot is running
in a fresh build folder; its results are not yet claimed. No hidden evaluator data reaches the actor.

Claude Fable actual resolved claude-fable-5-1 reviewed the eight hashed holding/verifier inputs:
source verdict pass, no blockers; optional robustness findings/limits preserved in result.json.
This is source review, not actual branch integration or runtime/image validation.
Panel SHA f8afbc47a236e33d7f0f919bfc2b0693e80628af7c863b91450db57c11d54da5 unchanged;
existing independent Opus design review applies only to that panel. No exported UI/locale changes.

Full CI now requires rendered camera/goal/owner/rest checks instead of headless-only partial paths.
Windows timeout reproduction failed with os.killpg AttributeError and leaked child; owned tree
cleanup/APPDATA isolation and portable log names fixed. Three runner unit tests pass.
Complete native suite, fixed3×3 model trials/blind controls, four exports, browser/native package,
actual Fable rebase/human merge/reviewed-version publication are pending at this checkpoint.

Toolchain: local build/toolchain-linux official Godot4.7.2 editor/templates digest checked by existing
installer; isolated Python3.14.7 and all39locked packages. Existing uv0.12.13 used explicitly.
WSL Ubuntu chromium-dependency install completed; pinned Playwright1.63 Chromium153.0.8010.12
launch observed after missing libnspr4 reproduction. Build/venvs are ignored, no global PATH changes.
The WSL dependency installer installed/upgraded its standard Chromium/Xvfb/Mesa packages.
Browser skill is used with the repository's existing five acceptance scripts; no new browser suite.

Raw Arch recovery/task CLI release remain pending while freiren is powered off. Do not manually
edit generated state/Handoff. Exact recovery paths remain in ../stabilization/README.md.
Next: finish precision/full verification/packages, latest Fable actual branch rebase, human merge
and explicit approval of reviewed version/scope before publishing. macOS runtime requires a Mac.
Backup/selected recovery: C:/Users/Hojun/.agents/backups/ssok-completion-20261010.
Restore only matched post-hash files; preserve later/other writers and historical failed evidence.

## Later checkpoint ? 2026-10-11, same active task

The medium-effort pilot completed: exact image goal3/3 (32,37,37px), independently viewed by
native Astra; independent physical criteria0/3 (14.41,14.91,15.11cm), no contact/transport errors.
The unchanged image interval and4..14cm physical interval are reported independently; no threshold
is relaxed and neither is substituted for the other. A fresh3x3 study with the same10input hashes
and original goal is running; do not pool pilot and final results.

Fable5-1 also passed the six-source actor/UTF8/owner/budget follow-up. Its optional limitations,
including CLI child cleanup on an outer subprocess timeout and a no-op goal's strict failure label,
remain explicit. See fable-actor-dispatch.json/result.json and astra-pilot-inspection.json.

The first WSL full gate completed4checks/1failure and was aborted during the rest check.
Actual shared localhost8127 collision with Windows live trials and missing ALSA hardware output
caused engine errors. A software-rendering watchdog overrun is a hypothesis, not an attested cause.
Only the identified owned runner/child were stopped; partial failed evidence remains in
full-verification-aborted/. Full native Windows gate will run sequentially after the live trials.
Dummy audio now separates functional/rendering checks from unavailable hardware audio.

Actual offline package regression found10brokenlinks from the new handoff and4runtime/UI source
files missing in copy_notices. Adding those5files to documentation payload produced an actual
ZIP/extraction pass1/0. This changes packaging only, not application pack inclusion; before/after
logs and build source SHA are in release-documents-before/ and release-documents-after/.

Native Windows CPython3.14.7 and the locked project dependencies are now isolated in
build/venv-native (40resolved packages including Windows-only pywin32); WSL has39. No global
Python/PATH setting was changed. Full verification,4exports/5browser/native installer and actual
Fable branch integration remain pending. The canonical Wiki and project state are checkpointed;
Now refresh/check4085bytes and Wiki policy get allowed/full readback succeeded.

## Fixed3x3 study completed before integration

Same frozen clarified goal and10input hashes: actual live9/9 completed transport/reobserve/Stop,
zero transport errors or contacts. Developer pixel measurement and native Astra's actual9PNG
inspection agree: nominal image9/9, center strips27,32,24,36,37,35,37,37,37px.
The24px result is at the lower edge with?1px uncertainty; do not claim every result has an interior
margin. Independent physical criteria0/9 (14.13?15.00cm vs maximum14cm) remain failures.
No hidden physical hint or criterion change was made. See clarified-hold-medium-final/ receipts;
pilot and final are distinct studies. Blind controls/full release verification remain pending.
