# 설정·테마·언어 구현 검증 — 2026-09-30

issue #38. 처음 `ed6ed32`에서 구현하고, 최신 main `6eacf39`를 합친 뒤 설정 동작 `81914b6`, 메뉴 글자 보완 `7ad1ab4`, CI 회귀 수정 `d71a68d`를 차례로 검증했어요. 감사 당시의 소스와 별개이며 [설정 계약](../../INTERFACE_PREFERENCES.md), [ADR 0026](../../adr/0026-interface-preferences.md)를 따릅니다.

## 네이티브

Godot `4.7.2.stable.official.ed1daf0bf`, GL Compatibility, Intel HD Graphics 530/Mesa 26.2.1, X11에서 실제 화면을 캡처했어요. 앱 코드 `d71a68d`와 동일한 문서 커밋 `495e261`에서 `tests/interface_preferences_check.gd -- --screenshots`는 **107 checks, 0 failures**예요([원문 로그](native.log)). 4개 언어의 작업 화면과 설정 창, 밝게/어둡게, 1024×768의 화면 글자 200%와 한국어 1400×950/200%를 기록했어요. 화면은 별도 수동 검수하며 자동 대비 검사는 지정한 팔레트 쌍에 한정해요.

관련 headless 검사는 import, scene-load, app controller, authoring UI, blocks, control flow, core authoring, flag mission, preferences, keyboard navigation, localization, manual control, stage authoring, viewport framing, workshop UI의 **15종**이에요. [첫 실행](focused-initial.json)에서 14종이 통과했고 flag mission은 새 autoload의 조기 클래스 컴파일로 실패했어요. 설정 의존성을 `_ready`에서 조회하도록 고친 [재검사](focused-recheck.json)에서 flag mission과 preferences가 통과했어요. 실패 기록을 성공으로 덮어쓰지 않아요.

최신 main 통합 후 [17종 검사](integrated-focused.json)는 모두 통과했어요. 브라우저 검수에서 발견한 메뉴 글자/창 제목/체크박스 보완 후 [관련 7종 재검사](theme-browser-recheck.json)도 모두 통과했어요. 메뉴 pressed 대비 [단일 재검사](pressed-recheck.json)와 네 언어 확대 경계 [관련 4종 재검사](enlarged-recheck.json)도 통과했어요. 최종 네이티브 검사는 메뉴 선택 대비와 unfocused 창 팔레트, 네 언어 200%의 패널 경계까지 포함한 107개예요. 실제 PNG 12장은 앞선 `7ad1ab4` 검수본과 바이트가 모두 같고 대표 화면을 다시 확인했어요.

```sh
python3 tools/ci/verify.py --match 'import|scene-load|interface_preferences_check|localization_check|keyboard_navigation_check|block_program_check|viewport_framing_check|workshop_ui_check|stage_authoring_check|authoring_ui_check|app_controller_check|control_flow_check|flag_mission_check|manual_control_check|core_authoring_check' --output build/settings-verification/final-focused
python3 tools/ci/verify.py --match '^flag_mission_check$|^interface_preferences_check$' --output build/settings-verification/final-recheck
XDG_DATA_HOME="$PWD/build/settings-verification/final-native-data" XDG_CONFIG_HOME="$PWD/build/settings-verification/final-native-config" godot --path . --language en --script tests/interface_preferences_check.gd -- --screenshots
```

## Web/Linux

`python3 tools/ci/build.py --version settings-38-final-20260930 --output build/settings-final-release`를 실행했어요. [최종 release.json](release.json)의 소스는 **495e261b1eb237b7e3b6fde726caa17502a0c318**, 앱 코드는 `d71a68d`와 같고 `dirty_worktree: false`예요. Web은 single-threaded이고 양쪽 pack의 리소스 검사와 Linux headless 실행이 통과했어요. ZIP은 로컬 `build/settings-final-release/`에 있으며 manifest에 SHA256과 크기를 기록했어요. 후속 커밋은 증거/STATUS만 바꾸며 앱 코드와 export 도구는 같아요. 앞선 [CI 보완 전 manifest](release-before-ci.json)는 당시 결과로 보존해요.

agent-browser 0.38.1에서 실제 Web 화면과 canvas, 엔진 관측, 오류/console를 확인했어요. Chromium 153.0.8010.12 설정 입력·저장·새로고침 검사는 `tools/ci/browser_settings.py`에서 **14개/0실패**, console/page 오류 0으로 통과했어요([결과](browser-result.json), [console](browser-console.json)). 한국어 전환, 두 글자 배율, 음소거/25%음량, 원본/초안 해시 보존, 시스템 변경/명시 테마 유지, 새로고침 복원과 한국어200% 패널 경계를 실제 입력으로 확인했어요. 첫 Web 검사는 headless popup 좌표가 실제 창 크기와 달라 실패했어요([첫 기록](browser-initial.json)). 좌표 수정 후 메뉴 입력이 선택 항목보다 하나 적게 이동한 [재검사 실패](browser-coordinate-recheck.json)도 보존했어요. Godot 메뉴는 마우스로 열 때 키보드 항목 포커스가 없으므로 실제 프레임 사이에서 `index + 1`번 이동하도록 테스트를 보정했어요. 이 실패는 설정 앱의 저장 실패로 해석하지 않아요.

## 범위

