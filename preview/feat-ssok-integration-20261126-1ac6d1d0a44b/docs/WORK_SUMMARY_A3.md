# 작업 A-3 — 작은 창·실행 라벨·음영·글꼴 위계

2026-10-22 · Codex · 지정된 네 항목 구현/커밋, headless 검증 완료. 실제 GL 재검수·통합·출시는 후속.

## 기준·소스·소유

- 근거: 사용자가 전달한 2026-10-22 Astra의 RTX 4090 실제 캡처 결함. 취향 재판단 없이 1→2→4→3 순서로 수정했어요.
- 브랜치: `feat/ui-onboarding-r3-20261022`. 시작 HEAD `f8ec3e15e85e29b6dda972d2be0a3408ed5d5eb7`, 시작 dirty 파일 없음.
- 최종 앱/검사 소스 커밋: `bc8af77df886f6ead335615a41248dc589a6da20`. 이후 변경은 문서와 Godot이 생성한 테스트 UID뿐이에요.
- `build/ui-onboarding-a3/source-sha256.json`: 앱/에셋/장면/테스트/번역 inventory 752파일의 SHA-256. manifest SHA-256 `bb35904c090c23c095bb4ef544043302f9e75ebd8bd47d80891b4974f77ed43e`. 최종 바이트 대조용이에요.
- 현재 사용자 지시로 이 작업실의 A-3을 소유했어요. `agent-task list --project ssok --cwd "$PWD"` 결과는 `[]`였어요. GitHub CLI에 로그인/토큰이 없어 이슈/PR 담당 확인·생성은 못 했어요. 공유 task 저장소는 쓰기 허용 범위 밖이에요.
- 최신 Claude Fable의 검수/통합 준비 대상은 이 브랜치예요. main merge/back-merge, push, PR, export, 공개 배포는 하지 않았어요.

## 바뀐 것과 전후 근거

| 항목 | 이전 → 수정 | 근거 |
|---|---|---|
| 1. 작은 창 | 버튼 생략과 자식 최소 높이에 의존 → 번역된 실제 폭으로 완전한 라벨/아이콘 선택, 두 줄·내부 스크롤 | `StageHud.layout`, `main._setup_scene_ui`/`_position_scene_panels`, `workshop_compact_check` |
| 2. 실행 라벨 | `Run code`가 잘리거나 안내의 실행과 다름 → 기존 `Run` 키로 통일, 코드 탭은 `Code` 유지 | ko 실행 / zh_CN 运行 / ja 実行 / en Run. 안내·상태·튜토리얼에서 정확한 버튼명을 인용. 실제 실행/재설정 신호 검사 |
| 4. 위계·강조 | 제목/목표/힌트 유사 크기, 실행 블록 전체 노란 tint → 큰 28 / 중간 16 / 작은 14·회색, 실행 행 윤곽선 | `SsokTheme.title_settings`, `StageHud`, `BlockProgramPanel.highlight_line`; 두 테마·네 언어와 결과 화면의 주요 채운 버튼 1개 검사 |
| 3. 도로 음영 | 그림자 투사만 해제된 얇은 도로/목표 면 → 해당 도색 면의 그림자 수신도 해제 | `WorkbenchSurface._stabilize_road_paint`; 정상 법선·높이 분리·충돌 보존 98개 검사. 실제 GPU 전후 확인은 미완료 |

스트립은 기본 글자에서 **최대 94px**예요. 기본 두 줄 96px 기준을 넘지 않으며 확대 글자는
선호 배율을 유지한 두 줄로 커져요. 힌트가 들어가지 않으면 먼저 숨기고, 네 칩 자체도 안 들어가면
아이콘과 상태 문자만 남겨요. 칩 툴팁에 전체 이름/힌트를 보존해요. 도구 버튼은 이름 전체가
들어가거나 아이콘만 보이며, 주요 실행/재설정 라벨은 생략하지 않아요. 목표는 기본 작은 창에서
전체 문장을 검사하고, 확대 시에는 기존 ADR처럼 생략/전체 툴팁을 허용해요.

