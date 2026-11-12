# 카메라 루프 통신·중단 안정화 — 2026-10-10

사용자 요청: 기존 로컬 초안을 안정화하고, Arch 컴퓨터를 끈 뒤 Windows에서 계속 개발한다.
작업: issue32, 기존 task `ssok/robot-camera-loop-20261010`, Codex session
`ssok-stabilize-20261010-1`. Windows checkout `C:/Users/Hojun/Projects/ssok-ai-loop`,
branch `feat/32-robot-camera-loop`, HEAD `4eb059f6432bebbbc8db94896cac56cbb8bb2927`와 기존 WIP를 보존했다.
커밋·push·main 통합·공개 배포는 수행하지 않았다.

## 수정과 재현

- 감시용 describe 연결이 먼저 TCP 주 통신 경로를 차지하면 실제 actor 요청이
  `priority_tool_required`로 거절됐다. [실패 재현](race-before/result.json)을 보존했다.
  인증된 작은 actor 요청 한 개를 4096bytes/최대5초 대기시킨 뒤 기존 검증으로 한 번 실행한다.
  대기 요청이 Stop 경로를 점유하지 않으며, Stop은 generation을 바꿔 이전 요청을 거절한다.
  실제 pending 작업은 추가 actor 요청에 busy로 응답한다. 미실행 요청의 만료/연결 끊김은 제어권을 취소하지 않는다.
- 이전 actor의 종료 정리가 새 실행까지 중단하던 오류를 실제 앱에서13검사/7실패로 재현했다.
  종료 Stop을 episode/revision/generation에 묶고 양쪽 통신 경로에서 원자적으로 검사한다.
  문맥 불일치는 현재 상태와 이전 제어권 해제를 반환하며 새 실행을 취소하지 않는다.
  잘못된 문맥은 거절하며 전체 Stop으로 바꾸지 않는다. 첫 observe 요청 전 문맥을 고정하고,
  미고정 세션/로그인 실패는 앱 Stop을 보내지 않는다. 로컬 Stop과 명시적 무문맥 Stop은 전체 중단이다.
  `owner_revocation_confirmed`와 현재 앱 상태가 stopped인지 확인하는 `stop_confirmed`를 구분한다.
  이 응답 상태만으로 물리 속도0을 인증하지 않으며 실제 정착은 camera loop/독립 평가자가 따로 측정한다.

변경: `agent_desktop_bridge.gd`, external `desktop_client/session`, `run_goal/run_operator`,
관련 Python 회귀와 `bridge_stop_owner_check.gd`, monitor-first 재현 도구 및 bounded 실험 도구.
Windows 검증 도구는 APPDATA/LOCALAPPDATA를 각 실험 폴더로 격리한다.
물리·카메라·목표·평가 기준·UI·번역·제공자 설정은 바꾸지 않았다.

현재31코드 입력: [source-stability-current.json](../source-stability-current.json).
기존28입력/이전 실패 기록은 보존했다. 초기 통신 수정 bridge `b15b9dc3…ba763`와
최종 문맥 Stop bridge `18dff9d7…0bc7d`의 실험을 합쳐 현재 버전의 성공률로 표시하지 않는다.

## 실제 Windows 런타임

