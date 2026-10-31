# r3 후속 검사 근거 — 2026-10-31

보고서는 [cloud-20261031-ssok-fix](../../cloud-20261031-ssok-fix.md), 결정 보완은 [ADR 0029](../../adr/0029-rendered-desktop-agent-camera-loop.md)예요.
시작 소스는 `feat/own-build-r3-20261022`의 `578ca79`, 엔진은 `4.7.2.stable.official.ed1daf0bf`(공식 Linux x86_64, SHA-256 검증),
렌더러는 Xvfb 1600×1000 + Mesa llvmpipe예요. 이 폴더의 로그는 WARNING·백트레이스를 제거한 발췌이며 원문은 Git 제외 `build/`에 있어요.

| 파일 | 내용 |
|---|---|
| [results-before.json](results-before.json), [SUMMARY-before.md](SUMMARY-before.md) | 변경 전 전체 115 suite: 113 PASS / 2 FAIL (`agent_camera_rest_check`, `motion_lab_ui_check`) |
| [github-ci-camera-failures.md](github-ci-camera-failures.md) | GitHub run 39797157897·38156164681의 카메라 실패 발췌: `drive_stop`이 settling 중 약 10초 뒤 fault, 유휴 drift 14.7·15.0 mm |
| [verify-before-lifecycle-drive_stop.log](verify-before-lifecycle-drive_stop.log) | 같은 소스가 이 VM에서는 통과: tick 37→185까지 settling 후 ready(초당 약 13.6틱, 벽시계 10초 한도 직전) |
| [verify-before-agent_camera_rest_check.log](verify-before-agent_camera_rest_check.log) | 변경 전 유휴 drift 2.7669 mm, 2 mm 한도 1 실패 |
| rest-probe-1600x1000-run1..3.log, [rest-probe-800x500.log](rest-probe-800x500.log) | 개발 probe 4회: 주행 후 settle 155/152/152틱, 유휴 drift 네 번 모두 `0.00276690465398` m, 30틱마다 위치·속도·모터 duty·hold 적분 |
| [rest-probe-no-hold.log](rest-probe-no-hold.log) | 같은 절차에서 PI hold만 끈 비교: 유휴 drift 14.67 mm(전진 creep) |
| [rest-check-new-test-old-loop.log](rest-check-new-test-old-loop.log) | 새 회귀 검사를 수정 전 loop에 실행: 느린 프레임 주입 때 tick 103에서 fault, drift 15.1 mm, 14 checks / 9 failures |
| [rest-check-new-test-fixed-loop.log](rest-check-new-test-fixed-loop.log) | 수정 후: 느린 프레임 주행 155틱/19.8초에도 ready, drift 2.7669 mm, 8 checks / 0 failures |
| [rest_probe.gd.txt](rest_probe.gd.txt) | probe 스크립트(저장소 검사 아님, 재현용) |
| [results-after.json](results-after.json), [SUMMARY-after.md](SUMMARY-after.md), [verify-after-agent_camera_rest_check.log](verify-after-agent_camera_rest_check.log) | 변경 후 전체 116 suite: 116 PASS / 0 FAIL(새 Python 검사 1개 포함, engine error 0); rest check 느린 프레임 155틱/19.9초 ready, drift 2.7669 mm |

## 재현

```sh
python3 tools/ci/install_godot.py
python3 -m venv build/venv && build/venv/bin/python -m pip install -r tools/ci/requirements-lock.txt
xvfb-run -a -s "-screen 0 1600x1000x24" build/venv/bin/python tools/ci/verify.py --godot "$PWD/build/toolchain/godot"
XDG_DATA_HOME=/tmp/ssok-probe XDG_CONFIG_HOME=/tmp/ssok-probe SSOK_AGENT_TOKEN=<32자 이상 임의 문자열> \
  xvfb-run -a -s "-screen 0 1600x1000x24" build/toolchain/godot --audio-driver Dummy --path . --language en --fixed-fps 60 \
  --script tests/agent_camera_rest_check.gd -- --ssok-agent-bridge
```

probe는 `--script <절대경로>/rest_probe.gd -- --ssok-agent-bridge [--size 800 500] [--no-hold] [--steps N]`로 실행했어요.
토큰은 합성 픽스처 값이며 외부 서비스 호출은 없어요.
