# 모듈형 조립: 구멍에 끼워 만들기

결정 기록은 [ADR 0039](../adr/0039-hole-targeted-snap-building.md)에 있어요. 이 문서는 화면과 조작의 명세예요. 구현은 이 문서를 기준으로 하고, 명세와 다르게 해야 하면 이유를 작업 요약에 적어요.

## 목표

학습자가 빈 작업대에서 빔과 판, 모터를 하나씩 골라 구멍끼리 맞춰 끼우면서 로봇을 쌓아 가요. 손에 남아야 하는 느낌은 세 가지예요.

1. 부품을 집으면 어디에 끼울 수 있는지 구멍이 보여요.
2. 구멍 위로 가져가면 끼워질 모습이 미리 보이고, 클릭하면 그대로 붙어요.
3. 붙은 자리에는 볼트가 박혀 있어서 고정된 게 보여요.

연결 그래프, 실행 물리, 배선, 코드, 스테이지 판정은 바꾸지 않아요.

## 상태

| 상태 | 들어가는 방법 | 화면 |
|---|---|---|
| 평소 | 기본 | 부품과 볼트 머리. 구멍 링은 없음 |
| 선택 | 부품 짧게 클릭(이동 4 px 미만) | 선택 외곽선, 선택 부품의 빈 구멍 링 |
| 끼우기 | 트레이 부품을 누르고 끌기, 또는 한 번 클릭 | 커서를 따라다니는 고스트, 모든 부품의 빈 구멍 링, 대상 구멍 강조 |
| 다시 끼우기 | 놓인 부품을 누른 채 4 px 넘게 끌기 | 그 부품의 기계 링크를 풀고 끼우기 상태와 같은 화면 |
| 막힘 | 끼우기 중 고스트가 다른 부품에 2 mm 넘게 파고들거나 맞는 구멍이 없음 | 고스트가 오류 색, 클릭해도 안 붙음 |
| Blender 편집 | 선택 뒤 G·R(기존) | 지금 동작 그대로. 고급 조작으로 남김 |

## 끼우기 동작

### 대상 구멍 고르기
- 커서 레이가 부품에 맞으면 그 부품의 포트 가운데 비어 있고(링크 없음) 고스트의 어떤 포트와 호환되는(`accepts`) 것만 후보로 둬요.
- 후보 중 맞은 점에서 가장 가까운 포트를 골라요. 거리가 같으면 법선이 카메라 쪽을 향하는 면(`dot(normal, -ray_dir) > 0`)을 먼저 골라요. 구멍 하나에 앞뒤 포트가 있으니 보이는 면에 붙게 돼요.
- 레이가 부품에 맞지 않으면 바닥 평면(`FLOOR_TOP`)과의 교점에 놓아요. 부품 바닥이 바닥 위에 닿게 올리고 위치는 10 mm 격자에 맞춰요. 링크는 만들지 않아요.

### 고스트 자세
- 앵커 포트는 고스트 부품에서 대상 구멍에 끼울 포트예요. 기본값은 대상과 호환되는 첫 포트(빔이면 한쪽 끝 구멍)이고, 같은 부품을 다시 집으면 마지막에 쓴 앵커를 기억해요.
- 정렬은 `AssemblyMode.snap()`의 법선 정렬 수식과 같아요. 앵커 법선이 대상 법선의 반대를 향하고 두 포트 위치가 겹쳐요.
- 정렬 뒤 대상 법선을 축으로 `twist × 90°`만큼 돌려요.
- 회전 축 포트(`rotates`가 참이거나 축·허브 태그)에 끼울 때도 같은 방식이에요. 바퀴를 모터 축에 꽂는 경우가 여기에 해당해요.

### 조작
| 입력 | 끼우기 중 동작 |
|---|---|
| 마우스 이동 | 대상 구멍과 고스트 자세 갱신 |
| 왼쪽 클릭, 또는 끌던 버튼 놓기 | 확정(막힘이면 무시하고 이유 표시) |
| 오른쪽 클릭, Esc | 취소. 그래프 변화 없음(다시 끼우기였으면 원래 자리와 링크로 복구) |
| R, 마우스 휠 위 | 대상 법선 축으로 +90° |
| Shift+R, 마우스 휠 아래 | −90° |
| Tab | 앵커를 고스트의 다음 호환 포트로 |
| F | 앵커를 같은 구멍의 반대 면 포트로(부품 뒤집기) |

끼우기 중에는 휠이 회전을 맡아요. 카메라 확대는 끼우기 밖에서만 해요. 가운데 버튼 궤도 회전과 Shift 이동은 끼우기 중에도 돼요.

### 확정
- 부품을 추가하고 앵커 링크를 만들어요.
- 이어서 새 부품의 빈 포트와 다른 부품의 빈 포트 가운데 위치가 0.5 mm 안에서 겹치고, 법선이 반대(`dot < −0.99`)이고, 서로 호환되는 쌍을 모두 링크해요. 빔을 판 위에 구멍 줄을 맞춰 놓으면 겹친 구멍 수만큼 묶여요.
- 부품 추가와 모든 링크를 실행 취소 한 번으로 되돌려요.
- 확정 뒤에도 끼우기 상태를 유지하지 않아요. 같은 부품을 하나 더 놓으려면 트레이에서 다시 집어요.

