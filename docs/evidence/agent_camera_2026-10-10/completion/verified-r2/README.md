# Stabilization r2 — reviewed local draft

Final runtime checkpoint 2026-10-11T02:45:08+09:00. App/package source **f31f8d5ea7b6b3eaa48df9e6d50f60621eb3dfa4**;
version **0.3.1-camera-r2**, feature `feat/32-robot-camera-loop`, existing issue32/task/session.
This follow-up changes documentation/evidence only. No main merge, push or publication.

| Acceptance check | Actual result | Evidence |
|---|---|---|
| Windows full native |81programs/0failures;426input hashes unchanged, import/load/localization included |[summary](full-native-final-r2/SUMMARY.md) |
| Clean exports |Web/Linux/Windows/macOS,6artifacts; dirty=false/source_changed=false; resource audits and actual Linux startup pass |[release](final-build/release.json), [checksums](final-build/SHA256SUMS), [byte readback](final-build/artifact-readback-final-r2.json) |
| Same clean Web payload |5/5 existing smoke/authoring/physics/learning/settings gates; source/payload unchanged |[receipt](browser-final-clean-r2/receipt.json) |
| Same Windows installer |17/0, actual default Title/map/3Stage programs and persistent clears, normal close/logclean, install/registration/shortcut/uninstall, extra-user-file preservation |[receipt](native-installer-final-clean-r2/receipt.json), [checks](native-installer-final-clean-r2/checks.json) |
| Title Settings fix |80geometry/16GUI keyboard cases, Astra16after images and independent Opus5-5 review PASS; live existing picker4/0 at200% compact size preserves same Title and focus |[runtime](title-clip-after-r2/geometry.json), [live language](title-live-language-r2/result.json), [Opus](opus-title-clip-independent-review/result.json) |
| Final packaged images |Astra actually viewed10native/Web frames; displayed labels/map/success/Stop fit within bounded scope |[findings](astra-final-package-r2.json), [image identity](astra-final-image-hashes.json) |
| Functional review and actual integration |Latest actual Fable5-1 PASS/no blockers; actual separate fetch/rebase on f31, up-to-date no-op against4eb059f; cherry3feature commits |[review](fable-integration-final-r2/result.json), [actual Git proof](fable-integration-final-r2/coordinator-proof.json) |

The camera's frozen3×3 study remains **image9/9, independent physical0/9**. Actual gap14.1289..14.9976cm
exceeds unchanged14cm maximum. No criterion, robot pose, finite torque, evaluator or model distance input
was changed to turn this into success. Blank/frozen strict failures and all original red gates remain below.
Tool/time bounds do not prove model identity, empty context, billing/request caps or universal navigation.

The native gate measured installed PE/PCK hashes matching export bytes. Builder windows-binary.json still
says native_runtime_verified=false because it predates this separate runtime receipt; original metadata is
unchanged. Mac structure/two architectures/ad-hoc seals pass; **native Mac interaction is unrun**. Linux
startup is actual headless verification, not native graphics. Existing Web gates use the workshop query
entry; default Title/map routing is verified by native Windows, not separately claimed as a default Web gate.
The ten-image review does not itself attest physics, persistence, process shutdown, clipboard or downloads.

Local artifacts: `build/camera-release-clean-r2/ssok-0.3.1-camera-r2-windows-x86_64-setup.exe` and the other
five files named in release.json. Installer SHA256 ebfde14e4b6b23e539bf08acb253dc9cfb3781e24ad4db441ed58c7fc55f4f06.
The immutable packages contain the documentation available at build source f31; later final runtime results
live in this documentation-only follow-up. Do not rewrite historical package metadata or imply public release.

