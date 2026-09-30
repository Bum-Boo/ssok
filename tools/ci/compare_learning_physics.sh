#!/usr/bin/env bash
set -euo pipefail
mkdir -p out
touch out/.gdignore
python3 tools/ci/install_godot.py --directory out/toolchain
engine="$PWD/out/toolchain/godot"
"$engine" --headless --path . --editor --import --quit > out/import.log 2>&1
set +e
"$engine" --headless --path . --fixed-fps 60 --script tests/robot_car_check.gd > out/godot-car.log 2>&1
godot_status=$?
set -e
cp project.godot out/original-project.godot
python3 - <<'PY'
from pathlib import Path
p=Path('project.godot');s=p.read_text();s=s.replace('[physics]', '[physics]\n3d/physics_engine="Jolt Physics"',1);p.write_text(s)
PY
set +e
"$engine" --headless --path . --fixed-fps 60 --script tests/robot_car_check.gd > out/jolt-car.log 2>&1
jolt_status=$?
set -e
cp out/original-project.godot project.godot
python3 - "$godot_status" "$jolt_status" <<'PY'
from pathlib import Path
import json,sys
Path('out/comparison.json').write_text(json.dumps({'production_engine':'GodotPhysics3D','godot_exit':int(sys.argv[1]),'jolt_exit':int(sys.argv[2]),'jolt_isolated':True},indent=2)+'\n')
PY
# A comparison reports either engine's failure without claiming backend equivalence.
