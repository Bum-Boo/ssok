# 실행과 저장 흐름

실선으로 표현한 아래 세 도식은 [STATUS](STATUS.md)의 기준 코드예요. 마지막 도식은 후속 설계이며 현재 앱의 전체 상태 머신으로 사용하지 않아요.

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
    Build --> Validate[MiniRuntime.run: 전체 배선까지 검사]
    Validate -->|오류| Error[failed 신호 / 모터 명령 미전송]
    Validate -->|통과| Execute[서보 명령과 비동기 sleep]
    Execute --> Complete[finished 신호]
    Execute --> Stop[사용자 Stop / 모드·제어권 변경]
    Stop --> Invalidate[execution_id 증가 / 늦은 sleep 무효화]
```

`scenes/main.gd`가 실행 버튼과 제어권을 조정하고 `MiniRuntime`이 명령을 해석해요. 코드 종료와 임무 성공은 다른 사건이에요. 현재 Stop은 명령을 중단하고 서보의 마지막 목표를 유지해요. 물리 정지나 초기 자세 복원으로 해석하지 않아요. 편집 모드 복귀는 `RunMode.teardown()` 뒤 원본 그래프를 다시 보여줘요.

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

## 깃발 임무

```mermaid
stateDiagram-v2
    [*] --> Intro
    Intro --> Assembly: 시작 / 예제 선택
    Assembly --> Wire: 팔 기계 연결 확인
    Wire --> Ready: 실제 전기 연결 확인
    Ready --> Running: 실행 시작
    Running --> Success: 실제 팔 끝의 하강과 복귀 유지 관측
    Running --> Ready: Stop
    Success --> Ready: 편집 복귀 / 재도전
```

이것은 대표 경로예요. 그래프를 관찰해 기계 연결이 없어지면 Assembly, 배선이 없어지면 Wire로 돌아가는 경로가 모든 관련 상태에 추가돼요. 실제 전이는 [FlagMission._build_chart](../src/ui/flag_mission.gd), 실제 판정은 `_observed_flag_raised()`를 확인해요. 정확한 높이·유지 조건은 [FLAG_MISSION](FLAG_MISSION.md)에 있어요. 깃발 완료가 학습 효과나 다른 로봇의 성공을 인증하지 않아요.

## 후속 Stage와 공유 설계

```mermaid
flowchart LR
    Task[과제 버전 / 환경 / 목표] -.-> Preflight[대상과 제약 검사]
    Graph[편집 그래프와 코드] -.-> Preflight
    Preflight -.-> Run[실행 스냅샷 / 단일 제어권]
    Run -.-> Observe[실제 관측]
    Observe -.-> Outcome[성공 / 미달성 / 중단 / 판정 불가]
    Outcome -.-> Evidence[과제와 실행 버전에 연결한 증거]
    Evidence -.-> Verify[공유 시 기준 환경 재검증]
```

점선은 추가할 계약이에요. `issues-31-36` 작업의 부분 구현은 통합 후 다시 대조해요. 대상 객체 ID, 환경과 로봇의 경계, 실행 중 변경 방지, 취소 뒤 늦은 응답, 시스템 오류의 판정 제외를 명세해야 해요. 과제/환경 변경으로 기존 성공 인증이 유효한지 결정하고 저장 버전 이행과 함께 기록해요.

## 소스와 확인할 검사

[main.gd](../scenes/main.gd), [MiniRuntime](../src/runtime/mini_runtime.gd), [RunMode](../src/runtime/run_mode.gd), [BlockProgramPanel](../src/ui/block_program_panel.gd), [ProjectPanel](../src/ui/project_panel.gd), [FlagMission](../src/ui/flag_mission.gd)가 근거예요. 검사는 [core_authoring](../tests/core_authoring_check.gd), [control_flow](../tests/control_flow_check.gd), [flag_mission](../tests/flag_mission_check.gd)를 작업 범위에 맞춰 실행해요. 이 문서 작성으로 앱 검사를 새로 통과한 것은 아니에요.
