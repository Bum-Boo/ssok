# M2 로컬 검증 근거

2026-11-05, Windows native, Godot `4.7.2.stable.official.ed1daf0bf`, GL Compatibility,
NVIDIA RTX 4060 / OpenGL 3.3 / driver 610.88. 첫 전체/대상 앱 소스는 `4ea9705`,
호환 보정 후 최종 대상 앱 소스는 `71e5962`예요. 이후에는 문서만 갱신해요.
작업실은 `C:/Users/Hojun/agent-jobs/ssok-M2-20261105/repo`, 시작은 `c8d624d`예요.

- [작업 범위·부품 표·측정·제한](../../WORK_SUMMARY_M2.md)
- [최종 후속 대상 19종: 15 PASS / 4 FAIL](followup-summary.md)
- [첫 대상 12종: 10 PASS / 2 FAIL](target-summary.md), [보정 전 전체 121종: 111 PASS / 10 FAIL](full-before-fixes-summary.md)
- [키트 런타임 실제 출력](kit-runtime.log): 106 checks, 1 failures. 센서·주행·깃발·결승선 PASS, 벽 속도 FAIL.
- [Stage UI 실제 출력](stage-own-build.log): 164 checks, 1 failures. 벽 답지 실패를 유지해요.
- [장치와 M1 포트 검사](device-ports.log): 331 checks, 0 failures.
- [번역 실제 출력](localization.log)
- 최종 소스 실제 출력: [런타임](followup-kit-runtime.log), [Stage UI](followup-stage-own-build.log),
  [화면 흐름](followup-game-flow.log), [출제·연습](followup-stage-authoring.log), [카메라](followup-camera.log)
- [실제 GL 최종 16장 해시](final-gl-sha256.json): 네 언어 × 두 테마 × 두 크기, 149 checks, 0 failures.
- [키트 차 실제 편집 화면](finish-line.png), [키트 깃발 팔 내림 화면](raise-flag.png)

GL 원본 16장은 작업실 `build/m2-final-gl-user/appdata/Godot/app_userdata/ssok/parts_tray_previews/`에
있어요. 자동 검사와 독립 Astra의 실제 이미지 검수를 구분해요. 이전 contact 이미지 두 장은
해당 시점의 같은 빔·판 이름을 검토했고, 최종 원본은 총괄이 별도로 확인했어요.
후속 실패 네 종은 모두 벽 답지/증명이고, 보정 전 카메라 네 종과 깃발 90도·옛 연습 실패는
최종 후속 검사에서 복구됐어요. `mcp`·`mujoco` 모듈 누락은 전체 검사 실패로 보존했어요.
최종 소스로 전체 121종을 다시 실행한 것은 아니에요. 푸시·병합·배포·Web 실행은 하지 않았어요.
