# ssok 아키텍처

## 비전

마우스 드래그앤드롭으로 메쉬(로봇 파츠)를 연결·조립하고, 실제 기판/상용 제품 기반 코드로 구동하는
시뮬레이션 환경. 프리셋(답지)을 보며 탑다운으로 학습하고, 추후 과제를 얹어 과학상자 같은
교육 플랫폼으로 키운다. 목적은 공간·시간·금전적 제약의 극복.

## 확정된 결정 (2026-09-10)

아래는 요약표. 각 결정의 맥락·이유·기각된 대안은 [docs/adr/](adr/)에 있고, 그쪽이 정본이다.
결정을 뒤집으려면 여기 표를 고치기 전에 새 ADR로 supersede할 것.

| 항목 | 결정 | ADR |
|---|---|---|
|---|---|
| 첫 프로토타입 | 조립 + 코드 구동을 최소 기능으로 **동시에** 관통하는 얇은 슬라이스 | [0005](adr/0005-first-slice-scope.md) |
| 연결 방식 | **포트/소켓 기반 + 근접 스냅**. 기계 조인트뿐 아니라 **전기 배선(모터→보드 핀)** 도 포트 | [0002](adr/0002-connection-graph-single-source-of-truth.md) |
| 물리 | **하이브리드** — 조립 모드는 키네마틱, 실행 모드는 실물리(RigidBody+Joint+중력) | [0003](adr/0003-hybrid-physics-modes.md) |
| 타겟 보드 | 미정. 구조를 특정 보드에 종속시키지 않음 | [0004](adr/0004-hardware-abstraction-three-layers.md) |
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

### 데이터 모델 (`src/core/`)

- `Port` — 파츠 위의 연결점. `kind`(MECH/ELEC), 로컬 위치·법선, `tag`(내 정체), `accepts`(맞물릴 수 있는 tag).
- `PartDef` — 파츠 정의 리소스. 메쉬 + `ports[]` + 질량.
- `ConnectionGraph` — 배치된 파츠 인스턴스와 포트 간 링크. 조립·실행·배선 매핑·프리셋 전부 여기서 파생.

## 첫 슬라이스 시나리오

베이스에 서보를 포트에 스냅 → 팔을 서보 축에 스냅 → 서보 커넥터를 보드 핀에 스냅 →
실행 모드 전환(물리 켜짐) → 코드 몇 줄 실행 → 팔이 각도 따라 움직임 → 프리셋으로 저장 → 답지 보기.

구현 순서와 담당은 GitHub Issues 참고.

## Part/Port 스펙 (issue #1, 초안 — 에디터 튜닝은 issue #9)

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
`tools/blender/make_parts.py`(Blender 4.5), 검증은 `tools/blender/check_obj.py`. 팔레트(`scenes/main.gd`)는
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

- 첫 타겟 보드 (Arduino / ESP32 / 특정 상용 키트)
- Jolt Physics 채택 여부 (웹 export 지원 확인 필요)
- 라이선스
- 테스트 프레임워크 (GUT 예정)
