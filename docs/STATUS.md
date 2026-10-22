# 현재 방향과 문서 기준

2026-10-22 작업 A-5 로컬 후보: 목표 문장 28px·회색 태그 14px·패널 제목 16px 굵게로 위계 교정. [현재 검사·GL 미검증·인계](WORK_SUMMARY_A5.md), [ADR 0034](adr/0034-correct-workshop-type-roles.md). A-4 공간/관측/콘 규칙과 [이력](WORK_SUMMARY_A4.md)은 유지해요.

2026-10-22 작업 A-3 로컬 후보: 작은 창 두 줄/60% 편집 패널·Run 라벨·글꼴 위계·도로 그림자 수신 보완. [소스·현재 검사·GL 미검증·인계](WORK_SUMMARY_A3.md), [ADR 0032](adr/0032-compact-workshop-presentation.md).

2026-10-22 작업 A-2 로컬 후보: 내용물 자동 프레이밍·UI 목표 라벨·두 줄 안내·다크 장면·매트 테두리. 기존10+신규483검사 PASS. 실제 GL·공유 위키 기록은 환경 제약으로 미완료. [소스·검증·다음 담당](WORK_SUMMARY_A2.md), [ADR 0031](adr/0031-workshop-presentation-corrections.md).

2026-10-11 사용자 최신버전 배포 승인: Fable 통합 Title·CLI 진단과 앱/Windows/Mac/operator 버전을 0.3.1로 맞춘 clean 소스를 최종 검증합니다. [현재 배포 범위·결과](evidence/public_release_2026-10-11/README.md). 아래 수치는 당시 소스 이력입니다.

2026-10-11 최종 로컬 검증: Title v4 독립Opus PASS·Astra 실제 패키지37PNG 검수, clean Linux/Web/Mac 빌드와 실제 실행 통과. Web16화면+설정14, native Linux4/Mac4언어, 같은MacPCK20검사 PASS/오류0. 별도 r40 CLI진단81검사·operator준비5PASS. r37정밀도 후보 NOT_ADOPTED; physical0/9·새계정·human merge·정확버전 공개 승인 미완료. [현재 결과·실패·다음 담당](evidence/agent_camera_2026-10-10/completion/title-mac-r39/FINAL.md).

2026-10-11 r40 로컬 진단 수집: CLI 최상위error/turn.failed와 종료 경합 때의 영수증 유실을 수정. 실제Python71회귀+문서10/realpipes PASS, 독립Fable PASS. 과거r37원인은 복구불가·provider재시도0·앱/목표불변. [검증·한계](evidence/agent_camera_2026-10-10/completion/cli-diagnostics-r40/README.md).

2026-10-11 r39 로컬 Title 보완: compact1152×648 로고·언어·설정이 모두 보이는 Opus작성 초안. Arch/Mac 기본32화면·확대28사례·Arch동적30검사 PASS/오류0, Astra26PNG/동일v4 bytes·독립Opus PASS. 원본r7패키지는 그대로, 신규빌드/통합/공개는 후속. [전후·실패·한계](evidence/agent_camera_2026-10-10/completion/title-mac-r39/README.md).

2026-10-11 r26: 영상 하단 정지 선호를 실제AI 1회 시험했으나38px/14.9168cm jointFAIL입니다. 앱 미적용, 기준 불변. [결과·한계](evidence/agent_camera_2026-10-10/completion/lower-end-policy-r26/README.md).

2026-10-11 r25: Mac SSH 연결을 확인했지만 공용 기기에는 비공개 코드를 보내지 않습니다. 최신 백업에 Arch 최종 원자료5폴더가 없고 현재 소스와도 다릅니다. [실측·회수 경로](evidence/agent_camera_2026-10-10/completion/host-raw-r25/README.md). [r24 공식 작업 인계](evidence/agent_camera_2026-10-10/completion/task-tool-r24/README.md)는 완료했습니다. 정밀도·계정·개인 Mac·Arch 원자료·통합 공개는 미완료입니다.
2026-10-11 실행 초안: 앱fa868ca/0.3.1-projects-r7·operator r14 준비/Run/재관측/Stop 검증. r6~r19 수치·실패·버전은 [현재 근거와 보존된 이력](evidence/agent_camera_2026-10-10/completion/README.md)에서 확인. 정밀도 AI영상9/9·물리0/9는 미해결.

