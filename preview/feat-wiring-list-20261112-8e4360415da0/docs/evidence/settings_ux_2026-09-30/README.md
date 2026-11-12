# Native settings audit evidence

Source: `4340fe2`, Godot `4.7.2`, Linux GL Compatibility, 2026-09-30.

[Report](../../SETTINGS_UX_AUDIT_2026-09-30.md) lists all five flow steps, seven inspected screenshots, observations and limitations. The documentation branch has a different architecture baseline (`2759fde`); this evidence does not update its implementation claims.

`capture.gd.txt` and `populated.gd.txt` are the exact observer drivers used. They instantiate the real main scene, render the native viewport and emit the connected locale selection signal. They are retained as text so documentation does not register new Godot scripts. They are not production code or a full interactive keyboard/browser test. `observations.json` records the initial sequence; `restart.json` records a separate process; `populated.json` records graph/draft preservation with four parts and three links. `contrast.json` uses original palette values and WCAG relative luminance, not antialiased screenshot pixels.

To reproduce, create an isolated worktree at the source commit, import with Godot 4.7.2, copy the drivers into ignored `build/settings-audit/`, change their absolute OUT constant to that worktree output path, and set XDG_DATA_HOME and XDG_CONFIG_HOME to isolated directories. Run capture.gd once, then with `-- restart`, then populated.gd. Existing personal app data must not be used. Inspect every resulting PNG before adopting findings. Reproduction on other commits is new evidence, not a rewrite of these screenshots.

All seven PNGs were opened and accepted: correct scene, language and dimensions, no loading/blank screen. `sha256.json` hashes the images, drivers and observed metrics. Import and capture processes exited 0; retained observer logs had no script errors. No app source, language catalogs, user projects or the live integration worktree were changed. Browser, screen reader, running physics and save-error paths were not tested.

Import emitted existing OBJ/PBR ambient-material warnings; no ERROR or SCRIPT ERROR was observed. Capture/restart/populated logs contained no warnings or script errors. Logs are local audit worktree outputs, not bundled evidence. The live integration owner advanced to a1c4417 during this audit; these screenshots remain tied to 4340fe2.
