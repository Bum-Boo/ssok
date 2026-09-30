# ssok 아키텍처

새 참여자는 [START_HERE](START_HERE.md)에서 작업 경로를 고르세요. 현재 방향과 구현 단계는
[STATUS](STATUS.md), 파일 지도는 [CODE_MAP](generated/CODE_MAP.md), 실제 데이터 관계와 호출 흐름은
[DATA_MODEL](DATA_MODEL.md) / [FLOWS](FLOWS.md)를 참고해요. 아래의 날짜 있는 실험 설명은 이력이에요.

> 2026-09-22: 모터 토크 예산 결함을 [ADR 0020](adr/0020-whole-step-actuator-torque-budget.md)에서 수정했다. 아래 기존 모터 기반 보행·집기·달리기 수치는 이전 구현의 이력이며, 수정된 물리 한계에서의 성공은 별도 재검증 결과로 판단한다.

## 인터페이스 선호도

테마·화면/코드 글자·효과음은 그래프나 프로젝트와 분리한 로컬 설정으로 저장해요. 공유 Theme와 기존 컨트롤을 갱신해 학습자 초안과 실행 VM을 보존해요. 진입점·저장 계약·검증 갱신 규칙은 [설정 문서](INTERFACE_PREFERENCES.md)와 [ADR 0026](adr/0026-interface-preferences.md)에 있어요.

## 비전

마우스 드래그앤드롭으로 메쉬(로봇 파츠)를 연결·조립하고, 실제 기판/상용 제품 기반 코드로 구동하는
시뮬레이션 환경. 프리셋(답지)을 보며 탑다운으로 학습하고, 추후 과제를 얹어 과학상자 같은
교육 플랫폼으로 키운다. 목적은 공간·시간·금전적 제약의 극복.

## 확정된 구조 결정과 현재 보드 방향

아래는 요약표. 각 결정의 맥락·이유·기각된 대안은 [docs/adr/](adr/)에 있고, 그쪽이 정본이다.
결정을 뒤집으려면 여기 표를 고치기 전에 새 ADR로 supersede할 것.

| 항목 | 결정 | ADR |
|---|---|---|
| 첫 프로토타입 | 조립 + 코드 구동을 최소 기능으로 **동시에** 관통하는 얇은 슬라이스 | [0005](adr/0005-first-slice-scope.md) |
| 연결 방식 | **포트/소켓 기반**. 기계 스냅은 위치를 정렬하고, **전기 배선(모터→보드 핀)** 은 위치를 보존한다. 배선 탭과 근접 연결 모두 같은 그래프를 수정한다 | [0002](adr/0002-connection-graph-single-source-of-truth.md), [0007](adr/0007-blender-edit-and-manual-control.md), [0022](adr/0022-electrical-links-preserve-placement.md) |
| 물리 | **하이브리드** — 조립 모드는 키네마틱, 실행 모드는 실물리(RigidBody+Joint+중력) | [0003](adr/0003-hybrid-physics-modes.md) |
| 타겟 보드 | 2026-09-30 사용자 결정: micro:bit 먼저, Uno 두 번째. 이 문서 기준 코드는 가상 서보 API이며 프로파일 구현은 별도 작업. 구조는 특정 보드에 종속시키지 않음 | [0004](adr/0004-hardware-abstraction-three-layers.md), [현재 상태](STATUS.md) |
| 코딩 인터페이스 | 블록 ↔ 실제 코드 토글, **둘 다** | [0004](adr/0004-hardware-abstraction-three-layers.md) |
| 코드 언어 | 유저가 보드/환경에 따라 선택. 플랫폼이 기본값을 추천. 첫 런타임은 Python(MicroPython 스타일) | [0004](adr/0004-hardware-abstraction-three-layers.md) |
| 배포 | 웹 + 데스크톱 모두 (→ GDScript, GL Compatibility) | [0001](adr/0001-engine-and-deployment-targets.md) |
| 첫 프리셋 | 서보 팔 1개 (베이스 + 서보 + 팔 링크) | [0005](adr/0005-first-slice-scope.md) |

## 핵심 구조