### 다시 끼우기
- 끌기를 시작하면 그 부품의 기계 링크만 풀어요(배선은 유지, 지금의 `unsnap`과 같음).
- 확정·취소 규칙은 끼우기와 같아요. 실행 취소 한 번이면 끌기 전 상태로 돌아가요.
- 연결된 부품 묶음을 통째로 옮기는 기능은 이번 범위 밖이에요.

### 막힘 판정
- 고스트의 `PartDef.collision_boxes`를 각 면에서 2 mm 줄인 상자가 다른 부품의 충돌 상자와 겹치면 막힘이에요. 구멍끼리 맞닿은 면 접촉은 막힘이 아니에요.
- 맞는 구멍이 하나도 없는 부품 위에 있을 때도 막힘이에요. 이때 문구는 "다른 구멍"이 아니라 "바닥이나 다른 부품"을 안내해요.

### 피킹
- 레이 피킹은 메시 전체 AABB가 아니라 `collision_boxes` 기반이어야 해요. 빈 프레임 안쪽을 클릭하면 뒤에 있는 부품이 잡혀야 해요.
- 기즈모 손잡이는 부품과 다른 충돌 레이어에 둬서 끼우기 레이를 가리지 않게 해요.

## 시각 표현

색은 `SsokTheme`을 따라요. 밝은 테마 값은 괄호 안이에요.

| 요소 | 모양 | 색 |
|---|---|---|
| 빈 구멍 링 | 구멍 법선을 향한 납작한 링, 바깥 지름 6.4 mm, 안 지름 4.4 mm, 구멍 면에서 0.3 mm 띄움 | `ACCENT` 72d9bb(166e59), 불투명도 0.55 |
| 대상 구멍 링 | 같은 링을 1.6배로, 불투명도 1 | `ACCENT` |
| 회전 축 포트 링 | 같은 크기 | e6bb84(895214), 불투명도 0.7 |
| 볼트 머리 | 링크된 `kit_m4` 포트마다 지름 7 mm, 높이 2.5 mm 육각 머리. 링크 한 개에 하나만(두 포트 중 앞면 쪽) | 기존 금속 재질(`ChassisMetal`보다 약간 밝게) |
| 고스트 | 부품 메시를 반투명으로 | 붙을 수 있음: `ACCENT` 섞기, 불투명도 0.45. 막힘: `ERROR` ff9292(a51d36), 불투명도 0.45 |
| 선택 외곽선 | 지금 동작 유지 | 지금 색 유지 |

- 끼운 구멍(링크가 있는 포트)에는 링을 그리지 않아요.
- 구멍 링과 볼트 머리는 `MultiMeshInstance3D` 한 벌씩으로 그리고, 그래프가 바뀔 때만 다시 만들어요(지금의 `_mark_ports`를 대체).
- 실행 모드에서는 링을 숨기고 볼트 머리는 남겨요.

## 부품 트레이

### 탭
전체, 구조, 움직임, 전자, 센서, 환경. 이름 뒤에 크기나 용량을 붙여요(예: "빔 60 mm", "판 120 × 80 mm", "서보 12 Nm"). 트레이 맨 위에 한 줄 안내를 둬요.

### 보이는 부품
| 탭 | 부품 id |
|---|---|
| 구조 | `kit_beam_60` `kit_beam_100` `kit_beam_140` `kit_beam_180` `kit_beam_240` `kit_beam_260` `kit_plate_60_40` `kit_plate_60_60` `kit_plate_80_60` `kit_plate_120_80` `kit_plate_160_60` `kit_plate_220_120` `kit_angle_bracket` `kit_u_bracket_large` `kit_u_bracket_small` `kit_spacer_20` `kit_coupler_8` `kit_rubber_pad` `kit_weight_100` `kit_weight_300` |
| 움직임 | `kit_motor_12` `kit_motor_35` `tt_motor` `servo` `kit_passive_hinge` `kit_gear_2` `kit_gear_3` `kit_axle_40` `kit_wheel_40` `kit_wheel_90` `wheel_65` `ball_caster` |
| 전자 | `microbit` `arduino_uno` `motor_driver` `tb6612_driver` `kit_led` |
| 센서 | `hc_sr04` `kit_line_sensor` `kit_contact_button` |
| 환경 | `kit_env_ramp_10` `kit_env_ramp_20` `kit_env_ball` `kit_env_cup` `kit_env_line_straight` `kit_env_line_corner` `stage_wall` `flag` |

