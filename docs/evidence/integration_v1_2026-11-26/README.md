# 통합 v1 검증 기록 (2026-11-26)

- 브랜치: `Aura-the-Guillotine/ssok-integrate-v1`, 로컬 전용(push·PR 없음). 기준은 `origin/feat/part-cards-20261112` = `cf7a21d`.
- 병합: `37d80a3` 1단계 단순화(`673c28e`) → `5af00e8` E2 부품 정격(`a6ebf67`) → `a40023a` 벽 앞 정지 캐스터(`61f40cb`) →
  `65f2a61` 3D 배선(`c1ab787`) → `206e1ef` E3 초급 과정(`be3f293`). 이어서 `b999170` 정합화, `b755bd9` 릴리스 문서 번들, `1e5b99d` 첫 기록,
  `1ad5eaf` 정지 물리 수정(주인 결정 항목 44), 이 기록 갱신 커밋.
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

## 결과 (`1ad5eaf` 기준)

| 범위 | 결과 |
|---|---|
| import, scene-load | PASS |
| 헤드리스 Godot 검사 91개(변형 포함) | 91 PASS |
| Python 검사 14개 | 14 PASS |
| 반복 확인 | `power_net_check` 3/3, `kit_robot_runtime_check` 3/3 PASS. 세 번 모두 벽 0.05179 m, 0.00147 m/s, 접촉 0 |
| 렌더 모드 17개 | 미실행: 카메라 수명주기 13종, `bridge_stop_owner_check`, `agent_camera_rest_check`, `agent_camera_loop_check-rendered`, `agent_goal_ui_check-rendered`. 사용자 작업 중 창 팝업 금지 지시로 분기별 일괄 렌더 검증 대기 |
| 문서 | `maintain.py --check` 통과, `test_maintain` 10개 통과 |
| Web export | 4.7.2 공식 `web_nothreads` 템플릿으로 `--headless --export-release Web` exit 0, 오류·경고 0, `GODOT_THREADS_ENABLED = false`, `check_export.gd` 1098개 파일 0 실패, 수정 런타임 포함. 브라우저 실행·`browser_layout`·Playwright 게이트는 미실행 |

초급 5단계 답지 모두 물리 통과. 4단계 벽 앞 정지(배터리 탑재 소형 차)는 `kit_robot_runtime` 0.05179 m,
`beginner_course`·`stage_own_build` 0.0518 m, 0.0015 m/s, 접촉 0이에요. 결승선 0.506 m, 깃발 0.198 m예요.
첫 기록(`1e5b99d`)의 헤드리스 결과는 106/107이었고 `power_net_check`만 실패했어요.

## 정지 물리 수정 (`1ad5eaf`, 주인 결정 항목 44)

`power_net_check`의 두 실패(무전원 0.013 m, 스위치 끔 0.294 m)는 벽 캐스터 브랜치 `61f40cb`에서 넘어왔어요.
기준 `cf7a21d`는 통과했어요. 헤드리스 탐침으로 원인 세 가지를 찾았어요.

1. 볼 캐스터의 키트 구멍은 공 중심에서 10 mm 옆에 있어요. 구멍에 건 고정 관절은 바닥 반력을 각도 구속과 싸우는
   토크로 바꿨어요. 그래서 5 g은 떨리고 20 g은 큰 키트 차를 6.6 mm/s로 밀었어요. 레거시 마운트는 공 바로 위라 해당이 없어요.
   키트 구멍 캐스터 관절을 공 중심에 걸었어요.
2. 관절이 붙든 접촉 위의 미끄럼 마찰(0.01)이 래칫처럼 정지한 차를 1.7 mm/s로 밀었어요. 바퀴를 잠가도 같았고, 캐스터 마찰 0에서는
   사라졌어요. 4단계 차는 판정 뒤에도 15초 동안 0.0543 m에서 0.0362 m로 벽에 다가갔어요. 실제 공은 굴러요.
   그래서 공 구는 마찰 없이 미끄러지고, RunMode가 접촉 하중 비례 굴림 저항 0.01을 공의 움직임 반대 방향으로만 줘요.
   저항은 공을 멈추게 할 뿐 되돌리지 않아요. 측정 하중은 차 무게의 32%(2.08 N)예요.
3. `DriveMotor`는 구동하지 않는 축에 저항이 없었어요. 정착 충격이나 떨어진 배터리가 차를 계속 굴렸어요(0.157 m/s 유지).
   5 g 캐스터의 떨림이 우연한 제동으로 이를 가렸어요. 관성 주행·제동·무전원 TT 모터에 기어박스 마찰을 줬어요.
   크기는 정지 토크의 10%예요(사양 무부하 150 mA / 정지 1.5 A). 구동 중 모델은 무부하 속도에 마찰이 들어 있어 바꾸지 않았어요.

| 헤드리스 탐침 | 수정 전 | 수정 후 |
|---|---|---|
| 무전원 큰 키트 차, 2초 | 0.013 m | −0.0002 m |
| 스위치 끔 + 떨어진 배터리, 2초 | 0.294 m | −0.00002 m |
| 정지 소형 차 캐스터 최대 속도 | 0.0059 m/s | 0.0015 m/s 이하 |
| 4단계 판정 시점 → 15초 뒤 벽 간격 | 0.0543 → 0.0362 m | 0.0518 → 0.0515 m |
| 전원 켠 큰 키트 차 2초 주행(55%) | 1.02 m | 1.06 m |

레거시 캐스터 마운트의 질량(5 g)과 미끄럼 구는 그대로예요. 4단계 답지의 벽 간격 여유는 하한 0.05 m 대비 1.8 mm예요.
렌더 모드 카메라 검사는 TT 모터 차를 쓰므로 일괄 렌더 검증에서 확인해야 해요.

## 번역 영향

새 사용자 문구는 각 브랜치가 추가한 그대로예요. 통합에서 새로 만든 문구는 없어요.
