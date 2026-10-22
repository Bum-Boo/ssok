# 화면 흐름과 스테이지 레벨 검증 — issue #43

2026-09-30 · Claude · 브랜치 `feat/43-game-flow-levels` (기준 `af1973b`, 이후 `origin/main` 위로 재배치)

## 사용자 문제

- "내가 사용자잖아? 뭐 하라는 건지 이해 못하겠음." 화면이 `main.tscn` 하나라 스테이지가 게임처럼 불러와지지 않았어요.
- "상하좌우에 다 UI가 뜨니까 너무 복잡해. 떠야 할 것만." 스테이지 화면을 목표 카드와 프로그램 패널만 남겼어요.
- 깃발 스테이지는 조립 자세가 서보 0도에서 이미 목표 높이(16.5cm)라 아무것도 안 해도 성공했어요. 스테이지에서는 팔을 눕혀 시작해요. 측정: `write(0)` 팔 끝 8.9cm, `write(90)` 16.5cm.

## 자동 검사 (이 브랜치, 로컬 Godot 4.7.2)

| 명령 | 결과 |
|---|---|
| `godot --headless --path . --language en --fixed-fps 60 --script tests/game_flow_check.gd` | 43/43 통과 |
| 같은 검사, 창 모드 `--language ko/en/zh_CN/ja -- --screenshots` | 언어마다 43/43 통과, 아래 캡처 |
| `python3 tools/ci/verify.py` (72개) | 68 통과, 4 실패: 아래 참고 |
| `python3 -m unittest tests/test_release_documents.py` (수정 후) | 통과 |
| `python3 tools/docs/maintain.py --check` | 통과 |

`verify.py` 실패 4개:
- `localization_check`: 번역 파일을 고치는 중에 실행돼 새 문구가 빠져 보였어요. 다시 실행하면 새 문구는 모두 통과하고 `history switches language` 1건만 남아요. 이 1건은 수정하지 않은 main(`79530d9`)에서도 똑같이 실패해요.
- `tests-motion_mcp_check.py`, `tools-rl_lab-test_rl_lab.py`: 이 노트북에 `mcp`, `mujoco` 파이썬 모듈이 없어요. 앱 변경과 관계없어요.
- `tests-test_release_documents.py`: 새 소스 링크가 배포 문서 목록에 없었어요. `tools/ci/build.py`에 추가해 고쳤어요.

## 성능 관찰

스테이지 판정 중 한 프레임 비용(헤드리스, 이 노트북): 목표 카드가 매 프레임 과제 목록을 다시 만들던 버그를 고친 뒤 약 22ms. 이 중 약 19ms는 기존 `StagePanel`의 매 프레임 실행 문맥 fingerprint(ADR 0025)예요. 물리 설정 변경을 같은 프레임에 감지하는 기존 검사가 있어 이번에는 바꾸지 않았어요.

## 캡처

언어별 폴더 `ko/`, `en/`, `zh_CN/`, `ja/`에 타이틀, 스테이지 목록, 미션 소개, 스테이지 화면, 미달성, 성공, 결승선, 벽 앞 정지, 자유 제작, 예제 목록이 있어요. 1440×900, GL Compatibility, 실제 앱 화면이에요.

## 남은 일

문장형 블록, 스테이지 카드 미리보기 이미지, 나머지 12개 스테이지, 판정 비용 최적화, 자동차 블록의 `direction`/`speed` 미번역(기존), 가져온 과제의 레벨 참조(새 스키마 필요).
