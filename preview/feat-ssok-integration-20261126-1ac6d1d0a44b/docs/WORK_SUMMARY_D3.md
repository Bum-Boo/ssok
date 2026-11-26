# 작업 D-3 — Web 미리보기와 컵 관측 복구

2026-10-22 · Codex · `feat/own-build-r3-20261022`.
시작 HEAD는 `8a12a1c9ea50aa9538c23a6466abf2c459dd0d09`, 시작 dirty는 없었어요.
앱·검사·빌드 도구 검증 소스는 `e2c1eb3`예요. 뒤의 최종 커밋은 문서·검증 근거만 담아요.
push·main 병합·워크플로 변경·공개 배포는 하지 않았어요.

## 실제 정지 원인과 앵커

먼저 요청한 `timeout 120 build/toolchain/godot --headless --path . --language en --script res://tools/ci/browser_layout.gd -- /tmp/bl.json`을 실행했어요.
기본 user data가 허용 쓰기 범위 밖이라 프로젝트 저장 단계에서 exit 1이었어요.
같은 명령을 `XDG_DATA_HOME`/`XDG_CONFIG_HOME`의 격리된 `/tmp` 경로로 실행하니
**exit 124 / 120초 timeout**을 재현했어요. 실제 최초 실패는 라우터의 무한 로딩이 아니었어요.

기존 스크립트는 블록 추가 버튼을 `"+"`로 찾았지만 현재 UI의 이름은 `"Add block"`이에요.
`_point("add_block", null)`의 assertion 뒤에도 상위 코루틴은 계속 진행했어요.
이어서 예전 카드 구조인 `last_card.get_child(1).get_child(1)`가 자식 범위 초과와 null 호출로 중단됐어요.
`SceneTree`는 계속 실행되며 출력 파일 작성·`quit()`에 도달하지 못했어요.
[원문 재현 로그](evidence/own_build_d3_2026-10-22/browser-layout-before.log)를 보존해요.
GitHub의 300초 결과는 사용자 제공 근거이며 이 환경에서 GitHub run을 재실행하지 않았어요.

현재 스크립트는 **앱 라우터 → 세 Stage 세션 → Lab 세션**을 먼저 열고 앵커를 수집해요.
이후 기존 opt-in 브라우저 도구의 unprefixed 앵커를 별도로 유지해요.
옛 작업실의 의미가 같은 키 48개는 삭제하지 않았어요. 블록 버튼은 실제 문구로 찾고,
숫자 입력은 자식 순번 대신 `Argument_seconds` 이름으로 찾아요.

| 범위 | 새로 수집하거나 갱신한 키 |
|---|---|
| Title·스테이지 선택 | `game_title_play`, `game_title_lab`, `game_stage_<id>` |
| 각 Stage의 답지·확인·코드·실행 | `game_solution_<id>`, `game_confirm_<id>`, `game_program_<id>`, `game_code_tab_<id>`, `game_code_editor_<id>`, `game_run_<id>`, `game_stop_<id>` |
| Lab 실행·Help | `lab_run`, `lab_stop`, `lab_help` |
| Lab 탭·코드 | `lab_code_tab`, `lab_blocks_tab`, `lab_wiring_tab`, `lab_stages_tab`, `lab_code_editor` |
| Lab 배선 | `lab_wire_pin`, `lab_wire_connect`, `lab_wire_disconnect_first` |
| Lab 프로젝트·과제 내보내기 | `lab_project_name`, `lab_save`, `lab_export`, `lab_close_projects`, `lab_stage_export` |
| 기존 작업실 | 기존 Run/Stop·프로젝트·탭·배선·블록·과제 load/answer/export·확인창·설정 키 유지 |

`<id>`는 `raise-flag`, `finish-line`, `wall-brake`예요.
현재 Stage/Lab의 Run은 실행 중 Reset robot이 되므로 `game_stop_*`/`lab_stop`은 그 동작을 가리켜요.
**삭제한 키는 `game_start_<id>` 3개**예요. 현재 Stage에는 시작 briefing과 `start_button`이 없어요.
기존 native 캡처의 해당 속성 접근도 소스상 낡아 있었지만, 최초 재현에서는 앞의 블록 오류 때문에 도달하지 않았어요.
native Windows 입력 도구는 답지 메뉴 → 확인 → Code chip 순서로 갱신했어요.
`native_solutions`도 고정 문자열 대신 실제 답지 로드 후 소스를 읽어요.

