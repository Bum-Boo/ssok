# 현재 방향과 문서 기준

2026-10-11 r18: 실제bridge관측/scopedStop3회, K32 26px/14.0598cm·후보22px/14.0055cm·단일관측22px/13.9617cm 모두동시FAIL·미적용. [17PNG·Astra6·시작실패2/복구](evidence/agent_camera_2026-10-10/completion/observation-stop-r18/README.md). Source/goal불변. 정밀도·계정/Mac/Arch/통합·공개남음.
2026-10-11 r17: 자세기준시점3정책+고정rate16 조합 모두동시FAIL·미적용. Brake26px/14.0711cm, 조합23px/13.9225cm. [32PNG·Astra8·원본](evidence/agent_camera_2026-10-10/completion/attitude-latch-r17/README.md). Source426+7/ZIP/app/goal불변. 다음camera-only 관측/실제Stop. 정밀도·계정/Mac/Arch/통합·공개남음.
2026-10-11 r16: 자세32+회전16은24px/14.0128cm로 거리0.128mm미달; 고정18추가는22px/13.9864cm로 영상미달. 모두동시FAIL/미적용. [24PNG·Astra6·원본](evidence/agent_camera_2026-10-10/completion/attitude-rate-r16/README.md). Source426+operator7/ZIP/app/goal 불변. 정밀도0/9·계정/Mac/Arch/통합·공개 남음.
2026-10-11 r15: 자세계수32·64도 원래영상/물리 동시FAIL·미적용. Stock23px/14.1063cm,32는26px/14.1128cm,64는23px/14.1117cm; span4/3/4px. [24PNG·Astra6·원본](evidence/agent_camera_2026-10-10/completion/attitude-gain-r15/README.md). Source426+operator7/ZIP/app/goal 불변. 정밀도0/9·계정/Mac/Arch/통합·공개 남음.
2026-10-11 r14: operator 전용환경/준비점검·자동Python 선택 후 실제Run→3틱1행동/2PNG·재관측/Stop12/0. Python66/0·guard7/0·Astra10; 원래MCP/notice실패 보존. [10PNG·원본·한계](evidence/agent_camera_2026-10-10/completion/operator-setup-r14/README.md). 앱fa868ca/goal 불변. 새계정·정밀도0/9·Mac/Arch/통합·공개 남음.
2026-10-11 r13: 동일30/10/12 stock23px/14.1063cm·자세보정24px/14.0799cm 둘 다동시FAIL·4px변동/앱미적용. 원래compile/90s timeout과복구 보존. [16PNG·Astra4·원본·제안](evidence/agent_camera_2026-10-10/completion/attitude-hold-r13/README.md). Source426/동결goal/기준 불변, 별도12–20px안 미채택·미실행. 물리0/9·Mac/Arch/통합·공개 미완료.
2026-10-11 r12: 별도operator ZIP/Git-free 한글·공백 경로에서 실제Run→3틱1행동/2PNG·재관측·Stop/정상종료12/0·52.909s. 원래Git실패/Stop 보존, Python63/0·archive4/0·Astra10. [원본18PNG·버전·한계](evidence/agent_camera_2026-10-10/completion/operator-archive-r12/README.md). 앱fa868ca 불변/도구별도version; Python/MCP/Codex/login 외부. 물리0/9·Mac/Arch·humanmerge/공개 미완료.
2026-10-11 r11: 같은30/10/12 actualstock/world-wheel·K16reference/joint-integral 네진단 모두동시목표FAIL. 거리13.8458~14.1212cm/마지막영상20~25px, 차체각속도감소불명확; 두후보 앱미적용. [32PNG·Astra8·원본·한계](evidence/agent_camera_2026-10-10/completion/world-wheel-hold-r11/README.md). 앱/goal/평가기준 불변, 기존AI영상9/9·물리0/9·미공개 유지. 아래는 이전이력.
2026-10-11 r10: 현재 fa868ca/0.3.1-projects-r7 실제WindowsPE/PCK defaultUI의 Run→외부operator/기존login/요청Astra→3틱1행동/2실제PNG·재관측/Stop·정상종료12/0·54.463s. Astra10실제영상, goal필드꼬리/trace스크롤 한계 보존. [같은버전·원본·한계](evidence/agent_camera_2026-10-10/completion/current-package-goal-r10/README.md). 앱수정0/단일smoke·범용성/벽정밀도 증명아님. 물리0/9·Mac/Arch·humanmerge/공개승인 남음. 아래는 이전실험/패키지 이력.

