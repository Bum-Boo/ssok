# 실행과 저장 흐름

아래 도식은 [STATUS](STATUS.md)의 통합 소스에 있는 책임과 흐름을 요약해요.

## 코드 실행과 제어권

```mermaid
flowchart TD
    Click[Run code] --> Busy{이미 실행 중이거나 실험/안내 창 열림?}
    Busy -->|예| Ignore[새 요청 무시]
    Busy -->|아니오| Draft{미적용 블록 있음?}
    Draft -->|예| Apply[블록 적용과 충돌 검사]
    Apply -->|거부| Edit[초안 보존 / 편집]
    Apply -->|성공| Syntax[전체 문법과 이름 사전 검사]
    Draft -->|아니오| Syntax
    Syntax -->|오류| Edit
    Syntax -->|통과| Owner[수동 명령 해제 / 코드 제어 선택]
    Owner --> Build[필요하면 그래프에서 물리 생성]
    Build --> Validate[전체 배선까지 검사]
    Validate -->|오류| Error[failed 신호 / 모터 명령 미전송]
    Validate -->|통과| Goal[Stage 대상 검사와 실행 문맥 고정]
    Goal -->|거부| Error
    Goal -->|통과| Execute[bounded VM: 서보·모터·센서·조건·반복]
    Execute --> Complete[finished 신호]
    Execute --> Stop[사용자 Stop / 모드·제어권 변경]
    Stop --> Invalidate[execution_id 증가 / 대기·VM 무효화]
```

`scenes/main.gd`가 실행 버튼과 제어권을 조정하고 `MiniRuntime`이 명령을 해석해요. 코드 종료와 임무 성공은 다른 사건이에요. Stop은 VM을 중단하고 DC 모터를 정지하며 서보의 마지막 목표를 유지해요. 진행 중 Stage 시도는 cancelled로 기록해요. 물리 정지나 초기 자세 복원으로 해석하지 않아요. 편집 모드 복귀는 `RunMode.teardown()` 뒤 원본 그래프를 다시 보여줘요.

## 로컬 초안의 카메라·행동 제어권

`main.gd._build_agent_tools()`가 `AgentCameraLoop`, Claude 작성 `AgentTracePanel`, 선택적
`AgentDesktopBridge`를 연결해요. AI Enable은 기존 VM/수동/동작 프로그램을 멈춘 뒤 그래프의
차 몸체와 배선 모터 두 개를 확인해요. 물리 정지 확인 → 실제 렌더 캡처 → ready → 현재 프레임에
묶인 유한 행동 → 브레이크 → 실제 정지 확인 순서이며, 다음 행동 전에 다시 관측해요.
프레임은 episode/body instance/revision/generation과 PNG 해시에 묶여요. 에디터 카메라는 입력이 아니에요.
AI가 판단하는 동안에는 실제 바퀴 속도를 피드백한 제한 PI 브레이크가 기존 배선 모터로
느린 밀림을 억제해요. 모터 토크·몸체 위치·물리 시간은 바꾸지 않아요. 카메라 준비 조건은
12틱 연속 차체 속도≤0.001m/s·바퀴≤0.05rad/s로 강화했고, 독립 성공 판정 기준은 유지해요.
Stop/문맥 변경은 이 브레이크 제어도 해제하고 기존 zero-duty 정지로 돌아가요.

로컬 Stop, 코드 실행, 그래프/소스/모드 변경, 주요 대화창 열기, 타임아웃과 pending 연결 끊김은
generation을 바꾸고 기존 명령을 폐기해요. Stop은 앱의 `_on_stop_pressed()`를 공유해요.
전체 물리 일시정지나 몸체 위치 덮어쓰기를 하지 않아요. 외부 CLI/MCP는 이 열린 데스크톱에만
접속하고 앱은 제공자 모델을 호출하지 않아요. 기존 코드 실행·저장·Stage 판정 도식의 책임은 유지해요.
계약과 검증은 [APP_CONTROL_API](APP_CONTROL_API.md), [ADR 0029](adr/0029-rendered-desktop-agent-camera-loop.md)예요.

