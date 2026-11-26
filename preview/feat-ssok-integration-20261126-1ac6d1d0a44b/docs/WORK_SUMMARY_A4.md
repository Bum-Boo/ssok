# 작업 A-4 — 목표 라벨 공간 규칙과 관측 전 표시

2026-10-22 · Codex · 로컬 구현/검사 후보. 실제 GL 검수와 통합/출시는 별도예요.

## 기준·소스·소유

- 문제/근거: 사용자가 전달한 2026-10-22 Claude의 RTX 4090 실제 렌더 확정 결함이에요. 작은 창의 확대 일본어 라벨 압축, 실행 전 벽 규칙 6줄, 과밀한 결승선 콘을 수정했어요. 디자인 재판단이나 외부 조사는 하지 않았어요.
- 작업실: `feat/ui-onboarding-r4-20261022`, 시작 HEAD `1aa83da08f13883fd21bf7183ede494918b3324b`. 시작 dirty 파일 없음. 사용자 지정 A-3 적용 워크트리에서 작업했어요.
- 최종 앱/테스트 소스: `557ee43a2f4aa185ed7ca22dcfb78089f8efd9db`. 검사한 바이트와 커밋 이후 808파일의 SHA-256을 대조했고 변경은 없어요(`source-verify.json`). 이 뒤 변경은 문서뿐이에요.
- 소스 manifest: `build/ui-onboarding-a4/source-sha256.json`, 808파일, SHA-256 `51fc284bbc673837fdc1712d491606d57ce91b0e76d00bba3fb56d804ed65fb7`.
- `agent-task list --project ssok --cwd "$PWD"`: `[]`. 사용자 지정 A-4 범위로 작업했으며 다른 소유자의 작업실/WIP는 건드리지 않았어요. `gh auth status`는 미로그인이라 GitHub 이슈 생성/담당 확인·PR 작성은 못 했어요.
- Serie 빠른 시작과 공통 정책 조회기로 Frieren (arch)의 `30_Projects/ssok.md`를 읽었어요. 이 기록은 위치/지속 지침 포인터이며 현재 사용자 브리프와 저장소의 최신 구현을 우선했어요.

## 바뀐 것과 실제 전후 근거

| 항목 | 이전 → 현재 | 변경/검증 |
|---|---|---|
| 1. 폭·숨김 | 가용 폭까지 축소 + 단어 줄바꿈 → 내용의 자연 폭과 `260 × ui_scale` 중 큰 폭, 자동 줄바꿈 없음 | `StageGoalDisplay`의 실제 Label/Panel 최소 크기·rect 측정. 가장자리 고정에서도 같은 폭. 패널·스트립을 뺀 영역의 폭/높이가 부족하면 카드·리더 선 숨김 |
| 1. 대체 요약 | 목표 라벨이 찌그러짐 → 스트립 힌트 자리에 첫 규칙의 `현재 값 / 목표` 한 줄 | 칩 이름을 먼저 줄여 요약 공간 확보. 모든 규칙은 툴팁, 수정 가능한 오류가 우선. 창/패널을 복구하면 라벨과 원래 단계 힌트 복원. 요약에는 중복 측정 항목명을 넣지 않아 현재 값과 목표가 모두 들어감 |
| 2. 관측 전 | 벽 규칙마다 측정 불가·목표·유지 시간 2줄 → 목표 조건과 측정 항목 1줄 | 세 미션 모두 관측 전 규칙당 1줄. running이어도 샘플이 없으면 목표만. 샘플 이후 기존 현재 값/목표와 실제 유지 시간 2줄. null 센서는 측정 불가, 유효한 0은 그대로. 재설정 시 목표만 복원 |
| 2. 앵커 | 조립 자세가 현재 값처럼 표시 → evaluator 샘플만 현재 관측으로 사용 | `show_assembly` 프리뷰 경로 제거. 높이가 바뀌어도 월드 앵커와 투영 앵커 유지. 판정/실행 흐름은 그대로 |
| 3. 콘 | 결승선 도로 양옆 18개, 간격 0.15m → 보이는 콘 8개, 간격 0.30m | `.tscn`의 짝수 번호 10개에 `visible=false`만 추가. 결승선 x=0.5에 가장 가까운 x=0.45 양쪽 2개 유지. 기존 콘은 MeshInstance3D 장식이며 충돌 변경 없음. 생성기에도 결승선만 같은 희소 배치 적용 |

