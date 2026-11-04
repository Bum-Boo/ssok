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

## M2b — 벽 앞 정지 진단과 수정 (2026-11-05)

작업 계약: 시작 e599149, 같은 브랜치의 격리 작업실 M2b, 사용자 brief.md 범위만 수정하고 푸시하지 않아요. 기존 코드·판정·전역 물리 수치는 고정해요. 진단 → 질량 → 위치 → 높이 → 필요한 최소 변환 수정 → 대상·전체 검사 → 커밋 순서예요. 세 답지·옛 차 회귀 통과가 합격 조건이에요.

변환 실험 전 근거: 기존 캐스터는 5 g 별도 강체이고 키트 차체는 539.8 g(107.96:1), 옛 차체는 174 g(34.8:1)이에요. 경량화·레버 단축·높이 보정과 두 구멍 체결을 순서대로 시험했지만 통과하지 못했어요. 캐스터 접촉이 유지된 채 선속도의 수직 성분이 남았어요. 키트 고정 관절의 기준점이 작은 캐스터 중심에서 x=10 mm, y=12 mm 벗어나며 옛 마운트는 y=1.5 mm예요. 먼저 같은 기존 형상에서 고정 구속 기준점만 캐스터 중심으로 옮기는 대조 실험으로 수치 조건 원인을 검증해요. 이 단계는 가설이며 아직 채택하지 않았어요.

### 결론과 소스

**세 답지 전체 통과는 여전히 미달성이며, 브리프의 실패 시 중단 조건으로 종료해요.**
형상과 변환 대조 실험 모두 통과하지 못해 앱·프리셋을 시작 커밋으로 복원했어요.
최종 변경은 `tools/ci/diagnose_kit_car.gd`, 이 절과 [M2b 근거](evidence/modular_build_m2b_2026-11-05/README.md), 생성 지도·문서 검토 메타데이터예요.
새 ADR 0040은 채택한 변환이 없어서 작성하지 않았고 0003·0037은 그대로예요.
원인이 병합 제외 규칙이라고 확정할 근거는 부족해요. 구속과 접촉이 함께 있는 작은 강체의
잔류 수직 속도는 관측했지만 질량비·장착점·관절 종류 하나만 바꿔 해결하지 못했어요.

- 작업실 `C:/Users/Hojun/agent-jobs/ssok-M2b-20261105/repo`, 브랜치 `feat/modular-build-20261105`.
- 앱 기준 `e5991492ce3081db25ad9a937116b597cd261c99`; 최종 `src/`, `presets/`, `project.godot`, workflows 변경 없음.
- Windows native / Godot 4.7.2 / GodotPhysics3D / headless / 60 Hz, 바닥 윗면 y=0.05 m / 벽 x=0.8 m.
- 두 차량 모두 생성 직후 동일 BRAKE_CODE로 시작하며 초기 안정화 시간을 한쪽에만 주지 않았어요.
- 사용자 문구·카탈로그·네 언어·비용·M1 조작은 변경하지 않았어요. Web 실행·새 시각 승인은 하지 않았어요.

### 동일 조건 진단

최종 도구의 [final.json](evidence/modular_build_m2b_2026-11-05/final.json) 수치예요.
군집은 solver body의 동일 인스턴스로 분류하고 질량은 실제 `RigidBody3D.mass`를 읽었어요.

| 솔버 강체 | 옛 차 구성원 / kg | 키트 차 구성원 / kg |
|---|---|---|
| 차체 | car_chassis, tt_motor×2, microbit, motor_driver, hc_sr04 / 0.174000 | kit_plate_220_120, kit_beam_140×2, kit_beam_100×2, tt_motor×2, microbit, motor_driver, kit_spacer_20, kit_angle_bracket, hc_sr04 / 0.539800 |
| 왼쪽 바퀴 | wheel_65 / 0.030000 | kit_wheel_90 / 0.055000 |
| 오른쪽 바퀴 | wheel_65 / 0.030000 | kit_wheel_90 / 0.055000 |
| 별도 캐스터 | ball_caster / 0.005000 | ball_caster / 0.005000 |
| 고정 벽 | stage_wall / 2.000000 | stage_wall / 2.000000 |

| 진단 항목 | 옛 차 | 키트 차 |
|---|---:|---:|
| 차체:캐스터 질량비 | 34.80:1 | 107.96:1 |
| 조립 캐스터 중심 y / m | 0.062000 | 0.064000 |
| 조립 캐스터 장착 포트 y / m | 0.063500 | 0.076000 |
| 조립 바퀴 축 y / m | 0.082500 | 0.115000 |
| 장착 포트−바퀴 축 / mm | −19.000 | −39.000 |
| 구 중심−바퀴 축 / mm | −20.500 | −51.000 |
| 바퀴 반경−캐스터 반경 / mm | 20.500 | 33.000 |
| 전진 방향 캐스터−축 거리 / mm | 66.500 | 137.500 |
| VM 종료 / s | 3.166667 | 14.133333 |
| 성공 판정 / s | 3.750000 | 성립하지 않음 |
| 관측 마지막 1초 차체 피치 / ° | −0.756630..−0.504964 | −2.181445..−1.598137 |
| 같은 구간 캐스터 속력 / m/s | 0.005276..0.005297 | 0.061865..0.064506 |
| 마지막 캐스터 각속도 (x,y,z) / rad/s | (0.000115, 0.001091, −0.004509) | (−0.000571, 0.000168, −0.002047) |
| 마지막 1초 바닥 접촉 | 60/60 ticks | 60/60 ticks |
| 평가 결과 | PASS, 0.3초 유지 | FAIL, 속도 유지 0초 |

장착 높이 표는 조립 좌표이며 실행 후 높이가 아니에요. 바퀴 크기가 달라 축 높이 차만으로
원인을 단정하지 않아요. `stop_tick`은 VM 종료로서 물리 정지와 구분해요.
옛 차의 [시계열](evidence/modular_build_m2b_2026-11-05/final-legacy.csv)은 성공 전후 1초를 포함하고,
키트 [시계열](evidence/modular_build_m2b_2026-11-05/final-kit.csv)은 VM 종료 전 1초~후 2초를 담아요.
성공하지 않은 키트에는 실제 0.3초 정지 판정 창이 없어요. 각 CSV는 선속도/각속도 전 축과
피치·접촉·차체 속도를 60 Hz로 보존하고 JSON에 해시·구간을 연결했어요.

