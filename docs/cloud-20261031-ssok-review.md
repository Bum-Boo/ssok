# r3 통합 후보 독립 회귀 검토 (2026-10-31)

Claude Code 클라우드 세션 · 검토 브랜치 `claude/r3-integration-review-zudlk7`.
대상은 `feat/own-build-r3-20261022` `578ca79`, 기준은 `main` `4eb059f`예요.
r3는 main을 그대로 포함한 fast-forward 후보(+95 commit, main 쪽 추가 commit 0)예요.
이 검토는 제품 소스·워크플로·의존성·릴리스 규칙을 바꾸지 않았어요.
추가한 것은 이 보고서, 재현 검사 `tests/review/`, 근거 `docs/evidence/cloud_review_2026-10-31/`,
그리고 새 디렉터리로 인한 `docs/generated/CODE_MAP.md` 한 줄 재생성뿐이에요.
사용자 문구 변경이 없어 PO/번역 변경은 필요하지 않았고, ADR 결정 변경도 없어요.

## 결론

- **P1(데이터 손실·크래시)은 찾지 못했어요.** main이 쓴 프로젝트·진행·설정·과제 JSON은 r3에서 손실 없이 열려요.
- **통합 차단 요소 2개:** r3 CI `verify`가 GitHub와 이 VM 모두에서 같은 두 suite로 실패해요.
  그래서 GitHub의 `build`(Web export·브라우저 게이트)는 r3에서 한 번도 실행되지 않았어요.
  이 VM에서 Web을 직접 export해 보니 smoke·authoring·physics는 통과하고 `browser_learning`은 낡은 기대값으로 실패해요(#17).
- **P2 검증 결함 8개**(기어 축, 떠 있는 환경 부품, 무이동 결승 통과, 환경 부품의 로봇 집계,
  학습자 벽의 스테이지 벽 인정, 컵 관측 비용, browser_layout 부분 성공 exit 0, browser_learning 낡은 기대값)와 다수의 P3가 있어요.
- 93개 부품 데이터·생성기 결정성·번역, 기존 v1/v2 과제 평가 동일성, ADR 0038 판정 규칙,
  browser_layout 앵커 키 생산/소비 일치는 확인됐어요.

## 실행 환경과 명령

Linux x86_64 VM 4 vCPU, Xvfb + Mesa llvmpipe. Godot는 저장소 설치기로 공식 SHA-256을 확인해 설치했어요
(`4.7.2.stable.official.ed1daf0bf`). Python은 3.14.7을 구할 수 없어 **3.13.18**로 `requirements-lock.txt`를 설치했어요.

```sh
python3 tools/ci/install_godot.py --directory <scratch>/toolchain
python3 -m venv <scratch>/venv && <scratch>/venv/bin/pip install -r tools/ci/requirements-lock.txt
xvfb-run -a -s "-screen 0 1600x1000x24" <venv>/python tools/ci/verify.py --godot <godot> --python <venv>/python --output <out>
xvfb-run ... tools/ci/verify.py ... --match '<실패 suite 정규식>'     # 단독 재실행
python3 tools/docs/maintain.py --check
```

| 실행 | main `4eb059f` | r3 `578ca79` |
|---|---|---|
| 전체 `verify.py` (두 브랜치 동시 실행, 부하 있음) | 72 checks / **1 fail** `motion_lab_ui_check` | 115 checks / **5 fail** |
| r3 실패 단독 재실행 | — | `agent_camera_loop_check-rendered`·`camera_evaluator_lifecycle_check-normal_stop` PASS, `agent_camera_rest_check`·`agent_goal_ui_check-rendered`·`camera_evaluator_lifecycle_check-drive_stop` FAIL |
| `motion_lab_ui_check` 단독 반복 | PASS, PASS, FAIL(125 s) / 이전 단독 PASS | PASS, PASS, PASS / 이전 단독 FAIL |
| GitHub CI (참고, 읽기 전용 조회) | run 36737314345 success | run 39797157897: 115 / **2 fail** (`agent_camera_rest_check` 12중 8, `camera_evaluator_lifecycle_check-drive_stop`) |
| `maintain.py --check` | — | PASS (검토 추가 후 CODE_MAP 재생성 필요 → `--write` 후 PASS) |

- 두 브랜치 공통의 `motion_lab_ui_check` 간헐 실패는 r3 회귀가 아니에요(약 1/4, 125 s 대기 후 두 항목 실패).
- r3의 `agent_camera_rest_check`·`…drive_stop` 실패는 GitHub CI와 이 VM에서 같아요. D-3 인계(115/89/26)는 이 둘을
  "GL 디스플레이 초기화" 환경 실패로 분류했지만, 실제 GL이 있는 Linux에서는 **환경이 아니라 검사 자체가 실패**해요.
  메시지: `Camera/action settles within its finite budget`, `Ready camera drifts at most 2mm over 10 seconds`,
  `LIFECYCLE_FAIL: motor action reaches measured rest`. 원인 분석은 이번 초점(카메라 루프 ADR 0029) 밖이라 하지 않았어요.
- `agent_goal_ui_check-rendered`는 GitHub에서 PASS, 이 VM에서는 2회 FAIL(`Operator claims current ready goal`)이라 환경 민감으로 분류해요.
- 이 검토 추가 후 `verify.py --list`는 그대로 115개예요(`tests/review/`는 비재귀 glob 밖). 앱 테스트를 새로 통과시킨 것이 아니에요.

Web export·브라우저 게이트 결과는 아래 "Web export" 절에 따로 적어요.

## 발견 목록

분류: **V** 검증 결함(재현됨) · **S** 정적 위험(재현 안 함) · 기존 = main에도 있음. 줄 번호는 r3 `578ca79` 기준이에요.

### P2

| # | 위치 | 트리거 → 관측 → 기대 | 분류 | 최소 수정 방향 |
|---|---|---|---|---|
| 1 | `tests/agent_camera_rest_check.gd`, `camera_evaluator_lifecycle_check.gd` drive_stop | r3 CI verify → 115 중 2 FAIL(GitHub·VM 동일) → green | V (게이트) | 카메라 정착 예산/측정 정지 조건을 실제 llvmpipe에서 원인 분석. skip 금지. 통과 전 통합 보류 |
| 2 | `src/runtime/gear_constraint.gd:10,20`, `src/runtime/run_mode.gd:494-497` | 기어를 모터 장착면·앵글 브래킷 밑면에 볼트 결합(병합 body) → 제약 축이 housing body 기준 BACK, 출력 0.0000 rad/s(기대 −2.378) → 기어 부품 자체 축 | V `gear_axis_cluster_check` 9/4 | `_make_gear`에서 `axis_local = housing.global_basis.inverse() * (part.transform.basis * Vector3.BACK)`(모터 `run_mode.gd:290`과 동일), `_angles` 기준축도 부품 프레임에서 |
| 3 | `scenes/main.gd:1013` + 고정(anchored) 환경 부품 | 트레이에서 ramp_10/20·cup·line 추가 → Run에서 바닥 위 30 mm 공중 고정 → 바닥에 놓임 | V `tray_environment_floor_check` 8/4 (base/board 동일 현상은 기존) | 고정 부품은 mesh 바닥을 `FLOOR_TOP`에 맞춰 생성 |
| 4 | `src/core/stage_catalog.gd:9`, `src/runtime/stage_evaluator.gd:186-213` | finish-line에 `kit_weight_100` 하나를 x=0.8에 두고 `sleep(1)` Run → `success`, 독립 클리어 기록 → 실제 주행 요구 | V `stage_aggregate_review_check` | 출발 구역 또는 시작→끝 변위 조건 추가. WORK_SUMMARY_D가 출발 구역 제한을 미보장으로 적었지만 결과(무이동 클리어)는 ADR/계약에 없어요 |
| 5 | `src/runtime/stage_evaluator.gd:186-191` | 정답 차 + `kit_env_line_straight`(x=−0.1) → min_x −0.12 `not_met` → 환경 부품은 로봇 집합 제외 | V 동 검사 | `environment_role`/`surface_marker` 부품을 `_robot_indices`에서 제외(`_part_category`와 같은 기준) |
| 6 | `stage_evaluator.gd:205-208`, `scenes/main.gd:1066-1078` | wall-brake에서 정지 블록 앞 7 cm에 트레이 `stage_wall` 배치 → `success`(wall_distance 0.0700) → 레벨 StaticBody 벽만 인정 | V 동 검사 | `environment_walls`가 있으면 그래프 벽 무시 및/또는 Stage 트레이에서 `stage_wall` 숨김 |
| 7 | `src/runtime/run_mode.gd:607-619`, `449-470` | `cup_count` 규칙이 있으면 매 physics tick `cup_object_count()`가 비물체 부품마다 링크 고정점 반복 → 유휴 VM에서 car 0.65 ms, modular 14.6 ms, kit humanoid 184부품 **1075 ms/호출**, 256 사슬 23 s → 프레임 예산 16.7 ms 내 | V `cup_cost_presets_check`, `cup_observer_check` | build 시 MECH 링크 union-find로 한 번 계산, RID는 Dictionary 집합. 도달 경로는 가져온 v2 과제뿐(내장 과제·편집기 선택지 없음) |
| 17 | `tools/ci/browser_learning.py:91,97` | r3 Web export에 CI와 같은 게이트 실행 → raise-flag 답지 5부품(ADR 0036의 깃발 추가)인데 4 기대, 지표 `height`/`x,upright`/`sonar_distance,speed` 기대 → 실제 `max_height`/`min_x`/`wall_distance,robot_speed`로 assertion 실패 | V(Web 실측) | 기대값을 5부품과 현재 내장 과제 지표로 갱신. #1이 고쳐지면 CI `build`에서 바로 드러나는 다음 차단 요소예요 |
| 8 | `tools/ci/browser_layout.gd:36-37` | `_native_routes` 안 GDScript 런타임 오류 → 코루틴 반환, `_failed` false, 부분 JSON 작성·exit 0 → nonzero | V(검토 subagent의 오류 주입 사본, 커밋 안 함) | `_native_routes` 끝 완료 플래그 확인 + 쓰기 전 필수 키 집합 검사. `build.py`의 `SCRIPT ERROR:` 정규식이 빌드에선 막지만 문서의 수동 명령은 exit code만 봐요 |

### P3

| # | 위치 | 내용 | 분류 | 수정 방향 |
|---|---|---|---|---|
| 9 | `src/core/stage_progress.gd:27` | 작업대 저장 `JSON.stringify(data, "  ", true)`에 full_precision 누락 → kit humanoid part 44 변환 −3.82137e-15 → −3.82e-15. 물리 영향 없음, 재개 graph/fingerprint 불일치 | V `save_compat_check` 60/1 | 네 번째 인자 `true` |
| 10 | `scenes/main.gd:2033-2041` | 코드 64 KiB 초과·256부품 초과 등에서 Back/목록/다음이 영구 거부, 이유 없음. Lab의 "Leave without saving" 같은 출구 없음 | V `stage_aggregate_review_check` | 원인 표시 + 확인 후 저장 없이 나가기 |
| 11 | `scenes/main.gd:2013-2014`, `src/ui/project_panel.gd:315` | `SsokTheme.font_size(420)`은 폭이 아니라 글꼴 등급(28×scale) → 확인창이 최소 200 px 폭으로 표시 | 정적 확인 + `solution_confirm_as_shown`(200×136) | `roundi(420 * SsokTheme.ui_scale)` 등 실제 폭 사용. 네 언어 줄바꿈 재확인 필요 |
| 12 | `tools/ci/browser_layout.gd:286-297`, `81-83`, `208-211`, `111-117` | 확인창 재중앙화로 `game_confirm_*` Y 516 vs 실제 528(버튼 38 px, 여유 ~7 px); 기존 `stage_confirm` 484 vs 498(기존); 클리어 후 스테이지 카드 Play 최대 15 px 이동; 비격리 데이터에서 프로젝트를 먼저 저장한 뒤 거부 | V(`solution_confirm_as_shown`, `stage_map_after_clear`) | 확인창은 재-popup 없이 OK 버튼 측정; 진행 상태별 앵커 또는 고정 카드 높이; `library.item_count == 0` 선검사 |
| 13 | `tools/blender/check_construction_kit.py:127-128`, `make_construction_kit.py:111` | 새 `functional_v1` 17부품에 OBJ·생성 분기 없음 → `FileNotFoundError obj/kit_passive_hinge.obj` | V(검사 스크립트 함수 직접 실행; Blender 미설치로 생성기는 정적) | `geometry.type == "functional_v1"` 건너뛰기. `CONSTRUCTION_KIT.md:176`의 30부품 서술 갱신 |
| 14 | `src/core/stage_progress.gd:9-15` | 손상된 `progress.json` → 빈 기본값 → 다음 저장이 모든 클리어와 **모든 스테이지 작업대**를 덮어씀 | V(기존, 영향 범위는 r3에서 커짐) | 파싱 실패 파일을 `.corrupt-<time>`으로 보존하거나 저장 거부 |
| 15 | `src/core/stage_progress.gd:40`, `58` | `cleared` 값 하나가 bool이 아니면 비교 스크립트 오류로 클리어 전체가 안 보임 | V(기존) | `typeof(v) == TYPE_BOOL and v` |
| 18 | `assets/stage_runtime_identity.json`, `tools/ci/stage_identity.py:18` | 커밋된 manifest가 낡아 매 build가 이 파일을 다시 써서 `release.json`이 항상 dirty로 표시돼요(r3 30여 항목, main도 8줄 차이로 기존). 런타임은 소스 실행 시 실제 해시로 덮고 export 전 재생성하므로 판정 영향은 없어요 | V(기존, r3에서 확대) | 통합 commit에서 `python3 tools/ci/stage_identity.py` 결과를 커밋하거나 dirty 판정에서 생성 파일 제외 |
| 16 | `src/runtime/run_mode.gd:643` | 로봇이 공을 컵 벽에 밀어 1.003 mm 침투 → 0개로 집계(직접 배치도 재현) | V(경계 사례, 안전 측) | 접촉면 여유를 설정값의 소폭 배수로. 물리 파라미터 자체는 ADR 0038상 유지 |

### 정적 위험 (재현 안 함)

| # | 위치 | 내용 |
|---|---|---|
| S1 | `stage_progress.gd:20-30` | `.tmp`만 남은 경우 복구하지 않고 빈 진행으로 읽어요(TMP-only 상태는 재현). Windows `rename_absolute`의 삭제 후 이동 비원자성은 엔진 소스 미확인 |
| S2 | `stage_evaluator.gd:213` | 집계 경로가 `bodies[index]`의 `is_instance_valid`를 확인하지 않아요(색인 경로 148행은 확인). 해제된 body면 `physics_unavailable` 대신 오류 |
| S3 | `run_mode.gd:521` | 기어용 추가 shaft body(layer 3)가 `bodies`에 없어 `robot_rids()`에서 빠져요. 라인 센서/소나가 자기 축을 볼 수 있어요 |
| S4 | `src/ui/stage_goal_display.gd:122-123` | `cup_count` 라벨·단위가 없어 네 언어 모두 원문 키 `cup_count`가 보여요(가져온 과제만) |
| S5 | `tools/godot/make_levels.gd:163` | 생성기는 짝수 콘을 건너뛰지만 커밋된 `stages/finish_line/level.tscn`은 숨김 노드로 유지. 재생성 시 `res://stages/` 해시 기반 증명값이 바뀌어요 |
| S6 | `assets/construction_kit/catalog.json` | 새 17항목 중 12개의 `size`/`center`가 복사값(예: `kit_wheel_90` 0.04×0.02×0.004 vs mesh 0.09×0.09×0.02). 런타임 미사용, Blender 검사만 사용. LED/버튼 mount 4 mm 뒤, 기어 축 포트 4–6 mm 밖, 추 밀도 12–15 g/cm³도 표시상 문제 |
| S7 | `browser_layout.gd` watchdog 45 s | 이 VM headless 19 s, xvfb 렌더 실행은 47 s에 watchdog 실패(기한 상향 시 74 s 완료) |
| S8 | `docs/evidence/` | 추적 크기 58 MiB → 226 MiB. Windows 사용자 홈 경로 문자열이 main 2개 → r3 199개 파일. 비밀값 패턴(`sk-`, `ghp_`, 개인키)은 0건 |
| S9 | 다운그레이드(참고) | r3 v2 진행을 main의 `mark_cleared`가 v1로 다시 써 `solutions`/`workspaces`를 버려요. 새 부품·`flag_mount` 프로젝트와 새 지표 과제는 main에서 열리지 않아요. 통합 후 되돌릴 때만 해당 |

## 확인된 정상 (already covered / non-issue)

- **저장 호환:** main 프리셋 10종으로 main이 쓴 프로젝트가 r3에서 파싱되고 그래프가 byte 동일하게 재인코딩돼요.
  `project_store.gd`·`MotionSnapshot` 변경 없음. `arm_link` 링크는 포트 id로 연결돼 `flag_mount` 추가가 기존 그래프를 바꾸지 않아요.
  v1 진행 클리어 보존·v2 승격·미지 키 보존·쓰기 실패 시 파일 미생성 확인. 답지 배지 규칙은 `stage_own_build_check`가 이미 덮어요.
  main `interface.cfg`는 그대로 로드(명시 "system"도 유지).
- **기존 스테이지:** main 내장 과제 3개를 r3 Lab에서 각자의 정답으로 평가한 값이 두 브랜치에서 같아요
  (`legacy_builtin_check` 6/0, 높이 0.16496, x 0.50652, sonar 7.128 등). 빈 그래프·벽만 있는 그래프는 `target_missing`,
  비유한 값은 `nonfinite_physics`. 세 답지 그래프는 실제 물리로 클리어. 복원은 코드를 실행하지 않고, 답지/리셋/나가기는 실행 id를 무효화해요.
  삭제된 테스트 파일 없음, 바뀐 단언은 ADR 0030/0036과 일치.
- **부품 팩:** "93"은 트레이/`MotionSnapshot._catalog()`의 PartDef 총수(main 75 → r3 93: 깃발 1 + kit 17)예요.
  `catalog.json`은 25 → 42 항목. 93개 모두 로드·id 유일·질량 양수·포트 id 유일, 42 항목의 `.tres`/mesh/포트/기어비/반지름/anchored 일치.
  `make_functional_parts.gd`·`make_stage_flag.gd` 재생성 byte 동일. 93개 부품명 ko/zh_CN/ja 번역(fuzzy 없음), `localization_check` 57,092/0.
  `parts_catalog_data_check`의 10 실패는 main부터 있던 humanoid 내장 재질이에요. 경사로 winding 정상.
- **ADR 0038:** 객체→객체→구조 사슬 제외, 전기 배선만 있으면 자유, freeze 제외, 겹친 컵에서 RID 1회, 병합 객체 전원 내부 요구,
  45° 상자 꼭짓점, 옆으로 눕힌 컵, 회전 구의 해석적 범위 모두 ADR대로예요. `parts_pack_environment_check`는 `--fixed-fps 60` 5회와 없이 1회 모두 byte 동일,
  48조건 민감도 실험에서 픽스처 속도 35는 12/12 진입·유지. 정착 여유가 0.4–0.6 mm라 #16과 연결돼요.
  잘못된 혼합 kind 링크의 비대칭은 편집기가 만들 수 없어 non-issue.
- **browser_layout:** headless r3 exit 0 / 90 anchors / 18.8–19.2 s, main 44 anchors / 4.7–5.0 s, 각 2회 `cmp` 동일.
  제거된 키 0, 추가 46. 소비자 6개(73회 사용)의 모든 키가 r3에서 생산돼요. 90개 앵커 모두 실제 hover 대상이 자기 컨트롤이에요.
  누락·숨김·화면 밖·출력 불가·정지(watchdog 45 s)·legacy 오류는 모두 exit 1. 60 s 동기 hang은 `build.py`가 종료하고 로그를 남겨요.
- **CI·버전:** `ci.yml`의 xvfb 추가는 적절해요. `project.godot`/export 버전 0.3.1은 r3 계보의 태그 `v0.3.1`(`b3570c6`)과 일치해요.

## Web export

GitHub r3 CI는 `verify` 실패로 `build`가 skip돼, 이 VM에서 공식 템플릿(SHA-256 확인)을 설치해 r3 Web을 직접 export했어요.

```sh
python3 tools/ci/install_godot.py --directory <scratch>/toolchain --templates
<venv>/python tools/ci/build.py --godot <godot> --platforms Web --version 0.0.0-review --output <scratch>/build-r3
<venv>/python tools/ci/<gate>.py --directory <scratch>/build-r3/web --output <out> --executable /opt/pw-browsers/chromium
```

| 단계 | 결과 |
|---|---|
| `build.py --platforms Web` (layout 포함) | exit 0, 46 s, ZIP 253 MB. `release.json`은 `dirty_worktree`/`source_changed_during_build` true(#18) |
| `browser_smoke.py` | **PASS** 76 s (Title → Stage → 답지 확인 → Run → Reset) |
| `browser_authoring.py` | **PASS** 259 s (IndexedDB 저장·재로드·JSON 내보내기/붙여넣기·블록) |
| `browser_physics.py` | **PASS** 102 s |
| `browser_learning.py` | **FAIL** 47 s → #17 |
| `browser_learning.py` 두 단언만 출력으로 바꾼 임시 사본(커밋 안 함) | exit 0. raise-flag `max_height` 0.1849, finish `min_x` 0.5018, wall-brake `wall_distance` 0.0694로 **세 답지 모두 실제 Web 물리에서 클리어**, 내보낸 과제 10부품 |

즉 r3 앱은 Web에서 세 스테이지를 통과하지만, CI의 네 번째 브라우저 게이트는 낡은 기대값 때문에 실패할 거예요.
Chromium은 사전 설치된 `/opt/pw-browsers/chromium`(headless, 소프트웨어 WebGL)이에요. 스크린샷 육안 검토는 하지 않았어요.

## 이 VM에서 검증하지 못한 것

- Windows·macOS 실기기, `native_ui.ps1` 입력, 서명/설치 파일, 실제 GPU 글리프·클리핑(네 언어 × 두 테마).
- Python 3.14.7 정확 버전(3.13.18 사용). Blender 생성 경로(미설치).
- 실제 외부 서비스·provider 호출(모두 mock, 호출 없음). GitHub Pages 미리보기는 실행하지 않았고,
  r3 preview run 39797157788 실패는 Pages 빌드 `queued` 10분 대기 시간 초과였어요(배포 push 자체는 수행됨).
- 카메라 실패 두 suite의 근본 원인, 장시간 수동 플레이.

## 다음 단계 (소유자)

1. 통합 전 #1(CI 두 suite)을 원인 분석해 green으로 만들고, #17 기대값을 갱신한 뒤 GitHub `build` 잡의 Web export·브라우저 게이트 결과를 확인해요.
2. P2 #2–#6은 학습자에게 보이는 판정·물리 오류예요. 각각 `tests/review/`의 재현 검사를 고친 뒤 `tests/*_check.gd`로 옮겨 회귀 검사로 만들어요.
3. #7(컵 비용)은 가져온 과제 경로를 열기 전에 고쳐요. #8은 빌드 외 수동 사용을 위해 exit code를 바로잡아요.
4. P3 #9–#16·#18과 S1–S7은 다음 정리 묶음으로, #11은 네 언어 확인창 스크린샷과 함께 확인해요.
5. S8: evidence 크기 정책과 개인 경로 문자열 제거 여부를 결정해요. WORK_SUMMARY_D3의 "환경 실패 26" 분류를 실제 CI 결과로 정정해요.

## 재현 검사와 근거

- 재현 검사·실행 방법·기대 결과: [tests/review/README.md](../tests/review/README.md). 커밋된 픽스처는 main의 writer로 만든 합성 데이터예요.
- 실행 로그 요약·SUMMARY: [cloud_review_2026-10-31](evidence/cloud_review_2026-10-31/README.md).
- 검토는 영역별 subagent 5개(저장 호환, 부품 팩, 빈 작업대 스테이지, browser_layout, 컵 관측)로 병렬 수행했고,
  핵심 결함(#2·#3·#4–#7·#8·#9·#11)은 소스에서 직접 다시 확인했으며 재현 스크립트는 유휴 상태에서 이 브랜치로 재실행했어요.
- 원격 조회는 GitHub Actions run/job 로그 읽기만 했어요. 다른 브랜치·PR·이슈는 변경하지 않았어요.
