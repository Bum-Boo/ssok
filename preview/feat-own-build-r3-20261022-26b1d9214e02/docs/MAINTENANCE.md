# 문서 갱신과 인수인계 규칙

## 정본과 책임

| 정보 | 정본 | 갱신하는 사람 |
|---|---|---|
| 구현 구조·저장 계약 | 코드와 관련 테스트 | 해당 코드를 바꾸는 개발자 |
| 합의한 구조 결정 | `docs/adr/` | 결정을 제안한 개발자, PR 검토자 확인 |
| 사용자 방향·구현 단계 | [STATUS](STATUS.md) | 방향 변경 또는 통합 담당자 |
| 파일 위치·클래스·ADR 목록 | 자동 생성 CODE_MAP / ADR INDEX | 파일 이동·추가 또는 ADR 작성자 |
| 데이터 관계·호출 흐름 | [DATA_MODEL](DATA_MODEL.md), [FLOWS](FLOWS.md) | 관련 계약을 바꾸는 개발자 |
| 실제 검증 | 버전 있는 `docs/evidence/`와 PR 결과 | 검사를 실행한 개발자 |
| 현재 담당·다음 작업 | 이슈/PR, 이 사용자의 로컬 agent-task | 작업 소유자 |
| 기술 이력·조사 | 날짜 있는 기술/개발노트 | 새로운 근거를 추가하는 개발자 |

개인 볼트는 사용자 결정과 재개 포인터를 보존해요. 저장소 참여 규칙을 볼트에만 두지 않아요. Now에는 최신 시작점과 다음 작업을 연결하고 장문의 기술 설명은 복사하지 않아요.

## 같은 변경에서 갱신할 것

| 변경 | 함께 검토할 문서 |
|---|---|
| 파일/클래스 추가, 삭제, 이동 | CODE_MAP, context.json의 경로와 symbol, START_HERE의 진입점 |
| 저장 키·한도·식별자 | DATA_MODEL, AUTHORING, 저장 버전 이행과 테스트 |
| 실행 순서·제어권·Stop | FLOWS, CONTROLS, 해당 제어기 계약과 테스트 |
| 보드 API·시간 단위·언어 | DATA_MODEL/FLOWS, AUTHORING, 예제와 profile 계약 |
| 목표·환경·판정 | FLOWS, 과제 명세, STATUS; 범용 Stage 계약이면 ADR |
| 새 UI·사용자 문구 | POLICIES, LOCALIZATION과 네 언어 카탈로그, 전후 증거 |
| 새 AI 제공자·전송·과금 | POLICIES, provider 설계 노트, 공식 출처 확인 날짜 |
| 엔진·물리·배포/권한 | 해당 ADR, ARCHITECTURE, BUILD 또는 RELEASE_PLAN |
| 제품 방향·통합·검증 상태 | STATUS, README의 현재 안내와 해당 작업 인계 |

의미가 같은 구현 정리에도 도식을 반드시 고쳐 쓸 필요는 없어요. 관련 내용을 검토했다면 도식 유지 이유를 PR/인계에 한 줄 적어요. 중요한 계약 소스의 해시를 확인하는 도구는 검토 필요성을 감지하며 문서 의미가 맞는지 증명하지는 않아요.

## 자동 검사

Python 표준 라이브러리만 사용해요. 엔진, 네트워크와 API 키는 필요 없어요.

```sh
python3 tools/docs/maintain.py --write
python3 tools/docs/maintain.py --check
python3 tools/docs/maintain.py --check --base <실제-작업-시작-커밋>
```

`--write`는 파일 지도와 ADR 색인만 생성해요. `--check`는 생성물 차이, 등록 문서의 로컬 링크, 경로/선언 symbol, 입구 크기, 등록한 계약 소스의 검토 해시를 검사해요. `--base`는 변경 파일에 해당하는 문서 경로를 안내해요. 파일 지도는 자체 코드의 위치를 요약하고 서드파티 내부, 빌드 파일과 원본 로그를 펼치지 않아요.

계약 소스가 바뀌면 관련 도식과 설명을 실제 코드와 대조하고 다음 명령으로 **검토한 계약만** 기록해요.

```sh
python3 tools/docs/maintain.py --review data-model
python3 tools/docs/maintain.py --review execution-flow
python3 tools/docs/maintain.py --review flag-flow
```

해시만 갱신해 검사 오류를 없애지 않아요. 설명을 유지했다면 검토 이유를 PR에 적어요. 문서 도구의 회귀 검사는 `python3 -m unittest discover -s tools/docs -p 'test_*.py'`예요. CI에는 이 두 검사를 독립 job으로 등록해요.

검사 범위는 `docs/context.json`의 managed 문서와 ADR 파일이에요. 모든 과거 증거·외부 URL·Mermaid 렌더링·자연어 의미·Markdown anchor를 자동 검증하지 않아요. 새 다이어그램은 Mermaid 렌더러에서 표시 여부를 확인하고 실제 관계/전이도 사람이 검토해요.

선택형 렌더러 `tools/docs/render_diagrams.py`는 설치된 Playwright와 로컬 Mermaid JS bundle을 사용해 SVG/PNG와 소스 해시를 만들어요. 기본 문서 검사에는 이 의존성이 필요 없어요.

```sh
python3 tools/docs/render_diagrams.py --mermaid-js /path/to/mermaid.min.js --renderer-version mermaid@10.9.3
```

## 기술노트와 개발노트

날짜 있는 기술노트의 과거 수치와 실패를 현재 결과로 덮어쓰지 않아요. 새 결과는 `날짜 / source commit / 조건 / 결과 / 근거 경로 / 한계`로 추가해요. 최신 상태를 찾는 사람은 STATUS로 안내해요.

개발노트의 새 항목은 `사용자 문제 → 결정/제안 → 변경 파일 → 확인한 근거 → 미확인 → 다음`을 짧게 남겨요. 배포하지 않았다면 배포 완료로, mock이면 실제 API 결과로 쓰지 않아요. 채팅 전문과 큰 로그는 복사하지 않고 파일로 연결해요.

## 세션 인계 양식

```text
작업/소유자: 이슈 또는 task ID, 세션 ID
작업실/브랜치: 실제 경로, branch, HEAD, 미커밋 변경
완료: 변경 파일과 결과
검증: 실행 명령, 결과, source 식별값, 근거 경로
미실행/실패: 그대로 명시
문서: 갱신 파일, 검토 유지 이유, 번역/비용 영향
다음: 이어서 할 행동 하나와 필요한 명령
진입점: docs/START_HERE.md + 해당 task Handoff
```

로컬 agent-task는 bounded task를 claim/checkpoint 후 finish/release해요. live owner를 가져오지 않아요. 새로 합류한 개발자가 전임자의 비공개 대화·기억·개인 볼트를 필요로 하게 만들지 않아요.
