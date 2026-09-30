# 개발 참여 시작점

이 문서는 새 개발자와 AI 세션의 공통 입구예요. 이력 전체를 읽지 않고 작업 범위에 맞는 문서와 코드로 이동해요.

## 처음 읽는 순서

1. [AGENTS](../AGENTS.md)의 공통 규칙을 읽어요.
2. [STATUS](STATUS.md)에서 문서 기준 소스, 제품 결정과 구현 상태를 구분해요.
3. 아래 표에서 작업 하나를 선택하고 관련 문서, 코드, ADR만 읽어요.
4. 작업 브랜치와 인수인계를 확인한 뒤 범위를 정해요. 다른 작업자의 수정은 보존해요.

공통 입구는 AGENTS와 이 문서, STATUS 합계 250줄 이내를 유지해요. 이는 토큰 수 보장값이 아니라 문서 크기 제한이에요. 기술노트, 연구 조사와 원본 로그는 필요한 주장이나 실패를 확인할 때 열어요.

## 작업별 읽기 경로

| 작업 | 먼저 읽을 문서 | 코드 시작점 | ADR 번호 |
|---|---|---|---|
| 조립, 배선, Undo | [데이터 관계](DATA_MODEL.md), [저작 흐름](AUTHORING.md) | `src/assembly/assembly_mode.gd`, `src/ui/wiring_panel.gd` | 0002, 0007, 0022 |
| 저장, 가져오기, 버전 | [데이터 관계](DATA_MODEL.md), [저작 흐름](AUTHORING.md) | `src/core/project_store.gd`, `src/runtime/motion_snapshot.gd` | 0002, 0016, 0022 |
| 보드, 언어, 블록 | [실행 흐름](FLOWS.md), [저작 흐름](AUTHORING.md) | `src/core/board_profile.gd`, `src/runtime/mini_runtime.gd`, `src/blocks/servo_program.gd` | 0004, 0007 |
| 물리, 모터 | [아키텍처](ARCHITECTURE.md), [실행 흐름](FLOWS.md) | `src/runtime/run_mode.gd`, `src/runtime/servo_drive.gd` | 0003, 0020; 로봇별 ADR 추가 |
| 첫 경험, 과제, UI | [제품 정책](POLICIES.md), [깃발 임무](FLAG_MISSION.md), [번역](LOCALIZATION.md), [설정 경험 검토안](INTERFACE_PREFERENCES.md) | `scenes/main.gd`, `src/ui/flag_mission.gd` | 0007, 0022; 새 과제 계약은 별도 |
| AI, 외부 도구 | [제품 정책](POLICIES.md), [MOTION_LAB](MOTION_LAB.md) | `src/runtime/motion_lab_client.gd`, `tools/motion_lab/service.py` | 0008, 0010 |
| 빌드, 배포 | [BUILD](BUILD.md), [RELEASE_PLAN](RELEASE_PLAN.md) | `tools/ci/verify.py`, `tools/ci/build.py`, `.github/workflows/ci.yml` | 0001, 0013, 0017 |
| 문서, 다이어그램 | [갱신 규칙](MAINTENANCE.md) | `docs/context.json`, `tools/docs/maintain.py` | 0000, 0023 |

[파일 구조와 클래스 위치](generated/CODE_MAP.md) · [ADR 색인](adr/INDEX.md)에서 실제 경로와 결정 상태를 찾아요. 표는 읽기 안내이며 담당자를 고정 배정하지 않아요. 관련 ADR이 다른 ADR을 확장하거나 일부 대체하면 연결된 결정도 읽어요.

## 새 세션과 압축 후 재개

```sh
git status --short --branch
git log -3 --oneline
python3 tools/docs/maintain.py --check
python3 tools/docs/maintain.py --route storage
```

문서 검사 실패는 낡은 설명이나 끊어진 참조를 알리는 신호예요. 앱의 성공/실패 판정이나 작업 소유권 검사를 대신하지 않아요.
`--route`는 해당 작업의 문서·코드·ADR 경로만 출력해요. 선택지는 assembly, storage, language, physics, product, ai, delivery, docs예요.

이 사용자의 로컬 환경에서는 `agent-task list --project ssok` 후 해당 작업의 `show`와 Handoff를 읽어요. 로컬 CLI가 없는 외부 개발자는 이슈/PR의 담당자와 인계 내용을 확인해요. 개인 볼트가 없어도 저장소 문서만으로 개발에 참여할 수 있어야 해요.

재개 시 AGENTS, STATUS, 해당 작업 인계, ADR 색인과 변경 범위의 ADR을 다시 읽어요. 이전 요약의 브랜치/커밋/작업 디렉터리를 실제 Git 상태와 대조해요. 변경되지 않은 연구 보고서와 로그를 반복해서 전부 읽지 않아요.

## 작업을 마칠 때

[CONTRIBUTING](../CONTRIBUTING.md)의 완료 절차를 따라 코드와 관련 문서를 같은 변경으로 남겨요. 실행하지 않은 검사는 `미실행`, 다른 소스의 결과는 해당 커밋의 이력으로 적어요. 세션 인계에는 작업 범위, 파일, 검증, 남은 일과 다음 명령을 적고 이 문서로 연결해요.
