# 작업 A-2 — 장면 중심 UI 결함 수정

2026-10-22 · Codex · 로컬 구현/검사 완료, 실제 GL 검수와 통합/출시는 후속.

## 기준·소스·소유

- 사용자 문제/근거: 2026-10-22 사용자가 전달한 Claude의 RTX 4090 실제 OpenGL 검수 결과. 내용물이 작고 치우친 프레이밍, 읽기 어려운 3D 글, 높은 안내 스트립, 다크 장면 불일치, 불명확한 매트 가장자리를 확정된 순서 1→5로 수정했어요. 별도 디자인 재판단이나 외부 조사는 하지 않았어요.
- 작업실: `feat/ui-onboarding-r2-20261022`, 시작 HEAD `e8025e597dc7d5043c8b112a5b43bc4011190d93`. 시작 시 dirty 파일 없음. 작업 A가 적용된 현재 사용자 지정 브랜치예요.
- 검사한 앱 소스 확정 커밋: `fbcd731993312d89657ae671f4e7c4dc59dd994a`. 이 뒤 변경은 문서뿐이에요.
- `build/ui-onboarding-a2/source-sha256.json`: 검사한 앱/장면/테스트/에셋 733파일. manifest SHA-256 `91286fec299dc714f3b727fb42af150a11d52c5d81b6853c66f3cfa3c8a7575f`. 검사 후 현재 바이트와 전부 대조했어요.
- 현재 사용자 지시로 A-2를 소유했어요. `agent-task list --project ssok --cwd "$PWD"`는 빈 목록이었어요. GitHub CLI는 로그인/토큰이 없어 이슈 생성·담당 확인을 못 했어요. 다른 작업실/WIP는 수정하지 않았어요.

## 바뀐 것과 전후 근거

| 항목 | 이전 → 수정 | 현재 근거 |
|---|---|---|
| 1. 프레이밍 | 큰 play_area를 UI 배치 전에 맞춤 → 그래프의 실제 메시와 레벨 Markers 메시 AABB를 합쳐 배치 뒤 피벗/거리를 계산 | `WorkshopFraming`, `main._frame_workshop`; 세 스테이지 진입·열린 프로그램 패널·재시도, 빈 Lab/팔 조립물의 8개 끝점 투영 검사 |
| 2. 목표 표시 | 작고 겹치는 Label3D → UI Label + 반투명 패널·2단계 글꼴·리더 선 | 목표선 끝/결승선/정지 구역의 실제 메시 위치에 앵커. 현재 값/목표/유지 시간만 표시, 앞/뒤/상하좌우 화면 밖 앵커는 가장자리에 고정 |
| 3. 지금 할 일 | 목표·칩별 설명·중복 측정 안내의 여러 줄 → 목표/행동 한 줄 + 네 pill/현재 단계 힌트 한 줄 | 기본 글자에서 4언어 × 1440×900/1152×648: 높이 ≤100px, 같은 칩 행, 목표/힌트 전체 문자열과 아이콘/이름/체크가 들어감 |
| 4. 다크 일관성 | 패널만 다크 → 장식 배경 그라데이션·매트·격자·안개 색도 즉시 전환 | 다크 배경/매트/격자/안개 색 검사, 라이트 원래 색 복원 검사 |
| 5. 가장자리 | 경계가 흐린 유한 매트 → 매트 아래로 조금 넓은 두꺼운 테두리 | 기존 1.8×1.4m 시각 매트 유지, 테두리 폭/높이 및 추가 충돌 없음 검사. 원래 바닥 메시는 숨김 유지 |

사용자가 카메라를 조작하면 자동 프레이밍과 실행 추적이 멈춰요. 패널/레이아웃 변경이나 그래프 상태 갱신이 수동 뷰를 다시 맞추지 않아요. 명시적인 재설정/예제 불러오기는 다시 프레이밍해요. 열린 패널과 상단 스트립을 뺀 영역으로 맞추며, 실제 물리 결과를 편집 그래프에 쓰지 않아요.