A-2/A-3의 프레이밍·두 줄 스트립·관측 후 라벨 서식·다크 장면색·Run 라벨을 유지했어요.
`src/runtime`, `src/core`, 부품/보드 profile·API, 블록 파서, 물리 설정과 판정 규칙의 시작 HEAD 대비 diff는 없어요.
새 의존성·제공자·네트워크·과금·전송 변경은 없어요. 영어 원문 두 개와 ko/zh_CN/ja PO·명시 inventory를 함께 갱신했어요.

## 직접 커밋

1. `593e37b` Preserve goal label width and fall back to strip summaries
2. `9b12c14` Show only targets until goal observations arrive
3. `fc584d8` Halve visible roadside cones near the finish line
4. `557ee43` Keep fallback current and target values fully visible

영어 메시지와 `Agent: codex` trailer로 항목별 커밋했어요. 마지막 문서/인계 커밋은 별도예요.
main merge/back-merge·push·공개 배포는 하지 않았어요.

## 실제 검사 출력

Godot `build/toolchain/godot`, `4.7.2.stable.official.ed1daf0bf`, headless, 고정 60fps.
개인 저장을 건드리지 않도록 각 suite의 XDG data/config/cache를 `/tmp/ssok-a4-final-NAME-{data,config,cache}`로 분리했어요.

```sh
build/toolchain/godot --headless --path . --language en --fixed-fps 60 --script tests/NAME.gd
```

```text
workshop_run_label_check: 72 checks, 0 failures
workshop_emphasis_check: 76 checks, 0 failures
workshop_road_check: 98 checks, 0 failures
compact geometry: default strip max=94 px; block input viewport min=122 px
workshop_compact_check: 2176 checks, 0 failures
workshop_presentation_check: 483 checks, 0 failures
scene_workshop_ui_check: 366 checks, 0 failures
game_flow_check: 43 checks, 0 failures
workshop_ui_check: 420 checks, 0 failures
localization_check: 53882 checks, 0 failure(s)
block_program_check: 28 checks, 0 failures
interface_preferences_check: 95 checks, 0 failures
app_controller_check: 14 checks, 0 failures
authoring_ui_check: 32 checks, 0 failures
Agent goal UI checks: 11 / failures: 0
control_flow_check: 0 failure(s)
workshop_goal_space_check: 10416 checks, 0 failures
workshop_goal_observation_check: 4512 checks, 0 failures
```

- 기존 15 suite + 신규 공간/관측 2 suite, 최종 소스에서 모두 exit 0. `SCRIPT ERROR`/`ERROR:`/`FAIL` 없음. 명령·시간·exit·요약은 `build/ui-onboarding-a4/results.json`, 원문은 같은 폴더의 `NAME.log`예요. build는 Git 제외이며 현재 워크트리에 남아요.
- 공간 신규 검사: 세 미션 × 네 언어 × 100%/130%/200% × 1152×648/1440×900 × 밝게/어둡게. 실제 패널 개폐·창 크기/언어/배율 전환, 자연 폭·최소 폭·무줄바꿈, 화면 밖 앵커 고정, 가용 폭/높이 각각 1px 부족, 요약/힌트 복원과 전체 요약 폭을 검사해요.
- 관측 신규 검사: 같은 미션·언어·배율·두 크기 × 프로그램 패널 열림/닫힘. 샘플 없는 idle/running 각각 규칙당 1줄, 관측 후 2줄, 실제 유지 값·앵커·높이 복원, 부분/null/0 샘플을 확인해요. UI fixture와 실제 evaluator 관측은 구분하며, 기존 `scene_workshop_ui_check`가 실제 실행 샘플과 display.samples의 동일성을 계속 확인해요.
- 콘 검사: `18 total / 8 visible / 10 hidden`; 보이는 번호 1·3·5·7의 Left/Right, 결승선 양쪽 5번 유지. `.tscn` diff는 visibility 10줄뿐이고 충돌/transform은 같아요. 기존 `workshop_road_check` 98검사도 통과했어요.
- `build/toolchain/godot --headless --path . --import --quit`: exit 0. parse/compile 오류 없음. 환경의 editor TCP 소켓 생성 ERROR 4줄은 `import-final.log`에 보존했어요.
- `build/toolchain/godot --headless --path . --quit`: exit 0, 오류 없음 (`scene-load.log`).
- `python3 tools/docs/maintain.py --check`: PASS. `python3 -m unittest discover -s tools/docs -p 'test_*.py'`: `Ran 10 tests ... OK`. `git diff --check`: PASS.

