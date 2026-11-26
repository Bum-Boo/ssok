# 작업 D-2 — B-2·C 통합과 검사 정리

2026-10-22 · Codex · `feat/own-build-r2-20261022`의 로컬 통합 후보예요.
시작 HEAD는 `1ea644a50e8b2e4dcc822e9e42a981849c9ca0e2`, 시작 dirty는 없었어요.
1~5번 커밋의 앱·도구 소스는 `f8a2f31ca6f0c7e37e2d9477268a3ef8b7d2f524`예요.
뒤의 최종 커밋은 D 검사 한 곳의 고정 부품 수 보완, 검사 기록과 문서 인계를 포함해요. GitHub push·main 병합·공개 배포는 하지 않았어요.

## 사용자 문제와 바뀐 것

빈 작업대 D에 기능 부품 B-2와 브랜치 미리보기 C가 따로 있어 사용자가 한 후보로 플레이할 수 없었어요.
기존 graph 정본·실제 관측 판정·명시적 실행 원칙을 유지하며 두 브랜치를 병합했어요.
카탈로그는 D 81종 + B-2 12종 = 93종(중복 ID 0), 키트 42종이에요.
Environment(환경/环境/環境)에서 선 조각 2종·경사판 2종·공·컵을 고르고,
라인 센서·접촉 버튼·LED는 Electronics 15종에 포함돼요. Construction kit 접근은 유지해요.
workshop_ui의 81종 고정 검사 두 곳과 stage_own_build의 한 곳은 실제 `MotionSnapshot._catalog().size()`로 유도했어요.

`cup_count`는 Stage v2의 `part_id="*"`, `target_index=-1`에서만 유효해요.
기존 `RunMode.cup_object_count()`의 컵 내부 자유 강체 수를 읽고 기존 min/max/hold 판정을 사용해요.
카탈로그별/인덱스/v1 선택은 거부하며 새 스테이지는 없어요. 물리·보드 API·블록 파서는 병합 후 수정하지 않았어요.
새 의존성·제공자·전송·과금 변경, UI 레이아웃·글꼴·색 변경, 집게 재시도는 없어요.

## 항목별 직접 커밋과 충돌 해결

1. `0e97859` — B-2 두 부모 머지(`1ea644a`, `e32f112`).
2. `bf6ebd5` — C 두 부모 머지(`0e97859`, `224ea52`), 충돌 0개.
3. `73c0ede` — Environment와 Electronics 분류·네 언어·실제 필터 검사.
4. `7a2f5e4` — 전체 부품 수 유도와 Electronics 기대 수 갱신.
5. `f8a2f31` — 컵 집합 지표·Stage 계약과 유효성/관측 회귀 검사.
6. 이 문서가 포함된 커밋 — 추가 발견한 D 트레이 고정 수 보완·전체 검사 기록·STATUS·명시적 인계.

새 커밋 제목은 영어이며 사용자 요청대로 트레일러는 없어요.
C 요약의 당시 미커밋/읽기 전용 설명은 과거 기록이며, 이 작업에서는 로컬 ref `224ea52`를 병합했어요.

B-2 충돌은 `assets/locales/{ko,ja,zh_CN}.po`, `docs/AUTHORING.md`, `docs/adr/INDEX.md`,
`docs/context.json`의 6개 파일이었어요. PO의 D/B-2 추가 항목과 AUTHORING 두 절을 모두 보존했어요.
공통 조상 대비 각 부모의 실제 번역 변경(D 71개, B-2 23개/언어)은 세 PO 모두 손실 0개예요.
context의 경로·라우트·symbol·계약 소스 키를 합친 뒤 실제 병합 소스와 문서를 검토해 해시를 갱신했어요.
B의 ADR 0035와 D의 0036을 유지하고 B-2의 0031을 0037로 옮겼어요.
B-2가 확장하는 B 번호도 0030→0035로 맞추고 링크·생성 색인을 갱신했어요.

자동 머지된 `tools/ci/build.py`는 양 부모 참조의 합집합(98 경로)을 유지해요.
D 추가 5개와 B-2 런타임 4개가 모두 있으며 실제 문서 압축/해제 검사도 통과했어요.
DATA_MODEL의 B-2 리소스/장치 절과 D Stage/저장 절, FLOWS의 장치/Stop과 D 진입/판정 절을 확인했어요.
CODE_MAP의 런타임 26개 및 새 클래스 4개도 생성기로 대조했어요.
머지 import에서 누락된 B-2 재고 검사 `.gd.uid`가 생성되어 B-2 머지에 포함했어요.
`.github/workflows/preview.yml`은 C의 bytes와 같아요. YAML 파싱과 shell 블록 7개의 `bash -n`도 통과했어요.

## 실제 검사 출력

엔진은 `build/toolchain/godot`, `4.7.2.stable.official.ed1daf0bf`이며 Linux headless·fixed-fps 60이에요.
각 실행은 `/tmp`의 XDG data/config/cache를 격리했어요. 표준 명령:

