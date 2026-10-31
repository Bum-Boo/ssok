# r3 통합 후보 후속 두 건 — 2026-10-31 클라우드 세션 보고

브랜치 `claude/ssok-r3-follow-ups-k9dd0c`, 기준 `feat/own-build-r3-20261022` `578ca79`.
격리된 Linux x86_64 VM, 공식 Godot `4.7.2.stable.official.ed1daf0bf`(SHA-256 검증), Python 3.13.18 venv + `tools/ci/requirements-lock.txt`,
Xvfb 1600×1000 + Mesa llvmpipe. 외부 서비스 호출·실제 토큰·push 외 GitHub 쓰기는 없어요. 검사 근거는 [evidence/cloud_fix_2026-10-31](evidence/cloud_fix_2026-10-31/README.md)예요.

## 1. 미리보기 워크플로 대기 (C-2) — 검증된 결함, 수정

**원인.** run 39797157788의 `verify` 로그는 `pages/builds/latest`가 10분 내내 `{"status":"queued"}`(commit 없음)만 돌려준 뒤 timeout exit 1이에요.
기존 단계는 이 응답의 `commit`이 push한 gh-pages commit과 같고 `built`일 때만 성공했으므로, 사이트가 이미 게시되어 200을 돌려줘도 실패했어요(`.github/workflows/preview.yml` 옛 109–136행).
run 39769547535의 실패는 다른 원인(`browser_layout.gd` 300초 timeout)으로 D-3에서 이미 수정됐어요.

**변경.**
- 게시 단계가 `build/web/preview.json`(source commit·branch·slug·run id)을 기록한 뒤 rsync해요: `.github/workflows/preview.yml:99-110`.
- 대기 단계는 새 `tools/ci/pages_preview_wait.py`를 호출해요(`preview.yml:124-141`, 총 900초, 15초 간격, `GITHUB_STEP_SUMMARY`에 한 줄 기록).
  - 성공 기준은 실제 URL `preview/<slug>/preview.json?source=<sha>`가 200이며 `source`가 push한 앱 commit과 같은 것(`pages_preview_wait.py:162,179`). 이미 built/served 상태를 즉시 인정하고, CDN 캐시는 commit별 query로 우회해요.
  - Pages API(`/pages`, `/pages/builds` 목록)는 매 poll 진단 줄에 기록하고, push한 gh-pages commit의 build가 `errored`면 즉시 exit 1(`:175`). API 오류는 기록만 하고 served 판정을 막지 않아요.
  - timeout 시 마지막 HTTP 상태·served source를 설명하고 롤백이 없음을 명시해요. build 요청 POST는 유지하되 실패를 치명으로 보지 않아요(`:118`).
- 안전 속성 유지: `gh-pages` root 확인, 최신 revision 확인 후 skip, `--force` 없는 push, Pages 설정 변경 없음, 권한 그대로. 작업 timeout 35분 대비 대기 15분 + export는 여유가 있어요.
- `tools/ci/test_pages_preview_wait.py` 9건: queued placeholder+served 성공, 옛 marker→새 marker 대기, errored 즉시 실패, bounded timeout(7회 poll/60초), API 예외 허용, soft-404 거부, marker 기록, 음수 예산 거부, 워크플로 구조(`--force` 없음·timeout 범위). `verify.py`가 `tools/**/test_*.py`를 자동 수집하므로 전체 검사에 포함돼요.
- 문서: `docs/BUILD.md` 미리보기 절.

**이 VM에서 못 한 것.** 실제 GitHub Actions 실행과 실제 Pages/CDN 전파는 미검증이에요. 다음 `feat/**` push에서 Job summary의 `Preview served after …` 줄과 poll 로그를 확인해 주세요.

## 2. Verify의 카메라 기준 실패 — 원인 분리

### 2-a `camera_evaluator_lifecycle_check-drive_stop`, `agent_camera_rest_check`의 fault — 검증된 결함, 근본 원인 수정