### 시도 순서와 수치

아래 속도는 각 실험 종료 시의 기존 `robot_speed` 판정값이며 기준 0.015 m/s/0.3초는 그대로예요.
종료하지 못한 안은 20초 시점의 값으로 **정지 후 수치가 아니에요**. 모든 안의 부품은 트레이 허용 ID예요.
구조의 시각적 간섭·조립 UI 배치 가능성까지 승인된 답지라는 뜻은 아니고, 모두 미채택이에요.

| 키 / 시도 | 차체 kg / 질량비 | 중심−축 높이 mm | VM 종료 s | 벽 간격 m / 최대 부품 속도 m/s / 벽 접촉 | 결과 |
|---|---:|---:|---:|---|---|
| baseline / 기존 | 0.53980 / 107.96 | −51 | 14.133 | 0.073392 / 0.061906 / 0 | FAIL |
| light / 120×80 판, 빔4→2·60 mm, 보드 직접 장착 | 0.28060 / 56.12 | −51 | 5.867 | 0.066848 / 0.062459 / 0 | FAIL |
| lever / 캐스터 x=90→30 mm | 0.28060 / 56.12 | −51 | 미종료 | 0.654293 / 0.061603 / 0 | FAIL |
| height / 20 mm 스페이서 제거 | 0.26860 / 53.72 | −31 | 미종료 | 0.631742 / 0.030694 / 0 | FAIL |
| height_long / 높이 보정 후 x=90 mm | 0.26860 / 53.72 | −31 | 5.867 | 0.048587 / 0.052561 / 0 | FAIL |
| compact / 80×60 판, 하부 모터 빔, 65 mm 바퀴 | 0.22876 / 45.75 | −17 | 미종료 | 0.704976 / 0.043332 / 0 | FAIL |
| double / 캐스터 두 구멍에 스페이서 체결 | 0.24076 / 48.15 | −17 | 3.900 | 0.020019 / 0.077937 / 0 | FAIL |
| center / 기존 형상, 관절 기준점만 구 중심 | 0.53980 / 107.96 | −51 | 2.533 | 0.001973 / 0.047175 / 0 | FAIL |
| pin / 구 중심 PinJoint3D | 0.53980 / 107.96 | −51 | 2.500 | 0.000000 / 0.037346 / 1 | FAIL |
| minimal / 60×40 판·65 mm 바퀴 | 0.20284 / 40.57 | −51 | 미종료 | 0.596546 / 0.119673 / 0 | FAIL |
| minimal_level / 모터 하부·캐스터 빔으로 높이 일치 | 0.21580 / 43.16 | −21 | 미종료 | 0.721491 / 0.048463 / 0 | FAIL |
| order / 기존 형상, 캐스터를 관절 node_a로 | 0.53980 / 107.96 | −51 | 5.267 | 0.064078 / 0.071760 / 0 | FAIL |

각 키의 JSON/CSV에 옛 차 대조 PASS와 구성원·질량·실제 좌표를 함께 남겼어요.
질량을 줄인 첫 안도 실패했고, 경량화·레버·높이 보정의 누적 안은 주행 자체가 나빠졌어요.
이는 질량비 단독 원인이나 단순 수평 보정의 해결을 지지하지 않아요. PinJoint는 체결 의미도
바꾸고 접촉까지 발생해 기각했어요. 마찰 0.01 유지 여부와 별개로 통과 근거가 없어서
변환 규칙을 채택하지 않았어요. 구를 차체에 합치고 접촉 재질을 분리하는 설계는 구현·검증하지 않았어요.

### 검증과 남은 일

독립 Astra는 진단 코드와 원본 JSON의 동일 조건, 질량비, 속도 벡터 크기, 접촉과 관측 창을
검토해 차단 결함을 찾지 못했어요. VM 종료와 물리 정지를 구분하라는 지적을 위에 반영했어요.
앱 검사는 아래 실제 실행과 구분해요. ARCHITECTURE/FLOWS/DATA_MODEL의 기존 설명은 앱
변환·그래프·제어권 변경이 없으므로 유지해요. 번역 변경은 필요 없어요.

공통 instruction-health core는 작업 시작에 43파일/33오류로 실패했어요. 기존 junction의
`WinError 448`이며 작업 저장소 결함과 별도예요. 필수 작업/인계 스킬은 junction의 실제
`C:/Users/Hojun/Projects/agent-workflow-private/shared-skills/skills/` 원본으로 읽었어요.
환경 지침·링크는 이 작업에서 수정하지 않았어요.


### M2b 실제 검사 출력

대상은 14종 중 10 PASS / 4 FAIL,
전체는 **121종 중 115 PASS / 6 FAIL**이에요.
앱 기준은 복원한 `e599149`, 진단 도구는 `6fe2da4`예요. 대상 실행 중 마지막 관절 순서 대조
실험을 병행했으므로 대상 배치는 탐색 결과로 남겨요. 복원 후 앱 변경 없이 실행한 전체 검사를
최종 앱 소스의 근거로 삼아요. 전체 결과에 대상 14종도 모두 포함해요.
실패를 expected-failure나 PASS로 바꾸지 않았어요.

실제 전체 실패 suite: `game_flow_check`, `kit_robot_runtime_check`, `stage_authoring_check`, `stage_own_build_check`, `tests-motion_mcp_check.py`, `tools-rl_lab-test_rl_lab.py`.
이 중 `mcp`/`mujoco` 모듈 누락에 해당하는 환경 실패는
`tests-motion_mcp_check.py`, `tools-rl_lab-test_rl_lab.py`이에요.
나머지는 키트 벽 답지와 그 성공 증명이 성립하지 않은 실패예요.
`stage_authoring_check`의 3개 assertion은 벽 성공·결과 표시·새 증명 내보내기예요.
깃발과 결승선의 실제 관측은 통과했고, 옛 차 `robot_car_check`/`sonar_stage_check`,
`parts_pack_*`, `agent_camera_*`는 전체 검사에서 통과했어요.
import/scene-load와 localization도 전체 검사에 포함해요.