`browser_smoke.py`는 기본 Title → Stage 선택 → 빈 작업대 → 답지 메뉴/확인 → Run → Reset을 눌러요.
레이아웃의 90개 앵커는 모두 1400×950 안에 있고, smoke의 여섯 click 키와 일치해요.
컨트롤 누락·숨김·범위 이탈은 `push_error` + `quit(1)`이에요.
예상 밖 코루틴 중단에는 45초 monotonic watchdog, 빌드 호출에는 60초 subprocess timeout과 부분 로그 보존을 두었어요.

- 정상 생성: **8.328초 / exit 0 / 90 anchors**.
- 누락 컨트롤 주입: **0.323초 / exit 1**, 누락 이름을 출력했어요.
- 120초 await 주입: **45.235초 / exit 1**, watchdog 오류를 출력했어요.
- watchdog 주입은 `3fe5882`, 정상/누락 검사는 최종 `e2c1eb3` 소스예요. watchdog 함수와 기한은 같아요.
- 실제 Chromium 클릭·렌더 검증은 아래 export 제약으로 미실행이에요.

최종 좌표 검토에서 headless 창이 Lab 프로젝트 요청 너비 760px를 640px로 보고하는 차이도 확인했어요.
기존 프로젝트 확인창의 요청 크기 복원·줄바꿈 재배치 절차를 현재 Lab/Stage popup에도 적용했어요.
Lab 제목 입력 중심은 X=636→700px, Stage 답지 확인 중심 Y는 528→516px로 보정됐어요.
이는 캡처 도구만의 보정이며 앱 창 크기/UI를 바꾸지 않았어요.

## Web export 결과

`install_godot.py`는 기본 실행에서 editor만 설치하고 템플릿은 `--templates`가 필요해요.
다음 명령을 실제 실행했어요. editor는 기존 SHA-256 검증 캐시를 사용했어요.

```sh
XDG_DATA_HOME=/tmp/ssok-d3-build XDG_CONFIG_HOME=/tmp/ssok-d3-build python3 tools/ci/install_godot.py --templates
XDG_DATA_HOME=/tmp/ssok-d3-build XDG_CONFIG_HOME=/tmp/ssok-d3-build python3 tools/ci/build.py --godot build/toolchain/godot --platforms Web --version test
```

템플릿 다운로드는 `Temporary failure in name resolution`로 실패했어요.
표준 build는 import의 editor TCP 소켓 생성 권한 오류 때문에 layout 호출 전에 중단됐어요.
이 오류 gate를 우회하거나 통과 처리하지 않았어요.
별도 실제 Web export 명령도 `web_nothreads_debug.zip`/`web_nothreads_release.zip` 부재로 exit 1이었어요.
**`build/web`의 정상 HTML/WASM/PCK 산출물은 없어요.** 정상 layout 단계의 별도 실행 로그와 JSON은 남겼어요.
빌드의 자동 생성 identity 변경은 export 실패 후 되돌렸어요.
네트워크·소켓을 허용하는 호스트에서 같은 빌드 명령을 다시 실행해야 해요.

## 컵 관측 규칙과 픽스처

`cup_object_count()`는 `environment_role="object"`인 **움직일 수 있는 자유 환경 물체**만 세어요.
기계 그래프를 따라 비물체 부품에 연결된 물체도 제외해요.
따라서 컵·보드·모터·섀시·구조 부품 및 그 조립에 연결된 공은 대상이 아니에요.
전기 배선은 기계적 소속을 바꾸지 않아요. SKU 이름에는 의존하지 않아요.
동일 solver RID는 컵 여러 개에 걸쳐 한 번만 세고, 병합 몸체의 모든 구성원이 내부에 들어와야 해요.
기존 회전된 컵 좌표·구의 반지름·나머지 mesh bounds·1 mm solver 허용 오차는 유지해요.

기존 ADR 0037의 모든 movable body 후보 범위만 [ADR 0038](adr/0038-free-environment-cup-objects.md)로 명시적으로 대체했어요.
Stage v2 `cup_count`의 `"*"`/`-1`, min/max/hold, unavailable 판정은 유지해요.
계약 검사 설명과 [Stage 계약](STAGE_CONTRACTS.md), [실행 흐름](FLOWS.md)을 맞췄어요.

