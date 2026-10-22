# 작업 A-5 — 목표 문장과 패널 제목의 글꼴 위계 교정

2026-10-22 · Codex · 로컬 구현/검사 후보. 실제 GL 검수·통합·출시는 별도예요.

## 기준·소스·소유

- 문제 근거는 사용자가 전달한 2026-10-22 Claude의 RTX 4090 실제 렌더 확정 결함이에요. A-3이 ‘지금 할 일’ 분류 태그와 패널 제목을 28px로, 목표 문장을 16px로 표시했어요. 디자인을 다시 판단하거나 외부 조사를 하지 않았어요.
- 작업 브랜치 `feat/ui-onboarding-r5-20261022`, 시작 HEAD `ae4a87e01e2d80dd607ab91dcfe4128d54fec6b1`, 시작 dirty 파일 없음. 사용자 지정 A-4 적용 작업실에서 작업했어요.
- 최종 앱/검사 소스 `337eff1ef2fbb786e2f694ea16ded90935cb4e0f` (아래 커밋 목록). 이 뒤 변경은 문서뿐이에요. 검사 전 manifest와 검사 후 파일 해시를 대조했어요. manifest는 앱/검사/리소스 742파일이며 SHA-256은 `c4e602d67835c66d5c945d15d16066c4f90df0f95d8b39362fc5c8b5ffc27b61`예요.
- `agent-task list --project ssok --cwd "$PWD"`: `[]`. 사용자 지정 A-5 범위로 작업했어요. `gh auth status`는 미로그인이어서 GitHub 이슈 생성/담당 확인·PR 작성은 못 했어요.
- Serie 빠른 시작·정책 조회기로 Frieren (arch)의 `30_Projects/ssok.md`를 읽었어요. 이 기록은 프로젝트 위치/상시 지침 포인터이고 현재 브리프와 저장소 소스를 우선했어요.

## 바뀐 것과 실제 전후 근거

| 대상 | 이전 → 현재 | 유지한 규칙/확인 |
|---|---|---|
| 스트립 목표 | 16px → **28px** | 기본·확대 글자 모두 한 줄, 공간 부족 시 생략/전체 번역 툴팁. 선호 배율을 줄이지 않음 |
| 분류 태그 | 28px 민트 → **14px 회색** | 목표 앞의 기존 ‘Now’/‘지금 할 일’ 키. 검사에서 `GoalTag`를 직접 식별 |
| 칩/힌트 | 14/14px → **16/14px** | 두 줄·힌트 생략·아이콘/전체 툴팁·A-4 요약 우선순위 유지. 기본 스트립 최대 **96px** |
| 패널 제목 | 공통 제목 28px, 코드/배선 작은 회색 → **16px 굵게** | 프로그램·블록·코드·배선·부품·프로젝트·수동 조작·출제·도움/튜토리얼. 설정/프로젝트/도움 창 제목도 16px 굵게 |
| 굵은 CJK | 일반 글꼴 → 기존 파일의 `FontVariation` embolden 0.8 | ko/zh_CN/ja/en의 기존 지역별 face를 언어 전환과 함께 갱신. 새 파일/의존성 없음 |
| 결과 제목 | 28px → **28px 유지** | 성공·실패 양쪽과 주요 채운 버튼 1개 유지 |
| 검사 | 태그 제목 > 목표 > 힌트 → 목표 28·태그 14 회색·패널 16 굵게 | 두 테마 × 네 언어 × 두 해상도 × 세 배율, 크기/굵기/지역 face/번역 글리프/단일 행/툴팁/패널 내 큰 Label 부재. 기존 실행 행 윤곽선·초안 보존·주요 버튼 검사 유지 |

`SsokTheme.title_settings()`를 공통 패널 제목 스타일로 고쳤기 때문에 블록·프로젝트·부품 등 기존 호출부는 별도 크기 override 없이 함께 바뀌어요. 코드·배선·출제·튜토리얼 내부 제목도 같은 스타일을 사용해요. 패널 높이 60%와 내부 스크롤은 유지했고, 현재 작은 창 검사에서 블록 입력 뷰포트의 최솟값은 **156px**예요.

