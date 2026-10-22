# Operator local preparation r14

2026-10-11T08:42:36+09:00; issue32, local draft. Operator **0.2.0-operator-r14**, clean source
**f2342f8890422b76f64c6f1a842140bc7c1f64c1**, ZIP SHA256 `734e273ed58f0a15ba6cc5ee2466f1c899912179e6d6ada5385a2c36c5ec7625`.
Godot remains **fa868ca / 0.3.1-projects-r7** with the same checked PE/PCK.

The earlier launcher failed on the actual default Python3.13.3 because MCP was
missing, before model/app launch. The new explicit `setup-operator.ps1` creates
an archive-local `.operator-venv`, installs pinned MCP2.2.0 and checks dependencies.
`start-operator.ps1 -CheckOnly` checks source identity, Python/MCP, Codex and the
existing supported ChatGPT login status. It never signs in or launches a model.
The foreground launcher selects the local environment automatically.
The actual ZIP was extracted outside Git to a Korean/spaces path; setup used the
default Python from another cwd. Preparation changed exit1 to exit0, while the
global Python still had no MCP. [Setup receipt](provenance/setup-receipt.json).
Passing preparation does not certify provider availability, quota, billing or
fresh-account sign-in. Python and Codex installation/login remain external.

Use the packaged [README](operator-source/README.md): invoke setup once, then
check readiness, set the existing app token and intentionally start foreground
operator/app Run. No service, global installation, credential read or paid fallback.
Requirements pin the top-level MCP version; its transitive packages are not fully locked.
An existing unrecognized local environment folder is refused and preserved.
Eight module hashes check consistency with the included identity, not publisher authenticity.
The ZIP has exactly14 allowlisted entries. [Package hashes](provenance/package-receipt.json).

Actual immutable native app default Title→Projects import/OK→goal Enter(no dispatch)
→new archive launcher without Python override→intentional Run→one3tick action,
two distinct640×480 camera PNGs, final reobserve and scoped Stop→CLI/launcher/app
normal exit0: **12/0, 56.765s**. Actor Python was the archive-local
3.13.3 environment; developer inspection used a separate interpreter.
[Runtime receipt](runtime/native/run-receipt.json), [actor](runtime/native/actor/result.json),
[checks](runtime/native/checks.json). Independent authenticated describe confirms
the current app stopped; context_replaced alone only confirms owner revocation.
Clipboard/environment restored, listener8127 released, no engine errors.
The native harness supplied process-local PYTHONUTF8=1; this is not every-locale proof.
Existing Codex `features.skills` ignored warnings are retained in stderr; actor JSON
does not independently attest backend identity. No actor prompt/command change.

Relevant Python66/0 with MCP SDK, docs10/0/maintain PASS, seven actual archive guards.
The first broad discovery was40tests/one release-notice link failure/one Windows
POSIX-mode skip. Reproducing the old allowlist confirmed that BUILD linked to an
omitted OPERATOR.md. Adding that documentation file to the release allowlist fixed
the direct caller; the original failure is preserved. [Before notice](provenance/notice-before.log),
[checks](provenance/checks.json), [guards](provenance/archive-checks.json).
425/426 original source-manifest entries are unchanged; the sole changed entry is
tools/ci/build.py's documentation allowlist. New doctor/setup and operator identity/
launcher/package/test/docs files are additional r14 changes, not counted in that
older manifest. [Scope proof](provenance/implementation-proof.json).

Astra actually viewed8UI and2sensor originals: primary controls/warnings readable,
goal field partial and full trace outside captured scroll. Small sensor differences
are image observations only. [Inspection](provenance/astra-inspection.json).
All76 named raw files/10PNG have byte-identical copies;
[manifest](copy-manifest.json). Private install/provider/account/config records are excluded.

This is one wall0.8m functional smoke, separate from the original three-layout
precision study. Historical camera9/9 and physical0/9 remain unchanged. The original
frozen goal and physical thresholds are retained; the separate12–20px proposal
has not been adopted/run. No production UI/style/localization/physics/camera edits.
App import/fullnative/Web/installer/four exports were not rerun; those are datedr7
checks. Existing Opus design review applies to unchanged UI. Tool/time limits do
not certify billing/request caps or provider reliability.

Next Codex: original-target precision, fresh-account onboarding and navigation.
Native Mac, powered-off Arch raw/formal task16 CLI release, human merge and exact
version/scope publication remain. Fable reviews/rebases this branch; human merges.
This local tool ZIP does not update the public Godot app or website. Global goal incomplete.
