# 작업 B 검증 근거 — 2026-10-22

기준 HEAD `b3570c650bd0fa285af94fd9136708b1df41bdc8`, 브랜치
`feat/parts-freedom-20261022`, Godot `4.7.2.stable.official.ed1daf0bf`.
미커밋 overlay의 코드/테스트/생성 자산 SHA-256은 `source_manifest.json`에 있어요.
작업 범위와 미완료는 [WORK_SUMMARY_B](../../WORK_SUMMARY_B.md)를 따라요.

`results.json`은 저장소의 `tools.ci.verify.checks()`가 만든 명령을 같은 `run()` 판정으로
실행한 최종 100-suite 결과와 후속 검사를 보존해요. 로컬 소켓을 열 수 없어 mock 서버를
시작하지 못했으므로 공식 verify의 동등한 release PASS가 아니에요. 오류 로그를 무시하거나
expected-failure로 감추지 않았어요. suite PASS에는 각 기존 검사 내부의 SKIP이 있을 수 있어요.

원래 공식 명령:

```sh
python3 tools/ci/verify.py --godot "$PWD/build/toolchain/godot" --output build/verification-b-baseline
```

mock 서버 생성에서 `PermissionError: [Errno 1] Operation not permitted`로 시작 전 중단됐어요.
격리 XDG 임시 폴더에서 사용한 대체 실행 스크립트는 `run_without_mock.py`예요. 마지막 실행은
100 suites, 73 PASS / 27 FAIL이고 후속 문서 패키지 검사에서 링크 실패 1개를 해소했어요.
이후 비대칭 힌지의 부호/연결 순서 수정과 관련 앱·물리·핵심 작성·Stage 검사를 다시 실행했고,
후속 12 suites 모두 통과했어요. 따라서 확인된 잔여 실패는 26개예요. raw 최종 전체 로그는 `build/verification-b/all-final-progress.log`,
suite별 로그와 JUnit은 `build/verification-b-all/`에 있고 이 근거 폴더에는 큰 원본 로그를 복사하지 않았어요.

초기 전체 99 suites는 71 PASS / 28 FAIL이었어요. 키트/전체 카탈로그 개수 검사 두 개를 새
SKU에 맞춰 수정했고 각 새 ID의 도달 검사를 추가했어요. 최종 100-suite 실행 중에는 아직 작성
중이던 WORK_SUMMARY_B 링크가 문서 패키지 검사에서 실패했어요. 파일/인계/근거를 작성한 뒤
해당 검사를 다시 실행했어요. 첫 실패 출력은 `build/verification-b/all-progress.log`와 최종 전체
진행 로그에 남기며 뒤의 PASS로 실패 이력을 대체하지 않았어요.

잔여 실패 종류:

| 종류 | suite 수 | 실제 원인/한계 |
|---|---:|---|
| import | 1 | exit 0이나 editor TCP listen이 금지돼 engine ERROR 검출 |
| 실제 렌더/카메라/브리지 | 17 | DISPLAY 없음; Xvfb도 listening socket을 열지 못함 |
| motion_lab_ui_check | 1 | HTTP 소켓 생성이 OS에서 거부되어 실패 경로 기대와 다름 |
| Python socket fixture | 5 | desktop client/session, pickup bridge, races/service가 로컬 socket 생성에서 PermissionError |
| Python 선택 의존성 | 2 | `mcp`, `mujoco` 모듈 없음; 사용자 지시대로 설치하지 않음 |

관련 현재 PASS:

| 검사 | checks / failures |
|---|---:|
| runtime (추가 후속) | 28 / 0 |
| blocks | 51 / 0 |
| mechanics (추가 후속) | 79 / 0 |
| Stage/Lab graph integration | 50 / 0 |
| construction kit | 12,894 / 0 |
| workshop UI | 440 / 0 |
| construction kit UI | 398 / 0 |
| localization | 52,774 / 0 |
| original robot car | 14 / 0 |
| docs tool unittest | 10 / 0 |

물리 관측: wheel 40/90 mm의 실제 motor 속도 약 9.93/9.92 rad/s, 전 구간 회전 관측값이
정지 자세와 달랐어요. 수동 힌지는 초기 ±5 rad/s에서 양방향 최대 47.311°, 기본 제한 ±45°와
solver tolerance 5° 이내였어요. 반대 방향·다른 각도 설정의 무동력 제한도 별도 확인했어요.
100/300 g solver 질량과 중력 낙하를 확인했어요. 실제 차량 새 바퀴의 직진/균형/Stage 성공률은
검증하지 않았고, 원래 65 mm 차량의 회귀는 별도 14/0이에요.

렌더 글리프/잘림, Web/desktop export, 게임 Stage에서 새 부품 트레이 추가는 미실행/미완료예요.
새 부품의 headless 그래프 호환 결과로 이 범위를 추정해 PASS로 세지 않아요.
