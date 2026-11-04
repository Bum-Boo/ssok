# M2 키트 부품 트레이와 키트 답지 로봇

2026-11-05, Codex. 사용자 피드백인 “전혀 모듈형이 아니에요”에 대한 로컬 구현이에요.
작업 정본은 작업실 상위 `brief.md`이고, ADR 0039의 트레이·장치 구멍·키트 답지 범위를 구현해요.
최종 대상은 **19종 중 15 PASS / 4 FAIL**이며 실패 네 종은 벽 답지/증명에 해당해요.
깃발·결승선은 통과했으나 캐스터 속도 약 0.0624 m/s로 **세 답지 전체 통과는 미달성**이에요.

## 소스와 작업 계약

- 작업실: `C:/Users/Hojun/agent-jobs/ssok-M2-20261105/repo`
- 브랜치: `feat/modular-build-20261105`, 시작 `c8d624d87c18502e1a6e1deb2068d5d5b3238655`, clean.
- 흐름: 빈 작업대 → 판·빔·장치의 구멍/축 연결 → 그래프 배선 → 기존 보드 코드 실행 → 실제 목표 관측.
- 합격 조건: 명세 순서의 48종 트레이, 숨김 부품의 저장 호환, 아홉 장치의 키트 포트,
  기존 답지 코드로 키트 로봇 세 과제 통과, 네 언어와 대상 검사 및 문서 검사예요.
- 소유 분리: 장치 생성기/리소스, 트레이/UI/번역, 프리셋/Stage 검사는 독립 작업자가 맡고
  총괄이 통합·문서·검증·커밋을 맡아요. 기존 WIP는 없었어요.
- 물리 파라미터·변환 규칙·보드 API·파서·과제 판정·기존 프리셋·A-2~A-5 레이아웃은 유지해요.
- 커밋은 영어 명령형 제목과 `Agent: codex` 본문 마지막 줄로 남기고 푸시하지 않아요.

## 바뀐 것

장치의 키트 포트, 명세 순서의 48종 트레이, 키트 답지 그래프를 분리해 구현했어요.
트레이의 전체/구조/움직임/전자/센서/환경은 각각 48/20/12/5/3/8종이에요.
검색·스테이지 `level.parts`는 같은 허용 목록의 교집합이고 UI 재설정도 이 필터를 유지해요.
전체 카탈로그 로더는 보존해 숨김 부품의 옛 저장 파일과 프리셋을 계속 열어요.
빔·판의 영어 이름을 `Beam`/`Plate`로 줄이고 ko/ja/zh_CN PO와 JSON을 함께 맞춰
고정된 트레이 폭에서 크기가 드러나게 했어요. M1 안내와 기존 화면 배치는 유지했어요.

## 부품별 추가 포트

단위는 mm, 좌표는 부품 로컬이에요. 앞면은 양수 두께와 +법선, 뒷면은 음수 두께와 -법선이에요.
ID는 `kit_h0_front/back`부터 각 구멍 번호로 이어져요. 모두 MECH, `kit_m4`,
`accepts=[kit_m4]`, `rotates=false`예요.

| 부품 | 구멍 수 / 추가 포트 수 | 구멍 중심과 면 |
|---|---:|---|
| microbit | 4 / 8 | (x,z)=(-10,-10),(10,-10),(-10,10),(10,10), y=±2.5, 법선 ±Y |
| arduino_uno | 4 / 8 | 같은 (x,z), y=±0.8, 법선 ±Y |
| motor_driver | 4 / 8 | 같은 (x,z), y=±4, 법선 ±Y |
| tb6612_driver | 4 / 8 | 같은 (x,z), y=±4, 법선 ±Y |
| hc_sr04 | 2 / 4 | (x,y)=(-10,0),(10,0), z=±0.8, 법선 ±Z |
| tt_motor | 2 / 4 | (x,z)=(-16.5,0),(3.5,0), y=±11, 법선 ±Y |
| servo | 2 / 4 | (x,z)=(-10,0),(10,0), y=±15, 법선 ±Y |
| ball_caster | 2 / 4 | (x,z)=(-10,0),(10,0), y=±12, 법선 ±Y |
| flag | 2 / 4 | (x,y)=(-10,0),(10,0), z=±0.5, 법선 ±Z |

