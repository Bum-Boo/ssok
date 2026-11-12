# 개발 합류 문서 검증 기록

2026-09-30 Codex. 애플리케이션 기준 소스는 `2759fde`, 작업 브랜치는
`docs/contributor-context-20260930`예요. 변경 범위는 문서·문서 도구·문서 CI예요.

## 확인한 결과

- `python3 tools/docs/maintain.py --check`: 등록 문서 로컬 링크, 경로, 클래스/함수,
  생성 파일, 계약 소스 검토 해시와 공통 입구 크기 검사 통과.
- `python3 -m unittest discover -s tools/docs -p 'test_*.py' -v`: 합성 저장소 기반 **10개 검사 통과**.
  실제 행동만 바꾸어도 재생성으로 해시 검토가 생략되지 않는지, 이름 변경·삭제·깨진 링크·낡은
  파일 지도·입구 과다·알 수 없는 검토 요청을 잡는지 확인했어요.
- `--route storage`: 해당 문서 2개, 소스 3개, ADR 3개의 정확한 경로를 출력했어요.
- `--check --base 2759fde`: 미추적 신규 파일도 포함해 영향받는 문서 경로를 안내했어요.
- 공통 입구 AGENTS + START_HERE + STATUS는 **171줄**이에요. 관련 문서/ADR을 포함한
  실제 토큰 사용량이나 절감률을 측정한 수치는 아니에요.
- Mermaid **10.9.3**를 Chromium headless에서 실행해 도식 **6개를 렌더링**하고 PNG 화면을
  직접 확인했어요. 한국어 표시, 관계·분기·조건 표시와 문법 오류 여부를 확인했어요.
- 앱 소스/장면/자산/프리셋/기존 앱 테스트 변경 없음. Godot·물리·Web 앱 검사는 이번에 미실행.
  CI workflow는 로컬 작성·검토했으며 GitHub에서 실행한 결과로 표기하지 않아요.

## 도식 출력

편집 정본은 [DATA_MODEL](../../DATA_MODEL.md)과 [FLOWS](../../FLOWS.md)의 Mermaid예요.
아래 SVG는 검증 당시의 출력 스냅샷이며 최신 정본으로 자동 갱신하지 않아요.

- [리소스 ERD](data_model-1.svg), [저장 JSON ERD](data_model-2.svg)
- [실행과 제어권](flows-1.svg), [저장/가져오기 분기](flows-2.svg)
- [깃발 대표 상태 경로](flows-3.svg), [후속 Stage 설계](flows-4.svg)

[render.json](render.json)은 각 Mermaid 블록의 SHA-256, 렌더러 버전과 성공 여부를 기록해요.
재현 도구는 [render_diagrams.py](../../../tools/docs/render_diagrams.py)이며 로컬 bundle과 Playwright를 사용해요.
후속 Stage 도식은 제안 상태예요. 기존 브랜치의 작업 중 구현이나 전체 15개 과정의 통합 성공을 인증하지 않아요.

## 적용 경계

별도 문서 작업실에서 작성했어요. 진행 중인 issues-31-36와 기존 물리 WIP는 수정하지 않았어요.
기능 통합 후 STATUS의 기준 소스와 도식·계약 해시를 실제 변경에 맞춰 재검토해야 해요.
자동 검사는 Markdown anchor, 외부 정책의 최신성, 도식 의미와 앱 기능을 증명하지 않아요.