기존 `workshop_compact_check`/`workshop_presentation_check`의 기본 글자 목표 ‘항상 전체 표시’ assertion은 28px 유지·생략·전체 툴팁으로 바꿨어요. 창/버튼/패널 기하, A-2 프레이밍·A-4 공간/관측 검사는 유지했어요. [ADR 0034](adr/0034-correct-workshop-type-roles.md)는 ADR 0032의 글꼴 역할 배정과 그에 따른 목표 생략 범위만 부분 대체해요. 나머지 결정은 유지해요.

추가로 작은 패널 제목 때문에 목표 라벨이 표시될 공간이 늘면서 기존 투영 경계 검사의 카메라 평면 앵커가 실제 계산에 도달했어요. Godot이 그 입력에서 오류와 함께 반환하던 `Vector2.ZERO`를 깊이 0 부근에서 직접 사용하도록 수치 보호만 추가했어요. 기존 가장자리 고정/숨김/폭/관측 규칙은 그대로예요. 카메라 위치·같은 평면·화면 밖 입력을 제거하지 않고 유한 좌표 assertion을 21개 추가했어요.

물리·런타임·부품/보드 API·블록 파서·레벨/판정·장면 파일과 A-2/A-4 프레이밍 구현·다크 환경색·콘 배치는 시작 HEAD 대비 diff가 없어요. 영어 원문·번역 키·PO·inventory는 변경하지 않았어요. 제공자·전송·과금·새 의존성 변경도 없어요.

## 직접 커밋

1. `ce74fa9` Assign large strip type to the goal sentence
2. `4a66cd3` Use medium bold headings throughout workshop panels
3. `337eff1` Preserve edge placement for singular camera projections

영어 메시지와 `Agent: codex` trailer로 의미 단위별 커밋했어요. 문서/인계 커밋은 별도예요. main merge/back-merge·push·공개 배포는 하지 않았어요.

## 실제 검사 출력

Godot `build/toolchain/godot`, `4.7.2.stable.official.ed1daf0bf`, headless, 고정 60fps.
각 suite의 XDG data/config/cache를 `/tmp/ssok-a5-final-NAME-{data,config,cache}`로 분리했어요.

```sh
XDG_DATA_HOME=/tmp/ssok-a5-final-NAME-data \
XDG_CONFIG_HOME=/tmp/ssok-a5-final-NAME-config \
XDG_CACHE_HOME=/tmp/ssok-a5-final-NAME-cache \
build/toolchain/godot --headless --path . --language en --fixed-fps 60 --script tests/NAME.gd
```

최종 17 suite의 출력:

