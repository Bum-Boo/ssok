# v0.2.0 공개 전달 — 2026-09-30

사용자 명시 지시로 PR40·41을 병합하고 [ADR0027](../../adr/0027-current-workshop-public-release.md) 범위의 v0.2.0을 공개했어요. 저장소, 웹 실행과 최종 다운로드를 인증 없이 확인했어요.

- [웹 실행](https://bum-boo.github.io/ssok/) — HTTPS, `gh-pages` 루트, `.nojekyll`.
- [최종 배포본](https://github.com/Bum-Boo/ssok/releases/tag/v0.2.0) — Web/Linux/Windows/macOS ZIP, Windows setup, 해시와 빌드 식별값 총8파일.
- [공개 저장소](https://github.com/Bum-Boo/ssok) — 원본 권리 유보와 서드파티 고지는 유지해요.

## 소스와 파일 식별

앱 빌드와 태그 `v0.2.0`은 clean `af1973b28424aa89bed92db47312cbb14b655e16`, Godot `4.7.2.stable.official.ed1daf0bf`예요. [release.json](delivery/release.json)의 `dirty_worktree`와 `source_changed_during_build`는 모두 false예요. [SHA256SUMS](delivery/SHA256SUMS)는 최종6배포 파일의 해시예요.

Web 배포 커밋은 `ae501c516c343e986a4a25586610e5ab451cab36`예요. 검증한 Web 폴더1634파일을 수정 없이 복사하고 식별용 `deploy.json`만 추가했어요. [Pages 빌드](delivery/pages-build.json)는 이 커밋의 built를 확인해요. 일반 main push는 새 앱 배포가 아니에요. 이후 main의 증거 문서와 검사기 수정은 이미 배포한 앱 소스를 바꾸지 않아요. ZIP 안의 오프라인 문서는 빌드 시점의 스냅샷이며 최신 전달 상태는 이 문서가 정본이에요.

## 실제 검사

| 검사와 대상 | 결과 | 근거 |
|---|---|---|
| clean 앱 소스 전체 native suite | 71종 / 0실패 | [요약](native/SUMMARY.md), [전체 결과](native/results.json), [JUnit](native/junit.xml) |
| 네 플랫폼 export·PCK 제외 규칙·Linux 시작·Windows/NSIS·Mac Universal/ad-hoc seal | 통과 | 최종 manifest와 BUILD의 포장 계약. 전체 로그는 로컬 `build/public-v0.2.0/export-logs/` |
| 최종 setup의 실제 Windows 설치·실행·세 과제·종료·제거 | 17항목 / 0실패 | [checks](windows/checks.json), [실제 화면](windows/stage-raise-flag.png), [깃발](windows/stage-raise-flag.json)·[결승선](windows/stage-finish-line.json)·[벽 정지](windows/stage-wall-brake.json) 답안 |
| 같은 Web 파일의 실제 Chromium smoke | 통과 | [결과](browser/smoke/result.json) |
| 같은 Web 파일의 저장·재열기·JSON/블록/배선·Undo/Redo | 9흐름 / 0실패 | [결과](browser/authoring/result.json) |
| 기존 실제 WebAssembly 물리 회귀 | 19항목 / 0실패 | [결과](browser/physics/result.json). 보류 연구의 신규 실험은 하지 않았어요 |
| 세 학습 과제·실제 JSON 다운로드·무한반복 Stop | 5흐름 / 0실패 | [결과](browser/learning/result.json) |
| 테마·한국어·독립 글자 크기·음량/음소거·작업 보존·설정 reload | 14항목 / 0실패 | [결과](browser/settings/result.json) |
| 공개 URL의 smoke·저장/편집·설정 reload | 세 검사 통과, 작성9·설정14항목 | [smoke](public/smoke/result.json), [작성](public/authoring/result.json), [설정](public/settings/result.json) |
| 인증 없는 저장소·Release·8파일 접근/해시·실제 Web ZIP 다운로드·Pages 파일 일치 | 9검사 / 0실패 | [상세](delivery/anonymous-delivery.json). 공개 runtime10파일의 실제 GET 해시도 최종 Web export와 일치 |

공개 화면은 [기본 밝은 화면](public/workshop.png)과 [새로고침 뒤 한국어/어두운 테마/글자200%](public/settings/05-reloaded.png)를 직접 검수했어요. [로컬 브라우저 상태](delivery/public-browser-state.json), [console](delivery/public-browser-console.log), [page errors](delivery/public-browser-errors.txt)에 공개 주소의 actual WebGL2·single-threaded 실행을 남겼어요. canvas 외부의 DOM 대체 UI로 검증하지 않았어요.

전체 native71종과 Windows17항목은 각각 하나의 실행이에요. Web5종은 첫 시도의 smoke/작성/물리/학습 통과와 수정된 검사기의 설정14항목 재실행으로 확보했어요. 첫 시도를 단일5/5 성공으로 바꾸어 기록하지 않아요. 공개 URL의 세 검사는 한 작업에서 모두 통과했어요.

## 실패와 재실행

1. 최초 힘멜 브라우저는 `libnspr4`, NSS, ALSA 런타임 라이브러리 누락으로 앱을 열기 전에 종료했어요. [원본 결과](failures/browser-missing-libs.json)를 보존하고 공식 Ubuntu 패키지를 작업 폴더에만 풀어 재실행했어요. 전역 설치·sudo·공용 Mac 전송은 없어요.
2. 설정 검사기의 `graph.parts.length`가 화면 준비 전의 빈 graph에서 예외를 냈어요. [원본 실패](failures/settings-before-ready.json)를 보존하고 `tools/ci/browser_settings.py`에서 준비 대상을 nullable guard로 기다리도록 고쳤어요. 검사 조건은 부품 수가 실제로0보다 커지는 것이며 그대로 유지해요. 수정 검사기 SHA256은 `db7530bc2c68c96b2a329108a2487ed462d19d70648f486445839f09fb1db46b`예요. 앱 파일은 바꾸지 않았어요.
3. [앱 소스 CI](https://github.com/Bum-Boo/ssok/actions/runs/36706773404)의 첫 시도는 native71·export·smoke·물리·학습 통과 뒤 작성 검사의10분 기한으로 exit137이었어요. [원본 로그](failures/ci-authoring-timeout.log)를 보존해요. 같은 최종 Web 파일의 힘멜 작성9흐름과 공개 작성9흐름은 통과했어요. 같은 앱 소스의 build 재실행 attempt2는 export·네 브라우저 gate·결과/최종 빌드/Pages artifact 업로드까지 통과했고 run 전체가 success예요. native71은 최초 시도의 통과 결과를 유지했어요. [CI 최종 기록](delivery/source-ci.json).
4. 로컬 준비 중 software-renderer의 CDP 평가/캡처 timeout과 존재하지 않는 full-Chrome 경로를 확인했어요. 설치된 headless-shell과 GL 인자로 최종 로컬·공개 화면을 확인했어요. 앞선 시도를 성공으로 계산하지 않아요.

Release published 이벤트가 만든 [run36710683314](https://github.com/Bum-Boo/ssok/actions/runs/36710683314)는 직접 올린 검증 파일과 별개 파일을 다시 생성·첨부하지 않도록 이 작업에서 취소했어요. [취소 기록](delivery/release-event-cancelled.json). main 앱 소스 검증 run은 별도로 유지했어요. 기존 artifact 삭제나 과금 변경은 하지 않았어요. private 준비 단계의 artifact quota 오류 이후 공개 저장소에서는 native/browser 결과 업로드가 성공했어요.

## 재현과 인계

고정 엔진·Python3.14.7·`tools/ci/requirements-lock.txt`로 `tools/ci/verify.py`를 실행하고, 다음처럼 export된 동일 파일을 검사해요. 최신 main의 수정 검사기를 사용해요.

```sh
python3 tools/ci/build.py --godot /path/to/godot --version 0.2.0 --output build/public-v0.2.0
python3 tools/ci/browser_authoring.py --directory build/public-v0.2.0/web --output build/browser-authoring
python3 tools/ci/browser_physics.py --directory build/public-v0.2.0/web --output build/browser-physics
python3 tools/ci/browser_learning.py --directory build/public-v0.2.0/web --output build/browser-learning
python3 tools/ci/browser_settings.py --directory build/public-v0.2.0/web --output build/browser-settings
python3 tools/ci/browser_settings.py --directory build/public-v0.2.0/web --url https://bum-boo.github.io/ssok/ --output build/public-settings
```

개인 힘멜 작업: native `20260930-201025-ssok-v020-native-suite-b14ae625`, Windows `20260930-202139-ssok-v020-windows-lifecycle-9eec7899`, 최초 브라우저 `20260930-202059-ssok-v020-browser-gates-e66492f0`, 브라우저 재실행 `20260930-203602-ssok-v020-browser-retry-16537814`, 설정 재실행 `20260930-204346-ssok-v020-settings-retry-26810245`, 공개 URL `20260930-204959-ssok-v020-public-url-912b7e54`. 모두 완료/실패와 실제 exit를 확인하고 자원 해제를 확인했어요. 결과는 로컬 `build/himmel-*/`에 회수했고 필요한 작은 결과·화면만 이 문서에 연결해요.

## 공개 감사와 한계

Gitleaks8.30.1 공식 다운로드 해시를 먼저 확인했어요. 준비93커밋/33.13MB 뒤 clean 앱 소스까지 전체 ref94커밋/33.14MB를 재검사해 비밀값0을 확인했어요. [redacted 보고서](delivery/gitleaks-redacted.json), 인증 파일명 이력 검사도 의심 경로0. 원본 권리와 서드파티 고지를 보존했고 유료 모델 호출은0이에요.

공개 범위는 세 학습 과제, 조립·배선·코드/블록·기기 내 저장, 네 언어·개인 설정과 네 플랫폼 전달이에요. Windows는 publisher 서명 없음, Mac은 ad-hoc signing만 있고 실기 GUI·Developer ID·공증은 미검증이에요. 모든 브라우저/OS의 접근성, 실제 학생 학습 효과, 실물 물리 보정과 전시 로봇의 범용 지속 보행을 보장하지 않아요. 이족·Kit·RL의 신규 연구는 계속 보류해요. 기존 source별 실패와 연구 결과는 유지해요. 이번 후속 변경은 전달 증거와 검사기만 바꿔 UI/번역/데이터 계약/ERD·FlowChart 변경이 필요 없어요.

최종 문서 도구 `maintain.py --check`와10회귀 검사는 통과했어요. 설정 검사기는 같은 export의 실제14항목과 공개14항목으로 확인했어요. 전체 native71종은 clean 앱 소스 `af1973b`의 실행 결과이며 후속 문서·검사기 변경 뒤 전체 native를 다시 실행하지 않았어요.