`.tres`는 `make_part_defs.gd`, `make_learning_parts.gd`, `make_construction_kit_defs.gd`로 생성했어요.
학습 부품 생성기의 TT 전원 포트 추가 조건은 포트 개수 대신 ID로 확인해 새 구멍이 있어도
`power` 배선과 기존 기능 속성이 유지돼요. 이전 수동 flag 정의도 동일 필드의 생성기 입력에 넣었어요.
이것은 M1 조작 코드 수정이 아니에요.

| 출력축/상대 축 | 이전 accepts | 이후 accepts |
|---|---|---|
| tt_motor.shaft_left/right | wheel_hub | wheel_hub, kit_axle_8 |
| servo.output_shaft | arm_mount | arm_mount, kit_axle_8 |
| kit_axle_40.front/back | kit_axle_8, kit_shaft_8, motor_shaft | kit_axle_8, kit_shaft_8, motor_shaft, servo_output |

회전 의미·기존 태그·관절 생성은 유지했어요. 상대 키트 축도 서보 태그를 받아 실제 양방향 호환이 돼요.
기존 직렬화 필드·포트와의 Godot 비교는 621/0, 별도 원문 비교에서도 아홉 장치의 기존
포트·핀·ID·이름·질량·메쉬·구동 선언 보존을 확인했어요.

## 답지와 호환 범위

키트 차는 `kit_plate_220_120` 하나와 빔 네 개, TT 모터 두 개, 90 mm 바퀴 두 개,
캐스터와 20 mm 스페이서, microbit·드라이버·초음파·꺾쇠로 만들었어요.
모든 로봇 부품은 구멍/축의 그래프 기계 링크로 연결하며 각 링크의 위치 일치·반대 법선도 검사해요.
microbit 0/8/12/16 → driver input, motor_1/2 → 좌/우, pin1/2 → trig/echo 배선과
`RobotCarPreset.ANSWER_CODE`/`BRAKE_CODE`는 그대로예요.
깃발 팔은 `kit_plate_120_80`, `kit_weight_300`, 꺾쇠, `kit_motor_12`, 작은 U 브래킷,
`kit_beam_140`, flag, microbit를 사용하고 pin0에 배선해 기존 `Servo(pin0)` 코드를 써요.
팔 내림은 새 출력 포트의 실제 위치/법선을 중심으로 출력 쪽 부품 묶음만 회전해요.

팔 내림 부호 보정 전 `4ea9705`의 직접 물리 측정은 다음과 같아요. 후속 보정 결과는 아래 검사 절에
별도로 남겨요. **세 스테이지 모두 통과는 미달성**이에요.

| 과제 | 실제 결과 | 관측 |
|---|---|---|
| 깃발 | PASS | flag 최고 높이 0.209737 m, 1초 유지 |
| 결승선 | PASS | 모든 부품 경계의 min_x=0.501517 m |
| 벽 앞 정지 | FAIL | 벽 간격 0.073392 m, 접촉 0, 캐스터 속도 0.061906 m/s |

벽의 간격·무접촉 조건은 맞지만 최대 부품 속도 기준 0.015 m/s를 넘었어요.
같은 시점 섀시 강체는 0.000510 m/s, 두 바퀴는 0.000930/0.000708 m/s 이하였어요.
독립 캐스터 강체의 잔류 움직임이 최대 속도를 결정한 것은 관측했고, 구속 지터가 원인이라는
설명은 추론이에요. 물리 파라미터·고정 연결 병합·판정 기준을 바꾸지 않고 브리프 지시대로 중단했어요.