편집 패널은 화면 높이의 60% 이내예요. 탭 등 기존 컨트롤을 스크롤 안으로 옮겨 최소 높이가
패널을 밀어내지 않게 했어요. 검사한 100%/130%/200% 배율에서 블록 입력 스크롤 영역은
**최소 122px**예요. 스크롤 밖의 내용을 모두 한 번에 보여 준다는 의미의 ‘잘림 0’은 아니며,
뷰포트 밖 패널/도구 라벨 잘림·스트립과 패널 겹침이 없고 내부 내용은 스크롤로 접근해요.

실행 중에는 버튼/툴팁이 `Reset robot`으로 바뀌므로 ‘Run을 누르라’는 안내 대신 기존
`Challenge running. Watching the real robot.` 관찰 안내를 재사용해요. 재설정하면 Run 안내가 돌아와요.

## 도로 원인 점검과 수정의 한계

실제 Godot 4.7.2 headless 리소스에서 기록한 값:

```text
road shadow diagnostic: bias=0.10000000149012 normal_bias=2.0 max_distance=100.0 map_size=4096
finish_line: mat_top=0.0500000 road_top=0.0510000 gap=0.0010000 road_cast=0 receive_disabled=true
wall_brake: mat_top=0.0500000 road_top=0.0510000 gap=0.0010000 road_cast=0 receive_disabled=true
```