**측정.** CI 두 run(0.3.1 `38156164681`, r3 `39797157897`)의 `drive_stop` 진행 로그는 tick 37→157이 각각 11.4초·9.97초, 즉 초당 10.5·12.0 물리 틱이에요(`--fixed-fps 60`은 렌더 프레임마다 1틱이고 llvmpipe 1600×1000은 그만큼 느려요).
25틱 전진 뒤 측정 정지까지 이 VM에서 네 번 모두 settle 152–155틱(2.5초 물리 시간)이 필요했는데, `agent_camera_loop.gd`의 주행·정지 벽시계 한도는 10초였어요.
CI는 tick 167·182(브레이크 후 106·121틱)에서 `operation_timeout` fault가 났고, 이 VM(13.6틱/초)은 9.0초로 간신히 통과했어요(변경 전 전체 검사에서 PASS).
rest check의 CI 실패 8건과 14.7·15.0 mm "drift"는 같은 fault의 후속이에요: loop가 꺼진 뒤 수동 제동만 남은 creep이며, 이 VM에서 hold를 끈 비교도 14.67 mm였어요.

**수정.** 주행 30틱·정지 240틱은 이미 물리 틱으로 한정되어 있으므로(ADR 0029), 벽시계 guard는 물리 시계가 멈춘 경우만 덮도록 60초로 바꿨어요: `src/runtime/agent_camera_loop.gd:18,126,212`. ready의 60초 decision watchdog, 정지 임계값, 모터 duty, hold 이득, 캡처 규칙은 바꾸지 않았어요.
회귀 검사: `tests/agent_camera_rest_check.gd:34-38,71-73`가 첫 주행의 매 틱에 100 ms를 주입해 느린 렌더러를 재현하고, 벽시계 10초를 넘겼음을 자체 확인한 뒤 ready를 요구해요. 수정 전 loop에 실행하면 tick 103 fault·15.1 mm·9 failures로 CI와 같은 모양으로 실패하고, 수정 후에는 155틱/19.8초에도 ready예요.

### 2-b `agent_camera_rest_check` 유휴 drift 0.00277 m — 허용값 문제, 측정 근거로 조정

**측정.** 변경 전 소스에서 이 VM의 유휴 600틱 drift는 `0.00276690465398` m로 1600×1000 3회·800×500 1회 모두 동일(결정적)이고, Windows GL 기록은 1.1753 mm(`docs/evidence/agent_camera_2026-10-10/completion/rest-hold-3`)예요.
성분은 x −1.41, y −0.27, z +2.36 mm: 바퀴는 hold가 잡고 있는데(duty 0.2–0.4%, 바퀴 속도 ≤0.01 rad/s) 차체가 초당 약 0.3 mm 옆으로 미끄러지고, 30틱 단위 로그에서 접촉 solver 요동 4회가 각 0.3–0.7 mm를 더해요.
같은 절차에서 hold만 끄면 14.67 mm(전진), 기록된 P-only hold는 5.7–6.0 mm예요. 즉 hold는 Linux에서도 5.3배 억제하고 있고, 2 mm 한도는 Windows 단일 측정에 0.8 mm 여유만 둔 값이었어요.

**결정.** 한도를 4 mm로 정했어요(`tests/agent_camera_rest_check.gd:11,83`): 측정된 두 플랫폼(1.18·2.77 mm)을 통과시키고, 기록된 모든 실패 양상(5.7·6.0·14.7·15.3 mm)은 여전히 거부해요. 카메라 환산으로 2.4 mm 측면 이동은 0.3 m 앞 벽에서 약 3 px이고, 기존 24–38 px 목표 띠의 ±2 px 추정 오차 안이에요.
측면 미끄럼의 원인은 원통 바퀴+마찰 0.01 캐스터의 solver 특성으로 보이며 GDScript 제어로 없앨 수 없어요. 바퀴 형상 변경은 별도 ADR·전체 차량 근거 재검증이 필요해 하지 않았어요(정적 위험으로 기록).
창 크기를 800×500으로 낮춘 것(`:48`)은 UI 단언이 없는 물리 검사의 비용만 줄여요: 1600×1000에서 CI 속도면 유휴 600틱이 57초로 60초 decision watchdog에 근접하는데, 물리 결과는 창 크기와 무관함을 4회 probe로 확인했어요.

ADR 0029에 2026-10-31 보완 문단, `docs/APP_CONTROL_API.md`·`docs/FLOWS.md`의 10초 설명을 갱신하고 `maintain.py --review execution-flow`를 기록했어요.

## 3. 명령과 결과