```
           ┌────────────────────┐
  조립 UX  │  ConnectionGraph   │  ← 단일 진실. 프리셋은 이것만 직렬화
  (스냅)  →│  parts[] links[]   │
           └─────────┬──────────┘
        ┌────────────┼────────────┐
        ▼            ▼            ▼
   조립 모드      실행 모드      배선 → 핀 매핑
  (키네마틱)   (RigidBody/Joint)  (어떤 모터가 어떤 핀에)
                                      │
     ┌────────────────────────────────┼─────────────────────┐
     ▼                                ▼                     ▼
 보드 프로파일                    언어 런타임             블록 세트
 (핀맵, 기능, 추천 언어)       (인터프리터, 보드 무관)   (보드 API에서 자동 생성)
```

세 층(보드 프로파일 / 언어 런타임 / 블록 세트)은 서로 몰라야 한다. 이래야 나중에 보드를 정하거나
언어를 추가해도 갈아엎지 않는다.

### 프로젝트와 블록 저작 (2026-09-22)

2026-09-30의 [ADR 0023](adr/0023-bounded-learning-vm-and-dc-hardware.md)은 언어 AST와 연산 스택 VM,
그래프 배선으로 구동하는 DC 모터·초음파, 선언형 과제를 추가한다. micro:bit 예제는 밀리초,
기존 가상 보드·Uno 예제는 초를 쓰며 단위는 보드 프로파일 데이터다. 스테이지와 Lab의 로컬
과제 파일은 실제 물리 측정으로 판정한다. [기능과 제한](LEARNING_STAGES.md), [앱 API 설계](APP_CONTROL_API.md) 참고.

`ProjectStore`는 그래프 스냅샷과 학습자 코드를 버전이 있는 JSON으로 보관한다. 검증된 카탈로그
ID와 강체 변환만 읽으며, 불러오기는 편집 모드로 돌아가고 코드를 실행하지 않는다. 저장은 이전
파일을 덮어쓰지 않는 독립 스냅샷이다. 빈 조립도 JSON 왕복과 목록 복원을 지원한다.

`BoardProfile.api`는 선언적인 명령·인자·한계를 제공한다. `BlockProgramPanel`이 이를 읽어
편집 카드를 만들고 `ServoProgram`이 지원하는 코드 부분집합과 왕복한다. 미수정 줄의 주석·공백을
보존하고, 지원하지 않는 줄이나 코드/블록 충돌은 조용히 삭제하지 않는다. 저장·내보내기는 유효한
블록 초안까지 반영하며 코드 실행도 같은 검사를 거친다. `MiniRuntime`은 실행 전 전체 소스의
문법·변수·배선을 검사해 뒤쪽 오류가 앞쪽 모터 명령을 일부 실행하지 않도록 한다.
구체적인 사용자 흐름과 제한은 [AUTHORING.md](AUTHORING.md) 참고.

### 편집·조종 입력 (2026-09-15)

사용자 요청에 따라 오른쪽 버튼 비행 카메라를 `BlenderCamera`의 가운데 버튼 회전/패닝으로
교체한다. `AssemblyMode`의 G/R 변환은 취소·Undo 시 그래프 위치와 연결을 함께 복구한다.
ADR 0007이 기존 ADR 0002의 "자유 배치 후순위" 범위만 변경하며, 포트·그래프 정본 규칙은 유지한다.
ADR 0022에 따라 `WiringPanel`은 실제 ELEC 포트와 호환 핀을 그래프에서 읽고 위치를 바꾸지 않고
연결·해제한다. 변환은 기계 링크만 해제하고 배선은 유지한다. 삭제·Undo·저장은 동일한 그래프를 쓴다.

실행 중 WASD/패드 입력은 `ManualController`의 이동 명령이며, `RobotMotionProgram`에
미리 작성된 관절 동작 코드가 이를 소비한다. 입력 자체가 개별 관절이나 고정 핀을 선택하지 않는다.
예제 `BipedMotion`은 그래프에서 2족 관절 역할과 배선을 해석한다. `MiniRuntime` 코드와 이동
프로그램은 명령 권한을 동시에 갖지 않으며, 모드 변경 전에 `MiniRuntime.stop()`으로 이전
비동기 실행을 무효화한다. 세부 조작법과 교체 지점은 [CONTROLS.md](CONTROLS.md) 참고.

### 선택적 AI 동작 탐색 (2026-09-15)

`MotionPolicy`의 제한된 4개 파라미터를 외부 `tools/motion_lab` 서비스가 GPT-5.6 Luna에
제안받고, `MotionTrial`의 별도 World3D에서 `ConnectionGraph` 기반 물리로 평가한다.
기준/후보의 측정값을 피드백으로 보내며, 정상적인 최선 결과만 사용자가 편집 모드에서
WASD 프로그램에 명시적으로 적용한다. 모델 가중치 훈련·임의 생성 코드 실행은 하지 않는다.