초기 짧은 형상은 센서가 기울어 401 cm 범위 밖이었고, 긴 판/빔으로 바꿨어요.
스페이서 보정 전 형상도 벽 간격 0.06474 m, 속도 0.05511 m/s로 실패했어요.
최종 형상은 실제 벽을 20 cm 이동했을 때 초음파가 69.2182 → 89.2372 cm로 바뀌고,
기존 주행 코드로 +X 방향 0.853423 m 이동했어요. 프로그램·물리 수치로 실패를 숨기지 않았어요.
통합 중 발견한 한 구멍의 중복 사용은 빈 구멍으로 고쳐 그래프 저장 검증을 회복했어요.
`RobotCarPreset`·`ServoArmPreset`은 보존해요. 카메라 검사는 기존 차 프리셋을 직접 불러오고,
Stage는 원래부터 AI 탭을 숨겨요. `AgentCameraLoop`의 `car_chassis` 판별을 변경하지 않았어요.
따라서 키트 차를 Lab에 불러왔을 때 AI 카메라 지원까지 확장한 작업은 아니에요.
`FlagMission`의 옛 `arm_link` 경로도 보존하고 Stage의 실제 flag 높이 판정은 그대로 사용해요.

## 검사와 제한

첫 전체·대상 검사는 앱·검사 소스 `4ea9705`를 고정해 실행했어요. 최종 앱 소스는 호환 보정 후
`71e5962`예요. Windows native, Godot
`4.7.2.stable.official.ed1daf0bf`, GL Compatibility, RTX 4060/driver 610.88 환경이에요.
검증기는 별도 임시 APPDATA/LOCALAPPDATA를 써 개인 저장 작업과 분리했어요.

```powershell
$env:PYTHONUTF8 = '1'
python tools/ci/verify.py --godot "$env:GODOT" --match '^(import|scene-load|device_kit_ports_check|parts_tray_check|workshop_ui_check|parts_pack_inventory_check|construction_kit_ui_check|parts_freedom_workshop_check|stage_own_build_check|kit_robot_runtime_check|localization_check|workshop_run_label_check)$' --output build/verification-m2-target-final
```

첫 대상 검사의 실제 출력이에요. [원본 표와 Stage 출력](evidence/modular_build_m2_2026-11-05/README.md)을 보존해요.

```text
PASS import (3.8s)
PASS scene-load (0.5s)
PASS construction_kit_ui_check (5.9s)
PASS device_kit_ports_check (0.5s)
FAIL kit_robot_runtime_check (9.8s)
PASS localization_check (5.5s)
PASS parts_freedom_workshop_check (9.3s)
PASS parts_pack_inventory_check (4.9s)
PASS parts_tray_check (2.9s)
FAIL stage_own_build_check (175.5s)
PASS workshop_run_label_check (10.5s)
PASS workshop_ui_check (5.0s)
12 checks; 2 failures.
```

`parts_tray_check` 133/0, 장치 포트 331/0, 번역 59,344/0, 키트 UI 362/0이에요.
새 런타임 검사는 106/1, 기존 Stage 전체 흐름 검사는 164/1이고 둘 다 벽 속도 한 항목이 실패했어요.
Stage UI의 실제 벽 결과는 간격 0.0738911 m, 접촉 0, 속도 0.0624377 m/s,
`not_met/program_finished`예요. 깃발은 0.2097462 m/1초, 결승선은 min_x=0.5025774 m로 PASS예요.
다른 구성 통과·목표 미달 실패·답지 확인/취소·복원·저장 실패·언어/테마/키보드 검사는 유지했어요.
브리프의 Windows 기준선 후보 `workshop_run_label_check`는 이번 실제 실행에서 PASS였어요.

