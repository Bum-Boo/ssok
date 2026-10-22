# Actual browser physics — 22 September 2026

The raw [physics result](physics_result.json) records one successful real Chromium 153.0.8010.12
WebAssembly episode on Linux/WSL, using Playwright 1.63.0 and the exported Godot 4.7.2 client.
Actual canvas clicks selected the bundled learned biped and Run mode; actual W key events drove
the robot. The observer only read measurements. No service, paid API, injected command or paused
simulation supplied the result.

The [build manifest](build_release.json), [archive checksums](SHA256SUMS) and
[individual Web payload hashes](web_payload.json) identify the tested snapshot. It was an explicitly
dirty review build based on commit `671c9d3`, including the new observer and contemporary release
work. This is evidence for those exact bytes, not a claim that an arbitrary checkout of the base
commit or the final public release was tested. A clean release must run the browser gates again.

The 720 physics-interval snapshot covers exactly 12 seconds, even if browser polling arrives late.
It measured 0.429881 m forward, 0.070111 m lateral, 12.807° yaw, minimum uprightness 0.958920 and
minimum torso height 0.128712 m above the floor. Both collision soles lifted: 175/274 frames above
0.5 mm, with maximum clearances 7.684/13.230 mm. After W was released for 90 physics intervals,
uprightness was 0.999881 and the command was zero. Graph and runtime fingerprints stayed unchanged.

This is one browser episode. It is separate from native held-out and restart statistics and does
not establish all-browser, arbitrary-start/restart or hardware robustness.

Full authoring subsequently passed twice on these same exported bytes in independent fresh browser
contexts: [first result](authoring_result_1.json), [second result](authoring_result_2.json). Both
used actual clipboard paste, IndexedDB save, reload/open, valid JSON import, incompatible JSON
rejection and a new Wait block edited to 0.2 seconds, then verified downloaded project contents.
The [block editor](authoring_blocks.png) and [1152 × 577 workshop](authoring_compact.png) captures
were visually reviewed. Earlier test-driver attempts failed because input was issued before the
next Godot UI frame and menu navigation selected another operation; assertions stayed unchanged.

Reproduce after installing the pinned environment and exporting the project as described in
[BUILD.md](../../BUILD.md):

```sh
timeout --signal=INT --kill-after=20s 10m python tools/ci/browser_physics.py \
  --directory build/web --output build/browser-physics
```

For a deployed URL, add `--url https://HOST/ssok/` and supply the exact matching downloaded build
with its adjacent `export-logs/browser-layout.json`. Retain new raw results and build hashes.