공식 Godot4.7.2 portable/GL Compatibility, NVIDIA RTX4060, Python3.13 project venv/MCP2.2.0.
엔진 zip SHA-256 `731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953`를
공식 [릴리스 자산](https://github.com/godotengine/godot/releases/tag/4.7.2-stable)의 digest와 비교했다.
`build/toolchain-windows/install.json`에 설치 근거를 남겼다. PATH/사용자 전역 설정은 변경하지 않았다.
portable 엔진과 venv는 빌드 산출물이므로 소스 패키지에 포함하지 않는다.

| 검사 | 현재 결과 | 근거 |
|---|---|---|
| monitor-first receipt/action/reobserve/queuedStop | 4경로 통과, priorityStop 약22ms, 이전 요청 stale_dispatch | [결과](windows-race-current/result.json) |
| 이전 제어권의 Stop/새 제어권 보호 | 13/0 | [결과](windows-owner-stop-current/result.json) |
| Python protocol/session/evaluator | 56/0, SDK skip0 | [로그](windows-checks-r2/python.log) |
| 렌더 카메라 | 29/0 | [로그](windows-checks/camera.log) |
| 목표 UI | 66/0, 24언어/테마/크기 조합의 keyboard Run/Stop 검사 | [로그](windows-checks-r2/goal-ui.log) |
| 기존 control-flow/manual | 0실패 | [control](windows-checks-r2/control-flow.log), [manual](windows-checks-r2/manual-control.log) |
| headless import/scene-load | exit0, SCRIPT ERROR 없음 | [import](windows-import/godot.log), [load](windows-checks/scene-load.log) |
| 실제 앱 Run 신호→외부 operator→AI MCP | 1행동/2PNG, 재관측/실제Stop, CLIexit0, 원문 목표 보존 | [결과](windows-operator-current/actor/result.json) |

검사 실행 argv·시간·로그 SHA·31입력 변경 없음은 [r1 receipt](windows-checks/result.json)와
[r2 receipt](windows-checks-r2/result.json)에 있다. r1 검사 도구가 잘못된 출력 문자열을 기대하고
`--screenshots`를 빠뜨려 중단했다. 앱의 기본 UI18/0은 통과했으며 앱 실패로 취급하지 않는다.
수정된 도구로 UI matrix/남은 검사를 실행했다. 새 UI 이미지48장은 격리 user-data에 있으며
이번에는 기능 검사만 수행했다. 전체48장 시각 검수를 주장하지 않는다.
새 full release suite, Web export 및 Windows/macOS 설치 패키지 검사는 미실행이다.

## 고정 목표의 별도 반복 실험

모델은 같은 원문 목표,640×480 로봇 PNG, 허용한 frame 정보·공개 요약·도구 결과만 받는다.
장면 거리·graph·소스·독립 물리 평가를 전달하지 않는다. 구체화 목표는 기존 계획의 원문/SHA를
고정했으며 기준은 travel≥3cm, gap4–14cm, 접촉 없음, 측정된 정지12틱과 최종 재관측/Stop이다.
각 실행8행동/9영상/180초, 계획한 CLI 실행만 수행하고 실패를 대체하는 자동 재시도는 없다.

| 소스/호스트/조건 | 물리 기준 결과 | 최종 gap | 통신 오류 |
|---|---|---|---|
| 초기 통신 수정/Arch/구체화 3배치×3회 | 9/9 | 12.552–13.855cm | 0 |
| 같은 소스/Arch/원래 모호한 목표 3배치×1회 | 0/3, gap에서 실패 | 15.035–18.640cm | 0 |
| 최종 문맥 Stop/Windows/구체화 3배치×1회 | 3/3 | 12.443–13.905cm | 0 |

[Arch9회](clarified-live/summary.json), [Arch원래3회](original-live/summary.json),
[Windows계획](windows-clarified-live/plan.json)과 [결과](windows-clarified-live/results.json)를 보존했다.
원래 목표의 이전0/9, frozen0/3(한 번의 관측 오류), blank0/3와 초기 calibration 실패는
[이전 연구](../repeated/README.md)에 그대로 있다. 이번 구체화 조건의 새로운 blind 대조는 미실행이다.
이는 소수 배치의 별도 탐색 결과이며 카메라의 인과적 기여·범용 주행 신뢰성·학습 효과를 인증하지 않는다.

물리 기준 통과는 이미지 목표 달성과 다르다. 독립 Astra가 Windows 최종3PNG를 원본 해상도로
직접 보았다. 요청한 중심 바닥띠24–38pixels에 실제 추정값33±2만 들어가고,19±2/20±2는 미달이다.
따라서 최신 Windows는 **물리3/3, 시각 목표1/3**이다.
[5PNG 실제 검수](astra-windows-camera-inspection.json)에는 operator 전후2장도 포함한다.
영상만으로 물리 거리·접촉·정지를 인증하지 않는다. Arch9회 중 마지막3장만 별도로 직접 검수했으며
[해당 범위와 경계 오차](astra-clarified-final-inspection.json)를 보존했다.

Windows Codex CLI0.159.0-alpha.9/기존 ChatGPT login으로 `gpt-6-astra`를 요청했다.
CLI JSON은 backend identity를 증명하지 않으며 `features.skills` 무시 경고를 남겼다.
실제 호출은 observe/decide/stop뿐이지만 모델의 전체 문맥이 비어 있다고 주장하지 않는다.
도구/시간/CLI 실행 한도는 모델 요청 횟수나 과금 상한이 아니다. 로그인·모델 fallback·전역 설정은 변경하지 않았다.

## 독립 리뷰와 문서

실제 Claude Fable5-1의 [초기 통신 소스 리뷰](fable-source-review.json)와
[최종8파일 문맥 Stop 리뷰](fable-owner-source-review.json)는 pass/차단 의견0이다.
소스 읽기 리뷰이며 Claude의 실제 앱/이미지 검증은 아니다. 공급한 버전·미검토 파일·queue 만료와
상태 표현의 한계는 JSON에 그대로 있다. Windows user-data 격리 도구 수정은 최종8파일 밖이다.
Claude 작성 panel SHA `f8afbc47a236e33d7f0f919bfc2b0693e80628af7c863b91450db57c11d54da5`는 그대로다.
기존 Opus 디자인 리뷰는 그 패널에 유지하며 새 시각 변경이나 공개 승인으로 확대하지 않는다.

API/FLOWS/CONTROLS/STATUS/제안ADR0029/context와 generated map을 갱신한다.
저장 graph/VM/Stage의 책임·호출이 같으므로 해당 DATA_MODEL/도식은 유지한다.
변경된 agent 경로는 FLOWS의 설명과 실제 코드로 검토한다. 새 exported UI 문구가 없어 번역 변경은 없다.

## 인계와 꺼진 Arch 호스트의 복구

다음 담당은 최신 Claude Fable의 실제 브랜치 통합, 이후 human merge다.
미커밋 WIP와 기존 소스/실패 근거를 보존한다. 시각 목표 정밀도, 설치형 로그인/operator,
카탈로그 카메라·범용 로봇, release 검증과 검토 버전/범위의 사용자 공개 승인은 남았다.

Arch의 최종 scopedStop13/0·race4경로·Python56/0·구체화3/3은 실제 stdout에서 관측했지만
최종3회 PNG/journal/evaluation 원자료는 아직 회수하지 못했다.
[관측 범위와 정확한 회수 경로](arch-uncollected-observations.json)를 읽고,
호스트가 켜진 뒤 `/home/bumboo/Projects/ssok-ai-loop/build/ai-loop-evidence/stabilization/`
아래 `owner-stop-before`, `owner-stop-after`, `race-current`, `clarified-current-live`, `operator-current`를
확인한다. 마지막 operator는 완료를 관측하지 못했다. 기존 output을 덮어쓰거나 자동 재실행하지 않는다.
요약/입력 해시를 확인한 완료 결과만 공개 JSON/PNG/log로 회수하고 user-data/config는 제외한다.

기존 task는 revision16/active/동일 Codex session이며 Windows에 agent-task CLI가 없다.
생성된 state/Handoff를 수동으로 변경하지 않았다. **CLI checkpoint/release는 미완료**다.
호스트 복구 후 기존 CLI의 `show ssok robot-camera-loop-20261010` 및 `release --help`로
실제 소유자/lease/현재 문법을 확인한 뒤 이 기록·현재31입력·ready branch를 인계하여 release한다.
다른 live owner를 강제 취득하지 않는다. 전원이 꺼진 상태에서 Arch parity·main 상태를 새로 검증했다고 주장하지 않는다.

선택 복구 before 사본/manifest와 검증은
`C:/Users/Hojun/.agents/backups/ssok-stabilization-20261010`에 있다.
기록된 post SHA와 같은 영향 파일만 해당 before 사본으로 복구하고, 달라지면 이후 변경을 병합한다.
공유 Work Log/상태는 `ssok-stabilization-20261010` 표시만 선택 병합한다.
진입점: [START_HERE](../../../START_HERE.md), [통합 인계](../../../../CLAUDE-REVIEW.md).