외부 `run_goal.py`는 기존 Codex ChatGPT 로그인으로 요청 모델 Astra를 MCP에 직접 연결해요.
`observe(PNG) → decide(해시·공개 요약·유한 행동) → 실측 정지 → observe`를 한도 안에서 반복하고
마지막 재관측 뒤 Stop으로 끝내요. `DesktopGoalSession`이 episode/revision/generation을 고정하고
영상·행동·시간 한도를 검사하며 실행 오류/EOF는 닫힌 세션으로 끝내요. 실행기는 별도 읽기 전용
describe 연결로 사람 Stop을 감시해요. 감시 요청이 먼저 도착했을 때 작은 AI 요청 한 개를 최대5초
별도 대기시킨 뒤 일반 검증 경로에서 한 번 실행해요. 실행 중인 작업에는 busy로 응답하며,
대기 요청은 Stop 전용 통신 경로를 차지하지 않아요. Stop 뒤에는 이전 문맥 검사가 거절해요.
실행기·MCP 세션의 종료 정리는 같은 episode/revision/generation을 가진 제어권에만 Stop을 보내요.
앱이 이미 다른 문맥이면 새 실행을 그대로 두고 이전 제어권 해제를 확인해요. 첫 관측 요청 전에
문맥을 고정하며 아직 고정하지 않은 세션 종료는 앱을 중단하지 않아요. 수동 Stop은 전체 중단이에요.
이전 코드/저장/Stage 도식의 호출은 바뀌지 않았어요.

후속 로컬 초안에서는 명시적으로 켠 `run_operator.py`가 연결된 동안 AI 탭의 목표 Run 클릭을
`AgentGoalInbox`에 한 번 큐잉해요. 앱이 코드/수동 제어를 종료하고 새 카메라 episode를 만든 뒤
목표와 revision/generation을 고정해요. ready일 때 operator_poll이 한 번 claim하며 부모·실행기
사전 검사·첫 MCP 영상부터 같은 문맥을 검사해요. Stop→Enable 사이에 남은 목표가 새 실행으로
넘어가지 않아요. Stop/fault/문맥 변경은 즉시 큐를 지워요. 제공자 호출은 계속 외부 foreground이고
한 작업 뒤 종료해요. Web/Stage 도식과 프로젝트 저장에는 operator/목표/로그인을 넣지 않아요.

## 저장과 가져오기

```mermaid
sequenceDiagram
    participant User as 학습자
    participant Main as main.gd / ProjectPanel
    participant Blocks as BlockProgramPanel
    participant Store as ProjectStore
    participant Codec as MotionSnapshot
    participant Edit as AssemblyMode
    User->>Main: 저장 / 내보내기
    Main->>Blocks: 유효한 초안 반영
    Blocks-->>Main: source 또는 적용 거부
    alt 초안 적용 성공
        Main->>Store: document(title, graph, source)
        Store->>Codec: encode / decode로 구조 검증
        Codec-->>Store: 카탈로그·변환·포트 검증
        Store-->>Main: 유효 문서 또는 오류
        alt 유효 문서
            Main->>Store: 저장은 새 파일 / 내보내기는 JSON
        else 오류
            Main-->>User: 저장 거부 / 작업 유지
        end
    else 초안 충돌 / 거부
        Main-->>User: 초안 보존 / 수정 안내
    end
    User->>Main: 가져오기 / 저장본 열기
    Main->>Store: parse / load_project
    Store->>Codec: 교체 전 임시 그래프 검증
    Store-->>Main: 유효 문서 또는 거부
    alt 유효 문서
        Main->>User: 작업 교체 확인
        User->>Main: 교체 선택
        Main->>Edit: 편집 모드에서 그래프와 코드 복원
    else 손상 / 미지원 문서
        Main-->>User: 가져오기 거부 / 열린 작업 유지
    end
    Note over Main,Edit: 가져온 코드를 자동 실행하지 않음
```