칩 아래의 설명과 중복 실행 안내는 제거했어요. 단계 힌트는 현재 것 하나만, 자세한 스테이지 힌트는 기존 힌트 아이콘의 툴팁에 있어요. 해결 가능한 코드 오류는 현재 힌트 자리에 표시하고 툴팁에서 전체 내용을 볼 수 있어요. 확대 글자에서는 목표/힌트가 줄바꿈 대신 생략될 수 있으며 전체 문장은 툴팁으로 남아요. 기본 두 해상도/네 언어에서는 생략 없이 들어오는지 검사했어요.

관측은 기존 evaluator 샘플과 같고 null 센서는 측정 불가로 유지해요. 판정·실행·저장·제어권·선호도 계약은 유지했어요. `src/core`, `src/runtime`, `assets/parts`, `assets/construction_kit`, `src/blocks/servo_program.gd`의 시작점 대비 diff는 없어요. `.tscn`, 패널 내부 구조, AI 실험실도 수정하지 않았어요. 새 의존성·제공자·네트워크/유료 호출은 없어요.

## 직접 기록한 커밋

1. `2af742a` Frame workshop interests after scene layout
2. `3b1444a` Project goal observations into screen labels
3. `36904ad` Condense task guidance into two rows
4. `a7f7fd7` Apply appearance to the workbench environment
5. `dcd1872` Give the finite workbench a visible rim
6. `fbcd731` Preserve camera ownership and full step labels

전부 영어 메시지와 `Agent: codex` trailer로 현재 `.git`에 기록했어요. 마지막 문서 커밋은 별도예요. main으로 merge/back-merge하거나 공개하지 않았어요.

## 실제 검사 출력

Godot `build/toolchain/godot`, `4.7.2.stable.official.ed1daf0bf`, headless, 고정 60fps.
개인 저장을 건드리지 않도록 XDG data/config/cache를 `/tmp/ssok-a2-final-{data,config,cache}`로 분리했어요.

공통 명령:

```sh
build/toolchain/godot --headless --path . --language en --fixed-fps 60 --script tests/NAME.gd
```

최종 원문 출력(11 suite 모두 exit 0, SCRIPT ERROR/ERROR/FAIL 진단 없음):

```text
scene_workshop_ui_check: 360 checks, 0 failures
game_flow_check: 43 checks, 0 failures
workshop_ui_check: 420 checks, 0 failures
localization_check: 53853 checks, 0 failure(s)
block_program_check: 28 checks, 0 failures
interface_preferences_check: 95 checks, 0 failures
app_controller_check: 14 checks, 0 failures
authoring_ui_check: 32 checks, 0 failures
Agent goal UI checks: 11 / failures: 0
control_flow_check: 0 failure(s)
workshop_presentation_check: 483 checks, 0 failures
```

- 명령/exit/시간/진단: `build/ui-onboarding-a2/results.json`. suite별 원문은 같은 폴더의 `NAME.log`. build 폴더는 Git 제외이며 이 작업실에 남아요.
- 기존 `scene_workshop_ui_check`의 3D 라벨 설명만 UI 라벨로 바꾸고 판정/정밀도 검사는 유지했어요. 번역 2문구의 명시 검사 6건이 늘었어요. 기존 다른 검사 파일은 바꾸지 않았어요. 앱 코드와 기존 suite가 그대로인 마지막 경계 사례 추가 후 신규 검사만 재실행했어요.
- 신규 검사는 실제 입력 이벤트로 카메라 조작을 보내 패널 변화 후 수동 뷰 보존을 확인해요. AABB 투영 포함과 가용 영역 대비 크기도 함께 검사해 작은 로봇만 화면 안에 들어오는 퇴행을 막아요.
- `build/toolchain/godot --headless --path . --import --quit`: exit 0, parse/compile 오류 없음. 환경의 editor TCP listen 소켓 생성 오류 4줄은 남아 있어요. `import.log`에 원문 보존.
- `build/toolchain/godot --headless --path . --quit`: exit 0, 오류 없음 (`scene-load.log`).
- `python3 tools/docs/maintain.py --review execution-flow --write`: 실제 흐름 문서 대조 뒤 명시 검토/지도/ADR 색인 갱신.
- `python3 tools/docs/maintain.py --check`: PASS.
- `python3 -m unittest discover -s tools/docs -p 'test_*.py'`: `Ran 10 tests ... OK`.
- `git diff --check`: PASS. 금지 경로의 diff 없음.

