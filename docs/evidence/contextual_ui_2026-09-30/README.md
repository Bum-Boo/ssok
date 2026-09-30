# 작업 공간 UI 맥락 수정 — 2026-09-30

Issue [#42](https://github.com/Bum-Boo/ssok/issues/42). 독립 브랜치 `feat/42-contextual-workspace-ui`에서 `af1973b`를 기준으로 수정했다. 이 기록은 이 브랜치의 검증이며 공개 배포 상태를 뜻하지 않는다.

## 관찰과 변경

- 이전 로컬 `c4f43fb` 실행에서는 휴머노이드 예제 위에 깃발 임무 카드가 남고, 카드가 넓게 늘어나 3D 공간을 가렸다. [수정 전 1920×1043](screenshots/before-humanoid.png).
- 비깃발 예제·비깃발 Stage·Lab·저장 프로젝트에서는 깃발 카드와 3D 표식을 숨긴다. 깃발 예제나 Stage에서는 다시 표시하고, 카드 폭을 최대 500 px로 제한한다. 숨겨진 카드 높이를 카메라 영역에서 빼며 예제 로드 다음 프레임에 최종 배치로 다시 프레이밍한다. [비깃발 예제](screenshots/biped.png) · [깃발 예제](screenshots/ready.png).
- 넓은 빈 작업 공간에서는 중앙 시작 카드 하나만 보인다. 좁은 창에서는 깃발 임무 카드를 시작 안내로 사용한다. 기본 블록 탭의 제어 선택은 코드로 맞춘다. [수정 후 첫 화면](screenshots/start.png).
- 임무의 연결·배선·물리 성공 판정과 그래프·학습자 코드는 변경하지 않았다. 새 사용자 문구가 없어서 번역 카탈로그 변경은 없다.

## 검증

- Godot 4.7.2, 로컬 Intel HD 530 GL Compatibility. `godot --headless --path . --import --quit`와 `--quit` 통과.
- `tests/flag_mission_check.gd`: 헤드리스 17/0; 네이티브 캡처 19/0. 시작 카드 하나, 제어 선택, 비깃발 숨김, 깃발 재진입, 목표 위치와 카드의 비겹침을 포함한다.
- `tests/viewport_framing_check.gd`: 62,660/0. `tests/interface_preferences_check.gd`: 95/0. `tests/stage_ui_check.gd`: 36/0. `tests/workshop_ui_check.gd`: 420/0.
- Web·Linux release preset 수동 export 성공. Linux export의 `--headless --quit` 시작 성공. `python3 tools/docs/maintain.py --review execution-flow --review flag-flow` 뒤 `--check` 통과.
- 1440×900 한국어 네이티브 화면의 시작·깃발 준비·이족 예제를 원본 PNG로 확인했다. 시작 및 깃발 이미지는 `tools/godot/capture_flag_mission.gd`, 이족 이미지는 `tests/flag_mission_check.gd -- --screenshots`로 얻었다.
- 실제 Chromium WebGL 2에서 [첫 화면](screenshots/web-start.png)과 [서보 팔 시작](screenshots/web-ready.png)을 캡처해 확인했다. 두 단계의 브라우저 콘솔 오류는 0건이었다. 최종 소스의 전체 `browser_smoke.py`는 두 번째 캡처 뒤 외부 SIGTERM(exit 143)으로 끝나 세 번째 실행 결과와 전체 통과를 확인하지 못했다. 앞선 중간 소스의 전체 브라우저 smoke는 통과했으나 최종 소스의 통과로 간주하지 않는다.

브라우저 로그와 캡처 원본은 이 작업실의 `build/browser-smoke-ui-final/`에도 있다. 이후 전체 smoke를 다시 실행하면 결과를 PR에 명시한다.