새 설정 16개 원문과 ko/zh_CN/ja 카탈로그를 함께 갱신했어요. 코드·그래프·블록 초안·탭·모드·실행 VM 보존, 언어 포커스, Esc 복귀, 저장값 검증/실패 안내, 확대, 음소거를 검사했어요. 모든 OS 외관 콜백, 모든 해상도, 스크린리더, WCAG 전체 준수를 인증하는 결과는 아니에요. 보행 연구 정책과 물리 성공 판정은 변경하지 않았어요.

브라우저의 앞선 `f77c1ed` 전체 설정 검사는 [13개 모두 통과](browser-previous-pass.json)했어요. 마지막 pressed 대비와 한국어 확대 경계 보완을 포함한 `81914b6`에서도 동일 흐름과 패널 경계까지 14개를 다시 통과했어요. 중간 [프로세스 중단](browser-interrupted.json)은 3개 통과 이후 종료 코드 143으로 끝났으며 성공으로 계산하지 않아요. 원격 작업을 제출하지 않았고 모든 검사는 로컬에서 진행했어요.

메뉴를 연 채 포인터를 두는 추가 상태의 글자 대비는 `7ad1ab4`에서 `font_hover_pressed_color`로 보완했어요. 실제 엔진 상태 목록과 네이티브 107개 검사, 깨끗한 `7510cc9` export 및 [실제 Web 메뉴 화면](web-menu-final.png)을 확인했어요. 메뉴를 연 상태에서도 선택 버튼의 글자가 읽혀요. 전체 Web 14개 결과의 소스는 `81914b6`이며, 마지막 글자 색상 보완을 포함한 14개 재실행으로 해석하지 않아요.

## 전체 CI 회귀 수정

[`81914b6` 전체 CI](https://github.com/Bum-Boo/ssok/actions/runs/36700827668)는 **70종 중 5종 실패**했어요([요약](ci-initial.json)). 브라우저 관측 노드의 새 autoload 전역을 초기 컴파일 때 찾지 못했고, 설정 테스트의 언어 저장값이 뒤 검사에 남아 learned/motion/pickup의 영문 기대값 3종이 실패했어요. 배포 문서 파일지도에서 새 설정 소스 2개로 가는 링크도 빠졌어요. 별도로 GitHub artifact 저장 한도 때문에 로그 업로드도 실패했어요.

`d71a68d`는 브라우저 설정 참조를 `_ready` 조회로 바꾸고 관측 종료 시 인터페이스 값도 지워요. 테스트는 실제 언어 선택을 검증한 뒤 원래 파일 유무/바이트와 언어를 복구해요. 배포 문서 참조 목록에는 두 설정 파일을 포함하고 BUILD에 공유 테스트 저장소 복구 규칙을 추가했어요. import/scene-load와 실패 5종, preferences를 함께 실행한 [재검사 8종/0실패](ci-regression-recheck.json)를 확인했어요. [`d71a68d` GitHub 전체 재검사](https://github.com/Bum-Boo/ssok/actions/runs/36702431582)는 **70종/0실패**예요([요약](ci-final.json)). 문서 CI도 통과했어요. 결과 업로드 단계만 artifact 저장 한도로 실패해 전체 workflow는 failure이며 후속 CI 빌드는 실행하지 못했어요. 설정 앱 검사 실패로 표현하지 않으며 로컬 최종 Web/Linux export는 위 manifest로 보존해요.

최종 깨끗한 `495e261` Web을 agent-browser에서 다시 열어 WebGL/관측값, 톱니바퀴와 테마 메뉴의 실제 입력, 밝은 메뉴 대비를 확인했어요([최종 관측](web-final-menu.json), [화면](web-menu-final.png)). page/console 오류 0이고, `Preferences` 참조가 `_ready` 이후에 조회되어 관측이 정상 출력돼요. 전체14흐름은 `81914b6`, 마지막 메뉴/초기 조회는 `495e261`이라는 검사 범위를 구분해요. 최종 네이티브·전체 검사는 설정 저장과 동작을 같은 앱 코드에서 확인해요.

로컬 전체 실행은 앱 코드 `d71a68d`로 **70종 중 69통과/1실패**였어요([전체 기록](local-full.json)). 실행 중 후속 증거 문서가 바뀌었지만 앱/테스트 코드는 같아요. MCP 검사는 의도적으로 PATH 조회를 제거하는데 명령에서 Godot을 절대 경로로 지정하지 않아 하위 서비스가 엔진을 못 찾았어요. 아래처럼 실제 핀 엔진 경로를 명시한 [동일 MCP 재검사 1종/0실패](mcp-pinned-recheck.json)를 확인했어요. 이 결과를 로컬 단일 70/70이라고 쓰지 않아요. GitHub의 전체70/0은 처음부터 절대 엔진 경로를 지정한 별도 전체 실행 결과예요.

```sh
/home/bumboo/Projects/ssok-release/build/venv/bin/python tools/ci/verify.py --output build/settings-verification/full-final
/home/bumboo/Projects/ssok-release/build/venv/bin/python tools/ci/verify.py --godot /home/bumboo/.local/bin/godot --match '^tests-motion_mcp_check.py$' --output build/settings-verification/mcp-pinned-recheck
python3 tools/docs/maintain.py --check --base 6eacf39
python3 -m unittest discover -s tools/docs -p 'test_*.py'
```

문서 검사와 도구 테스트10개도 최종 변경에서 통과했어요. 추가 실험/유료 자원/외부 제공자 호출 없이 구현·검증·리뷰 전달까지 완료했으며 main 병합과 공개 배포는 별도예요. 다음 세션은 START_HERE의 preferences 경로와 이 기록으로 시작해요.
