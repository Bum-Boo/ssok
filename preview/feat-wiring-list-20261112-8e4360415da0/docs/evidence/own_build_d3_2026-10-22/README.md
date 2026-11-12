# 작업 D-3 검사 근거 — 2026-10-22

소스·결정·한계·checkpoint는 [D-3 요약](../../WORK_SUMMARY_D3.md)에 있어요.
앱/검사/도구 소스는 `e2c1eb3a9bca6cc1624d3e56c5b54952d0a8b4cc`,
이 폴더를 포함하는 후속 커밋은 문서·증거만 담아요.

- [첫 전체 결과](initial_results.json): popup 보정 전 `3fe5882`, 115 suites / 89 PASS / 26 FAIL.
- [전체 결과](results.json): 표준 115 suite 이름 일치, 89 PASS/26 FAIL, D-2 PASS 89개 유지·환경 실패 집합 동일.
- [기존 layout 오류](browser-layout-before.log): 격리 user data로 120초 timeout(exit 124). Add block 누락과 옛 카드 구조 오류.
- [수정 layout](browser-layout-after.log), [90개 실제 앵커](browser-layout.json), [실측 시간/종료 코드](layout-checks.json).
- [누락 control 주입](browser-layout-missing.log), [120초 await 주입/45초 watchdog](browser-layout-watchdog.log): 둘 다 exit 1.
- [최종 환경 검사](environment.log): 직접 1/1/0, 물리 push/Stop 모두 1, 21 checks / 0 failures.
- [기존 관측 함수 반증](environment-original-observer.log): 임시 RunMode 하위 클래스에 시작 HEAD의 cup 함수만 override, 같은 검사에서 21/3 실패(peak=2·Stop=2·연결 물체 제외).

## 재현

쓰기 가능한 별도 data/config 경로를 쓰고, 레이아웃 실행마다 새 user data를 사용해요.

```sh
XDG_DATA_HOME=/tmp/ssok-new-layout XDG_CONFIG_HOME=/tmp/ssok-new-layout timeout 60 build/toolchain/godot --headless --path . --language en --script res://tools/ci/browser_layout.gd -- /tmp/browser-layout.json
XDG_DATA_HOME=/tmp/ssok-env-check XDG_CONFIG_HOME=/tmp/ssok-env-check build/toolchain/godot --headless --path . --language en --fixed-fps 60 --script tests/parts_pack_environment_check.gd
python3 tools/ci/verify.py --godot build/toolchain/godot --output build/d3-strict
python3 docs/evidence/own_build_2026-10-22/run_checks.py --output build/d3-final
```

표준 runner는 mock loopback 서버 생성 권한 거부로 중단됐어요.
진단 도구가 동일 표준 계획/명령/timeout/error gate를 빠짐없이 실행했어요.
원문 명령·로그·JUnit·source manifest는 Git 제외인 `build/d3-final/`에 있어요.
SHA-256 전후 불일치 0개이며 manifest 해시는 results JSON에 있어요.

설치·빌드·직접 export 시도 로그는 `build/d3-repro/{install,web-build,web-export-direct}.log`,
실제 build import 로그는 `build/export-logs/import.log`예요.
템플릿 다운로드 DNS 오류, import 소켓 권한 오류, Web 템플릿 부재를 각각 확인했어요.
빌드 gate를 우회하지 않았고 정상 Web 산출물이 없어 Chromium 실행은 미실행이에요.
Linux headless 물리와 Windows 실기기·WebAssembly 물리의 검증을 구분해요.