`MotionSnapshot`은 카탈로그 ID·강체 변환·검증한 연결만 전송한다. Godot 런타임은 여전히
GDScript/비동기 HTTP이며 API 키·프로세스 실행은 선택적 외부 Python 도구에만 있다.
MCP는 공식 SDK의 stdio describe/start/get/cancel로 제한한다. 기존 ADR을 변경하지 않는
서비스 경계를 [ADR 0008](adr/0008-bounded-motion-learning-bridge.md)에 기록했다.
사용법과 평가 한계는 [MOTION_LAB.md](MOTION_LAB.md) 참고.

### 실제 물리 사람형 로봇 (2026-09-15)

`HumanoidPreset`은 몸통·머리·가상 보드와 고관절/무릎/발목/어깨/팔꿈치 각 2개, 상자를
하나의 그래프로 만든다. `PartDef.actuator_torque_nm`이 양수인 관절만 `ServoDrive`의 위치 피드백을
받는 제한 토크 힌지 모터를 사용한다. 기존 이상적 서보 동작과 네 서보 로봇은 유지한다.
`HumanoidMotion`은 그래프에서 관절 역할과 배선 주소를 읽고 보행/웅크리기/팔 뻗기 상태를 구동한다.
양손과 상자가 실제 접촉한 뒤에만 임시 두 점 구속을 만들고, 놓기/제어권 전환/해제 시 제거한다.
몸통 이동 힘이나 위치 덮어쓰기는 없다. 구형 휴머노이드의 달리기는 다양한 출발·연결 순서 14조건에서 실제 공중 구간을 확인했지만 횡방향 제어에는 한계가 있다. AI 탐색 대상에는 포함하지 않는다.
[ADR 0009](adr/0009-humanoid-actuation-and-contact-grasps.md), [측정과 조작법](HUMANOID.md) 참고.

### 모듈형 휴머노이드와 병렬 집기 탐색 (2026-09-15)

아래 `ModularHumanoidPreset`은 구형 하위 조립품 프리팹의 구현 기록이다. 부품 내부의 레일과
외장이 합쳐져 있어 기본 부품 조립 키트로는 부적합했다. 현재 사용자용 키트는
[ADR 0011](adr/0011-elementary-construction-kit.md)에 따라 별도 `assets/construction_kit/`을 쓴다.
공통 20 mm 간격 구멍/포트, 독립 빔·판·브래킷·체결 부품, 재사용한 두 조립 그래프를
하나의 정의에서 Blender와 Godot으로 만든다. [기본 부품 키트](CONSTRUCTION_KIT.md) 참고.

`ModularHumanoidPreset`은 기존 블록형 모델과 별개다. Blender에서 만든 18종 부품을
37개 로봇 모듈과 상자로 조립한다. 모터 하우징 → 출력 힌지 → 브래킷 → 수동 프레임의
각 부품이 실제 그래프 노드다. 외장·손·컨트롤러도 분리 가능하며 PBR 재질을 공유한다.
`RunMode`는 opt-in 고정 연결만 묶어 38개 그래프 파츠를 12개 물리 강체로 바꾸되 각 부품의
질량·충돌·상대 위치와 그래프 인덱스 매핑을 보존한다. 빈 프레임에는 복합 박스 충돌을 사용한다.
`MiniRuntime`의 `write_relative()`는 그래프 배선과 기존 관절 제한을 그대로 따른다.

`PickupPolicy`는 기존 보행용 `MotionPolicy`와 별개인 7개 집기 파라미터다. `PickupTrial`은
독립 `World3D`/`SubViewport`를 소유하며, `PickupLabPanel`이 1~4개 평가를 병렬로 관찰하게 한다.
한 라운드의 네 후보를 Luna 요청 한 번으로 제안받고 측정 피드백을 다음 라운드에 보낸다.
평가 종료 후에는 그 에피소드의 물리 월드를 정지하고 마지막 결과 화면을 보존한다.
기준과 후보 모두 실제 접촉/상승/유지 시간을 측정하며, 저장/불러오기가 성공을 인증하지 않는다.
`PickupScenarioStore`의 user:// 기록은 검증된 그래프·정책·측정값·출처만 포함한다.
현재 편집 그래프와 동일한 새 물리 검증 성공 결과만 명시적으로 적용한다.

