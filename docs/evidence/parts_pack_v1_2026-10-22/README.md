# B-2 local verification — 2026-10-22

Base: `fbf2d6392e0222e62010aa98a7318dce256e479c`, branch `feat/parts-freedom-r2-20261022`.
Engine: `build/toolchain/godot`, 4.7.2 stable. No export, push or merge.
Commands use `XDG_DATA_HOME=/tmp/ssok-b2-data`, `XDG_CONFIG_HOME=/tmp/ssok-b2-config`,
`XDG_CACHE_HOME=/tmp/ssok-b2-cache` and `--headless --path . --script tests/<name>.gd`.

- Gear physics: [actual output](gears.txt), 36 checks / 0 failures. First chain fixture failed
  because wheel/housing collided; same-step server velocities and rigid rotor clustering were
  required for the constraint. These failures preceded the passing measurement, not app success.
- B regressions after gear addition: runtime 28/0, blocks 51/0, mechanics 79/0, workshop 50/0.
- Localization: 52,875/0; construction kit: 13,170/0.
- Import exits 0 but emits socket creation errors in this sandbox; not counted as a clean pass.
- Screen/glyph/clipping inspection is unrun without DISPLAY. Headless catalog checks are narrower.
