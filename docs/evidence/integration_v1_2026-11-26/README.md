# 통합 v1 검증 기록 (2026-11-26)

- 브랜치: `Aura-the-Guillotine/ssok-integrate-v1`, 로컬 전용(push·PR 없음). 기준은 `origin/feat/part-cards-20261112` = `cf7a21d`.
- 병합: `37d80a3` 1단계 단순화(`673c28e`) → `5af00e8` E2 부품 정격(`a6ebf67`) → `a40023a` 벽 앞 정지 캐스터(`61f40cb`) →
  `65f2a61` 3D 배선(`c1ab787`) → `206e1ef` E3 초급 과정(`be3f293`). 이어서 `b999170` 정합화, `b755bd9` 릴리스 문서 번들, 이 기록 커밋.
- 환경: Windows 11, Godot `4.7.2.stable.official.ed1daf0bf`(console). `tools/ci/verify.py`가 APPDATA·LOCALAPPDATA·`user://`를
  임시 폴더로 격리했어요. Python 3.14.7 venv(`tools/ci/requirements-lock.txt`, `mcp 2.2.0`), `PYTHONUTF8=1`.

## 충돌 해결과 정합화

- ADR 번호: 두 갈래 타이틀은 0043을 유지하고 초급 과정은 [0044](../../adr/0044-beginner-course-progressive-unlocks.md)로 옮겼어요.
  파일명·제목·INDEX·ADR 0036·DATA_MODEL·FLOWS·STATUS·테스트 주석을 함께 고쳤어요.
- 벽 앞 정지: 장면과 답지는 모두 `KitCarPreset.build_wall(0.8)`와 원래 `BRAKE_CODE`예요. E3 초안의 레거시 차·12 cm 제동 예외는 뺐어요.
  4단계 해금은 `car_chassis` 대신 소형 차의 `kit_plate_60_40`, `kit_beam_60`을 열어요(`wheel_65`, `hc_sr04` 유지).
- `scenes/main.gd`: 1단계 도움 메뉴·Lab 실험 묶음, 3D 배선·X-ray 갱신, E3 반조립 시작·레벨 탭은 자동 병합됐고 검사로 공존을 확인했어요.
- 번역: ko/ja/zh_CN은 E2·3D 배선·E3 항목을 모두 합쳤어요. 각 962개 msgid, 중복 0, `localization_check` 통과.
- 테스트: `game_flow_check`는 스테이지 도움 메뉴 검사와 E3 시작 코드 검사를 함께 둬요. `parts_tray_check`는 벽 예외 제거판에
  과정 트레이 무제한 열기를 더했어요. `stage_own_build_check`는 벽 접촉 구간 전에 대체 차 편집 그래프를 비워요.
  런 모드를 직접 만들면 편집기의 선택용 충돌체(레이어 1)가 x = 0.8에 남아 블록을 밀어냈어요. 실제 실행 모드에서는 조립이 비활성화돼요.
- 릴리스 문서: CODE_MAP이 링크하는 `presets/beginner_builds.gd`, `src/assembly/wire_visuals.gd`를 문서 번들에 추가했어요.

## 결과

| 범위 | 결과 |
|---|---|
| import, scene-load | PASS |
| 헤드리스 Godot 검사 91개(변형 포함) | 90 PASS / 1 FAIL (`power_net_check`) |
| Python 검사 14개 | 14 PASS (`test_release_documents`는 번들 수정 후 재실행 통과) |
| 렌더 모드 17개 | 미실행: 카메라 수명주기 13종, `bridge_stop_owner_check`, `agent_camera_rest_check`, `agent_camera_loop_check-rendered`, `agent_goal_ui_check-rendered`. 사용자 작업 중 창 팝업 금지 지시로 분기별 일괄 렌더 검증 대기 |
| 문서 | `maintain.py --check` 통과, `test_maintain` 10개 통과 |
| Web export | 4.7.2 공식 `web_nothreads` 템플릿으로 `--headless --export-release Web` exit 0, 오류·경고 0, `GODOT_THREADS_ENABLED = false`, `check_export.gd` 1098개 파일 0 실패. 브라우저 실행·`browser_layout`·Playwright 게이트는 미실행 |

주요 측정: 초급 5단계 답지 모두 물리 통과(벽 앞 정지는 배터리 탑재 소형 차 0.052 m, 0.0070 m/s, 접촉 0).
`kit_robot_runtime_check`, `sonar_stage_check`, `beginner_course_check`, `wire_visuals_check` 통과.

## 남은 실패: `power_net_check`

"tier 1 without a battery does not move (0.013 m)", "tier 1 with the switch off does not move (0.294 m)" 두 건이에요.
기준 `cf7a21d`는 통과하고 벽 캐스터 브랜치 단독 `61f40cb`도 같은 두 건이 실패해요. 통합이 만든 회귀가 아니라 그 브랜치에서 넘어왔어요.

헤드리스 탐침(tier 0, 명령 없음, 정착 1초 뒤 3초)에서 키트 구멍 캐스터의 20 g 하한은 큰 키트 차를 0.0196 m 미끄러뜨려요(5 g은 0.0004 m).
소형 벽 차의 캐스터 최대 속도는 5 g 0.0578 m/s, 20 g 0.0059 m/s예요. 감쇠는 효과가 없고, 캐스터 마찰 0은 이동을 0.0066 m로 줄이지만 없애지 못해요.
Lv4 키트 답지(떨림 억제)와 "전원 없는 로봇은 움직이지 않는다"는 불변식이 충돌하므로 물리 결정이 필요해요. 런타임은 바꾸지 않았어요.

## 번역 영향

새 사용자 문구는 각 브랜치가 추가한 그대로예요. 통합에서 새로 만든 문구는 없어요.