각 화살표는 책임 간 논리 호출을 요약해요. 거부 경로에서는 이후 저장/교체 호출을 하지 않아요. 저장 중인 그래프는 편집 원본이며 현재 강체 위치가 아니에요.

## 화면 흐름과 스테이지 레벨

```mermaid
flowchart LR
    Title[타이틀] --> Select[스테이지 선택]
    Title --> Lab[자유 제작 작업실]
    Title --> Examples[예제 목록] --> Example[예제 작업실]
    Select --> Loading[로딩] --> Stage[레벨 + 작업실 stage 세션]
    Stage --> Play[장면 / 지금 할 일 / 접이식 도구]
    Play --> Result{관측 결과}
    Result -->|성공| Clear[기록 저장 / 다음·다시]
    Result -->|미달성| Retry[다시 하기 / 힌트]
    Clear -->|다음| Loading
```

[app.gd](../scenes/app.gd)는 타이틀 → 스테이지 선택 → 로딩 → 새 작업실을 연결해요.
스테이지 선택에는 목표 그림·난이도·배우는 것과 Lab 카드가 있어요. `stage`는 기존
[StageLevels](../src/core/stage_levels.gd)의 레벨 씬으로 기본 바닥을 바꿔요.
[StageHud](../src/ui/stage_hud.gd)는 중앙 진입 팝업 없이 목표·조립/배선/코드/실행 칩과
짧은 힌트, 접이식 부품·프로그램 버튼, 도움, 실행/재설정을 보여줘요.
[WorkshopGuide](../src/ui/workshop_guide.gd)가 그래프·실제 배선·코드/블록 유효성·실행 모드를
읽어 체크와 자동 패널 열림을 정해요. 사용자가 접은 패널은 단계가 바뀔 때까지 유지돼요.
[StageGoalDisplay](../src/ui/stage_goal_display.gd)는 장면에 목표 범위·조립 자세의 미리보기와
판정기 관측값/유지 시간을 표시해요. 결과는 기존 판정기에서만 와요.
도움 메뉴에서 예제·직접 팔 조립·설정·프로젝트·튜토리얼을 열어요. 예제 교체는 기존 확인 절차를
거치고 스테이지 목표는 유지해요. `lab`에도 같은 안내와 접이식 도구를 쓰며 출제는 남겨요.
`example`과 세션 없는 직접 `main.tscn` 진입은 기존 도구 구성을 유지해요.
웹 검사의 `?ssok_workshop=1` / `?ssok_verify=1` 직접 진입도 유지해요.
레벨 씬 생성/에디터 조정은 [ADR 0028](adr/0028-game-screen-flow-and-stage-levels.md),
바뀐 표시 계약은 [ADR 0030](adr/0030-scene-first-workshop-guidance.md)이에요.

## 깃발 임무

```mermaid
stateDiagram-v2
    [*] --> Intro
    Intro --> Assembly: 시작 / 예제 선택
    Assembly --> Wire: 팔 기계 연결 확인
    Wire --> Ready: 실제 전기 연결 확인
    Ready --> Running: 실행 시작
    Running --> Success: 실제 팔 끝의 목표 높이와 유지 시간 관측
    Running --> Ready: Stop
    Success --> Ready: 편집 복귀 / 재도전
```

이것은 대표 경로예요. 그래프를 관찰해 기계 연결이 없어지면 Assembly, 배선이 없어지면 Wire로 돌아가는 경로가 모든 관련 상태에 추가돼요. 실제 전이는 [FlagMission._build_chart](../src/ui/flag_mission.gd), 실제 판정은 `_observed_flag_raised()`를 확인해요. 정확한 높이·유지 조건은 [FLAG_MISSION](FLAG_MISSION.md)에 있어요. 깃발 완료가 학습 효과나 다른 로봇의 성공을 인증하지 않아요. 세션 작업실에서는 옛 깃발 패널을 숨기고 깃발 시각물(`show_visual`)은 깃발 스테이지에서만 켜요.