```powershell
python tools/ci/verify.py --godot "$env:GODOT" --match '^(kit_robot_runtime|stage_own_build|game_flow|stage_authoring|robot_car|sonar_stage|parts_pack_.*|stage_contract|parts_tray)_check' --output build/verification-m2b-target
$env:PYTHONUTF8='1'
python tools/ci/verify.py --godot "$env:GODOT" --output build/verification-m2b-full
```

아래는 실행 콘솔을 그대로 옮긴 내용이에요. 줄바꿈만 UTF-8/LF로 보존했으며
[대상 원문](evidence/modular_build_m2b_2026-11-05/target-console.log),
[전체 원문](evidence/modular_build_m2b_2026-11-05/full-console.log),
[전체 JSON](evidence/modular_build_m2b_2026-11-05/full-results.json)에 실제 명령·시간·개별 exit code가 있어요.

대상 출력:

```text
RUN  game_flow_check
FAIL game_flow_check (36.5s)
"success": false, "expired": false, "elapsed_seconds": 2.0, "measurements": [{ "metric": "min_x", "part_index": -1, "value": 0.00419510155916, "state": "valid", "held_seconds": 0.0, "met": false }], "wall_contact": false } measurements=[{ "metric": "min_x", "part_index": -1, "value": 0.00419510155916, "state": "valid", "held_seconds": 0.0, "met": false }]
CHECK ok   the short starter drive does not reach the finish line
RESULT { "status": "success", "reason": "", "execution_id": 6, "success": true, "expired": false, "elapsed_seconds": 1.96666666666666, "measurements": [{ "metric": "min_x", "part_index": -1, "value": 0.50257760286331, "state": "valid", "held_seconds": 0.01666666666667, "met": true }], "wall_contact": false } measurements=[{ "metric": "min_x", "part_index": -1, "value": 0.50257760286331, "state": "valid", "held_seconds": 0.01666666666667, "met": true }]
CHECK ok   a longer drive crosses the finish line
CHECK ok   stage list returns to the map
CHECK ok   wall-brake level loads from the map
RESULT { "status": "not_met", "reason": "program_finished", "execution_id": 5, "success": false, "expired": false, "elapsed_seconds": 15.9333333333337, "measurements": [{ "metric": "wall_distance", "part_index": -1, "value": 0.07388705015182, "state": "valid", "held_seconds": 2.43333333333333, "met": true }, { "metric": "robot_speed", "part_index": -1, "value": 0.06243774667382, "state": "valid", "held_seconds": 0.0, "met": false }, { "metric": "wall_contact", "part_index": -1, "value": 0.0, "state": "valid", "held_seconds": 15.9333333333337, "met": true }], "wall_contact": false } measurements=[{ "metric": "wall_distance", "part_index": -1, "value": 0.07388705015182, "state": "valid", "held_seconds": 2.43333333333333, "met": true }, { "metric": "robot_speed", "part_index": -1, "value": 0.06243774667382, "state": "valid", "held_seconds": 0.0, "met": false }, { "metric": "wall_contact", "part_index": -1, "value": 0.0, "state": "valid", "held_seconds": 15.9333333333337, "met": true }]
CHECK FAIL the sensor loop stops in the zone
ERROR: the sensor loop stops in the zone
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _check (res://tests/game_flow_check.gd:23)
       [1] _run (res://tests/game_flow_check.gd:141)
       [2] _wait_result (res://tests/game_flow_check.gd:182)
       [3] _frames (res://tests/game_flow_check.gd:28)
CHECK ok   leaving a stage returns to the stage list
CHECK ok   free building opens a lab workshop
CHECK ok   lab keeps the full library and default floor
CHECK ok   lab keeps authoring but not the stage picker
CHECK ok   lab hides example robots and the AI lab
CHECK ok   lab shows no flag mission
CHECK ok   an unchanged lab exits straight to the title
CHECK ok   examples open their own list
CHECK ok   an example loads its robot
CHECK ok   a non-flag example shows no flag visual
CHECK ok   examples hide challenge authoring
game_flow_check: 43 checks, 1 failures

RUN  kit_robot_runtime_check
FAIL kit_robot_runtime_check (9.9s)
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

KIT_RUNTIME_MEASUREMENTS {"drive_dx_m":0.853422910498921,"left_pin":0,"moved_wall_cm":89.2371535301209,"right_pin":12,"sonar_cm":69.2182421684265,"sonar_pins":[1,2]}
KIT_STAGE_RESULT raise-flag {"elapsed_seconds":1.2,"execution_id":2,"expired":false,"measurements":[{"held_seconds":1.0,"met":true,"metric":"max_height","part_index":-1,"state":"valid","value":0.193339750170708}],"reason":"","status":"success","success":true,"wall_contact":false}
KIT_STAGE_RESULT finish-line {"elapsed_seconds":1.95,"execution_id":2,"expired":false,"measurements":[{"held_seconds":0.0166666666666667,"met":true,"metric":"min_x","part_index":-1,"state":"valid","value":0.501516819000244}],"reason":"","status":"success","success":true,"wall_contact":false}
KIT_STAGE_RESULT wall-brake {"elapsed_seconds":15.6333333333337,"execution_id":2,"expired":false,"measurements":[{"held_seconds":2.15,"met":true,"metric":"wall_distance","part_index":-1,"state":"valid","value":0.0733921527862549},{"held_seconds":0.0,"met":false,"metric":"robot_speed","part_index":-1,"state":"valid","value":0.0619057938456535},{"held_seconds":15.6333333333337,"met":true,"metric":"wall_contact","part_index":-1,"state":"valid","value":0.0}],"reason":"","status":"running","success":false,"wall_contact":false}
KIT_STAGE_BODY_SPEEDS [{"id":"kit_plate_220_120","speed_m_s":0.000509700214024633},{"id":"kit_beam_140","speed_m_s":0.000509700214024633},{"id":"tt_motor","speed_m_s":0.000509700214024633},{"id":"kit_wheel_90","speed_m_s":0.000929278845433146},{"id":"kit_beam_140","speed_m_s":0.000509700214024633},{"id":"tt_motor","speed_m_s":0.000509700214024633},{"id":"kit_wheel_90","speed_m_s":0.000708147417753935},{"id":"kit_beam_100","speed_m_s":0.000509700214024633},{"id":"kit_beam_100","speed_m_s":0.000509700214024633},{"id":"microbit","speed_m_s":0.000509700214024633},{"id":"motor_driver","speed_m_s":0.000509700214024633},{"id":"kit_spacer_20","speed_m_s":0.000509700214024633},{"id":"ball_caster","speed_m_s":0.0619057938456535},{"id":"kit_angle_bracket","speed_m_s":0.000509700214024633},{"id":"hc_sr04","speed_m_s":0.000509700214024633},{"id":"stage_wall","speed_m_s":0.0}]
ERROR: wall-brake unchanged answer physically clears kit stage
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _check (res://tests/kit_robot_runtime_check.gd:15)
       [1] _run (res://tests/kit_robot_runtime_check.gd:109)
kit_robot_runtime_check: 106 checks, 1 failures

RUN  parts_pack_button_check
PASS parts_pack_button_check (0.5s)
RUN  parts_pack_environment_check
PASS parts_pack_environment_check (1.5s)
RUN  parts_pack_gears_check
PASS parts_pack_gears_check (1.8s)
RUN  parts_pack_inventory_check
PASS parts_pack_inventory_check (4.2s)
RUN  parts_pack_led_check
PASS parts_pack_led_check (0.4s)
RUN  parts_pack_line_check
PASS parts_pack_line_check (0.6s)
RUN  parts_tray_check
PASS parts_tray_check (2.8s)
RUN  robot_car_check
PASS robot_car_check (0.7s)
RUN  sonar_stage_check
PASS sonar_stage_check (17.1s)
RUN  stage_authoring_check
FAIL stage_authoring_check (19.6s)
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

STAGE_RESULT raise-flag {"elapsed_seconds":2.15,"execution_id":3,"expired":false,"measurements":[{"held_seconds":1.0,"met":true,"metric":"max_height","part_index":-1,"state":"valid","value":0.203843221068382}],"reason":"","status":"success","success":true,"wall_contact":false}
STAGE_RESULT finish-line {"elapsed_seconds":1.96666666666666,"execution_id":6,"expired":false,"measurements":[{"held_seconds":0.0166666666666667,"met":true,"metric":"min_x","part_index":-1,"state":"valid","value":0.501516282558441}],"reason":"","status":"success","success":true,"wall_contact":false}
STAGE_RESULT wall-brake {"elapsed_seconds":15.0000000000003,"execution_id":9,"expired":false,"measurements":[{"held_seconds":1.5,"met":true,"metric":"wall_distance","part_index":-1,"state":"valid","value":0.07334965467453},{"held_seconds":0.0,"met":false,"metric":"robot_speed","part_index":-1,"state":"valid","value":0.0620631650090218},{"held_seconds":15.0000000000003,"met":true,"metric":"wall_contact","part_index":-1,"state":"valid","value":0.0}],"reason":"","status":"running","success":false,"wall_contact":false}
ERROR: actual author solution clears wall-brake
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _check (res://tests/stage_authoring_check.gd:101)
       [1] _run (res://tests/stage_authoring_check.gd:39)
ERROR: stage outcome remains visible while viewing code
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _check (res://tests/stage_authoring_check.gd:101)
       [1] _run (res://tests/stage_authoring_check.gd:40)
ERROR: fresh observed proof enables export
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _check (res://tests/stage_authoring_check.gd:101)
       [1] _run (res://tests/stage_authoring_check.gd:41)
stage_authoring_check: 44 checks, 3 failures

RUN  stage_contract_check
PASS stage_contract_check (15.6s)
RUN  stage_own_build_check
FAIL stage_own_build_check (48.5s)
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

OWN_BUILD_RESULT raise-flag {"elapsed_seconds":1.21666666666667,"execution_id":5,"expired":false,"measurements":[{"held_seconds":1.0,"met":true,"metric":"max_height","part_index":-1,"state":"valid","value":0.196155324578285}],"reason":"","status":"success","success":true,"wall_contact":false}
OWN_BUILD_RESULT finish-line {"elapsed_seconds":1.96666666666666,"execution_id":5,"expired":false,"measurements":[{"held_seconds":0.0166666666666667,"met":true,"metric":"min_x","part_index":-1,"state":"valid","value":0.502577364444733}],"reason":"","status":"success","success":true,"wall_contact":false}
OWN_BUILD_RESULT wall-brake {"elapsed_seconds":15.9333333333337,"execution_id":5,"expired":false,"measurements":[{"held_seconds":2.43333333333333,"met":true,"metric":"wall_distance","part_index":-1,"state":"valid","value":0.0738911032676697},{"held_seconds":0.0,"met":false,"metric":"robot_speed","part_index":-1,"state":"valid","value":0.0624377094209194},{"held_seconds":15.9333333333337,"met":true,"metric":"wall_contact","part_index":-1,"state":"valid","value":0.0}],"reason":"program_finished","status":"not_met","success":false,"wall_contact":false}
ERROR: wall-brake author graph and code physically clear
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _check (res://tests/stage_own_build_check.gd:15)
       [1] _run (res://tests/stage_own_build_check.gd:60)
       [2] _wait (res://tests/stage_own_build_check.gd:37)
       [3] _settle (res://tests/stage_own_build_check.gd:20)
OWN_BUILD_RESULT finish-line {"elapsed_seconds":2.0,"execution_id":7,"expired":false,"measurements":[{"held_seconds":0.0,"met":false,"metric":"min_x","part_index":-1,"state":"valid","value":0.00419505592435598}],"reason":"program_finished","status":"not_met","success":false,"wall_contact":false}
OWN_BUILD_RESULT raise-flag {"elapsed_seconds":1.21666666666667,"execution_id":5,"expired":false,"measurements":[{"held_seconds":1.0,"met":true,"metric":"max_height","part_index":-1,"state":"valid","value":0.193403735756874}],"reason":"","status":"success","success":true,"wall_contact":false}
stage_own_build_check: 164 checks, 1 failures

14 checks; 4 failures. Results: C:\Users\Hojun\agent-jobs\ssok-M2b-20261105\repo\build\verification-m2b-target\SUMMARY.md
```