`FLOWS`, `INTERFACE_PREFERENCES`, `LOCALIZATION`, `STATUS`, context/생성 지도/ADR 색인을 갱신했어요.
[ADR 0033](adr/0033-goal-label-space-and-observation-states.md)은 0032의 힌트 생략 우선순위와 0030의 화면 라벨 조립 미리보기만 부분 대체해요.
관련 실행·깃발 흐름을 실제 소스와 대조했고, 그래프/실행/저장/판정 도식은 계약이 같아 유지했어요.

## 실패·못 한 것·인계 checkpoint

- 첫 관측 검사에서 96실패: 테스트가 모든 `/`를 유지 시간으로 보아 속도 단위 `m/s`까지 금지한 잘못된 assertion이었어요. 실제 유지 문구 prefix 검사로 고치고 최종 통과했어요(`goal-observation-first.log`, `goal-observation-after.log`). 앱 오류를 해결한 결과로 세지 않아요.
- 기존 17 suite가 처음 모두 통과한 뒤, 더 강한 전체 요약 폭 검사에서 영어 200%/1152×648의 벽 프로그램 패널에 2실패를 찾았어요: 필요 861px, 실제 829px. 요약에서 측정 항목명 중복을 빼고 현재 값/목표 전체 폭 검사를 정식 suite에 추가했어요(`summary-width-probe.log`). 그 뒤 최종 17 suite를 재실행했어요.
- 문서 검사 첫 실행은 `Entry context is 251 lines; limit 250`으로 실패했어요. STATUS의 같은 문단 두 줄을 합쳐 입구를 250줄로 유지했고 최종 검사는 통과했어요.
- **실제 GL 캡처와 네 언어 글리프/클리핑·콘 밀도 시각 재검수 미완료.** `DISPLAY=:0 ... --display-driver x11 --rendering-method gl_compatibility --editor --quit`는 exit 1, X11 불가→Wayland 초기화 실패였어요(`render-probe.log`). headless 크기/글꼴 측정은 실제 RTX 렌더 통과를 뜻하지 않아요.
- Web/desktop export·실제 패키지 조작·전체 릴리스 suite는 미실행이에요. 이번 결과는 요청된 기존 15개와 신규 2개의 현재 소스 검사예요.
- **공유 위키·작업 로그·arch 현재 상태/Now·프로젝트 포인터·agent-task 종료 기록 미완료.** 쓰기 허용 경로가 저장소와 `/tmp`뿐이에요. 이 문서를 중요 작업의 접수 대기 기록으로 남겼어요. 호스트 담당자가 기존 ssok 기록의 Update·작업 로그·현재 상태에 이 검증/남은 일을 반영하고 `agent-context refresh`해야 해요. 공유 기록을 썼다고 주장하지 않아요.
- 구현 checkpoint: **`feat/ui-onboarding-r4-20261022`를 최신 Claude Fable에게 인계**해요. 다음은 같은 앱 바이트의 실제 GL 전후 검수 → 결합 소스 검사/rebase → human merge예요. 로컬 구현/검증 후보이며 통합/출시는 별도예요.

## 사용자가 해 볼 것 5줄

1. 1152×648에서 일본어와 글자 130%·200%로 바꾸고 목표 라벨이 한 글자씩 세로로 찌그러지지 않는지 본다.
2. 프로그램·부품 패널을 열고 닫아 공간 부족 시 스트립의 현재 값/목표 요약과 공간 복구 시 라벨이 돌아오는지 본다.
3. 벽 앞 정지 진입 직후 목표 3줄만 보이고, 실행 관측 후 현재 값·유지 시간이 붙으며 재설정하면 3줄로 돌아오는지 본다.
4. 깃발·결승선도 실행 전/후 표시와 같은 앵커를 확인하고, 결승선 콘이 8개이며 결승선 옆 양쪽 한 쌍이 남았는지 본다.
5. 1440×900와 네 언어·밝게/어둡게에서도 라벨/요약 잘림과 A-2/A-3의 프레이밍·Run·두 줄 안내가 유지되는지 본다.