픽스처는 seed `20261022`, physics ticks 60, 실행 `--fixed-fps 60`이에요.
직접 배치 관측과 실제 밀기를 분리했어요.
차는 X=0.46 m로 이동하고 공은 X=0.61 m, 입구는 X=0.636 m에 두었어요.
옆으로 눕힌 컵의 안쪽 바닥을 지면에 맞춰 4 mm 테두리가 별도 턱 오르기 시험이 되지 않게 했어요.
35% 출력으로 최대 120 tick만 밀고, count=1이면서 공 중심 X≥0.70 m이면 일찍 멈춰요.
그 뒤 240 tick을 정착해요. 공/로봇 transform을 밀기 중 덮어쓰지 않아요.

| 관측 | 실제 값 |
|---|---|
| 공 직접 배치 | count=1 |
| 섀시를 컵 구역에 겹침 | count=1 |
| 공을 꺼내고 섀시만 겹침 | count=0 |
| 밀기 종료 | ball=(0.700466, 0.019429, -0.000154), chassis=(0.611361, 0.016843, -0.000246), count=1, peak=1 |
| Stop 후 4초 정착 | ball=(0.776386, 0.019431, -0.000865), chassis=(0.614713, 0.017279, -0.000300), count=1, peak=1 |

처음 20%/60 tick, 이어 20%/120 tick 실험은 진입 부족으로 각각 2 assertion 실패였어요.
현재 픽스처 결과로 합산하지 않아요. 로그는 `build/d3-repro/`에 보존해요.
기존 관측 함수만 상속 override한 임시 반증 실행은 peak=2/정착 count=2 및 연결 물체 제외 실패를 재현했어요(21 checks / 3 failures).
최종 함수의 검사는 **21 checks / 0 failures**, Stage 계약은 **41 / 0**이에요.
Windows 실기기 실행은 하지 않았으므로 플랫폼 양쪽 통과를 확정하지 않아요.

## 전체 검사와 소스

엔진은 `build/toolchain/godot`의 `4.7.2.stable.official.ed1daf0bf`예요.
표준 실행은 mock HTTP loopback 소켓 생성의 `PermissionError: [Errno 1]`로 시작 전에 중단됐어요.
이 시도를 전체 검사로 세지 않아요. D-2와 같은 진단 실행이 표준 `checks()`, 명령,
timeout, exit/engine-error gate 전체를 그대로 실행했어요. 실패를 skip/pass 처리하지 않았어요.

```sh
python3 tools/ci/verify.py --godot build/toolchain/godot --output build/d3-strict
python3 docs/evidence/own_build_2026-10-22/run_checks.py --output build/d3-final
```

**115 suites / 89 PASS / 26 FAIL**이에요. 전체 통과를 주장하지 않아요.
[결과·소스 대조](evidence/own_build_d3_2026-10-22/results.json)의 이름 집합은 표준 계획 115개와 정확히 같아요.
D-2 PASS 89개를 모두 유지했고, FAIL 26개의 이름 집합도 같아 새 실패는 0개예요.
popup 보정 전 `3fe5882`의 [첫 전체 실행](evidence/own_build_d3_2026-10-22/initial_results.json)도 115/89/26이었어요.
최종 popup 보정 후 `e2c1eb3`에서 전체 115개를 다시 실행한 결과를 위 최종 수치로 기록해요.
최종 검사 전후 source 1,268개 파일 SHA-256 불일치는 0개예요.
manifest SHA-256은 `21251c998adf34d080971ea43c4815d08e91c2022eca141237859ef4c9377b7c`예요.
최종 앱·검사·도구 소스 commit은 `e2c1eb3a9bca6cc1624d3e56c5b54952d0a8b4cc`예요.
원문 명령·로그·JUnit·manifest는 `build/d3-final/`,
소형 재현/결과 근거는 [evidence README](evidence/own_build_d3_2026-10-22/README.md)에 있어요.

환경 실패 전체:

