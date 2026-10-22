# 작업 A — 장면 중심 작업실 UI와 지금 할 일

2026-10-22 · Codex · 사용자 지정 Claude 디자인 결정 적용 · 로컬 구현 후보, 통합/출시 아님.

## 바뀐 것과 근거

문제는 회색 패널/중앙 카드가 장면을 덮고, 다음 행동과 실제 목표를 읽기 어려웠다는 점이에요.
근거는 사용자의 2026-10-22 작업 A 지시와
[2026-09-30 실제 UX 점검](PRELAUNCH_UX_AUDIT_2026-09-30.md)이에요.
새 취향 판단이나 외부 조사를 추가하지 않고 지정한 1→2→3→5→4 범위를 구현했어요.

| 이전 → 현재 | 실제 코드/검증 근거 |
|---|---|
| 스테이지 중앙 소개 → 바로 장면 | `StageHud`, `game_flow_check`: 깃발의 실패·성공·다음·결승선·벽 정지까지 기존 실제 물리 판정 유지 |
| 고정 패널 → 접이식 부품/프로그램 | Stage/Lab 진입 시 닫힌 상태에서 시작하고 첫 상태 갱신이 필요한 편집 패널만 열어요. 실행 중 자동으로 접고 수동 접힘은 단계가 바뀔 때까지 유지해요. |
| 행동 불명 → 지금 할 일 + 네 칩/힌트 | `WorkshopGuide`: 부품 존재, 모터의 그래프 배선, 코드/미적용 블록 유효성, 실행 모드. 해제/오류 시 체크가 되돌아가요. |
| 목표를 카드에서만 확인 → 장면 표시 | 기존 목표선/결승선/정지 띠 유지. `StageGoalDisplay`: 목표 수치, 조립 높이/거리 미리보기, 실제 판정기 샘플·유지시간·모든 규칙 표시. 무효 센서값은 측정 불가로 남겨요. |
| 여러 결과 행동 → 다시 하기/다음 | 결과 카드를 아래에 놓고 성공한 경우에만 가능한 다음 스테이지를 보여줘요. 판정/기록은 기존 evaluator가 담당해요. |
| 트레이의 답지 목록 → 도움 메뉴 | 튜토리얼·설정·프로젝트·예제·직접 팔 조립. 기존 교체 확인을 거치며 스테이지 목표를 유지해요. |
| 스테이지 텍스트 목록 → 목표 그림/난이도/학습 주제 + 별도 Lab 카드 | 기존 세 스테이지와 기존 학습 주제만 사용해요. 목표 그림은 간단한 도해이며 실제 물리 성공 증거가 아니에요. |
| 어두운 기본값/사막 → 밝은 기본값/격자 작업대 | 저장한 테마는 유지. 세 UI 글자 크기, 반투명 패널, 민트 강조, 라벨 있는 도구, 인라인 블록 인수. 블록 실행 시 탭을 강제로 바꾸지 않아요. |

판정/물리/언어/보드 API/부품 카탈로그는 변경하지 않았어요. `src/core`, `src/runtime`,
`assets/parts`, `assets/construction_kit`, `src/blocks/servo_program.gd`는 수정하지 않았어요.
바닥 충돌도 유지하고 매트·격자·배경을 시각 장식으로 바꿨어요. 무세션 직접 작업실과
별도 example 세션은 기존 도구 구성을 유지해요. AI 패널 내부와 비용 동의는 바꾸지 않았어요.
새 제공자·네트워크 요청·유료 호출·의존성 추가는 없어요.

## 소스·소유·인계

- 실제 작업 브랜치: `feat/ui-onboarding-20261022`.
- 실제 HEAD/시작점: `b3570c650bd0fa285af94fd9136708b1df41bdc8` (v0.3.1). 기존 dirty 파일 없음에서 시작.
- 작업 A는 현재 사용자 지시로 소유해요. `agent-task list --project ssok --cwd "$PWD"` 결과는 빈 목록이었어요. 다른 작업실/소유자는 수정하지 않았어요. 이 환경에서 GitHub 이슈 할당을 확인/생성하지 못했어요.
- 앱 검사 소스: `build/ui-onboarding-a/source-sha256.json`. 명령·exit·진단 여부: `build/ui-onboarding-a/results.json`.
- `.git/index.lock` 생성이 **Read-only file system**으로 실패했어요. 실제 브랜치에는 커밋을 기록하지 못했어요. 읽기 전용 원본 메타데이터를 보존하고, 임시 Git 메타데이터로 의미 단위 후보 커밋 3개와 적용 패치를 준비했어요. 별도 index에 패치를 순서대로 적용한 tree가 후보 HEAD tree와 같고, 모든 변경 파일이 검사한 작업 파일과 바이트 단위로 같음을 확인했어요. 후보 목록은 `build/ui-onboarding-a/series.json`, 패치는 `build/ui-onboarding-a/series/`예요.
- 패치는 시작점의 별도 쓰기 가능한 clean checkout에 적용하는 용도예요. 이미 변경이 있는 현재 작업실에 중복 적용하지 않아요.
- 인계 대상은 이 브랜치의 작업 파일과 패치 시리즈예요. 최신 Claude Fable이 결합 소스 검증·rebase를 맡고 사람이 merge해요. Codex는 main 통합/공개를 하지 않았어요.

## 실제 검사 출력

Godot: 로컬 `build/toolchain/godot`, `4.7.2.stable.official.ed1daf0bf`.
모든 앱 검사는 임시 XDG data/config/cache에서 실행했어요. 개인 저장/언어/선호도는 건드리지 않았어요.

공통 명령 (`NAME`을 아래 표 이름으로 바꿈):

