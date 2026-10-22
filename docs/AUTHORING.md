# Projects and block programs

Stage and Lab tool panels now collapse over the scene. Open **Help** for Projects, tutorial and
explicit starter examples. Inline block argument controls still derive from the board descriptor;
Run preserves the selected programming tab and pending-draft conflict checks. See
[ADR 0030](adr/0030-scene-first-workshop-guidance.md).

## Preserve an assembly

Open **Projects** or press **Ctrl/Cmd+S**. Give the project a name and select **Save a snapshot**.
Each save creates a separate version, so saving a mistake does not overwrite the previous version.
Select a version under **Saved projects** and open it. Confirming replacement restores both the
assembly graph and learner code, returns to edit mode and leaves code execution stopped.

When loading a starter over modified work, the application offers **Save and switch**, explicit
replacement without saving, or cancellation. The current assembled pose—not a fallen robot's
runtime pose—is the state saved in a project.

Storage is local to the application/browser profile. Export a copy before changing devices or
clearing browser data. **Export project** exposes portable JSON for copying; the browser also
downloads `ssok-project.json`. Paste the document under **Import / export** and select **Import project**.
Invalid files leave the workshop unchanged. A project never includes service credentials,
learning-service settings or an automatically executable scene/resource.

Documents have a versioned `ssok-project` envelope, a title, a graph snapshot, learner source and
a UTC save timestamp. The graph retains catalog IDs, rigid transforms and validated mechanical
and electrical links. Limits are 256 parts, 1024 links, 64 KiB of learner source, 512 KiB per
document and 128 saved snapshots. Catalog IDs are allowlisted; arbitrary resource paths are rejected.
Writes use a temporary file and rename, and snapshots have independent generated IDs.
The editor refuses a 257th part and transforms beyond 100 m on any axis, matching snapshot limits.

## Wire the assembled robot

Open **Wiring**, choose a motor signal and a compatible board pin, then select **Connect wire**.
Connections use the actual electrical ports in the current graph. Occupied ports are unavailable;
use **Disconnect wire** before reassigning a motor. Both operations support Ctrl/Cmd+Z and redo.
These shortcuts work while buttons have focus; focused code and text fields retain their own undo.
Connecting a wire preserves every part's position and rotation. Moving a part retains its wires
while detaching mechanical mounts; deleting it removes all incident links. Cancel and undo restore
the graph together. Wiring controls are disabled during a transform or run mode.

Wires are logical connections: cable geometry, length and tension are not simulated.

## Code and blocks

**Blocks → Read from code** reads the supported servo subset. Each card is generated from the
board API descriptors in `src/core/board_profile.gd`. Edit its named inputs or add/remove a command,
then use **Apply blocks to code**. Applying does not start physics; **Run code** remains explicit.
**Run code**, saving and exporting validate and apply pending blocks. Invalid values or independently
changed code stop the action and retain both drafts. Starter replacement and **Read from code**
ask before discarding unapplied blocks. Numeric fields preserve fractional values such as `0.05`.

```python
from servo import Servo

arm = Servo(9)
arm.write(90)
sleep(0.5)
arm.write_relative(-20)
```

Supported operations include servo binding, absolute/rest-relative angle, motor power, sonar values,
variables, arithmetic/logic, if/elif/else, while, for/range and break/continue/pass. Repeat-range,
condition and sensor-value cards retain indentation on code/block round trips. New repeat-range
cards generate an empty `pass` body; creating a new nested body still uses code in the existing
flat card editor. [Language limits and hardware](LEARNING_STAGES.md) describe the full subset.
The teaching runtime resolves pin 9 through the current wiring graph. An unwired pin produces an
error. Before sending any motor command, the runtime checks the whole program for supported syntax,
defined servo names, connected pins and finite values. A later invalid line cannot partly actuate
the robot. Programs are limited to 2048 lines and 64 KiB; each wait is at most 60 seconds. Each run has a 10,000 total loop-entry budget and a
60-second simulated/wall-clock limit, including waits. Exceeding a budget fails and brakes DC motors.
`write` clamps to 0–180 degrees; relative commands clamp to the joint's bounded signed offsets. This language is
not full Python and does not compile or upload real-board firmware.

Comments, imports, whitespace and trailing newlines survive an untouched code/block round-trip.
An unsupported line is reported instead of being discarded. A restricted board API removes the
corresponding block operations. If the source changes after blocks are read, stale blocks cannot
overwrite it: read the updated source explicitly.

## Verification

- `tests/project_store_check.gd`: large-kit round-trip, Unicode source, snapshots, path/resource
  rejection, malformed/oversized documents, mode ownership and unsaved-work replacement.
- `tests/block_program_check.gd`: lossless conversion, API limits, actual runtime motor binding,
  physical hinge targets and protection against stale block application.
- `tests/authoring_ui_check.gd`: four languages, compact browser viewport, project/transfer views,
  rendered screenshots and usable catalog/block scrolling areas.
- `tests/core_authoring_check.gd`: actual wiring controls, placement-preserving graph edits,
  undo/redo, saved snapshots, code preflight, pending-block execution and saveable workspace limits.

Run these through the isolated [verification runner](BUILD.md); personal saved projects stay untouched.

## 2026-10-22 스테이지에서 내 로봇 만들기

스테이지는 처음에 빈 작업대와 전체 부품으로 열려요. 조립→배선→블록/코드→실행 순서로 만들며,
목표는 특정 섀시/센서가 아니라 로봇 전체와 환경을 관측해요. 깃발은 과제 부품을 붙여요.
목표 스트립의 답지 메뉴는 확인 뒤 현재 조립과 코드를 교체하고 답지 사용 상태를 남겨요.
처음부터 만들기도 확인 뒤 비워요. 기본 스테이지의 lower_arm 보정은 답지 로드에만 적용해요.

Back/list/next는 스테이지별 마지막 편집 그래프·코드를 로컬 저장하고, 다시 열면 복원해요.
저장 실패나 블록/코드 초안 충돌이면 나가지 않아요. 실행 중 나가기가 취소돼도 편집 모드로 돌아와
옛 시도가 뒤늦게 성공하지 않아요. 프로젝트 라이브러리의 독립 스냅샷·가져오기 계약은 유지해요.
이 저장은 나가기/답지/초기화 시점이며 창 강제 종료·브라우저 저장소 삭제의 복구를 보장하지 않아요.
자세한 현재 결과는 [작업 D](WORK_SUMMARY_D.md), 저장 필드는 [데이터 모델](DATA_MODEL.md)이에요.


## B-2 기능 부품의 코드·블록

micro:bit/Uno의 실제 그래프 신호선에 연결한 뒤 `line = LineSensor(pin1)`,
`button = Button(pin2)`, `led = LED(pinN)`을 써요. `pinN`은 실제 배선 번호로 바꾸고
한 핀을 여러 장치에 중복 배정하지 않아요. `line.value()`는 보드 공통 0~1023의 반사 밝기,
`line.is_dark()`는 512 미만, `button.is_pressed()`는 전면 접촉이에요. `led.on()`,
`led.off()`, `led.set(0.5)`의 밝기는 0~1이에요. 대응하는 연결·관측·출력 카드를 제공해요.
기존 가상 서보 보드는 PWM 전용 포트를 유지하므로 이 예제에는 micro:bit/Uno를 권장해요.
새 기어·환경 관측과 남은 집게 작업은 [B-2 검증](evidence/parts_pack_v1_2026-10-22/README.md)을 보세요.