| 원인 | 수 | suite |
|---|---:|---|
| GL 디스플레이 초기화 | 17 | `agent_camera_loop_check-rendered`, `agent_camera_rest_check`, `agent_goal_ui_check-rendered`, `bridge_stop_owner_check`, 아래 lifecycle 13개 |
| 소켓/mock 생성 권한 | 7 | `import`, `motion_lab_ui_check`, `tests-desktop_client_check.py`, `tests-desktop_session_check.py`, `tests-test_pickup_bridge.py`, `tools-motion_lab-test_races.py`, `tools-motion_lab-test_service.py` |
| 기존 Python 패키지 부재 | 2 | `tests-motion_mcp_check.py`(mcp), `tools-rl_lab-test_rl_lab.py`(mujoco) |

`camera_evaluator_lifecycle_check-`의 접미사 13개는 `normal_stop`, `drive_stop`, `teardown`,
`mode_off`, `app_free`, `rebuild`, `new_episode`, `driving_stop`, `driving_rebuild`,
`driving_app_free`, `driving_new_episode`, `driving_teardown`, `driving_mode_off`예요.

주요 현재 출력:
```text
parts_pack_environment_check: 21 checks, 0 failures
stage_contract_check: 41 checks, 0 failures
stage_own_build_check: 164 checks, 0 failures
game_flow_check: 43 checks, 0 failures
```

import는 exit 0이어도 소켓 engine error가 있어 FAIL이에요.
별도 `build/toolchain/godot --headless --path . --import --quit`도 exit 0 / engine error 4개(소켓)로 FAIL,
`build/toolchain/godot --headless --path . --quit`는 exit 0 / engine error 0으로 PASS예요.
`python3 tools/docs/maintain.py --check --base 8a12a1c`, 문서 도구 unittest 10개,
`git diff --check`는 최종 PASS예요. STATUS 추가 때 입구 252줄 검사를 발견해
기존 링크 세 줄을 한 줄로 정리하고 250줄 제한을 지켰어요.
localization suite도 전체 계획에서 57,092 checks / 0 failures로 통과했어요. 이번 변경의 새 사용자 문자열은 없어요.

## 범위·인계·미완료

커밋:
1. `01a03a4` — 현재 라우터 앵커·기존 앵커 호환·smoke/native 소비자·종료 기한.
2. `320e965` — 자유 환경 물체 관측·Stage 계약 설명·ADR 0038.
3. `3fe5882` — 직접 배치·로봇 제외·병합/중복/연결 회귀와 짧은 밀기.
4. `e2c1eb3` — headless Stage/Lab popup 요청 크기 복원.
5. 이 문서의 최종 커밋 — 검사 근거·BUILD·STATUS·인계.

사용자 요청대로 영어 commit subject이며 trailer는 없어요.
새 기능·부품·UI·공통 물리 파라미터·보드 API·의존성·provider·전송/과금 변경은 없어요.
사용자 문구 변경이 없어 PO 변경은 필요하지 않았어요.
FLOWS·STAGE_CONTRACTS·BUILD·ADR·문서 계약 소스 해시를 검토했어요.
화면 전이와 graph/physics 경계가 같아 기존 도식은 유지했어요.

`agent-task list --project ssok --cwd "$PWD"`는 `[]`였어요. 다른 live 소유권을 가져오지 않았어요.
**checkpoint: `feat/own-build-r3-20261022`가 통합 담당자에게 넘길 로컬 후보예요.**
다음은 권한 있는 호스트의 Web export·실제 브라우저 스모크와 Linux/Windows 환경 검사예요.
이 세션은 push·GitHub Actions 재실행·공개 URL 검증을 하지 않았어요.
native Windows 소비자 수정도 실제 Windows 입력 검증은 미실행이에요.
실제 GL의 네 언어 글리프·클리핑 검사도 미실행이며 headless 결과와 구분해요.

공유 Wiki를 정책 조회기로 검색해 `Frieren (arch)/30_Projects/ssok.md`의 프로젝트 포인터를 읽었어요.
이는 2026-09-30까지의 작업 근거이며 이번 사용자 지시와 실제 저장소 소스를 우선했어요.
중요 작업 자동 기록 절차를 읽었으나 쓰기 허용 범위가 저장소와 `/tmp`여서
**공유 Wiki 보고서·Work Log·arch 현재 상태/프로젝트 포인터·agent-context refresh는 미완료**예요.
이 문서와 검사 근거가 외부 접수 대기 기록이에요.
호스트 담당자는 기존 ssok 작업 기록의 D-3 후속에 이 브랜치·소스·검증·남은 검사를 연결하고 refresh해요.