2026-10-11 r9: 원래30/10/12·같은계측 stock/K16 모터제동2회. 거리14.1063→13.8506cm로 물리 통과지만 마지막영상23→21px로 여전히실패, 각속도 감소 불명확·앱 적용0. 모터callback30/10/12 일치, 계측기 초기영상 집계/후처리 오류 복구·실패보존. [원본16PNG/Astra6·한계·다음](evidence/agent_camera_2026-10-10/completion/angular-feedback-r9/README.md). 기존AI영상9/9·물리0/9/미공개 유지. 아래는 이전 진단/패키지 이력.

2026-10-11 r8: 동일426소스/동결목표로 combined 실패2회 재현, 직접 replay도4px흔들림. 엄격 각속도/P24는 정지시간 초과, P4도combined실패라 앱 적용0. 실제 motor callback30/10/12/1은 명령과 일치. 마지막 구간13틱의 deterministic3회는 물리3/3·영상0/3·AI아님. [원본91PNG/14진단·한계·다음](evidence/agent_camera_2026-10-10/completion/control-feedback-r8/README.md). 기존 AI영상9/9·물리0/9/미공개 유지. 아래 r7은 패키지 검증 이력.

2026-10-11 r7: Opus검토 UI의 clean 소스fa868ca/0.3.1-projects-r7로4플랫폼·6해시 확인. Native 최초81/2는 UTF8 한정2/0 복구해79+2개 해결; 같은 Web5/5·설치 단독17/0·실제 패키지 Projects6/0/재내보내기 일치·Astra17화면 확인. 첫 클립보드 오류/설치10/1·실패 진단은 보존, 원인 미확정. [현재 버전·원본 결과·인계](evidence/agent_camera_2026-10-10/completion/release-current-ui-r7/README.md). 물리0/9·Mac실기기·Arch정식인계·humanmerge/공개승인 미완료. 아래는 이전 소스/검증 이력.

2026-10-11 r6: 실제 r2 배포본 Run with AI→외부 operator→3틱1행동/2PNG/재관측·Stop12/0. Projects는 Opus 작성/수정·독립PASS, Astra32+4실제화면, native80경우1181/0·실제키25/0·Web작성9/0/설정14/0·Linux 초안 통과. 앱 변경은 ProjectPanel, CI좌표fixture도 복구; r2와 다른 미배포 로컬 초안. [결과·실패·인계](evidence/agent_camera_2026-10-10/completion/package-goal-ui-r6/README.md). 물리0/9·새clean배포본·Mac·Arch정식인계·humanmerge/공개승인은 남음.

2026-10-11 실제 Windows 배포본 카메라 r5: 기본 Title→프로젝트 가져오기→Lab AI Enable/Forward/Stop, 인증 관측·8틱행동·재관측·늦은요청 거부11/0·정상exit0. 앱/패키지 변경0, provider호출0. 실패3회·도구복구/Astra20영상과 한계는 [r5 근거](evidence/agent_camera_2026-10-10/completion/verified-r2/package-camera-r5/README.md). 실제 패키지 Run with AI/operator·Projects 문구/대비 Opus 검토·물리0/9/Mac/Arch/통합·공개 승인은 남음.

로컬 후속 갱신: 2026-10-10, Codex. 최신 카메라 안정화 초안은 아래 진행 작업에 있어요.
통합·배포의 다음 수치는 2026-09-30 이력이에요. 사용자 지시로 설치형 PR40과 설정 PR41을 병합하고 clean 앱 소스 `af1973b`의 v0.2.0을 공개했어요. [웹 실행](https://bum-boo.github.io/ssok/) · [당시 다운로드](https://github.com/Bum-Boo/ssok/releases/tag/v0.2.0) · [배포 기록](evidence/public_release_2026-09-30/README.md). 저장소도 공개예요. native71/0·Windows17/0·같은 파일의 Web5종 최종통과·공개 작성9/설정14와 실제 다운로드 해시를 확인했어요. 첫 실패와 재실행 범위는 배포 기록에서 구분해요. 이전6브랜치 [통합 기록](evidence/merge_2026-09-30/README.md)은 당시 결과로 보존해요.

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

Arch 전원이 꺼져 최신 원자료 일부 회수와 기존 task revision16의 CLI release는 미완료예요.
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