최종 실제 GL은 별도 사용자 디렉터리에서 `tests/parts_tray_check.gd -- --screenshots`로
149/0, 네 언어 × 두 테마 × 1152×648/1400×950의 16장을 저장했어요.
네 언어 글리프·보이는 빔/판 치수를 확인했고, 별도 판 스크롤 캡처와 폰트 폭 측정에서도
220×120 mm까지 표시됐어요. 가장 긴 판 이름은 en 133 px/ko 116 px/ja·zh 114 px,
사용 가능한 폭은 160 px예요. 모델명이 긴 일부 드라이버·환경 선 이름은 기존 말줄임을 사용해요.
초기 GL 후속 실행의 임시 무효 Stage 사전 오류와 RID 정리 경고는 통과로 합산하지 않았고,
중복 구멍 수정 뒤 최종 GL은 오류 없이 끝났어요. 드라이버의 display timeout override 안내는 비치명적이에요.

첫 전체 명령은 `python tools/ci/verify.py --godot "$env:GODOT" --output build/verification-m2-full-final`이고
실제 출력은 `121 checks; 10 failures.`였어요. [전체 원본 표](evidence/modular_build_m2_2026-11-05/full-before-fixes-summary.md)에
111 PASS와 실패 10종을 그대로 남겼어요. 실패를 예상 실패나 skip으로 바꾸지 않았어요.

| 첫 전체 실패 | 관찰과 보정 |
|---|---|
| agent_camera_loop_check-rendered, agent_camera_rest_check, agent_goal_ui_check-rendered, camera_evaluator_lifecycle_check-drive_stop | 기존 차의 정착·벽시계 제한/준비 상태 실패. 숨긴 정의의 강한 참조를 전체 로더 배열로 복원했어요. |
| game_flow_check | 90도 재시도와 벽 정지 실패. 키트 모터의 기존 구동 방향과 반대였던 초기 팔 내림 부호만 고쳤어요. |
| stage_authoring_check | 벽 답지·증명 실패와 옛 연습 시작 상태 실패. 연습을 명시적으로 시작해 이전 arm_link 답지에 의존하지 않게 했어요. |
| kit_robot_runtime_check, stage_own_build_check | 캐스터 잔류 속도로 벽 정지 실패. 물리·기준은 유지했어요. |
| tests-motion_mcp_check.py | `ModuleNotFoundError: No module named 'mcp'`. 새 의존성을 설치하지 않았어요. |
| tools-rl_lab-test_rl_lab.py | `ModuleNotFoundError: No module named 'mujoco'`. 새 의존성을 설치하지 않았어요. |

동일한 옛 차에서 revision 계산 20회 평균은 전체 정의를 보관하지 않을 때 50.07835 ms,
93종 참조를 유지할 때 3.64165 ms였어요. 트레이 필터링 전과 같은 참조 수명을 복원했고
카탈로그·핀·물리·카메라 명령 의미는 바꾸지 않았어요. 이것은 해당 경로의 비용 측정이며 모든 성능의 보장이 아니에요.
팔은 기존 `actuator_drives_connected_body`에 따라 내림 부호를 골라요. 격리 실험에서 0도는
0.07549 m로 낮게 유지됐고, 90도는 0.20331 m를 1초 유지했어요. 기존 답지 코드도 0.19423 m/1초로
통과했어요. 앞의 보정 전 `90→0` 일시 성공을 올바른 90도 동작의 근거로 쓰지 않아요.
최종 고정 소스 `71e5962`의 후속 명령은 위 대상 정규식에 `game_flow_check`, `stage_authoring_check`,
`flag_mission_check`, `agent_camera_loop_check-rendered`, `agent_camera_rest_check`,
`agent_goal_ui_check-rendered`, `camera_evaluator_lifecycle_check-drive_stop`을 더하고 출력 경로를
`build/verification-m2-followup`으로 지정했어요. [실제 19종 표](evidence/modular_build_m2_2026-11-05/followup-summary.md)를 보존해요.