```text
workshop_run_label_check: 72 checks, 0 failures
workshop_emphasis_check: 6480 checks, 0 failures
workshop_road_check: 98 checks, 0 failures
compact geometry: default strip max=96 px; block input viewport min=156 px
workshop_compact_check: 2176 checks, 0 failures
workshop_presentation_check: 504 checks, 0 failures
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

- 전체 17 suite exit 0,`SCRIPT ERROR`/`ERROR:`/`FAIL` 없음. 명령·시간·exit·출력은 `build/ui-onboarding-a5/results.json`, 원문은 같은 폴더의 `NAME.log`예요. build는 Git 제외이며 현재 작업실에 남아요.
- 글꼴 검사 48조합: 밝게/어둡게 × ko/zh_CN/ja/en × 1152×648/1440×900 × 100%/130%/200%. 언어·테마·배율을 같은 화면에서 바꾸며 200% 뒤 다음 언어의 100%로 돌아가며 누적 확대도 확인해요. headless 글리프 존재 검사는 실제 GPU 렌더 검수와 구분해요.
- 앱/검사/리소스 manifest는 `build/ui-onboarding-a5/source-sha256.json`, 검사 후 동일성은 `source-verify.json`이에요. 문서 커밋 후에도 검사한 앱 바이트와 같음을 재확인해요.
- `build/toolchain/godot --headless --path . --import --quit`: exit 0, parse/compile 오류 없음. 환경의 editor TCP 소켓 생성 ERROR 4줄은 `import-final.log`에 보존했어요.
- `build/toolchain/godot --headless --path . --quit`: exit 0, 오류 없음 (`scene-load.log`).
- `python3 tools/docs/maintain.py --check`: PASS. `python3 -m unittest discover -s tools/docs -p 'test_*.py'`: `Ran 10 tests ... OK`. `git diff --check`: PASS.

`FLOWS`, `INTERFACE_PREFERENCES`, `LOCALIZATION`, `STATUS`, context/생성 지도/ADR 색인을 검토·갱신했어요. 실행·깃발 흐름을 실제 소스와 대조했으며 그래프/실행/저장/판정 계약과 도식은 그대로여서 유지했어요. 번역 내용 변경은 필요하지 않았고 기존 네 언어 카탈로그 검사를 실행했어요.

## 실패·못 한 것·인계 checkpoint

- 첫 17 suite는 assertion 실패/비정상 exit가 없었지만 `workshop_presentation_check`가 `unproject_position: p.d == 0` ERROR를 8회 출력해 추가 로그 gate는 실패했어요 (`results-first.json`, `presentation-first.log`, `runner.log`). 시작 커밋을 `/tmp/ssok-a5-baseline`에 별도로 체크아웃해 같은 검사 483/0·오류 없음도 확인했어요 (`presentation-baseline.log`). 제목 축소가 드러낸 특이 입력 경로를 보호한 뒤 504/0·오류 없음 (`presentation-after.log`)과 최종 17 suite를 다시 확인했어요. 첫 실행을 오류 없는 통과로 세지 않아요.
- **실제 GL 캡처·네 언어의 실제 글리프/클리핑·굵기 시각 검수 미완료.** Xvfb + `--display-driver x11 --rendering-method gl_compatibility` 실행은 exit 1, X11 불가→Wayland 초기화 실패였어요 (`render-isolated.log`). 최초 비격리 탐색은 user 로그 디렉터리 생성 실패도 있어 `render-probe.log`에 남겼고, 이후 `/tmp`로 저장을 격리한 탐색에서도 디스플레이 실패를 확인했어요. RTX 4090에서 이번 소스를 검수했다고 주장하지 않아요.
- Web/desktop export·실제 패키지 조작·전체 릴리스 suite는 미실행이에요. 이번 결과는 요청된 17개 suite와 문서 검사예요.
- **공유 위키·작업 로그·arch 현재 상태/Now·프로젝트 포인터·agent-task 종료 기록 미완료.** 쓰기 허용 경로가 저장소와 `/tmp`뿐이에요. Serie의 중요 작업 기록 절차에 따라 이 문서를 접수 대기 인계로 남겨요. 호스트 담당자가 기존 ssok 기록의 Update·작업 로그·현재 상태에 소스/검증/남은 일을 반영하고 `agent-context refresh`해야 해요. 공유 기록을 썼다고 주장하지 않아요.
- **`feat/ui-onboarding-r5-20261022`를 최신 Claude Fable에게 인계**해요. 다음은 같은 앱 바이트에서 실제 GL 전후/네 언어·두 테마·두 해상도·확대 검수 → 결합 소스 검사/rebase → human merge예요. 통합/출시는 하지 않았어요. 재개 진입점은 [START_HERE](START_HERE.md)와 이 문서예요.

## 사용자가 해 볼 것 5줄

1. 스테이지를 열어 목표 문장이 28px로 가장 크고, 앞의 ‘지금 할 일’은 회색 14px인지 본다.
2. 1152×648와 글자 130%·200%에서 목표 글자가 작아지지 않고 말줄임되며 툴팁에 전체 문장이 있는지 본다.
3. 블록·코드·배선·부품·프로젝트·설정·도움을 열어 제목이 16px 굵게이고 패널 안에 과한 28px 제목이 없는지 본다.
4. 네 언어와 밝게/어둡게를 바꾸며 제목의 지역별 글리프·굵기·잘림, 두 줄 안내·칩/힌트·내부 스크롤을 본다.
5. 성공/실패 제목은 28px인지 보고, Run/재설정·목표 라벨/요약·프레이밍·다크 장면·결승선 콘이 A-4와 같은지 본다.
