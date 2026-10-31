# Review reproduction checks (2026-10-31)

Synthetic reproduction scripts for the r3 integration review in
[docs/cloud-20261031-ssok-review.md](../../docs/cloud-20261031-ssok-review.md).
They are deliberately outside `tests/*_check.gd`, so `tools/ci/verify.py` does not run them.
A failing check here documents an open defect; it turns green once the defect is fixed and can
then be moved into `tests/` as a regular regression check.

Run from the repository root with isolated user data:

```sh
D=$(mktemp -d)
XDG_DATA_HOME=$D XDG_CONFIG_HOME=$D XDG_CACHE_HOME=$D godot --headless --path . --import --quit
XDG_DATA_HOME=$D XDG_CONFIG_HOME=$D XDG_CACHE_HOME=$D godot --headless --audio-driver Dummy \
  --path . --language en --fixed-fps 60 --script res://tests/review/<name>.gd
```

| Script | Expected on 578ca79 |
|---|---|
| `save_compat_check.gd` | 60 checks, 1 failure (stage workspace float precision) |
| `stage_aggregate_review_check.gd` | 6 checks, 4 failures (aggregate stage findings) |
| `legacy_builtin_check.gd` | 6 checks, 0 failures (main's built-in tasks evaluate identically) |
| `gear_axis_cluster_check.gd` | 9 checks, 4 failures (gear axis on merged bodies) |
| `tray_environment_floor_check.gd` | 8 checks, 4 failures (anchored tray props float 30 mm) |
| `parts_catalog_data_check.gd` | 3612 checks, 10 failures (embedded humanoid materials, unchanged from main) |
| `ramp_winding_check.gd`, `cup_observer_check.gd` | 0 failures |
| `cup_cost_presets_check.gd`, `cup_fixture_sensitivity_check.gd`, `solution_confirm_as_shown.gd`, `stage_map_after_clear.gd` | measurement printouts |

`fixtures/main/` holds synthetic data written by main (4eb059f) through its own writers:
`gen_main_fixtures.gd` (`REVIEW_OUT=<dir>/`) and `export_builtins_check.gd` (`REVIEW_OUT=<file>`)
regenerate it from a main checkout. No personal or production data is included.
