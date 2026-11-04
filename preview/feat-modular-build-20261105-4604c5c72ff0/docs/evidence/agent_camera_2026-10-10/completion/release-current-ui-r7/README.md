# Current reviewed UI: clean release candidate r7

Checkpoint 2026-10-11T06:08:03+09:00. Clean immutable application source `fa868ca07cdd9d2b8edb27cbab89cd00263c851f`, Godot4.7.2,
version **0.3.1-projects-r7**. Four exports and all six artifact hashes verified against
[release metadata](build/release.json), [actual hash readback](artifact-readback.json).
No merge or publication. Packages remain local in `build/projects-release-clean-r7/`.
This documentation/evidence follow-up is later than the immutable package: packaged docs are
the snapshot at fa868ca, not these newly written records. No package rebuild is implied.

Windows source verification initially ran **81 checks / 2 failures**: two child Python suites
used cp949 instead of UTF8. Per-process inherited `PYTHONUTF8=1`, without global settings or
source/test changes, recovered just those **2 / 0**. Final coverage is the original79 passes
plus2 recovery passes, **81 resolved / 0**, not another single81/0 invocation.
[Original full receipt](runtime/native-full-receipt.json),
[focused recovery](runtime/native-encoding-recovery-receipt.json),
[final composite](runtime/native-gate-final.json); every original suite log/result remains.
Godot import/load and rendered camera/goal/scoped Stop regressions actually ran. Transport
uses its test mock; no live AI provider call occurred in these deterministic gates.

The same clean exported Web bytes passed all five real Chromium gates: startup, authoring,
physics, learning and settings. Authoring9checks and settings14checks include actual clipboard,
IndexedDB/reload, download comparison, confirmation, graph/source and progress checks.
[Five actual commands/results](runtime/browser/receipt.json). Corrected CI layout fixture506…d0d5
also passed the original Linux build bound and produced64 anchors/OK782,504. Two optional
short probes (40s/15s) expired during initialization; the40s wrapper captured no raw console
or receipt, while the15s instrumented ignored copy retains its [timeout](runtime/ci-layout-trace-2/receipt.json)
and console. They do not establish an application hang or a repaired source regression.
Approximate170.932s from import-log to layout-log modification time is not an independent
command stopwatch. Canonical fixture and app were not instrumented or changed.

The first actual Windows install gate failed **10checks / 1**, wall-brake after two successes;
Godot logged `Unable to open clipboard`. A Web clipboard job was concurrently active, but
that correlation does not prove causality. Original [failed receipt](runtime/windows-installer/receipt.json),
stderr, progress and uninstall snapshot remain unchanged. Initial registration readback still
showed entries while asynchronous uninstall was finishing; later actual readback and final
serial verification show both true installer keys absent. An older r6 location-only cleanup
checked `HKCU\Software\ssok` incorrectly; the actual key is `HKCU\Software\Bum-Boo\ssok`.

A wall-only diagnostic verified the program by actual app Ctrl+C after a clipboard sentinel,
then actually cleared the5–10cm stage at7.2cm. Both assertions passed, but its reduced fixture
incorrectly iterated beyond its one stage: **whole run exit1**, retained as a failed diagnostic,
not full acceptance. [Actual code/readback/stage and original exit](runtime/native-wall-clipboard-probe/receipt.json).
The future outside-repo wrapper was corrected to iterate the reduced list length; no app/source
change, overwrite of the failed receipt or diagnostic rerun occurred.

After all Web clipboard jobs ended, a fresh output path ran the unchanged canonical Windows
installer verifier with the identical setup bytes, layout and thresholds. **17 / 0,48.980s**,
all three stages, actual installed PE/PCK equal to export, per-user registration/shortcut,
uninstall and preservation of a synthetic user-added file passed.
[Serial receipt](runtime/windows-installer-serial/receipt.json),
[actual checks](runtime/windows-installer-serial/checks.json).
First failure cause remains unproved. Future clipboard UI jobs are serialized.

The actual current portable Windows package was opened from default Title; real paste/Import,
Escape cancellation, second Import/OK and actual Copy JSON passed **6 / 0,18.967s**.
Exported graph, source, format and version exactly equal the imported synthetic fixture.
[Package receipt](runtime/package-projects/receipt.json),
[strict comparison](runtime/package-projects/export-comparison.json).
Native source geometry is labeled as geometry only; actual Windows package input is separate.
No learner code or provider execution was triggered by this project transfer.

Astra actually viewed17 current PNGs, including five installed title/map/stage images and
six packaged Projects/cancel/import/reexport images. No material clipping or overlap;
warnings and primary controls readable. [Final11-image inspection](reviews/astra-packaged-final.json),
[Web plus wall diagnostic6-image inspection](reviews/astra-web-native-diagnostic.json),
[coordinator image hashes](reviews/viewed-input-hashes.json). Minor pre-existing underscore
tab separator, ellipsized library label and partial scroll rows remain. Still images do not
independently attest input, physics, storage equality, numerical contrast or backend identity.

Current ProjectPanel rawSHA877886…e038 is unchanged from Opus5-5 authored/revised and
independently PASS-reviewed [r6 design](../package-goal-ui-r6/reviews/opus-final-verdict.json).
Its80 native cases/1181checks/128images, real OS25checks and four-language/both-theme coverage
are dated r6 source proof, not new r7 executions. Out of the previous frozen426 input set,
only one application UI file and the PCK-excluded CI fixture differ; all current426 are
unchanged across r7 gates. Camera10, frozen goal, motors, physics and evaluator are unchanged.
No user strings or catalogs changed. FLOWS/DATA_MODEL/AUTHORING contracts remain reviewed as
in r6; this follow-up changes only documentation/evidence and Windows encoding guidance.

The r6 actual external-operator Run with AI12/0 used older immutable r2/f31 package bytes.
It is not an end-to-end AI invocation on this r7 PCK. Unchanged camera/controller inputs
support source continuity only. Account onboarding/operator packaging, billing/backend
attestation, broad robot navigation and catalog-camera serialization remain open.
Frozen nominal image9/9 and strict physical14cm **0/9** remain unchanged historical results;
the successful wall stage's5–10cm criterion is a different task.

Native Mac execution and native Linux GUI are untested; Linux exported startup/resources and
Mac cross-export/archive checks passed, which are narrower claims. Powered-off Arch originals
and generated revision16 official task CLI release, human merge and exact reviewed
version/scope publication approval remain pending. Fable owns actual feature rebase; the
human merges. The global ssok objective remains incomplete.

All [raw source/output copies](copy-manifest.json) have exact SHA256; binaries, isolated user
data, original clipboard, private model briefs/login state are excluded. Three specified
sensitive-shape patterns are checked separately, not a universal privacy certificate.
[Cleanup](provenance/runtime-cleanup.json) checks the actual two registry keys, shortcut,
owned project processes and port8127, without killing unrelated processes.
Final integration, canonical Wiki/Now readback, validator and recovery bundle receipts live
outside this immutable package/evidence commit under the existing completion backup/r7 folder.