```sh
python3 tools/ci/verify.py --godot build/toolchain/godot --output build/d2-strict
```

D와 같은 mock HTTP 서버 생성의 `PermissionError: [Errno 1] Operation not permitted`로 중단됐어요.
이 시도는 전체 suite 실행으로 세지 않아요. D의 진단 도구가 표준 계획의 모든 명령·timeout·오류 gate를 재사용해요.

```sh
python3 docs/evidence/own_build_2026-10-22/run_checks.py --output build/d2-final
```

**최종 115 suites: 89 PASS / 26 FAIL. 전체 통과를 주장하지 않아요.**
[최종 결과·소스·기준선 비교](evidence/own_build_d2_2026-10-22/results.json)와
[재현·원문 로그 위치](evidence/own_build_d2_2026-10-22/README.md)를 남겼어요.
D에서 통과한 83 suites와 B-2에서 통과한 79 suites는 전부 통과하며,
B-2에서 실패했던 workshop_ui도 통과했어요. D의 환경 실패 26개와 이름 집합이 같고 새 실패는 0개예요.
전체 목록 `tools.ci.verify.checks()`와 실행 결과의 이름 115개가 정확히 일치해요.

첫 전체 실행은 [115 suites / 88 PASS / 27 FAIL](evidence/own_build_d2_2026-10-22/initial_results.json)이었어요.
D의 `stage_own_build_check`도 81종을 고정해 세 스테이지의 트레이 assertion 3개가 실패했어요.
답지의 실제 물리 성공은 당시에도 세 가지 모두 통과했어요. 이 한 곳도 실제 카탈로그 수로 유도하고
전체 115개를 재실행해 통과했어요. 첫 실패를 삭제하거나 최종 결과와 합산하지 않았어요.

최종 실행 전후 추적 앱·자산·검사·도구·워크플로 1,008개 파일의 SHA-256 불일치는 0개예요.
manifest SHA-256: `df7adc65cbc15659c1615d6fbfdf6629e4cb277ee0ccf2ccac365f1311aa4892`.
최종 앱 소스는 위 `f8a2f31`이며 최종 검사 소스의 유일한 후속 변경은
`tests/stage_own_build_check.gd`(SHA-256 `c850b3daf59da42f852a8df2a36cb6f729cb6fa09a4ab384aff0b9b21dd7d2fc`)예요.
최종 커밋에는 이 검사 보완도 포함해요. 원문 명령·로그·JUnit·파일별 해시는 `build/d2-final/`에 있어요.

관련 실제 출력:

```text
stage_own_build_check: 164 checks, 0 failures
stage_contract_check: 41 checks, 0 failures
stage_authoring_check: 42 checks, 0 failures
stage_ui_check: 36 checks, 0 failures
game_flow_check: 43 checks, 0 failures
parts_pack_gears_check: 36 checks, 0 failures
parts_pack_line_check: 13 checks, 0 failures
parts_pack_button_check: 11 checks, 0 failures
parts_pack_led_check: 19 checks, 0 failures
parts_pack_environment_check: 14 checks, 0 failures
parts_pack_inventory_check: 265 checks, 0 failures
parts_freedom_runtime_check: 28 checks, 0 failures
parts_freedom_blocks_check: 51 checks, 0 failures
parts_freedom_mechanics_check: 79 checks, 0 failures
parts_freedom_workshop_check: 50 checks, 0 failures
workshop_ui_check: 495 checks, 0 failures
scene_workshop_ui_check: 382 checks, 0 failures
workshop_compact_check: 2320 checks, 0 failures
workshop_emphasis_check: 6816 checks, 0 failures
workshop_goal_space_check: 10032 checks, 0 failures
workshop_goal_observation_check: 4392 checks, 0 failures
workshop_presentation_check: 504 checks, 0 failures
construction_kit_check: 13655 checks, 0 failures, 217 catalog holes, 182 humanoid parts, 29 bridge parts
localization_check: 57092 checks, 0 failure(s)
```

머지 직후 `python3 tools/docs/maintain.py --check` PASS,
`localization_check: 57074 checks, 0 failure(s)`였어요.
Environment 추가 후 번역 57,092개 PASS, PO의 새 키 3언어 등록과 실제 4언어 필터 membership도 확인했어요.
기존 UI suites는 네 언어·두 테마·확대/compact·포커스 검사를 유지해요.
컵 계약 검사는 v2/전체 선택·직렬화·잘못된 선택·보드/센서 없는 시작·0/1 실제 관측·hold·teardown을 확인해요.

- import: exit 0이지만 editor TCP 소켓 오류가 있어 FAIL이에요.
- scene-load: exit 0 / engine error 0. 별도 `build/toolchain/godot --headless --path . --quit`도 exit 0 / 오류 0이에요.
- `python3 tools/docs/maintain.py --check`: PASS.
- `python3 -m unittest discover -s tools/docs -p 'test_*.py'`: 10 tests / OK.
- `python3 -m unittest tests/test_release_documents.py`: 1 test / OK, 실제 압축·해제한 문서 링크 확인.
- `git diff --check`: PASS. C workflow bytes 동일/YAML/7 shell blocks 문법 PASS.

