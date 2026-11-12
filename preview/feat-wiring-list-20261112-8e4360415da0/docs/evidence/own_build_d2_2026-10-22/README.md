# 작업 D-2 검사 근거 — 2026-10-22

범위·머지 부모·제약·checkpoint는 [작업 요약](../../WORK_SUMMARY_D2.md)에 있어요.
첫 전체 실행은 [initial_results.json](initial_results.json)에 보존해요.
최종 결과와 D/B-2 비교는 [results.json](results.json)에 있어요.

## 재현

저장소 루트에서 표준 실행:

```sh
python3 tools/ci/verify.py --godot build/toolchain/godot --output build/d2-strict
```

loopback mock 서버 생성이 `PermissionError: [Errno 1] Operation not permitted`로 중단됐어요.
이 시도는 전체 suite를 실행한 것으로 세지 않아요. 원문은 `build/d2-strict/runner.log`예요.
D와 같은 진단 도구는 표준 `checks()`/`run()`/timeout/error gate 전체를 재사용해요.
mock 실패나 렌더 실패를 생략·통과 처리하지 않아요.

```sh
python3 docs/evidence/own_build_2026-10-22/run_checks.py --output build/d2-full
python3 docs/evidence/own_build_2026-10-22/run_checks.py --output build/d2-final
```

첫 실행은 115 suites / 88 PASS / 27 FAIL이었어요. D 기준선 26개 실패에
`stage_own_build_check`의 81종 고정 트레이 assertion 3개만 추가됐어요.
기대 수를 카탈로그에서 유도한 뒤 전체 115개를 다시 실행했어요.
두 번째 실행 도중 앱·검사·도구 소스는 수정하지 않았어요.

원문 로그·전체 명령·JUnit·source manifest는 Git 제외인 `build/d2-full/`, `build/d2-final/`에 있어요.
저장소 결과 JSON에는 각 suite의 pass/exit/engine_error/timeout/시간과 소스 식별을 보존해요.
실제 GL·Web export·Actions·공개 URL을 이 로컬 결과로 인증하지 않아요.

최종 **115 suites / 89 PASS / 26 FAIL**, D 환경 실패 이름 집합과 동일·추가 실패 0개예요.
D 통과 83개와 B-2 통과 79개를 모두 유지했고 B-2의 기존 workshop_ui 실패도 통과했어요.
소스 1,008개 파일의 검사 전후 불일치 0개이며, 기준 앱 소스와 후속 검사 1개 해시는 결과 JSON에 있어요.