```sh
build/toolchain/godot --headless --path . --language en --fixed-fps 60 --script tests/NAME.gd
```

| NAME | 최종 PASS / FAIL |
|---|---:|
| localization_check | 53,757 / 0 |
| control_flow_check | 18 / 0 |
| workshop_ui_check | 420 / 0 |
| authoring_ui_check | 32 / 0 |
| agent_goal_ui_check | 11 / 0 |
| app_controller_check | 14 / 0 |
| scene_workshop_ui_check (추가) | 354 / 0 |
| block_program_check | 28 / 0 |
| interface_preferences_check | 95 / 0 |
| game_flow_check | 43 / 0 |

10개 suite 모두 exit 0이며 최종 로그에 SCRIPT ERROR/ERROR/FAIL 진단이 없어요.
총 54,772 PASS / 0 FAIL이에요. 원문 로그는 `build/ui-onboarding-a/<NAME>.log`에 있어요.
`scene_workshop_ui_check`는 실제 graph/DC driver 입력 쌍, 삭제된 전선, 잘못된 코드,
패널 수동 접힘/자동 열림, 실제 evaluator 샘플과 표시값 일치, 재시도, 네 언어·두 테마의 기본 한 줄 블록,
1152×648/1440×900·200% 글자 배치, 설정 후 키보드 포커스를 확인해요.
기존 흐름 검사의 물리 성공/실패 기준은 유지했고, 진입 팝업 기대만 새 계약으로 바꿨어요.
블록 검사에서는 바뀐 위젯 위치를 이름으로 찾아 같은 정밀도/충돌/저장 검증을 유지해요. 추가한 기본 한 줄 검사는 처음 영어/일본어의 모터 블록 16건 실패를 발견했고, 짧은 행동 라벨·인라인 단위·패널 폭을 고쳐 최종 0건으로 만들었어요.

추가 명령/결과:

- `build/toolchain/godot --headless --path . --import --quit`: exit 0, script parse/compile 오류 없음. 제한된 환경의 editor TCP listen 오류가 로그에 남아요. `build/ui-onboarding-a/import.log`.
- `build/toolchain/godot --headless --path . --quit`: exit 0, 오류 진단 없음. `build/ui-onboarding-a/scene-load.log`.
- `python3 tools/docs/maintain.py --review execution-flow --write`: 소스/흐름 설명을 대조한 뒤 검토 해시와 지도/ADR 색인을 갱신했어요.
- `python3 tools/docs/maintain.py --check`: PASS. 처음의 entry context 260/250 오류는 새 포인터를 줄이고 STATUS의 빈 줄을 정리해 해결했어요. 제한을 바꾸지 않았어요.
- `python3 -m unittest discover -s tools/docs -p 'test_*.py'`: 10 PASS / 0 FAIL.
- `git diff --check`: PASS. 금지한 core/runtime/catalog 파일의 diff 없음.

영어 원문과 ko/ja/zh_CN PO, 새 문구 30개 inventory를 함께 갱신하고 누락을 명시적으로 검사했어요.
headless 배치 검증은 통과했지만 실제 네 언어 글리프·색·잘림 확인은 아래 한계처럼 미완료예요.
런타임/판정 계약은 유지하고 ADR 0028의 표시/소개 범위, ADR 0026의 기본 테마만
새 ADR 0030으로 일부 대체했어요. 개발 중 실패는 아래에 설명하고 최종 집계에는 넣지 않았어요.

## 실패 이력·미완료와 이유

- 개발 중 match 구문·타입 배열·누락 아이콘 오류와 레이아웃 재호출의 메시지 큐 폭주를 발견했어요. 구문/타입을 고치고, 포함된 체크 문자 및 패널 위치만 갱신하는 resize 처리로 교체했어요. 재시도 시 오래된 관측값 표시도 고쳤어요. 이 중간 결과를 최종 PASS로 세지 않았어요.
- **실제 GL 화면/글리프/색·클리핑 검수 미완료**: `xvfb-run -a -s '-screen 0 1600x1000x24 -nolisten tcp' build/toolchain/godot --path . --language en --fixed-fps 60 --script tests/scene_workshop_ui_check.gd -- --screenshots` 실행이 X11/Wayland 디스플레이 연결 실패로 exit 1이었어요. headless 기하 검사는 실제 렌더 검수를 대신하지 않아요. 디스플레이가 있는 환경에서 이 명령의 Godot 부분을 실행해 PNG를 검수해야 해요.
- Web/데스크톱 export, 실제 사용자 첫 5분 관찰, 외부 모델 디자인 리뷰는 미실행이에요. 현재 소스를 출시했다고 주장하지 않아요.
- **공유 위키/arch Now·프로젝트 포인터/agent-task 등록은 미완료**: 허용 쓰기 경로가 저장소와 `/tmp`뿐이므로 공유 볼트를 갱신하지 않았어요. Serie 빠른 시작과 공통 조회기로 작업 A의 arch 브리프를 확인했고, 중요한 결과/검증/남은 일은 이 파일에 접수 대기로 기록했어요. 호스트 소유자가 이 요약을 기존 ssok 작업 기록에 반영하고 `agent-context refresh`를 해야 해요.

## 사용자가 해 볼 것

1. 앱을 열고 스테이지 선택에서 깃발 스테이지를 고른다.
2. 로봇 프로그램을 열고 블록의 서보 각도를 90으로 바꾼 뒤 코드 실행을 누른다.
3. 장면의 높이와 유지 시간을 보고 다음 스테이지를 누른다.
4. 결승선과 벽 앞 정지 스테이지에서 코드를 바꾸고 실행·다시 하기를 누른다.
5. 스테이지 선택에서 Lab을 열고 부품·배선·코드·도움 메뉴를 차례로 연다.