이 경계 변경은 [ADR 0010](adr/0010-modular-humanoid-and-observable-pickup-search.md)에 기록했다.
GPT 가중치 훈련·자율적인 임의 코드 실행·손가락 마찰 파지·실물 전이는 구현 범위가 아니다.
[집기 실험 사용법](PICKUP_LAB.md), [모듈/Blender 생성 절차](../assets/modular_humanoid/README.md) 참고.

### 데이터 모델 (`src/core/`)

- `Port` — 파츠 위의 연결점. `kind`(MECH/ELEC), 로컬 위치·법선, `tag`(내 정체), `accepts`(맞물릴 수 있는 tag).
- `PartDef` — 파츠 정의 리소스. 메쉬 + `ports[]` + 질량.
- `ConnectionGraph` — 배치된 파츠 인스턴스와 포트 간 링크. 조립·실행·배선 매핑·프리셋 전부 여기서 파생.

## 첫 슬라이스 시나리오

베이스에 서보를 포트에 스냅 → 팔을 서보 축에 스냅 → 서보 커넥터를 보드 핀에 스냅 →
실행 모드 전환(물리 켜짐) → 코드 몇 줄 실행 → 팔이 각도 따라 움직임 → 프리셋으로 저장 → 답지 보기.

구현 순서와 담당은 GitHub Issues 참고.

## Part/Port 스펙 (issue #1, 초안 — 에디터 튜닝은 issue #9)

이 절은 첫 슬라이스 당시의 규격 설명이에요. 당시 보드 미정 표현은 현재 micro:bit 우선 결정과
구분해서 읽어요. 현재 저장·클래스 계약은 [DATA_MODEL](DATA_MODEL.md), 실제 부품 정의는 카탈로그 소스를 따르세요.

첫 프리셋(서보 팔) 3파츠의 포트 정의. 치수는 실제 마이크로 서보(SG90류) 크기를 참고한 플레이스홀더이며,
`assets/parts/*.tres`로 생성돼 있다. 조립 느낌(스냅 반경, 위치 미세조정)은 issue #9에서 에디터로 다듬을 것 —
여기 숫자를 최종으로 보지 말 것.

| 파츠 | 메쉬(placeholder) | 질량 | 포트 | kind | 위치 / 법선 | tag | accepts |
|---|---|---|---|---|---|---|---|
| `base` | BoxMesh 0.08×0.02×0.08 | 0.08kg | `mount_top` | MECH | 윗면 중앙 / +Y | `base_mount` | `servo_mount` |
| `servo` | BoxMesh 0.023×0.03×0.012 | 0.02kg | `mount_bottom` | MECH | 아랫면 / −Y | `servo_mount` | `base_mount` |
| | | | `output_shaft` | MECH, **rotates** | +X 옆면 / +X | `servo_output` | `arm_mount` |
| | | | `signal_pin` | ELEC | −X 옆면 / −X | `pwm_signal` | `board_digital_pwm` |
| `arm_link` | BoxMesh 0.01×0.08×0.01 | 0.01kg | `mount_base` | MECH | 아래끝 −Z 옆면 / −Z | `arm_mount` | `servo_output` |
| `board` | BoxMesh 0.07×0.005×0.05 | 0.03kg | `pin_9`, `pin_10` | ELEC | 윗면 / +Y | `board_digital_pwm` | `pwm_signal` |