## Stage 판정과 공유

```mermaid
flowchart LR
    Task[Stage v2 / 환경 / 규칙] --> Preflight[인스턴스 대상과 부품 수 검사]
    Graph[편집 그래프와 코드] --> Preflight
    Preflight -->|유효| Run[배선 센서 준비 / 실행 문맥 fingerprint]
    Preflight -->|거부| Invalid[미달성 또는 판정 불가]
    Run --> Observe[실제 물리 관측 / 문맥 변경 검사]
    Observe --> Outcome[성공 / 미달성 / 중단 / 판정 불가]
    Outcome -->|성공| Proof[현재 실행 fingerprint 보존]
    Proof --> Verify[출제 상태 / 미적용 블록 / 문맥 재검사]
    Verify -->|유효| Export[JSON 내보내기 / Web 파일 다운로드]
    Export --> Import[가져올 때 구조 검사 / 성공 증거 초기화]
```

목표·그래프·코드·센서 조건 변경은 이전 성공 증거를 무효화해요. 편집 모드 복귀만으로 성공 증거를 지우지는 않아요. Stage의 센서는 학습 코드가 직접 읽지 않아도 그래프 배선에서 준비한 뒤 실행 문맥을 고정해요. 누락·중복·교체 대상, 센서/물리 오류는 판정 불가, 시간초과·프로그램 오류는 미달성, 사용자 중단은 cancelled예요. 종료한 시도의 늦은 결과는 적용하지 않아요. 범위 밖 초음파는 null 관측으로 계속 실행해요.

규칙은 선언형 수치이며 임의 판정 코드를 실행하지 않아요. 코드 종료 후에도 물리 목표 관측은 가장 긴 유지 시간 + 1.5초 동안 계속되고, 그때까지 목표에 닿지 않으면 `not_met`/`program_finished`로 끝나요(스테이지 세션, ADR 0028). 프로그램 오류/중단은 시도를 종료해요. 실패 이유와 복구 행동은 과제 패널과 공통 상태 표시줄에 나타나요. 서버 공유·계정·검증 서명은 미구현이에요. [계약 상세](STAGE_CONTRACTS.md)를 함께 읽어요.

## 소스와 확인할 검사

[main.gd](../scenes/main.gd), [MiniRuntime](../src/runtime/mini_runtime.gd), [RunMode](../src/runtime/run_mode.gd), [BlockProgramPanel](../src/ui/block_program_panel.gd), [ProjectPanel](../src/ui/project_panel.gd), [FlagMission](../src/ui/flag_mission.gd)가 근거예요. 검사는 [core_authoring](../tests/core_authoring_check.gd), [control_flow](../tests/control_flow_check.gd), [flag_mission](../tests/flag_mission_check.gd)를 작업 범위에 맞춰 실행해요. Stage 관련 검사는 `stage_contract_check`, `stage_authoring_check`, `stage_ui_check`, `sonar_stage_check`, 화면 흐름은 `game_flow_check`예요. 실제 통합 결과는 [증거](evidence/merge_2026-09-30/README.md)에 기록해요.

## 설정과 언어 전환

톱니바퀴 → 수동 입력 중립화·조립/카메라 입력 정지 → 설정 창 → 검증된 선호 변경 → 공유 Theme/기존 override 갱신 → 로컬 저장·결과 안내 → Esc/닫기 → 수동 입력 사용 가능 상태 복원·톱니바퀴 포커스 복귀예요. 실행 VM과 물리는 유지해요. 언어는 원문 키를 가진 기존 컨트롤을 다시 번역하며 블록 카드를 재생성하지 않아요. 화면 글자와 코드 글자 배율은 독립적이에요. [설정 계약](INTERFACE_PREFERENCES.md)과 ADR 0026을 함께 확인해요. 기존 실행·Stop·깃발 상태 전이는 그대로예요.
