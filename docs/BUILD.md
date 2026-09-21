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
- `build/browser-smoke/` with real Chromium screenshots and console results.
- `build/browser-authoring/` with saved/reopened project JSON, persistence/import results and
  screenshots of project controls, blocks and the compact desktop layout.

The export resource audit rejects developer tools, tests, documentation, Blender source files
and environment files in the application pack. The project license, third-party notices, README
and documentation snapshot accompany both archives as ordinary files beside the application.
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
save/reopen and invalid-import handling are verified by `browser_authoring.py` using actual
IndexedDB persistence, page reload, confirmation and downloaded JSON comparisons. It sends real
keyboard events because DOM text insertion does not enter Godot canvas text fields. Both browser
checks are CI gates; screenshots and partial results are uploaded even when a check fails.
Four-language UI and learning flows require their dedicated checks and release review.
No finite test suite certifies real hardware, every browser or every possible learner assembly.

## Local Web preview

```sh
python3 -m http.server 8060 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:8060/` in a current desktop Chromium or Firefox browser with WebGL 2.
Keep all exported filenames intact; opening `index.html` directly via `file://` is unsupported.
Use a keyboard and mouse. The public static demo does not host the optional Python API bridge.

## GitHub Actions and release

`.github/workflows/ci.yml` verifies pull requests and pushes. A successful full check is required
before exporting either target. The workflow retains verification logs even on failure, and uses
official GitHub Actions pinned by commit SHA. Python dependencies are pinned in the lock file.

Set repository **Settings → Pages → Source → GitHub Actions** once. A successful `main` push
deploys its Web export; a manual workflow on another branch deploys only if `deploy` is checked.
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