```text
PASS import (3.0s)
PASS scene-load (0.5s)
PASS agent_camera_loop_check-rendered (10.9s)
PASS agent_camera_rest_check (14.4s)
PASS agent_goal_ui_check-rendered (11.7s)
PASS camera_evaluator_lifecycle_check-drive_stop (11.8s)
PASS construction_kit_ui_check (4.8s)
PASS device_kit_ports_check (0.5s)
PASS flag_mission_check (4.0s)
FAIL game_flow_check (37.6s)
FAIL kit_robot_runtime_check (10.2s)
PASS localization_check (5.0s)
PASS parts_freedom_workshop_check (5.6s)
PASS parts_pack_inventory_check (4.3s)
PASS parts_tray_check (2.9s)
FAIL stage_authoring_check (19.2s)
FAIL stage_own_build_check (49.8s)
PASS workshop_run_label_check (4.8s)
PASS workshop_ui_check (4.7s)
19 checks; 4 failures.
```

최종 Stage UI는 깃발 **0.1961553 m / 1초**, 결승선 **min_x=0.5025774 m**로 통과했어요.
벽은 **거리 0.0738911 m / 속도 0.0624377 m/s / 접촉 0**으로 실패를 재현했어요.
`game_flow_check`는 43/1(벽만), `stage_authoring_check`는 44/3(벽 성공·결과·증명만),
`stage_own_build_check`는 164/1, `kit_robot_runtime_check`는 106/1이에요.
카메라 네 종과 옛 깃발 연습·90도 재시도는 복구됐어요. 전체 121종을 보정 후 다시 실행한 것은 아니에요.
독립 Astra 정적 검수는 확정 차단 결함 없이 장치 보존·48종 순서·필터·답지 배선·목표 유지 범위를
확인했어요. 최종 `4ea9705` 재검수와 실제 contact/판 스크롤 이미지 검수도 새 차단 결함 없이
마쳤고 `b29ba6e`/`71e5962`의 참조 유지·연습 진입·내림 방향도 독립 검수했어요.
알려진 벽 미통과는 그대로 남아요. 검수 자체는 Godot 실행이나 물리 통과를 대신하지 않아요.

문서는 CONSTRUCTION_KIT·STAGE_CONTRACTS·FLOWS·DATA_MODEL·STATUS·ARCHITECTURE·LOCALIZATION과
context 경로/심볼/계약 소스를 갱신했어요. ERD와 물리/VM 도식은 저장·물리 규칙이 같아 유지했어요.
새 파일의 오프라인 문서 링크를 위해 `tools/ci/build.py`의 문서 포함 목록만 보완했어요.
`maintain.py --write`, `--review data-model`, `--review execution-flow`, `--check`와 문서 도구 unittest
10개가 통과했고, 오프라인 문서 패키지 검사도 통과했어요. 옛 연습 진입 변경은 `--review flag-flow`로
대조했어요. 새 보드 API·제공자·유료 생성 변경은 없어요.
전역 instruction-health는 기존 신뢰되지 않은 스킬 마운트 33건 때문에 실패했어요.
필요한 sustainable-workflow/agent-handoff 원본은 확인한 링크 대상으로 읽고 환경은 변경하지 않았어요.

## 못 한 것과 다음 범위

- 세 답지 전체 통과와 통합 준비는 미달성이에요. 캐스터 잔류 움직임의 구속 원인은 추가 진단이 필요해요.
- 브리프의 중단 조건을 따라 형상·물리 수치·판정·코드를 더 조정하지 않았어요.
- Web export·배포·실사용자 학습 검증·키트 차의 AI 카메라 지원은 이번 작업에서 하지 않았어요.
- 환경 모듈 `mcp`·`mujoco` 누락과 최종 전체 재실행은 미완료예요. 실패를 억제하거나 의존성을 추가하지 않았어요.
- 브랜치 `feat/modular-build-20261105`는 로컬 회수용이며 통합 준비 완료로 release하지 않아요.

## 사용자가 해 볼 것

1. Lab에서 판을 바닥에 놓고 차의 바탕을 만들어요.
2. 빔을 판의 구멍에 끼워 차의 뼈대를 만들어요.
3. TT 모터 두 개를 구멍에 달고 각 출력축에 바퀴를 끼워요.
4. 보드와 드라이버를 구멍에 달고 모터·보드 핀을 배선해요.
5. 모터 코드를 작성하고 실행해 직접 만든 차를 달려 봐요.
