# 작업 D 검사 근거 — 2026-10-22

최종 소스와 변경·지표·제한은 [작업 요약](../../WORK_SUMMARY_D.md)에 있어요.
[최종 결과](results.json)는 109개 suite / 83 PASS / 26 FAIL이에요.
[병합 기준선](baseline_results.json)은 번역 검사 별도 재실행을 명시한 108개 / 27 FAIL이에요.
전체 suite 통과를 주장하지 않아요.

## 재현

저장소 루트에서 표준 실행은 다음이에요.

    python3 tools/ci/verify.py --godot build/toolchain/godot --output build/own-build-strict-final

이 샌드박스에서는 localhost mock 서버 생성부터 PermissionError로 종료됐어요.
[run_checks.py](run_checks.py)는 tools.ci.verify의 목록/명령/timeout/error gate를 그대로 실행하는
진단 도구예요. mock 서버를 만들지 못하며 해당 실패도 그대로 남겨요. 검사를 건너뛰지 않아요.

    python3 docs/evidence/own_build_2026-10-22/run_checks.py --output build/own-build-final3

원문 로그·명령·JUnit·source manifest는 build/own-build-final3에 있고 Git 제외예요.
최종 결과 JSON에는 원문 로그 대신 각 check의 pass/exit/error/timeout/시간만 보존해요.
공유 위키 접수·실제 GPU 검수와 전체 CI 통과는 작업 요약의 인계 항목으로 남아요.