| 명령 | 변경 전 | 변경 후 |
|---|---|---|
| `xvfb-run -a -s "-screen 0 1600x1000x24" build/venv/bin/python tools/ci/verify.py --godot "$PWD/build/toolchain/godot"` | 115 checks / 2 failures: `agent_camera_rest_check`(drift 2.77 mm > 2 mm), `motion_lab_ui_check`(1/54, 아래) | 116 checks / 0 failures(새 `tools-ci-test_pages_preview_wait.py` 포함, engine error 0, [results-after.json](evidence/cloud_fix_2026-10-31/results-after.json)) |
| `agent_camera_rest_check` 단독(수정 전 loop + 새 검사) | 14 checks / 9 failures, drift 15.1 mm | 8 checks / 0 failures, drift 2.7669 mm |
| `camera_evaluator_lifecycle_check -- --lifecycle-mode drive_stop` ×2, `driving_stop` ×1 | VM에서 PASS(CI FAIL) | 18/0, 22/0, 15/0 |
| `agent_camera_loop_check -- --ssok-agent-bridge --screenshots` | 30/0 | 30/0 |
| `build/venv/bin/python -m unittest tools/ci/test_pages_preview_wait.py` | 없음 | 9 tests OK |
| `godot --headless --path . --editor --import --quit`, `godot --headless --path . --quit` | exit 0 / engine error 0 | 전체 검사의 `import`·`scene-load` PASS |
| `python3 tools/docs/maintain.py --check`, `--write`, `--review execution-flow` | 통과 | 통과 |
| `git diff --check` | — | 통과 |

`motion_lab_ui_check`의 변경 전 실패 "poll-preempting cancellation reaches the bridge"(`tests/motion_lab_ui_check.gd:200`)는 mock HTTP 서버가 실제 Godot 하위 프로세스 trial을 돌리는 15초 경합 검사이고, r3 CI에서는 PASS였어요. 변경 후 전체 실행에서는 PASS(6.8초)였고 이번 변경 파일과 무관하므로 2회 중 1회의 환경 타이밍 플레이크로 분류하고 수정하지 않았어요.

localization: 사용자 문구 변경이 없어 PO 변경이 없고, 전체 검사의 `localization_check`가 통과했어요.

## 4. 이 VM에서 검증하지 못한 것

- 실제 GitHub Actions의 preview 워크플로 실행, Pages build 큐, CDN 전파와 공개 URL 응답.
- Windows·macOS 실기기, 실제 GPU(GL) 렌더링에서의 drift 값(여기 수치는 llvmpipe 결정론 값), 실제 Web export·브라우저 게이트(템플릿 1.28 GB 미설치).
- 실제 AI 제공자 호출·운영자 CLI 흐름(모두 mock/미실행).

## 5. 분류 요약

| 항목 | 분류 |
|---|---|
| 미리보기 대기가 `builds/latest` queued placeholder에 막힘 | 검증된 결함 → 수정 |
| `drive_stop`·rest check의 fault: 벽시계 10초 vs 물리 틱 settle 130틱 | 검증된 결함 → 근본 원인 수정 + 회귀 검사 |
| rest check 2 mm 한도(Linux 2.77 mm 결정론 값) | 허용값 문제 → 측정 근거로 4 mm |
| 측면 0.3 mm/s 미끄럼(원통 바퀴·캐스터 solver) | 정적 위험(기록, 미수정) |
| lifecycle 검사의 25초 ready·20초 settle 벽시계 기한, rest check 600틱 vs 60초 decision watchdog | 정적 위험(느린 렌더러 여유 ≥25%; 창 축소로 rest check는 완화) |
| run 39769547535 preview 실패(`browser_layout` 300초) | 이미 D-3에서 수정됨 |
| `motion_lab_ui_check` 1회 실패 | 비이슈로 추정(환경 타이밍 플레이크 1/2, 변경과 무관, 미수정; 재발하면 별도 조사) |

## 6. 다음 단계(소유자)

1. 다음 `feat/**` push에서 preview 워크플로의 Job summary와 poll 로그를 확인하고, 실제 공개 URL을 열어 `preview.json`의 source가 push한 commit인지 확인해 주세요.
2. GitHub CI `verify`에서 `agent_camera_rest_check`·`camera_evaluator_lifecycle_check-drive_stop`이 PASS인지 확인하고, 로그의 `drive_step 0: ticks=… wall_ms=…`와 `idle_drift_m`을 evidence에 추가해 주세요(실제 GPU 호스트 값도 함께).
3. 측면 미끄럼을 줄이려면 바퀴 collision 형상(원통→캡슐 등) 실험을 별도 ADR·전체 차량 근거 재검증과 함께 진행하세요.
4. 이 브랜치를 `feat/own-build-r3-20261022`에 반영할지 통합 담당자가 판단하고, 사람이 병합해요.