전체 출력:

```text
RUN  import
PASS import (2.8s)
RUN  scene-load
PASS scene-load (0.5s)
RUN  agent_camera_loop_check
PASS agent_camera_loop_check (4.1s)
RUN  agent_camera_loop_check-rendered
PASS agent_camera_loop_check-rendered (10.8s)
RUN  agent_camera_rest_check
PASS agent_camera_rest_check (14.4s)
RUN  agent_goal_ui_check
PASS agent_goal_ui_check (4.4s)
RUN  agent_goal_ui_check-rendered
PASS agent_goal_ui_check-rendered (11.9s)
RUN  app_controller_check
PASS app_controller_check (4.2s)
RUN  assembly_snap_check
PASS assembly_snap_check (0.4s)
RUN  authoring_ui_check
PASS authoring_ui_check (4.3s)
RUN  biped_app_check
PASS biped_app_check (13.7s)
RUN  biped_board_clearance_check
PASS biped_board_clearance_check (1.5s)
RUN  biped_motion_check
PASS biped_motion_check (1.9s)
RUN  blender_camera_check
PASS blender_camera_check (0.3s)
RUN  blender_edit_check
PASS blender_edit_check (0.4s)
RUN  block_program_check
PASS block_program_check (3.9s)
RUN  bridge_stop_owner_check
PASS bridge_stop_owner_check (5.4s)
RUN  browser_evidence_check
PASS browser_evidence_check (4.3s)
RUN  camera_evaluator_lifecycle_check-normal_stop
PASS camera_evaluator_lifecycle_check-normal_stop (5.3s)
RUN  camera_evaluator_lifecycle_check-drive_stop
PASS camera_evaluator_lifecycle_check-drive_stop (11.4s)
RUN  camera_evaluator_lifecycle_check-teardown
PASS camera_evaluator_lifecycle_check-teardown (5.2s)
RUN  camera_evaluator_lifecycle_check-mode_off
PASS camera_evaluator_lifecycle_check-mode_off (5.3s)
RUN  camera_evaluator_lifecycle_check-app_free
PASS camera_evaluator_lifecycle_check-app_free (5.0s)
RUN  camera_evaluator_lifecycle_check-rebuild
PASS camera_evaluator_lifecycle_check-rebuild (5.2s)
RUN  camera_evaluator_lifecycle_check-new_episode
PASS camera_evaluator_lifecycle_check-new_episode (6.4s)
RUN  camera_evaluator_lifecycle_check-driving_stop
PASS camera_evaluator_lifecycle_check-driving_stop (5.4s)
RUN  camera_evaluator_lifecycle_check-driving_rebuild
PASS camera_evaluator_lifecycle_check-driving_rebuild (5.5s)
RUN  camera_evaluator_lifecycle_check-driving_app_free
PASS camera_evaluator_lifecycle_check-driving_app_free (5.1s)
RUN  camera_evaluator_lifecycle_check-driving_new_episode
PASS camera_evaluator_lifecycle_check-driving_new_episode (6.6s)
RUN  camera_evaluator_lifecycle_check-driving_teardown
PASS camera_evaluator_lifecycle_check-driving_teardown (5.6s)
RUN  camera_evaluator_lifecycle_check-driving_mode_off
PASS camera_evaluator_lifecycle_check-driving_mode_off (5.3s)
RUN  construction_kit_check
PASS construction_kit_check (1.1s)
RUN  construction_kit_motion_check
PASS construction_kit_motion_check (7.0s)
RUN  construction_kit_store_check
PASS construction_kit_store_check (2.9s)
RUN  construction_kit_ui_check
PASS construction_kit_ui_check (4.5s)
RUN  control_flow_check
PASS control_flow_check (4.1s)
RUN  core_authoring_check
PASS core_authoring_check (4.7s)
RUN  device_kit_ports_check
PASS device_kit_ports_check (0.5s)
RUN  flag_mission_check
PASS flag_mission_check (3.9s)
RUN  game_flow_check
FAIL game_flow_check (36.5s)
"success": false, "expired": false, "elapsed_seconds": 2.0, "measurements": [{ "metric": "min_x", "part_index": -1, "value": 0.00419510155916, "state": "valid", "held_seconds": 0.0, "met": false }], "wall_contact": false } measurements=[{ "metric": "min_x", "part_index": -1, "value": 0.00419510155916, "state": "valid", "held_seconds": 0.0, "met": false }]
CHECK ok   the short starter drive does not reach the finish line
RESULT { "status": "success", "reason": "", "execution_id": 6, "success": true, "expired": false, "elapsed_seconds": 1.96666666666666, "measurements": [{ "metric": "min_x", "part_index": -1, "value": 0.50257760286331, "state": "valid", "held_seconds": 0.01666666666667, "met": true }], "wall_contact": false } measurements=[{ "metric": "min_x", "part_index": -1, "value": 0.50257760286331, "state": "valid", "held_seconds": 0.01666666666667, "met": true }]
CHECK ok   a longer drive crosses the finish line
CHECK ok   stage list returns to the map
CHECK ok   wall-brake level loads from the map
RESULT { "status": "not_met", "reason": "program_finished", "execution_id": 5, "success": false, "expired": false, "elapsed_seconds": 15.9333333333337, "measurements": [{ "metric": "wall_distance", "part_index": -1, "value": 0.07388705015182, "state": "valid", "held_seconds": 2.43333333333333, "met": true }, { "metric": "robot_speed", "part_index": -1, "value": 0.06243774667382, "state": "valid", "held_seconds": 0.0, "met": false }, { "metric": "wall_contact", "part_index": -1, "value": 0.0, "state": "valid", "held_seconds": 15.9333333333337, "met": true }], "wall_contact": false } measurements=[{ "metric": "wall_distance", "part_index": -1, "value": 0.07388705015182, "state": "valid", "held_seconds": 2.43333333333333, "met": true }, { "metric": "robot_speed", "part_index": -1, "value": 0.06243774667382, "state": "valid", "held_seconds": 0.0, "met": false }, { "metric": "wall_contact", "part_index": -1, "value": 0.0, "state": "valid", "held_seconds": 15.9333333333337, "met": true }]
CHECK FAIL the sensor loop stops in the zone
ERROR: the sensor loop stops in the zone
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _check (res://tests/game_flow_check.gd:23)
       [1] _run (res://tests/game_flow_check.gd:141)
       [2] _wait_result (res://tests/game_flow_check.gd:182)
       [3] _frames (res://tests/game_flow_check.gd:28)
CHECK ok   leaving a stage returns to the stage list
CHECK ok   free building opens a lab workshop
CHECK ok   lab keeps the full library and default floor
CHECK ok   lab keeps authoring but not the stage picker
CHECK ok   lab hides example robots and the AI lab
CHECK ok   lab shows no flag mission
CHECK ok   an unchanged lab exits straight to the title
CHECK ok   examples open their own list
CHECK ok   an example loads its robot
CHECK ok   a non-flag example shows no flag visual
CHECK ok   examples hide challenge authoring
game_flow_check: 43 checks, 1 failures

RUN  humanoid_contract_check
PASS humanoid_contract_check (0.4s)
RUN  humanoid_motion_check-walk
PASS humanoid_motion_check-walk (1.5s)
RUN  humanoid_motion_check-backward
PASS humanoid_motion_check-backward (1.5s)
RUN  humanoid_motion_check-pick
PASS humanoid_motion_check-pick (1.5s)
RUN  humanoid_motion_check-run
PASS humanoid_motion_check-run (1.5s)
RUN  humanoid_motion_check-walk-reverse-links
PASS humanoid_motion_check-walk-reverse-links (1.5s)
RUN  humanoid_motion_check-run-reverse-links
PASS humanoid_motion_check-run-reverse-links (1.5s)
RUN  humanoid_motion_check-run-settle-frames=181
PASS humanoid_motion_check-run-settle-frames=181 (1.5s)
RUN  humanoid_ui_check
PASS humanoid_ui_check (4.8s)
RUN  humanoid_ui_check-modular
PASS humanoid_ui_check-modular (5.2s)
RUN  interface_preferences_check
PASS interface_preferences_check (6.2s)
RUN  keyboard_navigation_check
PASS keyboard_navigation_check (4.1s)
RUN  kit_robot_runtime_check
FAIL kit_robot_runtime_check (9.9s)
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

KIT_RUNTIME_MEASUREMENTS {"drive_dx_m":0.853422910498921,"left_pin":0,"moved_wall_cm":89.2371535301209,"right_pin":12,"sonar_cm":69.2182421684265,"sonar_pins":[1,2]}
KIT_STAGE_RESULT raise-flag {"elapsed_seconds":1.2,"execution_id":2,"expired":false,"measurements":[{"held_seconds":1.0,"met":true,"metric":"max_height","part_index":-1,"state":"valid","value":0.193339750170708}],"reason":"","status":"success","success":true,"wall_contact":false}
KIT_STAGE_RESULT finish-line {"elapsed_seconds":1.95,"execution_id":2,"expired":false,"measurements":[{"held_seconds":0.0166666666666667,"met":true,"metric":"min_x","part_index":-1,"state":"valid","value":0.501516819000244}],"reason":"","status":"success","success":true,"wall_contact":false}
KIT_STAGE_RESULT wall-brake {"elapsed_seconds":15.6333333333337,"execution_id":2,"expired":false,"measurements":[{"held_seconds":2.15,"met":true,"metric":"wall_distance","part_index":-1,"state":"valid","value":0.0733921527862549},{"held_seconds":0.0,"met":false,"metric":"robot_speed","part_index":-1,"state":"valid","value":0.0619057938456535},{"held_seconds":15.6333333333337,"met":true,"metric":"wall_contact","part_index":-1,"state":"valid","value":0.0}],"reason":"","status":"running","success":false,"wall_contact":false}
KIT_STAGE_BODY_SPEEDS [{"id":"kit_plate_220_120","speed_m_s":0.000509700214024633},{"id":"kit_beam_140","speed_m_s":0.000509700214024633},{"id":"tt_motor","speed_m_s":0.000509700214024633},{"id":"kit_wheel_90","speed_m_s":0.000929278845433146},{"id":"kit_beam_140","speed_m_s":0.000509700214024633},{"id":"tt_motor","speed_m_s":0.000509700214024633},{"id":"kit_wheel_90","speed_m_s":0.000708147417753935},{"id":"kit_beam_100","speed_m_s":0.000509700214024633},{"id":"kit_beam_100","speed_m_s":0.000509700214024633},{"id":"microbit","speed_m_s":0.000509700214024633},{"id":"motor_driver","speed_m_s":0.000509700214024633},{"id":"kit_spacer_20","speed_m_s":0.000509700214024633},{"id":"ball_caster","speed_m_s":0.0619057938456535},{"id":"kit_angle_bracket","speed_m_s":0.000509700214024633},{"id":"hc_sr04","speed_m_s":0.000509700214024633},{"id":"stage_wall","speed_m_s":0.0}]
ERROR: wall-brake unchanged answer physically clears kit stage
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _check (res://tests/kit_robot_runtime_check.gd:15)
       [1] _run (res://tests/kit_robot_runtime_check.gd:109)
kit_robot_runtime_check: 106 checks, 1 failures

RUN  learned_app_check
PASS learned_app_check (4.2s)
RUN  learned_policy_check
PASS learned_policy_check (3.8s)
RUN  learned_tracking_check
PASS learned_tracking_check (5.0s)
RUN  learner_language_check
PASS learner_language_check (0.3s)
RUN  localization_check
PASS localization_check (4.7s)
RUN  manual_control_check
PASS manual_control_check (0.4s)
RUN  material_assets_check
PASS material_assets_check (0.5s)
RUN  mesh_assets_check
PASS mesh_assets_check (0.5s)
RUN  modular_humanoid_check-walk
PASS modular_humanoid_check-walk (0.6s)
RUN  modular_humanoid_check-pick
PASS modular_humanoid_check-pick (0.6s)
RUN  modular_humanoid_check-pick-reverse-links
PASS modular_humanoid_check-pick-reverse-links (0.6s)
RUN  modular_pickup_parallel_check
PASS modular_pickup_parallel_check (3.1s)
RUN  motion_lab_check
PASS motion_lab_check (9.8s)
RUN  motion_lab_ui_check
PASS motion_lab_ui_check (6.6s)
RUN  parts_freedom_blocks_check
PASS parts_freedom_blocks_check (0.3s)
RUN  parts_freedom_mechanics_check
PASS parts_freedom_mechanics_check (5.5s)
RUN  parts_freedom_runtime_check
PASS parts_freedom_runtime_check (0.5s)
RUN  parts_freedom_workshop_check
PASS parts_freedom_workshop_check (5.3s)
RUN  parts_pack_button_check
PASS parts_pack_button_check (0.5s)
RUN  parts_pack_environment_check
PASS parts_pack_environment_check (1.6s)
RUN  parts_pack_gears_check
PASS parts_pack_gears_check (1.8s)
RUN  parts_pack_inventory_check
PASS parts_pack_inventory_check (4.2s)
RUN  parts_pack_led_check
PASS parts_pack_led_check (0.4s)
RUN  parts_pack_line_check
PASS parts_pack_line_check (0.7s)
RUN  parts_tray_check
PASS parts_tray_check (2.9s)
RUN  pickup_bridge_ui_check
PASS pickup_bridge_ui_check (8.6s)
RUN  pickup_lab_ui_check
PASS pickup_lab_ui_check (7.2s)
RUN  pickup_store_check
PASS pickup_store_check (6.5s)
RUN  pickup_trial_check
PASS pickup_trial_check (6.9s)
RUN  port_indicators_check
PASS port_indicators_check (0.4s)
RUN  project_store_check
PASS project_store_check (5.8s)
RUN  relative_code_check
PASS relative_code_check (0.5s)
RUN  robot_car_check
PASS robot_car_check (0.7s)
RUN  run_mode_check
PASS run_mode_check (0.4s)
RUN  scene_workshop_ui_check
PASS scene_workshop_ui_check (20.0s)
RUN  servo_torque_budget_check
PASS servo_torque_budget_check (0.3s)
RUN  snap_build_check
PASS snap_build_check (0.4s)
RUN  snap_build_input_check
PASS snap_build_input_check (4.6s)
RUN  sonar_stage_check
PASS sonar_stage_check (17.5s)
RUN  stage_authoring_check
FAIL stage_authoring_check (19.3s)
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

STAGE_RESULT raise-flag {"elapsed_seconds":2.15,"execution_id":3,"expired":false,"measurements":[{"held_seconds":1.0,"met":true,"metric":"max_height","part_index":-1,"state":"valid","value":0.203843221068382}],"reason":"","status":"success","success":true,"wall_contact":false}
STAGE_RESULT finish-line {"elapsed_seconds":1.96666666666666,"execution_id":6,"expired":false,"measurements":[{"held_seconds":0.0166666666666667,"met":true,"metric":"min_x","part_index":-1,"state":"valid","value":0.501516282558441}],"reason":"","status":"success","success":true,"wall_contact":false}
STAGE_RESULT wall-brake {"elapsed_seconds":15.0000000000003,"execution_id":9,"expired":false,"measurements":[{"held_seconds":1.5,"met":true,"metric":"wall_distance","part_index":-1,"state":"valid","value":0.07334965467453},{"held_seconds":0.0,"met":false,"metric":"robot_speed","part_index":-1,"state":"valid","value":0.0620631650090218},{"held_seconds":15.0000000000003,"met":true,"metric":"wall_contact","part_index":-1,"state":"valid","value":0.0}],"reason":"","status":"running","success":false,"wall_contact":false}
ERROR: actual author solution clears wall-brake
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _check (res://tests/stage_authoring_check.gd:101)
       [1] _run (res://tests/stage_authoring_check.gd:39)
ERROR: stage outcome remains visible while viewing code
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _check (res://tests/stage_authoring_check.gd:101)
       [1] _run (res://tests/stage_authoring_check.gd:40)
ERROR: fresh observed proof enables export
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _check (res://tests/stage_authoring_check.gd:101)
       [1] _run (res://tests/stage_authoring_check.gd:41)
stage_authoring_check: 44 checks, 3 failures

RUN  stage_contract_check
PASS stage_contract_check (16.1s)
RUN  stage_own_build_check
FAIL stage_own_build_check (48.0s)
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

OWN_BUILD_RESULT raise-flag {"elapsed_seconds":1.21666666666667,"execution_id":5,"expired":false,"measurements":[{"held_seconds":1.0,"met":true,"metric":"max_height","part_index":-1,"state":"valid","value":0.196155324578285}],"reason":"","status":"success","success":true,"wall_contact":false}
OWN_BUILD_RESULT finish-line {"elapsed_seconds":1.96666666666666,"execution_id":5,"expired":false,"measurements":[{"held_seconds":0.0166666666666667,"met":true,"metric":"min_x","part_index":-1,"state":"valid","value":0.502577364444733}],"reason":"","status":"success","success":true,"wall_contact":false}
OWN_BUILD_RESULT wall-brake {"elapsed_seconds":15.9333333333337,"execution_id":5,"expired":false,"measurements":[{"held_seconds":2.43333333333333,"met":true,"metric":"wall_distance","part_index":-1,"state":"valid","value":0.0738911032676697},{"held_seconds":0.0,"met":false,"metric":"robot_speed","part_index":-1,"state":"valid","value":0.0624377094209194},{"held_seconds":15.9333333333337,"met":true,"metric":"wall_contact","part_index":-1,"state":"valid","value":0.0}],"reason":"program_finished","status":"not_met","success":false,"wall_contact":false}
ERROR: wall-brake author graph and code physically clear
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _check (res://tests/stage_own_build_check.gd:15)
       [1] _run (res://tests/stage_own_build_check.gd:60)
       [2] _wait (res://tests/stage_own_build_check.gd:37)
       [3] _settle (res://tests/stage_own_build_check.gd:20)
OWN_BUILD_RESULT finish-line {"elapsed_seconds":2.0,"execution_id":7,"expired":false,"measurements":[{"held_seconds":0.0,"met":false,"metric":"min_x","part_index":-1,"state":"valid","value":0.00419505592435598}],"reason":"program_finished","status":"not_met","success":false,"wall_contact":false}
OWN_BUILD_RESULT raise-flag {"elapsed_seconds":1.21666666666667,"execution_id":5,"expired":false,"measurements":[{"held_seconds":1.0,"met":true,"metric":"max_height","part_index":-1,"state":"valid","value":0.193403735756874}],"reason":"","status":"success","success":true,"wall_contact":false}
stage_own_build_check: 164 checks, 1 failures

RUN  stage_ui_check
PASS stage_ui_check (4.1s)
RUN  tutorial_ui_check
PASS tutorial_ui_check (4.4s)
RUN  viewport_framing_check
PASS viewport_framing_check (5.2s)
RUN  workshop_compact_check
PASS workshop_compact_check (20.2s)
RUN  workshop_emphasis_check
PASS workshop_emphasis_check (10.4s)
RUN  workshop_goal_observation_check
PASS workshop_goal_observation_check (15.5s)
RUN  workshop_goal_space_check
PASS workshop_goal_space_check (18.5s)
RUN  workshop_presentation_check
PASS workshop_presentation_check (14.7s)
RUN  workshop_road_check
PASS workshop_road_check (0.3s)
RUN  workshop_run_label_check
PASS workshop_run_label_check (4.7s)
RUN  workshop_ui_check
PASS workshop_ui_check (4.4s)
RUN  yaw_biped_check
PASS yaw_biped_check (0.5s)
RUN  tests-camera_experiment_check.py
PASS tests-camera_experiment_check.py (0.1s)
RUN  tests-desktop_client_check.py
PASS tests-desktop_client_check.py (0.7s)
RUN  tests-desktop_session_check.py
PASS tests-desktop_session_check.py (0.2s)
RUN  tests-motion_mcp_check.py
FAIL tests-motion_mcp_check.py (0.1s)
motion_mcp_check (unittest.loader._FailedTest.motion_mcp_check) ... ERROR

======================================================================
ERROR: motion_mcp_check (unittest.loader._FailedTest.motion_mcp_check)
----------------------------------------------------------------------
ImportError: Failed to import test module: motion_mcp_check
Traceback (most recent call last):
  File "C:\Users\Hojun\AppData\Local\Programs\Python\Python313\Lib\unittest\loader.py", line 137, in loadTestsFromName
    module = __import__(module_name)
  File "C:\Users\Hojun\agent-jobs\ssok-M2b-20261105\repo\tests\motion_mcp_check.py", line 16, in <module>
    from mcp import Client, StdioServerParameters
ModuleNotFoundError: No module named 'mcp'


----------------------------------------------------------------------
Ran 1 test in 0.000s

FAILED (errors=1)

RUN  tests-test_ci_verify.py
PASS tests-test_ci_verify.py (1.3s)
RUN  tests-test_desktop_package.py
PASS tests-test_desktop_package.py (0.1s)
RUN  tests-test_operator_doctor.py
PASS tests-test_operator_doctor.py (0.1s)
RUN  tests-test_operator_release.py
PASS tests-test_operator_release.py (0.2s)
RUN  tests-test_pickup_bridge.py
PASS tests-test_pickup_bridge.py (2.2s)
RUN  tests-test_release_documents.py
PASS tests-test_release_documents.py (18.3s)
RUN  tools-docs-test_maintain.py
PASS tools-docs-test_maintain.py (0.2s)
RUN  tools-motion_lab-test_races.py
PASS tools-motion_lab-test_races.py (1.7s)
RUN  tools-motion_lab-test_service.py
PASS tools-motion_lab-test_service.py (1.7s)
RUN  tools-rl_lab-test_rl_lab.py
FAIL tools-rl_lab-test_rl_lab.py (0.1s)
test_rl_lab (unittest.loader._FailedTest.test_rl_lab) ... ERROR

======================================================================
ERROR: test_rl_lab (unittest.loader._FailedTest.test_rl_lab)
----------------------------------------------------------------------
ImportError: Failed to import test module: test_rl_lab
Traceback (most recent call last):
  File "C:\Users\Hojun\AppData\Local\Programs\Python\Python313\Lib\unittest\loader.py", line 137, in loadTestsFromName
    module = __import__(module_name)
  File "C:\Users\Hojun\agent-jobs\ssok-M2b-20261105\repo\tools\rl_lab\test_rl_lab.py", line 10, in <module>
    import mujoco
ModuleNotFoundError: No module named 'mujoco'


----------------------------------------------------------------------
Ran 1 test in 0.000s

FAILED (errors=1)

121 checks; 6 failures. Results: C:\Users\Hojun\agent-jobs\ssok-M2b-20261105\repo\build\verification-m2b-full\SUMMARY.md
```

문서 유지보수는 `maintain.py --write`, `--check`, 문서 도구 unittest 10/0이에요.
첫 check에서 상속된 M2 검토 해시 7건이 낡은 것을 확인했고 DATA_MODEL/FLOWS와 실제
catalog·트레이·Stage·프리셋 소스를 대조한 뒤 `--review data-model --review execution-flow`를
기록했어요. 설명·도식의 관계는 현재 구현과 맞으므로 유지했어요.
CSV 26개는 LF 정규화 해시·샘플 수·tick 구간·선속도 벡터 크기를 확인했어요.
독립 진단 검토와 앱 실행 검사는 별개예요.

다음 작업은 구속/접촉의 속도 잔류 원인을 분리하고, 필요하면 그래프에 고정된 하우징과
낮은 마찰 구의 물리 표현을 설계하는 것이에요. 이는 아직 구현하거나 채택하지 않았어요.
검증된 수정 없이 브리프의 중단 조건으로 인계해요. 푸시·병합·배포는 하지 않았어요.
