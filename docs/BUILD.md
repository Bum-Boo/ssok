# Build, verify and publish ssok

The runtime is pinned to **Godot 4.7.2**, GDScript, GodotPhysics3D and GL Compatibility.
The official build is `4.7.2.stable.official.ed1daf0bf`. Python services and training tools are
developer tools; exported applications contain neither a Python runtime nor API credentials.

## Reproduce on Linux x86_64

Use Python **3.14.7**. Run from the repository root:

```sh
python3 tools/ci/install_godot.py --templates
python3 -m venv build/venv
build/venv/bin/python -m pip install -r tools/ci/requirements-lock.txt
build/venv/bin/python tools/ci/verify.py --godot "$PWD/build/toolchain/godot"
build/venv/bin/python tools/ci/build.py --godot "$PWD/build/toolchain/godot" --version 0.1.0
build/venv/bin/python -m playwright install chromium
build/venv/bin/python tools/ci/browser_smoke.py
build/venv/bin/python tools/ci/browser_authoring.py
build/venv/bin/python tools/ci/browser_physics.py
```

On a minimal Linux image, use `python -m playwright install --with-deps chromium` to install
the browser's system libraries. The installer checks the SHA-256 of both official archives
before extraction. Templates are installed into the normal Godot data directory; only the
Linux x86_64 and single-threaded Web templates are extracted. The template archive download
is approximately 1.28 GB. `build/.gdignore` keeps tooling and environments outside the importer.

The build creates:

- `build/web/index.html` and its neighboring WebAssembly/resource files.
- `build/linux/ssok.x86_64` and `ssok.pck`; keep them together.
- Versioned ZIP archives, `build/SHA256SUMS`, and `build/release.json` with engine/commit identity
  and a flag identifying any uncommitted source changes.
- Export and desktop-startup logs, plus the exported resource manifests under `build/export-logs/`.
- `build/export-logs/browser-layout.json` records actual control positions at the browser test
  viewport, derived by Godot from the same UI source and fonts as the export.
- `build/browser-smoke/` with real Chromium screenshots and console results.
- `build/browser-authoring/` with saved/reopened project JSON, persistence/import results and
  screenshots of project controls, blocks and the compact desktop layout.
- `build/browser-physics/` with the actual WebAssembly walking/release measurements, source
  fingerprints and browser screenshots.

The export resource audit rejects developer tools, tests, documentation, Blender source files
and environment files in the application pack. The project license, third-party notices, README
and documentation snapshot accompany both archives as ordinary files beside the application.
The small source documents, reference policy and code examples linked from that snapshot are
also bundled at their original relative paths, so those links work offline. They are outside
the application pack; development and training still use a complete source checkout.
The Web preset explicitly disables threads, extensions, PWA service workers and simulated
cross-origin headers. It runs on a normal static host, including GitHub Pages.

## Verification and failure reporting

`tools/ci/verify.py` discovers every `tests/*_check.gd`, Python test module under `tests/` and
`tools/`, and adds the humanoid walking/backward/pickup/running/link-order variants. It imports
the project and loads the main scene first. Each Python test file runs in a separate interpreter
to prevent module-level patches from leaking between suites. An authenticated loopback mock
HTTP bridge remains alive for the Godot transport tests. Actual OpenAI calls are disabled.

Godot user data/config/cache are redirected to a temporary directory. Personal saved projects,
language settings and learning scenarios are not modified. Each check has a timeout; a failure
does not skip later checks. `results.json`, `junit.xml`, `SUMMARY.md` and individual logs retain
every result. Any failed check returns a failing exit status. The running and new-kit acceptance
checks are included; known limitations are not silently marked as expected passes.
The runner passes its selected engine through `GODOT`; both optional bridge CLIs honor that
environment variable, with an explicit `--godot` taking precedence. The real MCP transport
check deliberately removes executable lookup from `PATH` to cover the clean CI environment.

For a focused development check, use `--match 'project|localization'`; `--list` prints the check
inventory. A filtered run is not the complete release gate. The browser smoke verifies loading,
WebGL startup and basic canvas input. Its screenshots still require visual review; complete
save/reopen, JSON transfer and block editing are verified by `browser_authoring.py` using actual
IndexedDB persistence, page reload, confirmation and downloaded JSON comparisons. An isolated
browser context pastes synthetic JSON through the clipboard and Ctrl+V into the Godot canvas;
DOM text insertion does not enter these fields. Browser checks are independent CI gates;
each runs after a successful export/setup even if another browser check fails, and screenshots
and partial results are uploaded on failure.
Each CI browser command has a ten-minute overall deadline as well as its individual waits.
Screenshots capture Chromium's actual view through CDP; Godot draws its own fonts, so these
captures do not wait for DOM-font stabilization. Stages and partial results are written as work proceeds.
The Web-only `WebClipboard` bridge preserves a trusted browser paste before Godot's native text
editing action; it requests no clipboard permission in the product (see [ADR 0016](adr/0016-native-browser-paste.md)).
Canvas clicks use the build's named control anchors rather than fixed button coordinates. When
checking a deployed URL, keep the matching local build and its layout manifest available.
Four-language UI and learning flows require their dedicated checks and release review.
No finite test suite certifies real hardware, every browser or every possible learner assembly.