도로는 표준 BoxMesh이고, 24개 법선 모두 유한한 단위 벡터이며 윗면 4개는 +Y예요.
도로 상면은 매트보다 1mm 위라 동일 깊이의 면은 아니었어요. 기존 도로는 이미 `cast_shadow=0`이지만
`disable_receive_shadows=false`였어요. 100m 그림자 범위의 기본 bias/normal bias와 4096 맵으로
작은 도색 면이 그림자를 받는 경로를 확인했어요. [Godot 공식 설명](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html#tweaking-shadow-bias)은
bias/normal bias·해상도에 따른 shadow acne를 설명해요(확인 2026-10-22).

**반복 띠의 GPU 원인을 확정한 것은 아니에요.** 이 환경에서 원래 RTX 캡처를 재현할 수 없으므로
그림자 경로라는 추론과 확인한 리소스 사실을 구분해요. 전역 bias나 맵 크기를 추측해서 바꾸지 않고,
도로·차선·정지/위험 구역·결승선의 0.8mm 도색 BoxMesh만 재질을 복제해 그림자 수신을 제외했어요.
[공식 재질 속성](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#class-basematerial3d-property-disable-receive-shadows)에 따른
수정이며 일반 조명/도로 색은 유지해요. 해당 도색 면 위의 실제 로봇 그림자도 표시되지 않는 절충이에요.
매트/부품의 그림자와 전역 조명은 그대로예요. 실제 GL에서 띠 소멸과 색은 재검수해야 해요.

A-2의 프레이밍, 화면 목표 라벨, 다크 장면색, 매트 가장자리는 유지했어요.
`src/runtime`, 블록 파서, 부품 카탈로그, 보드 profile/API, 물리 설정·충돌·레벨 `.tscn`은 변경하지 않았어요.
`src/core/stage_levels.gd`는 설명의 `Press “Run”.` 두 곳만 바꿨어요. UI 패널의 내부 기능·신호·파싱·초안 적용 계약은 유지했어요.
의존성·제공자·과금·전송 변경은 없어요.

## 직접 기록한 커밋

1. `8bece6d` Bound compact workshop overlays and preserve complete labels
2. `c775cd3` Use the existing Run label throughout workshop guidance
3. `310ae2c` Separate type hierarchy and outline executing blocks
4. `0d08fb2` Exclude instructional road paint from shadow artifacts
5. `bc2c3fc` Keep active-run guidance aligned with the reset action

6. `bc8af77` Preserve the compact strip palette across theme changes

모두 영어 메시지와 `Agent: codex` trailer예요. 마지막 인계/문서 커밋은 별도예요.

## 실제 검사 출력

Godot `build/toolchain/godot`, `4.7.2.stable.official.ed1daf0bf`, headless, 고정 60fps.
XDG data/config/cache는 각각 `/tmp/ssok-a3-{data,config,cache}`로 분리했어요.

```sh
build/toolchain/godot --headless --path . --language en --fixed-fps 60 --script tests/NAME.gd
```

최종 15 suite(기존 A-2의 11개 + 신규 4개), 모두 exit 0·SCRIPT ERROR/ERROR/FAIL 없음:

```text
compact geometry: default strip max=94 px; block input viewport min=122 px
workshop_run_label_check: 72 checks, 0 failures
workshop_emphasis_check: 76 checks, 0 failures
workshop_road_check: 98 checks, 0 failures
workshop_compact_check: 2176 checks, 0 failures
workshop_presentation_check: 483 checks, 0 failures
scene_workshop_ui_check: 360 checks, 0 failures
game_flow_check: 43 checks, 0 failures
workshop_ui_check: 420 checks, 0 failures
localization_check: 53807 checks, 0 failure(s)
block_program_check: 28 checks, 0 failures
interface_preferences_check: 95 checks, 0 failures
app_controller_check: 14 checks, 0 failures
authoring_ui_check: 32 checks, 0 failures
Agent goal UI checks: 11 / failures: 0
control_flow_check: 0 failure(s)
```

- 신규 작은 창: 세 Stage + Lab × 네 언어 × 100%/130%/200%. 인접 컨트롤 겹침, 도구/실행/칩 완전한 폭, 기본 목표 문장, 스트립/패널 경계, 패널 60%, 블록 입력 영역을 실제 Control rect로 검사해요. 크기를 키웠다 줄여 복원도 확인해요.
- 신규 라벨: 네 언어 Run/Code 구분, 안내 inventory의 정확한 인용, 실제 화면/블록 피드백/포커스, 실행→재설정→Run 복귀와 실행 중 관찰 안내를 검사해요.
- 기존 assertion은 `localization_check`의 예상 버튼 키를 `Run`으로 맞춘 한 곳 외에는 바꾸지 않았어요. 번역 글자/키 수가 바뀌어 해당 검사 개수는 53,853→53,807이며 비교/글리프 검사를 줄이지 않았어요.
- 기존 `workshop_presentation_check`의 A-2 프레이밍·기본 두 크기 전체 목표/힌트·다크/매트/수동 카메라 483검사도 유지/통과했어요.
- 원문 로그와 명령/exit/시간은 `build/ui-onboarding-a3/NAME.log`, `results.json`에 있어요. build는 Git 제외이며 현재 작업실에 남아요.
- `build/toolchain/godot --headless --path . --import --quit`: exit 0, parse/compile 오류 없음. 기존 환경의 editor TCP listen 소켓 생성 ERROR는 `import.log`에 보존했어요.
- `build/toolchain/godot --headless --path . --quit`: exit 0, 오류 없음 (`scene-load.log`).
- `python3 tools/docs/maintain.py --review execution-flow --write`, `--review flag-flow`: 실제 소스와 문서를 대조한 뒤 갱신했어요. 그래프/실행/저장/판정 도식은 동작 계약이 그대로여서 유지했어요.
- `python3 tools/docs/maintain.py --check`: PASS.
- `python3 -m unittest discover -s tools/docs -p 'test_*.py'`: `Ran 10 tests ... OK`.
- `git diff --check`: PASS. 금지 경로의 시작 HEAD 대비 diff 없음.

영어 원문, ko/zh_CN/ja PO와 관련 inventory를 함께 갱신했어요. `Run` 버튼 키는 재사용하며,
안내 문구만 바꿨어요. `FLOWS`, `INTERFACE_PREFERENCES`, `LOCALIZATION`, `STATUS`, context/ADR 색인을 검토/갱신했어요.
[ADR 0032](adr/0032-compact-workshop-presentation.md)는 0031의 기본 힌트 항상 표시만 일부 대체해요.

## 실패·못 한 것·인계 checkpoint

- A-2 기존 headless 483검사는 시작점에서도 통과했어요. 사용자가 본 일본어 73% 높이를 실제 렌더로 재현했다고 주장하지 않아요. 더 강한 신규 기하 검사와 강제되지 않은 버튼 최소 폭 경로를 추가했어요.
- 개발 중 신규 검사에서 높이 98px와 도구 라벨 생략 등 196실패를 발견했어요. `clip_text=false`에 더해 `OVERRUN_NO_TRIMMING`을 적용하고 strip 여백을 조정해 해결했어요. 해당 실패 로그는 `compact-first.log`/`compact-measure.log`에 보존해요. 도로 수정 전 42개 도색 면의 수신 제외 검사는 실패했고 수정 후 0이에요(`road-before.log`/`road-after.log`). 중간 결과를 최종 통과로 세지 않아요.
- **실제 GL 캡처·네 언어 글리프/클리핑·도로 띠 소멸 재검수 미완료.** `DISPLAY=:0 ... build/toolchain/godot --path . --editor --quit`는 exit 1, X11 불가→Wayland 초기화 실패였어요(`render-probe.log`). headless glyph 존재/폭 계산과 실제 GPU 화면은 다르며, RTX 4090 검수 통과라고 부르지 않아요.
- Web/데스크톱 export, 실제 패키지 입력, 전체 저장소 릴리스 suite는 미실행이에요. 기존 A-2의 11개 회귀와 신규 4개를 이번 소스로 실행한 범위예요.
- **공유 위키/작업 로그/arch Now·프로젝트 포인터/agent-task 종료 기록 미완료.** 허용 쓰기 경로는 저장소와 `/tmp`뿐이에요. Serie 빠른 시작, 정책 조회기로 arch ssok 노트와 기록 절차를 확인했어요. 이 문서를 접수 대기 인계로 남기며 공유 볼트에 썼다고 주장하지 않아요. 호스트 담당자가 기존 ssok 기록의 Update·작업 로그·현재 상태에 이 결과를 반영하고 `agent-context refresh`해야 해요.
- 구현 checkpoint: **`feat/ui-onboarding-r3-20261022`를 최신 Claude Fable에게 인계**해요. 실제 GL 전후 관찰 → 결합 소스 검사/rebase → human merge가 다음이에요. 현재는 로컬 구현/검사 후보이며 최종 시각 검수와 통합/배포는 별도예요.

실제 렌더가 가능한 환경에서 같은 앱 소스로 네 언어·두 테마·작은 창을 확인할 명령:

```sh
build/toolchain/godot --path . --language en --fixed-fps 60 --script tests/scene_workshop_ui_check.gd -- --screenshots
```

## 사용자가 해 볼 것 5줄

1. 창을 1152×648로 줄이고 네 언어에서 안내가 두 줄이며 도구가 전체 이름 또는 아이콘/툴팁으로 보이는지 본다.
2. 프로그램·부품을 열어 화면 높이 60% 이내이고, 블록 입력과 아래 항목을 스크롤로 조작할 수 있는지 본다.
3. ‘실행’을 누르고 버튼/툴팁이 ‘로봇 재설정’으로 바뀌며, 재설정 뒤 ‘실행’으로 돌아오는지 본다.
4. 벽 앞 정지와 결승선에서 도로·목표 띠의 대각선 음영이 사라졌는지 카메라를 움직이며 본다.
5. 밝게/어둡게와 글자 200%를 바꾸어 제목>목표>회색 힌트, 입력칸 색·실행 윤곽선, A-2 프레이밍/매트 가장자리를 본다.