2026-10-11 실제 Windows 배포본 카메라 r5: 기본 Title→프로젝트 가져오기→Lab AI Enable/Forward/Stop, 인증 관측·8틱행동·재관측·늦은요청 거부11/0·정상exit0. 앱/패키지 변경0, provider호출0. 실패3회·도구복구/Astra20영상과 한계는 [r5 근거](evidence/agent_camera_2026-10-10/completion/verified-r2/package-camera-r5/README.md). 실제 패키지 Run with AI/operator·Projects 문구/대비 Opus 검토·물리0/9/Mac/Arch/통합·공개 승인은 남음.

로컬 후속 갱신: 2026-10-10, Codex. 최신 카메라 안정화 초안은 아래 진행 작업에 있어요. 통합·배포의 다음 수치는 2026-09-30 이력이에요. 사용자 지시로 설치형 PR40과 설정 PR41을 병합하고 clean 앱 소스 `af1973b`의 v0.2.0을 공개했어요. [웹 실행](https://bum-boo.github.io/ssok/) · [당시 다운로드](https://github.com/Bum-Boo/ssok/releases/tag/v0.2.0) · [배포 기록](evidence/public_release_2026-09-30/README.md). 저장소도 공개예요. native71/0·Windows17/0·같은 파일의 Web5종 최종통과·공개 작성9/설정14와 실제 다운로드 해시를 확인했어요. 첫 실패와 재실행 범위는 배포 기록에서 구분해요. 이전6브랜치 [통합 기록](evidence/merge_2026-09-30/README.md)은 당시 결과로 보존해요.

## 제품 결정과 구현 상태

| 항목 | 사용자 결정 | 통합 소스의 상태 |
|---|---|---|
| 목적 | 디지털 과학상자처럼 직접 만들고 과제를 풀며 학습 경험·HCI 연구로 연결 | 조립, 배선, 코드/블록, 물리 실행, 로컬 저장 구현 |
| 첫 경험 | 전 연령, 첫 5분은 초등 고학년 기준, 블록 먼저 | 실제 관측 기반 깃발 임무. 화면·블록 표현과 재도전 경험은 개선 필요 |
| 보드 | micro:bit 먼저, Uno 두 번째 | 그래프의 보드에서 profile 선택. micro:bit의 ms와 generic/Uno의 초 단위 구분 |
| 제품 구조 | 튜토리얼 → Stage/Lab → 후속 과제 공유 | 타이틀·스테이지 선택·로딩·미션·결과 화면과 레벨 씬 3개(#43, 검토 전 브랜치). 자유 제작·과제 출제, JSON 가져오기/실제 다운로드. 커뮤니티 서버 미구현 |
| 언어와 센서 | 변수·조건·반복·모터·실제 센서로 확장 | 제한 AST/bytecode VM, DC 모터/드라이버, HC-SR04 관측과 블록 구현 |
| 판정 | 실제 결과와 예외를 구분 | 인스턴스 대상, 실행 문맥에 묶인 성공 증거, 성공/미달성/중단/판정 불가. Stage v2, v1 읽기 호환 |
| 부품과 커스텀 | 자기 로봇으로 여러 해법 탐색 | 카탈로그 75종. 구조·행동·과제 커스텀 가능, 색칠·데칼·작품 전시함은 미구현 |
| 보행 연구 | 이족·Kit 추가 실험 보류, 기존 결과는 전시용 | 기존 구현·결과 보존. 범용 지속 보행 보장 없음 |
| 출시 | 먼저 시각·게임성·초심자 흐름 보완 | 사용자 명시 요청으로 v0.2.0 공개 완료. 검증본 gh-pages/Release 게시·익명 URL/실제 흐름 확인. 일반 main push는 앱 배포 아님 |

## 진행 작업과 근거

2026-10-11 관측 제동 전환 r4: stock/생략 prototype 둘 다3px변동·combined실패. 앱 적용 근거부족, 소스변경0.
[단일변수 실험·한계·인계](evidence/agent_camera_2026-10-10/completion/verified-r2/observation-continuity-r4/README.md).

2026-10-11 물리/영상 경계 진단 r3:30/10/12 여백26px·거리14.0431cm 실패를 반복했고,
1틱 추가는22px·13.7652cm로 영상 미달. 재관측22↔24px/0.655mm 변동을 확인했어요.
조건의 좁은 경계와 자세 변화는 관측했지만 불가능성·원인·물리 개선을 확정하지 않았어요.
앱/목표/물리/패키지 변경0, 기존AI 이미지9/9·물리0/9 유지.
[진단·실패·한계·인계](evidence/agent_camera_2026-10-10/completion/verified-r2/physical-compatibility-r3/README.md).

2026-10-11 Windows 안정화 검토 초안 r2: 고정 카메라 이미지9/9·독립 물리0/9(14cm 기준 유지).
Windows full81/0·실제POSIX3/0, clean4exports/6hashes, 같은Web5/5·실제설치17/0을 통과했어요.
패키지 소스f31f8d5/version0.3.1-camera-r2;426입력 동일. 최종 문서 후속과 앱 패키지를 구분해요.
Settings 잘림은 Opus 속성2개 수정/독립리뷰, Astra16화면·80설정·16키보드·실시간4언어 검증 통과.
최종 패키지10화면 Astra 검수와 최신Fable 기능리뷰/실제fetch·rebase(up-to-date4eb059f)도 통과했어요.
첫81/5·Web4/5·dirty export·설치 집계 실패는 보존했고 통합/공개하지 않았어요. 물리0/9·Mac실기기·
Arch원자료/taskCLI release·human merge/정확한 버전 공개 승인은 남았어요.
[검증·버전·미완료·인계](evidence/agent_camera_2026-10-10/completion/verified-r2/README.md). 아래는 이전 소스 이력이에요.

2026-10-10 `feat/32-robot-camera-loop`의 **로컬 초안**: graph 차량의640×480 카메라,
유한 행동·실측 정지·재관측, 외부 CLI/MCP와 Claude 작성 패널, 목표 Run→명시적으로 켠
foreground operator→기존 ChatGPT login AI 도구 실행을 구현했어요. 앱 자체 제공자 로그인은 없어요.
최신 후속은 monitor-first TCP 경합과 이전 actor의 종료 Stop이 새 실행을 끊던 오류를 수정했어요.
Windows Godot4.7.2/GL에서 Python56/0(SDK skip0), 렌더 카메라29/0, 목표 UI66/0,
문맥 Stop13/0, 통신4경로/Stop22ms, import/load와 기존 control/manual 검사를 통과했어요.
실제 앱 Run 시험도1행동/2PNG·재관측/Stop·CLIexit0을 확인했어요.

실험은 버전별로 구분해요. 초기 통신 수정 Arch: 구체화9/9 물리 기준 통과, 원래 목표0/3;
최신 문맥 Stop Windows: 구체화3/3 물리 기준 통과지만 Astra 실제 이미지 목표 검수는 **1/3**예요.
이전 원래0/9·frozen0/3·blank0/3과 구체화2/3 결과를 보존했어요. 범용 주행 신뢰성은 미확보예요.
Claude Fable5-1의 최신 기능 소스 리뷰 pass; 변경 없는 패널 SHA f8afbc47…54da5에는
기존 Opus 최종 디자인 리뷰를 유지해요. CLI는 backend identity/빈 입력 문맥/과금 상한을 증명하지 않아요.
[안정화·소스·실패·검증](evidence/agent_camera_2026-10-10/stabilization/README.md) ·
[목표 UI 이력](evidence/agent_camera_2026-10-10/goal_ui/README.md) ·
[이전 반복 실험](evidence/agent_camera_2026-10-10/repeated/README.md).

Arch 최신 원자료 일부 회수는 미완료예요. 기존 task는 Windows/WSL 원본 CLI로 재개·checkpoint했으며 최종 release는 현재 인계 영수증으로 확인해요.
Windows 개발·검증 근거와 다음 절차는 [Claude 인계](../CLAUDE-REVIEW.md)에 있어요.
다음은 최종 인계 commit의 Fable rebase, human merge와 해당 버전/범위 공개 승인,
이미지 목표 정밀도예요. 현재 main 통합·공개 배포·카탈로그 카메라·범용 로봇/학습은 미완료예요.

- [출시 전 화면·부품·커스텀 점검](PRELAUNCH_UX_AUDIT_2026-09-30.md)은 실제 `90b9930` 화면 5장과 부품 목록을 포함해요. 신규 시각안·꾸미기·챕터 진행은 제안이에요.
- 설정 PR41과 설치형 PR40은 사용자 지시로 병합했어요. 같은 최종 소스의 네 대상 빌드와 실제 검증은 배포 기록을 확인해요.
- [Stage 계약](STAGE_CONTRACTS.md), [학습 구현](LEARNING_STAGES.md), [구조 결정](adr/INDEX.md), [데이터 관계](DATA_MODEL.md), [실행 흐름](FLOWS.md)이 현재 계약의 시작점이에요.
- [제품 경험 조사](PRODUCT_EXPERIENCE.md)와 [자연어 작업 요구](NATURAL_LANGUAGE_TASKS.md)는 날짜 있는 조사·요구 기록이에요. 책꽂기 명령창과 범용 실행기가 구현됐다는 뜻은 아니에요.
- [핵심 작성 검증](evidence/core_authoring_2026-09-30/README.md), [깃발 증거](evidence/flag_mission_2026-09-30/README.md), [문서 도구 기록](evidence/contributor_context_2026-09-30/README.md)은 각 소스의 과거 결과예요. 최신 결과와 구분해요.

문서 정본과 갱신 책임은 [MAINTENANCE](MAINTENANCE.md)에 있어요. 대상 사용자 관찰·학습 효과와 범용 보행 보장은 주장하지 않아요. 다음은 첫5분 사용자 관찰과 시각·블록·재도전 경험 개선이에요. 배포 기록은 실제 URL과 소스별 검증을 보존해요.

## 화면 흐름과 스테이지 레벨 — issue #43

사용자 관찰(2026-09-30): 켜면 무엇을 할지 모르겠고, 화면이 하나뿐이라 스테이지가 게임처럼 불러와지지 않았어요. `feat/43-game-flow-levels`에서 타이틀 → 스테이지 선택 → 로딩 → 미션 소개 → 실행 → 결과 흐름과 깃발·결승선·벽 앞 정지 레벨 씬을 만들었어요. 모드마다 보이는 도구를 나눴고 #42는 사용자 지시로 중단했어요. 스테이지 화면은 위·아래 메뉴 줄과 편집 도구를 숨기고 왼쪽 위 목표 카드와 오른쪽 프로그램만 보여줘요(사용자 요청: 필요한 것만). 깃발 스테이지는 팔을 눕혀서 시작해요(원래 조립 자세는 0도에서 이미 목표 높이라 아무것도 안 해도 성공처럼 보였어요). 결정은 [ADR 0028](adr/0028-game-screen-flow-and-stage-levels.md), 흐름은 [FLOWS](FLOWS.md#화면-흐름과-스테이지-레벨)예요. 남은 일: 문장형 블록, 스테이지 카드 미리보기, 나머지 12개 스테이지, Stage 판정의 매 프레임 문맥 계산 비용(약 19ms) 줄이기.

## 설정 구현 — issue #38, 병합 PR41

`feat/38-interface-preferences`에서 시스템/밝게/어둡게, 독립 화면/코드 글자 크기, 효과음 선호를 구현했어요. 언어 전환 시 블록 원문과 포커스를 유지하고 작은 창의 안내 겹침을 수정했어요. 계약은 [INTERFACE_PREFERENCES](INTERFACE_PREFERENCES.md), 결과는 [구현 증거](evidence/settings_implementation_2026-09-30/README.md)예요. PR41로 main에 통합됐으며 최종 배포 검증은 배포 기록과 구분해요.