Next owner: latest Fable performs actual rebase of the final documentation commit, then human review/merge.
Publication still requires the user's exact reviewed-version/scope approval. Physical calibration, native Mac,
and powered-off Arch raw recovery/formal task CLI release remain open. After Arch returns, first run
`/home/bumboo/.local/bin/agent-task show ssok robot-camera-loop-20261010` and `release --help`; check
owner/lease before checkpoint/release. Never edit generated state/Handoff or take another live owner's task.
Exact raw recovery folders are in [the existing stabilization manifest](../../stabilization/arch-uncollected-observations.json).
On an owned Mac, verify archive SHA6be170ac8ffe5970a907f98367b5a39b238a63f71e25cc9bf0bdd46ca5de53f9,
then default Title/map/three stages, preferences/focus and normal close/logs. No private source is sent to a shared lab Mac.
Records/selected recovery: `C:/Users/Hojun/.agents/backups/ssok-completion-20261010/RECOVERY.md`.
No user-facing strings/catalog changes were needed in this final documentation pass.

## Subsequent developer-only boundary diagnosis r3

[Actual probes and handoff](physical-compatibility-r3/README.md) reproduce26px/14.0431cm combined
failure; one extra tick passes distance but yields22px. Repeated observations show22↔24px with
sub-mm capture gap changes. No causal/global incompatibility claim, source or criterion changes.
AI image9/9·physical0/9 and immutable r2 package receipts remain unchanged.

## Historical checkpoint before final clean build — 2026-10-11T02:01:20+09:00

# Stabilization verification r2 — local draft

Checkpoint 2026-10-11T02:01:20+09:00 · issue32 / existing task robot-camera-loop-20261010 / feature feat/32-robot-camera-loop.
Source before local commit: HEAD8100cb3 plus the owned changes, fixed Title SHA
5f81349019953ebb8d96075ad6f056bef1e5e56ed74633efffaba761dda8c8c1.
No main merge, push or publication. This preparation is not a native Mac or navigation certification.

The camera sees actual rendered640×480 robot frames, takes bounded actions, reobserves and Stops.
The final frozen3×3 study remains **image9/9, independent physical0/9**: strips27,32,24,36,37,35,37,37,37px
(one24px boundary ±1), actual gap14.1289..14.9976cm against unchanged maximum14cm. All10 study
inputs and original goal hashes still match ([manifest](unchanged-camera-inputs.json)); no hidden
physical hint, pose/velocity overwrite or evaluator change was introduced. The studies are separate,
not pooled with older pilots. Holding reduced measured idle drift15.3058→1.1753mm/10s through
existing finite-torque graph motors; Stop releases holding and ordinary braking may creep.

## Actual current checks

| Check | Observed result | Evidence |
|---|---|---|
| Native Windows full CI after Title fix |81programs/0failures, source426hashes unchanged; one explicitly skipped POSIX-only case |[summary](full-native-final-r2/SUMMARY.md), [prelaunch sources](full-native-final-r2/source-before.json), [readback](full-native-final-r2/source-after.json) |
| Actual Linux POSIX package permission check |3tests/0failures on POSIX; not native Mac |[log](posix-package-final/unittest.log) |
| Preference process isolation |Rendered goal67/0, camera30/0 then authoring32/0/tutorial576/0/viewport62660/0; pre-existing preference bytes also preserved exactly |[chain](prefs-after-chain/receipt.json), [existing-file case](prefs-after-existing/receipt.json) |
| Native HTTP oversized requests |Original100trials/15connection errors → fixed100/0; current service16/races8 all pass, including header-only huge Content-Length |[before](http-repeat-before/receipt.json), [after](http-repeat-after/receipt.json), [service](full-native-final-r2/tools-motion_lab-test_service.py.log) |
| Browser learning gate on first Web bytes with current anchors |Actual3challenge passes, real JSON download/native clipboard/infinite-loop Stop; full tracked-source gate87.365s pass |[receipt](browser-learning-source-fixed/receipt.json) |
| Preliminary installed Windows app |Default title→map→actual entered reference programs→3clears/normal close/logclean; overall installer gate failed later from stage-map.png counted as fourth stage PNG |[checks](native-installer-preliminary/checks.json), [receipt](native-installer-preliminary/receipt.json) |
| Title Settings text fix |80geometry cases/0failures,16actual GUI keyboard cases and Astra16after PNGs pass; independent actual Opus5-5 source review pass/no blockers |[runtime](title-clip-after-r2/geometry.json), [Astra](title-clip-after-r2/astra-inspection.json), [Opus](opus-title-clip-independent-review/result.json) |