### 숨기는 부품
- 통짜 조립체와 로봇 전용 덩어리: `car_chassis`, `biped_body`, `base`, `chassis_plate`, `servo_bracket`, `arm_link`, `leg_link`, `foot`, `board`, 휴머노이드(`assets/humanoid`), 모듈 휴머노이드(`assets/modular_humanoid/parts`), 학습 2족(`assets/learning_biped/parts`).
- 코드로 쓸 수 없는 부품: `kit_controller`, `kit_controller_16`(보드 프로필 없음), `kit_optical_sensor`(전기 포트 없음).
- 따로 쥘 필요가 없는 체결 부품: `kit_bolt_4`, `kit_nut_4`. 구멍끼리 링크하면 볼트가 박힌 것으로 보고 볼트 머리를 그려요.

숨긴 부품은 카탈로그(`MotionSnapshot._catalog()`)에 남아 있어서 옛 저장 파일과 프리셋은 그대로 열려요. 트레이 목록은 허용 목록 하나로 관리하고 스테이지 트레이도 같은 목록을 써요.

### 트레이 부품의 조건
- 기계 부품은 키트 구멍(`kit_m4`) 포트나 키트 축 인터페이스(`kit_axle_8`, `kit_shaft_8`, `wheel_hub`) 가운데 하나 이상이 있어야 해요.
- 구동 부품의 출력축은 키트 축 인터페이스 하나 이상을 받아야 해요(바퀴, 축, 커플러, U 브래킷 축).
- `microbit`, `arduino_uno`, `motor_driver`, `tb6612_driver`, `hc_sr04`, `tt_motor`, `servo`, `ball_caster`, `flag`에는 20 mm 간격 `kit_m4` 앞뒤 포트를 더해요. id, 기존 포트, 핀, 실행 동작은 그대로 둬요.

## 문구

해요체로 쓰고, 문장 하나에 한 가지만 말해요. 가운뎃점을 셋 이상 잇거나 대시로 설명을 붙이지 않아요. 네 언어(en, ko, ja, zh_CN)에 같은 키로 넣어요.

| 자리 | ko | en |
|---|---|---|
| 트레이 안내 | 부품을 끌어다 구멍에 끼워요 | Drag a part onto a hole to attach it |
| 끼우기 중 | 구멍에 맞춰 클릭하면 붙어요. R로 돌리고 Tab으로 다른 구멍을 골라요. | Line up a hole and click to attach. R rotates, Tab picks another hole. |
| 대상 없음 | 바닥에 놓거나 다른 부품 위로 가져가 붙여요. | Place it on the floor, or move it over a part to attach. |
| 막힘(겹침) | 여기는 막혀 있어요. 다른 구멍에 대 보세요. | This spot is blocked. Try another hole. |
| 막힘(맞는 구멍 없음) | 이 부품에는 맞는 구멍이 없어요. 바닥이나 다른 부품에 놓아요. | This part has no matching hole here. Try the floor or another part. |
| 확정 | 구멍 %d곳에 붙였어요. | Attached at %d holes. |
| 바닥에 놓음 | 바닥에 놓았어요. | Placed on the floor. |
| 다시 끼우기 | %s 옮기는 중이에요. 구멍을 골라 다시 붙여요. | Moving %s. Pick a hole to attach it again. |
| 취소 | 끼우기를 그만뒀어요. | Placement cancelled. |

- 지금의 "Added %s - G to move, R to rotate, Enter to confirm"와 G·R을 가르치는 안내(`main.gd`, `tutorial_panel.gd`, 스테이지 안내)는 위 문구 기준으로 바꿔요. G·R은 `docs/CONTROLS.md`의 고급 조작 절에만 남겨요.
- 탭 이름: 전체 All, 구조 Structure, 움직임 Motion, 전자 Electronics, 센서 Sensors, 환경 Environment.

## 시험 가능한 API

마우스와 키 입력은 아래 호출만 써요. 검사는 실제 마우스 이벤트 없이 이 호출로 동작을 확인해요.

| 호출 | 동작 |
|---|---|
| `begin_place(def: PartDef) -> bool` | 새 부품 끼우기 시작 |
| `begin_move(part: PartNode) -> bool` | 놓인 부품 다시 끼우기 시작(기계 링크 해제) |
| `update_place_ray(origin: Vector3, direction: Vector3) -> void` | 대상 구멍과 고스트 자세 갱신 |
| `rotate_place(steps: int) -> void` | 90° 단위 회전 |
| `cycle_anchor() -> void` | 앵커 포트 바꾸기 |
| `flip_place() -> void` | 앵커를 반대 면 포트로 |
| `commit_place() -> int` | 확정. 만든 링크 수, 막힘이면 −1 |
| `cancel_place() -> void` | 취소 |
| `placement_state() -> Dictionary` | `active`, `definition_id`, `anchor_port`, `target_part`, `target_port`, `twist`, `blocked`, `reason`, `transform`, `pending_links` |

## 범위 밖

- 연결된 부품 묶음 통째 이동, 볼트·너트를 따로 끼우는 조작, 부품 썸네일 이미지.
- 물리 파라미터, 블록 파서, 보드 API, 스테이지 판정 규칙, `.github/workflows`, 새 의존성.