`browser_physics.py` uses the `?ssok_verify=1` read-only observer to measure the actual bundled
learned starter through real Run-mode clicks and W input. Its 720-interval walking snapshot and
90-interval released-command snapshot do not grow when browser polling is delayed. It checks the
same app displacement, heading, uprightness and height gates, unchanged graph/runtime fingerprints,
and positive collision-sole clearance for both feet. The observer exposes no command/setter API
and never pauses the simulation; ordinary URLs do not activate it. See [ADR 0017](adr/0017-read-only-browser-physics-evidence.md).
Run this against the exact exported or deployed build; native policy evaluation alone is not Web evidence.
The corrected [clean `6470757` checkpoint](evidence/browser_clean_6470757_2026-09-22/README.md)
passes all three Chromium gates and Linux startup. Its actual 12-second Web walk travels 0.429205 m,
with 0.029757 m lateral drift, 4.3922 degrees yaw, both feet lifting and uprightness 0.999834 after
stopping. Both latest GitHub verify/build runs also pass. This checkpoint is private; publication,
anonymous interaction and the remaining locomotion requirements still block the complete release.

The following earlier results use the historical actuator implementation; ADR0020 explains why
they cannot certify the current torque cap. The [22 September review snapshot](evidence/browser_2026-09-22/README.md) passed this real Chromium
WebAssembly gate: 0.429881 m forward in 12 seconds, 0.070111 m lateral, 12.807° yaw, minimum
uprightness 0.958920, both feet lifting, and uprightness 0.999881 after stopping. Its raw result and
exact archive/payload hashes are retained. That dirty review snapshot is not a completed public
release; every clean release build must pass all browser gates independently.

The subsequent [clean `0b2fe24` checkpoint](evidence/browser_clean_0b2fe24_2026-09-22/README.md)
exported Web/Linux successfully and passed smoke and full authoring. Its physical browser gate
failed: lateral displacement was 0.101064 m against the unchanged 0.10 m limit. The exact build,
raw failure, fingerprints and separate native start-time diagnostics are retained. This checkpoint
does not approve release; the earlier review episode does not override its failure.
The same exported bytes also passed the complete project/clipboard/block authoring flow twice in
fresh Chromium contexts. Both raw results and reviewed compact/editor screenshots are linked from
that evidence page. Input steps wait for Godot's next canvas frames before acting on changed UI.

## Local Web preview

```sh
python3 -m http.server 8060 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:8060/` in desktop Chromium with WebGL 2. The retained browser checks use
Chromium; Firefox and other browsers have not completed this release's interaction/physics gates.
Keep all exported filenames intact; opening `index.html` directly via `file://` is unsupported.
Use a keyboard and mouse. The public static demo does not host the optional Python API bridge.

## Run the Linux build

Extract the Linux x86_64 ZIP and keep `ssok.x86_64` and its neighboring PCK file together.
From the extracted directory, run:

```sh
chmod +x ssok.x86_64
./ssok.x86_64
```

The bundled executable contains the engine; running it does not require installing the Godot editor
or Python developer tools. This desktop artifact targets Linux x86_64, not Windows or macOS.

## GitHub Actions and release

`.github/workflows/ci.yml` verifies pull requests and pushes. A successful full check is required
before exporting either target. The workflow retains verification logs even on failure, and uses
official GitHub Actions pinned by commit SHA. Python dependencies are pinned in the lock file.

Set repository **Settings → Pages → Source → GitHub Actions** once. Pushes (including `main`) verify and build without publishing. To publish a reviewed revision,
run the workflow manually on that revision with `deploy` checked.
The `github-pages` environment reports the resulting URL. Publishing a GitHub Release triggers
the same validation/build and attaches ZIPs, hashes and metadata to that existing release.
Existing release assets are not silently overwritten. A tag or a build alone is not evidence of
a successful public deployment: open the final URL anonymously and run the browser smoke with
`--url https://OWNER.github.io/ssok/` after publication.

## Upstream references

- [Official Godot 4.7.2 release and downloads](https://github.com/godotengine/godot/releases/tag/4.7.2-stable)
- [Godot single-threaded Web export and hosting](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
- [GitHub custom Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [Godot license and third-party notices](https://godotengine.org/license/)

This build tooling changes no application text; no language-pack updates are required.
