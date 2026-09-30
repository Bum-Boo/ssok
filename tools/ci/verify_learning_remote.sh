#!/usr/bin/env bash
set -euo pipefail
mkdir -p out
touch out/.gdignore
python3 tools/ci/install_godot.py --directory out/toolchain
uv venv --python 3.14.7 out/venv
uv pip install --python out/venv/bin/python -r tools/ci/requirements-lock.txt > out/dependencies.log 2>&1
out/venv/bin/python tools/ci/verify.py --godot "$PWD/out/toolchain/godot" --python "$PWD/out/venv/bin/python" --output out/verification
