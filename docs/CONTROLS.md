# 조작법

## 편집 모드

Blender의 기본 **오브젝트 조작**에 맞춘 조립 화면이다. 메쉬 정점 편집 기능은 아니며,
기존 부품 치수·질량·연결 포트를 유지한다. 좌표계는 Godot의 **Y-up**, 이동 숫자는 **mm**다.

| 입력 | 동작 |
|---|---|
| 왼쪽 클릭 | 파츠 선택. 선택만으로 연결이 해제되지 않는다 |
| `G` / `R` | 이동 / 회전 시작 |
| 변환 중 `X`, `Y`, `Z` | 월드축 제한. 같은 축을 다시 누르면 해제 |
| 숫자, `-`, `.`, Backspace | 거리(mm) / 각도(도) 입력·수정. 예: `G X 10 Enter` |
| Enter / 왼쪽 클릭 | 확정. 가까운 호환 포트에 스냅 |
| Esc / 오른쪽 클릭 | 취소. 위치·회전·연결 상태를 함께 복구 |
| 변환 중 Shift / Ctrl | 미세 조절 / 1mm·15도 단위 조절 |
| 기즈모 화살표 / 링 드래그 | 축 이동 / 회전. 놓으면 확정, Esc로 취소 |
| Ctrl+Z / Ctrl+Shift+Z | 추가·삭제·변환 되돌리기 / 다시 실행 |
| Delete / X | 삭제 / 확인 후 삭제 |
| 가운데 버튼 드래그 | 시점 회전 |
| Shift+가운데 버튼 | 화면 이동(패닝) |
| 휠 / Ctrl+가운데 버튼 | 확대·축소 |
| 숫자패드 1 / 3 / 7 | 정면 / 오른쪽 / 위. Ctrl을 더하면 반대쪽 |
| 숫자패드 5 / `.` / Home | 원근·직교 전환 / 선택 파츠에 맞춤 / 전체에 맞춤 |

`S` 크기 변경, 다중 선택, 로컬축 전환, Blender의 전체 편집 명령은 제공하지 않는다.
크기 변경으로 충돌체·실물 치수·포트가 어긋나는 것을 방지하기 위해 파츠 크기는 고정한다.
다른 모드로 전환하거나 창/코드 입력으로 포커스를 옮기면 미확정 변환은 취소된다.

참조: [Blender 5.2 뷰포트 탐색](https://docs.blender.org/manual/en/5.2/editors/3dview/navigate/navigation.html).

## 실행 모드: 로봇 이동

오른쪽의 `Control: WASD / gamepad movement`를 선택하고 `Run mode`를 켠다.
키보드는 관절을 하나씩 선택하는 것이 아니라 **로봇 전체의 이동 명령**을 전달한다.

| 키보드 | 게임패드 | 명령 |
|---|---|---|
| W / S 또는 ↑ / ↓ | 왼쪽 스틱 위 / 아래 | 전진 / 후진 |
| A / D 또는 ← / → | 왼쪽 스틱 좌 / 우 | 좌 / 우 회전 |
| Space | A(남쪽 버튼) | 이동 입력 정지 |
| Esc / Stop input 버튼 | — | 입력·코드 실행 중지 |

키를 놓으면 이동 입력은 0이 된다. 스틱에는 데드존을 적용한다. 코드 편집기에서 타이핑하거나
창 포커스를 잃거나 패드 연결이 끊기면 입력을 해제한다. 패드는 포커스 복귀 후 스틱을 중앙으로
돌려야 다시 조종되며, 동시에 여러 패드의 입력을 섞지 않는다.

이동은 다음 경계로 분리한다.

```text
WASD / 게임패드 → ManualController → RobotMotionProgram → 관절 동작 → 물리 로봇
                      이동 명령          미리 작성된 코드
```

`ManualController.movement_changed(throttle, turn)`은 `[-1, 1]` 범위의 전후진·회전 입력이다.
`RobotMotionProgram.set_move_input(Vector2(turn, throttle))`이 이를 받아 관절 동작으로 바꾼다.
컨트롤러 입력 계층은 핀 번호나 관절 개수를 알지 못한다. 사용자 로봇은 이 인터페이스를 구현한
동작 프로그램을 연결하면 된다. 현재 예제 연결 지점은 `scenes/main.gd`의 `BipedMotion.new()`다.

`Answer: biped`에는 예제 이동 프로그램을 연결한다. 다른 구조의 로봇에는 해당 로봇의
관절 프로그램이 필요하다. 미연결 모터, TT 모터의 드라이버/API, 자동 로봇 구조 추론은 지원하지
않는다. 예제는 기계 연결과 전기 배선에서 관절 역할과 핀을 찾으며, 몸체 좌표를 직접 옮기지 않는다.

**기본 2족 보행은 실험용이며, 완성된 이동 알고리즘이 아니다.** 3초 안정화 후 12초 명령과
1.5초 정지 복귀를 검사했을 때 전진 약 1.7mm, 후진 약 44.8mm, 좌/우 회전 방향은 확인됐지만,
전진 중 약 28도 방향 드리프트가 있었다. 입력 연결과 보행 성능은 별개이며, 사용자 관절 코드로
교체하거나 보행을 더 튜닝해야 한다. UI에도 `experimental gait (slow / drift)`로 표시한다.

내부 관절 프로그램은 `ServoDrive.write_relative()`로 조립 자세 기준 ±90도 범위의 각도를
보낼 수 있다. 기존 학습 코드의 `servo.write()`는 0~180도 규약을 그대로 유지한다. 이동 예제의
진폭은 이보다 작게 제한한다. 코드 편집기는 기존 순차 실행 문법을 유지하며, WASD 콜백을
정의하는 Python 문법이나 임의 로봇의 보행 코드를 자동 생성하는 기능은 추가하지 않았다.

## 코드 실행과의 전환

`Run code`는 이동 입력을 끄고 기존 `MiniRuntime` 프로그램을 실행한다. 이동 모드로 바꾸면
실행 중인 코드를 취소한다. `sleep()` 뒤에 남은 명령도 새 로봇이나 새 실행에 영향을 주지 않는다.
실행 모드에서 편집 모드로 돌아가면 물리 오브젝트를 제거하고 조립 그래프의 자세로 복귀한다.
코드 전용 모드에서 명령을 보내지 않은 서보는 기존처럼 무전원 상태다.

키보드와 가상 게임패드 이벤트는 자동 테스트로 검사한다. 실제 USB/Bluetooth 패드 및 브라우저
장치 인식은 별도 확인 대상이다. 웹에서는 브라우저가 패드를 인식하도록 먼저 버튼을 눌러야 할 수 있다.
참조: [Godot 게임패드 입력 문서](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html).

## 검증

```sh
godot --headless --path . --import
godot --headless --path . --quit
godot --headless --path . -s tests/blender_camera_check.gd
godot --headless --path . -s tests/blender_edit_check.gd
godot --headless --path . -s tests/manual_control_check.gd
godot --headless --path . -s tests/biped_motion_check.gd
godot --headless --path . -s tests/control_flow_check.gd
godot --headless --path . -s tests/assembly_snap_check.gd
godot --headless --path . -s tests/run_mode_check.gd
godot --headless --path . -s tests/mesh_assets_check.gd
godot --headless --path . -s tests/material_assets_check.gd
```

실제 앱 화면 확인: `godot --path . -s tests/controls_screenshot.gd` →
`user://control_previews/{edit,run,run_released}.png`.