환경 실패의 전체 목록:

| 환경 | 수 | 실패 suite |
|---|---:|---|
| GL 디스플레이 | 17 | `agent_camera_loop_check-rendered`, `agent_camera_rest_check`, `agent_goal_ui_check-rendered`, `bridge_stop_owner_check`, 아래 lifecycle 13개 |
| 소켓/mock | 7 | `import`, `motion_lab_ui_check`, `tests-desktop_client_check.py`, `tests-desktop_session_check.py`, `tests-test_pickup_bridge.py`, `tools-motion_lab-test_races.py`, `tools-motion_lab-test_service.py` |
| 기존 Python 패키지 | 2 | `tests-motion_mcp_check.py`(mcp 없음), `tools-rl_lab-test_rl_lab.py`(mujoco 없음) |

`camera_evaluator_lifecycle_check-` 접미사 13개는 `normal_stop`, `drive_stop`, `teardown`, `mode_off`,
`app_free`, `rebuild`, `new_episode`, `driving_stop`, `driving_rebuild`, `driving_app_free`,
`driving_new_episode`, `driving_teardown`, `driving_mode_off`예요.
렌더 검사는 X11/Wayland 초기화 실패이며, 소켓 검사는 생성 권한 거부예요. 모든 실패는 D와 같아요.


## 못 한 것과 다음 담당

실제 GL의 네 언어 글리프·클리핑 검수, Web/desktop export와 브라우저 플레이, 실제 Actions/Linux CI,
Pages API 게시와 URL 접속은 미실행이에요. 로컬 headless 기하/번역 검사를 실제 렌더 검수로 세지 않아요.
집게는 B-3이며 이번 후보에 없어요. 임의 로봇의 모든 선 추종·기어 연쇄·경사 주행 성공도 보장하지 않아요.
20° 경사판의 검증 fixture는 90 mm 바퀴이며, 65 mm 기본 차체는 걸릴 수 있어요.

`agent-task list --project ssok --cwd "$PWD"`는 `[]`였어요. 사용자 지정 작업실만 수정했고
다른 live 작업은 인수하지 않았으며 GitHub 이슈/PR 생성·메시지 전송은 하지 않았어요.
**checkpoint: `feat/own-build-r2-20261022`를 통합 담당자에게 인계해요.**
담당자는 이 브랜치를 push한 뒤 Linux 전체 CI와 Preview workflow 결과를 확인해요.
C 설정이 유지될 때 예상 주소는
`https://bum-boo.github.io/ssok/preview/feat-own-build-r2-20261022-eda7aa6889f8/`예요.
예상 경로를 실제 게시 완료 URL로 보고하지 않아요. 익명 플레이와 기존 사이트 root 보존을 확인해야 해요.

공유 Wiki 조회는 정책 조회기를 거쳐 `Frieren (arch)/30_Projects/ssok.md`의 프로젝트 포인터를 읽었어요.
날짜 있는 과거 근거로만 사용하고 이번 요청·저장소 소스를 우선했어요.
중요 작업 자동 기록 규칙을 확인했으나 허용 쓰기 범위가 저장소·`/tmp`뿐이라
**공유 Wiki/Work Log/arch Now·프로젝트 포인터 기록과 agent-context refresh는 미완료**예요.
이 문서와 검사 근거가 접수 대기 기록이에요. 호스트 담당자는 기존 ssok 노트/로그의 같은 작업을 갱신하고,
앱 소스·검사 결과·이 브랜치와 남은 배포/GL 검수를 연결한 뒤 `agent-context refresh`를 실행해요.

DATA_MODEL·FLOWS·AUTHORING·STAGE_CONTRACTS·LOCALIZATION·STATUS·context·ADR 색인을 검토/갱신했어요.
기존 실행/Stop/저장 전이는 같아서 도식은 유지했고, 분류/컵 관측의 추가만 본문에 적었어요.
새 UI 키는 Environment 하나이며 영어 원문과 ko/zh_CN/ja PO·functional inventory를 함께 갱신했어요.
나머지 문서/검사 정리는 추가 번역이 필요하지 않았어요.

## 사용자가 해 볼 것 5줄

1. Lab의 빈 작업대에서 섀시·micro:bit·드라이버·모터·바퀴로 차동 주행 로봇을 만들어요.
2. Electronics의 라인 센서를 아래로 향하게 붙이고 Wiring에서 보드의 빈 핀에 연결해요.
3. Environment의 검은 직선 조각을 바닥에 이어 완만하게 굽은 길을 만들고 센서를 선 가장자리에 맞춰요.
4. Blocks/Code에서 `LineSensor(배선한 핀).is_dark()` 분기로 양쪽 모터의 빠름/느림을 바꾸고 짧게 기다리며 반복해요.
5. Run으로 선 추종을 보고 Stop 후 속도·센서 높이·선 배치를 한 가지씩 바꿔 다시 해 봐요.