The original full native run81/5 remains in [its summary](full-native-8100cb3/SUMMARY.md).
Rendered goal screenshots had persisted scale200%, contaminating subsequent authoring/tutorial/framing
processes. Both camera/goal fixtures now restore original bytes or remove only their newly-created preference
file. Full native81/0 before the Title patch is separately preserved in [fixture-only summary](full-native-fixture-fixed/SUMMARY.md).
The first red-chain goal had4engine errors because the extra developer launcher omitted its synthetic token;
that fixture error is distinct from the observed downstream scale leak. The corrected chain uses a scoped
synthetic token. Header-only HTTP's first new fixture also used an unsupported HTTPConnection context manager;
closing() corrected that fixture before current native/WSL24tests passed.

Browser Stage coordinates became stale when the code tab auto-scrolled the program bar. Actual scroll-arrow
clicks and captured tab indices fix the existing test driver, with no production tab redesign. The first5gates
were4/5 ([receipt](browser-gates-3e75cea/receipt.json)); the failed keyboard workaround entered the editor
instead of focusing tabs ([retained failure](browser-keyboard-before-fix/receipt.json)). The actual scroll
probe and tracked learning gate passed. Final clean Web bytes will receive all5gates again.

Native release templates actually rejected the attempted scene-path override; the revised native test now
uses the real title/map/router and fresh progress instead of a scene bypass or fake evaluator. Preliminary
uninstall cleanup succeeded, but the extra-user-file late check was not reached. Renaming its map capture
resolves the count collision; the final exact installer still needs the complete install/uninstall gate.

## Camera blind controls and operator

[blank3](clarified-hold-medium-blank/summary.json):0actions/1observation each; CLIexit0 and real Stop,
no assessable delivered pixels. [frozen3](clarified-hold-medium-frozen/summary.json):1action/2observations
each; CLIexit0/Stop, identical delivered PNGs while actual frames changed. Each strict trial runner still
reports failure because physical criteria are0/3; that is expected negative evidence, not a hidden success.
[Astra actually inspected14blank/frozen/operator PNGs](astra-blind-operator-inspection.json).
[Operator app Run](operator-final-3e75cea/ui-click.json): actual foreground job, one3tick action,
two rendered observations, final reobserve/Stop/CLIexit0; its one-step goal is separate from the wall goal.
Raw provider CLI events, auth/config and isolated user data are excluded from the copied public evidence.
Tool/action/image/time limits do not attest a monetary/model-request cap, backend identity or empty actor context.

## Reviews, history and next owner

[Fable5-1 actual earlier fetch/rebase](fable-integration/coordinator-proof.json) was an up-to-date no-op on
3e75cea, upstream4eb059f; git cherry showed the feature commit. Source-only reviews are separate from
actual integration. The later identity commit8100cb3 and current fixes still require latest Fable review/rebase.
The [first4export metadata](first-export-dirty/release.json) remains dirty/source_changed=true because the
builder generated tracked stage identity. The75identity entries were verified and committed, not rewritten
in the old release.json. Final clean4exports0.3.1-camera-r2, all5browser gates and full native installer checks
are next. Existing camera panel f8afbc47…54da5 retains its prior independent Opus review; Title is separately
reviewed and uses exactly two existing Button properties. No user text/catalog change.

Title captures cover four languages, both themes,1400×950 and1152×648 with scale100/200%, plus geometry
at115/130/150%. At200% the title scrolls; Japanese project action is ellipsized outside this Settings fix.
No mobile/320px/all-sizes guarantee, screen-reader or native hardware-audio certification.
First Title capture fixture's early static TitleScreen dependency compiled before Preferences autoload;
that raw failure remains in title-clip-after. Dynamic runtime loading in fresh-r2 resolved it without another
production edit. A failed ASCII stdin plan-record attempt was recovered with explicit UTF8 before record write.

Next owner: coordinator finishes clean draft exports and actual final gates → latest Fable rebase → human
merge and exact-version/scope publication approval. Powered-off Arch raw recovery/generated task rev16 CLI
release and native Mac interaction remain incomplete, with recovery in the existing stabilization handoff.
Never hand-edit generated task state, overwrite another owner or silently remove historical failures.
