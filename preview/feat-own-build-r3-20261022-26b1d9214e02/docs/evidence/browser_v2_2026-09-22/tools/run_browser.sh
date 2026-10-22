#!/usr/bin/env bash
set -eu
mkdir -p .browser-debs .browser-libs
(cd .browser-debs && apt-get download libnspr4=2:4.38.2-1ubuntu1 libnss3=2:3.120-1ubuntu2.1 libasound2t64=1.2.15.3-1ubuntu1.1)
for package in .browser-debs/*.deb; do dpkg-deb -x "$package" .browser-libs; done
export LD_LIBRARY_PATH="$PWD/.browser-libs/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
uv venv --python 3.14.7 .venv
uv pip install --python .venv/bin/python -r browser-requirements.txt
.venv/bin/python -m playwright install chromium
mkdir -p out
cp probe-source.json build-release.json SHA256SUMS schedule.json web-payload.json out/
cp -r native-parity out/
timeout --signal=INT --kill-after=20s 15m .venv/bin/python tools/browser_matrix.py --directory web --output out/browser --schedule schedule.json > out/browser.log 2>&1