유일한 움직이는 조인트는 `servo.output_shaft` ↔ `arm_link.mount_base` (서보가 구동). 실제 서보 혼처럼
축이 서보 **옆면**으로 나오고 팔은 축에 **수직**으로 붙는다 — 그래야 회전이 보인다. `Port.rotates`가 true인
포트가 물린 링크만 힌지가 되고 나머지는 강체 결합이다(실행 모드가 태그 문자열이 아니라 이 플래그로
판단). `base` ↔ `servo`는 고정 마운트. `board`는 타겟 보드(issue #10)가 정해질 때까지의 플레이스홀더로, 핀 번호는 포트 id
(`pin_9` → 9)에서 읽는다 — 이 숫자가 배선 그래프를 거쳐 학습자 코드의 `Servo(9)`와 만난다.

### 실물 기반 모듈 (issue #9 보강, 치수는 공식 도면 기준)

`tools/godot/make_part_defs.gd`가 이 표의 원본이고 `assets/parts/*.tres`를 재생성한다. 메쉬는
`tools/blender/make_parts.py`(Blender 5.2.1), 검증은 `tools/blender/check_obj.py`. 팔레트(`scenes/main.gd`)는
`assets/parts/*.tres`를 스캔하므로 파츠 파일만 추가하면 버튼이 생긴다.

| 파츠 | 실물 / 출처 | 포트 | kind | 위치 / 법선 | tag | accepts |
|---|---|---|---|---|---|---|
| `arduino_uno` | Arduino Uno R3, PCB 66.04×50.80, 디지털 헤더 2.54 피치 + D7/D8 사이 0.16" 간격, PWM 3/5/6/9/10/11 — [A000066 datasheet §5](https://docs.arduino.cc/resources/datasheets/A000066-datasheet.pdf) (CC-BY-SA) | `pin_3/5/6/9/10/11` | ELEC | 헤더 윗면 (+Z 모서리) / +Y | `board_digital_pwm` | `pwm_signal`, `digital_io` |
| | | `pin_2/4/7/8/12/13` | ELEC | 같은 헤더 / +Y | `board_digital` | `digital_io` |
| `tt_motor` | TT 기어모터 70×22×18, 양축 Ø5.4 D-샤프트 — Adafruit #3777 / DFRobot | `shaft_left`, `shaft_right` | MECH, **rotates** | 기어박스 양옆 x=−24 / ∓Z | `motor_shaft` | `wheel_hub` |
| | | `mount` | MECH | 기어박스 바닥 / −Y | `motor_mount` | `base_mount` |
| `wheel_65` | 65 mm 로봇 휠, 폭 26, 5.4 D-보어 — DigiKey 4205 | `hub` | MECH | 안쪽 면 중앙 / −Z | `wheel_hub` | `motor_shaft` |
| `hc_sr04` | HC-SR04 초음파, PCB 45×20, VCC/TRIG/ECHO/GND 2.54 헤더 — [datasheet](https://www.handsontec.com/dataspecs/HC-SR04-Ultrasonic.pdf); 트랜스듀서 Ø16/간격 26은 사진 기반 추정 | `mount` | MECH | 뒷면 중앙 / −Z | `sensor_mount` | `base_mount` |
| | | `trig_pin`, `echo_pin` | ELEC | 헤더 핀 끝 / −Y | `digital_io` | `board_digital`, `board_digital_pwm` |
| `biped_body` | Otto DIY 몸통 참고(우리 서보 크기에 맞춘 70×60×45), 눈 자리에 HC-SR04 | `hip_left`, `hip_right` | MECH | 바닥 x=∓20 / −Y | `base_mount` | `servo_mount` |
| | | `face` | MECH | 앞면 / +Z | `base_mount` | `sensor_mount` |
| `leg_link` | Otto 다리 참고, 12×40×16 | `hip_mount` | MECH | +X 옆면 위 / +X | `arm_mount` | `servo_output` |
| | | `ankle_mount` | MECH | 아래끝 / −Y | `base_mount` | `servo_mount` |
| `foot` | Otto 발 참고, 65×8×45 판 + 앞뒤 혼 탭 (안쪽 모서리가 몸 중심선까지 닿아 한 발 지지 가능) | `ankle_front`, `ankle_back` | MECH | 탭 안쪽 면 / ∓Z | `arm_mount` | `servo_output` |

**2족 프리셋** (`presets/biped.gd`, "Answer: biped"): 엉덩이 서보는 축이 바깥(±X)을 향해 다리가 앞뒤로 흔들리고(피치),
발목 서보는 축이 ±Z를 향해 발이 좌우로 기울며(롤) Otto처럼 한 발로 무게를 옮긴다. 좌우 발목 축 방향을 거울로 두어
같은 양수 각도가 거울 동작이 되게 했다 — 서보 힌지는 조립 자세=0°에서 양수 방향만 돌기 때문(ServoDrive 범위는 실제
서보의 90° 중립을 반영하는 후속 과제). 실행 모드를 켠 채 코드를 안 돌리면 무전원 힌지가 풀려 주저앉는 것은 슬라이스 1의
"무전원 팔은 떨어진다"와 같은 설계다. 이 로봇이 서 있으려면 GodotPhysics 솔버를 조여야 했다(`project.godot`:
solver_iterations 64, 접촉 허용 관통 1 mm — 기본 1 cm는 우리 cm 스케일에 너무 크다).

`base.mount_top`의 accepts에 `motor_mount`, `sensor_mount`가 추가됐다. `tt_motor`는 아직 ELEC 포트가 없다 —
DC 모터는 드라이버 모듈이 있어야 런타임이 다룰 수 있고, 그 API(`Motor`)는 런타임 계층(ADR 0004)의 다음 슬라이스다.
`arduino_uno`는 메쉬와 핀 배치만 실물이고, 타겟 보드 프로파일 결정(issue #10)은 여전히 열려 있다 — `board`
플레이스홀더는 그대로 둔다. 참고한 오픈소스 조립 예: [Otto DIY](https://github.com/OttoDIY/OttoDIYLib)(CC-BY-SA 4.0,
SG90×4 + Nano), [MeArm](https://github.com/MeArm/MeArm)(CC-BY-SA, SG90×4, 3 mm 아크릴 — 링크 길이는 DXF에서 직접
재야 해서 아직 미반영). EEZYbotARM은 CC-BY-NC라 제외.

### 상세 메쉬와 추가 구조물 (2026-09-15)

사용자의 최신 Blender 설치 요청에 따라 로컬 Blender **5.2.1 LTS**에서 OBJ/MTL을 생성한다.
`tools/blender/part_details.py`가 기존 파츠에 외장 패널, 나사, 통풍구, 관절 장식과 전자 부품 디테일을
더한다. 기존 포트·질량·메쉬 외곽 경계를 유지하며, 부품당 5,000 삼각형 미만이다. 현재 충돌 박스가
메쉬 AABB에서 나오므로 디테일이 충돌 크기를 바꾸지 않도록 생성 시 검사한다.

아래 두 파츠는 상용 제품 복제가 아닌 자체 설계 구조물이다. 원본은
`tools/blender/robot_accessories.py`, 포트 정본은 `tools/godot/make_part_defs.gd`다.

| 파츠 | 본체 치수 | 포트 | 위치 (m) / 법선 | tag | accepts |
|---|---|---|---|---|---|
| `chassis_plate` | 120×4×80 mm | 윗면 마운트 5개 | (0, 0.002, 0), (±0.04, 0.002, 0), (0, 0.002, ±0.025) / +Y | `base_mount` | `servo_mount`, `motor_mount`, `sensor_mount` |
| `servo_bracket` | 36×32×30 mm | 바닥 마운트 | (0, −0.002, 0) / −Y | `servo_mount` | `base_mount` |
| | | 선반 마운트 | (0, 0.002, 0) / +Y | `base_mount` | `servo_mount`, `motor_mount`, `sensor_mount` |
| | | 뒷면 마운트 | (0, 0.016, −0.015) / −Z | `base_mount` | `servo_mount`, `motor_mount`, `sensor_mount` |

마운트 표시 링은 해당 표면에서 0.3 mm 돌출한다.

편집용 `assets/blender/ssok_parts.blend`는 `.gdignore`로 Godot 임포트에서 제외한다.
실행 앱은 OBJ에서 생성한 Godot 메쉬와 재질 리소스를 사용한다. 재생성·미리보기 절차는
`tools/blender/README.md` 참고.

### 공유 PBR 재질 (2026-09-15)

`assets/materials/catalog.json`이 Blender/Godot 재질 값의 정본이다. 플라스틱·고무·금속·기판
코팅 등 26종과 내부 커터용 1종을 정의한다. Blender는 편집 가능한 Principled/Noise/Bump 노드,
Godot은 외부 `StandardMaterial3D`와 128px 미세 노멀 맵 3장을 사용한다. 주황색 LED만 약하게
발광한다. GL Compatibility와 기존 씬 조명은 유지한다.

`tools/godot/make_materials.gd`는 임포트된 OBJ의 정점·인덱스·경계를 그대로 복제해
`assets/meshes/*.res`에 외부 재질을 연결한다. `make_part_defs.gd`가 이 메쉬를 참조하므로
조립/실행 양쪽이 같은 재질을 사용한다. 포트·질량·충돌·런타임 구조는 변경하지 않는다.
UV 없는 기존 메쉬에 로컬 트라이플래너 매핑을 사용하며, 런타임 텍스처 생성이나 스레드는 없다.
상세 워크플로는 `assets/materials/README.md` 참고.

- 첫 타겟 보드 (Arduino / ESP32 / 특정 상용 키트)
- Jolt Physics 채택 여부 (웹 export 지원 확인 필요)
- 라이선스
- 테스트 프레임워크 (GUT 예정)