영어 원문 `%s: %s / Target: %s`, `Hold: %.1f / %.1f s`와 ko/zh_CN/ja PO·명시 메시지 inventory를 함께 갱신했어요. 실제 glyph/색 검수는 headless 통과와 구분해 아래에 남겼어요. [FLOWS](FLOWS.md), [설정 계약](INTERFACE_PREFERENCES.md), [STATUS](STATUS.md), context/지도/ADR 색인을 갱신했어요. 그래프/실행/저장 도식은 실제 호출과 대조했으며 물리·저장 계약이 바뀌지 않아 유지했어요. [ADR 0031](adr/0031-workshop-presentation-corrections.md)은 0026의 장식 3D 재질 테마 제외 범위만 명시적으로 대체해요.

## 실패 이력·못 한 것·다음 담당

- 중간 검사에서 미포함 cable/link 아이콘 진단, 스트립 높이 108px(24건 실패), 다크 배경 기준 미달(3건 실패)을 발견했어요. 포함된 cpu 아이콘, pill 여백, 더 어두운 하단 그라데이션으로 고쳤어요. 기존 기준은 약화하지 않았어요. 칩 전체 이름의 잘림 가능성과 뒤쪽 앵커의 가장자리 고정도 추가 검사/보완했어요. 이 중간 결과는 최종 PASS로 세지 않아요.
- **실제 GL 캡처/네 언어 글리프·색·잘림 검수 미완료.** `xvfb-run -a -s '-screen 0 1600x1000x24 -nolisten tcp' ... --script tests/scene_workshop_ui_check.gd -- --screenshots`와 `DISPLAY=:0 ... --script tests/workshop_presentation_check.gd` 둘 다 exit 1. X11 연결 불가 → Wayland 초기화 실패예요 (`render.log`, `display0.log`). 실제 PNG를 만들지 못했어요. 현재 결과를 RTX 4090 재검수 통과라고 부르지 않아요.
- Web/데스크톱 export·실기기 입력·확대 글자에서 목표 라벨의 실제 가독성 검수는 미실행이에요. headless는 네 언어 기본 두 크기의 라벨/스트립 배치와 기존 200% UI/키보드 포커스를 확인한 범위예요.
- **공유 위키/arch Now·프로젝트 포인터·agent-task 등록/종료 기록 미완료.** 쓰기 허용 경로가 저장소와 `/tmp`뿐이에요. Serie 빠른 시작과 정책 조회기로 arch의 A-2 브리프를 읽었고, canonical 기록 대신 이 문서를 접수 대기 인계로 남겨요. 호스트 담당자가 이 결과를 기존 ssok 기록/작업 로그/현재 상태에 반영하고 `agent-context refresh`해야 해요. 공유 기록을 완료했다고 주장하지 않아요.
- 통합 대기 브랜치는 `feat/ui-onboarding-r2-20261022`예요. 최신 Claude Fable이 실제 GL 검수와 결합 소스 검사·rebase를 맡고, 사람이 merge해요. 다음 행동은 디스플레이가 있는 환경에서 같은 앱 소스의 아래 명령으로 PNG를 만들고 확정된 1~5 기준을 확인하는 것이에요.

```sh
build/toolchain/godot --path . --language en --fixed-fps 60 --script tests/scene_workshop_ui_check.gd -- --screenshots
```

## 사용자가 해 볼 것 5줄

1. 깃발 스테이지에 들어가 로봇과 초록 목표선이 화면 중앙에 크게 잡히고, 목표 라벨이 읽히는지 본다.
2. 프로그램 패널을 열고 닫아 가용 화면에 맞는지 본 뒤 카메라를 움직여 수동 뷰가 유지되는지 본다.
3. 실행·로봇 재설정·결과의 다시 하기를 눌러 로봇과 목표가 함께 다시 잡히는지 본다.
4. 결승선·벽 앞 정지와 Lab을 열고, 언어 네 개와 1152×648 창에서 두 줄 안내와 라벨을 본다.
5. 도움→설정에서 라이트/다크를 바꾸어 장면 배경·격자·매트 색이 즉시 바뀌고 가장자리 두께가 보이는지 본다.
