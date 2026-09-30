# 설정·테마·언어 구현 검증 — 2026-09-30

issue #38. 처음 `ed6ed32`에서 구현하고, 최신 main `6eacf39`를 합친 뒤 최종 앱 소스 `81914b6`를 검증했어요. 감사 당시의 소스와 별개이며 [설정 계약](../../INTERFACE_PREFERENCES.md), [ADR 0026](../../adr/0026-interface-preferences.md)를 따릅니다.

## 네이티브

Godot `4.7.2.stable.official.ed1daf0bf`, GL Compatibility, Intel HD Graphics 530/Mesa 26.2.1, X11에서 실제 화면을 캡처했어요. `tests/interface_preferences_check.gd -- --screenshots`는 **105 checks, 0 failures**예요([원문 로그](native.log)). 4개 언어의 작업 화면과 설정 창, 밝게/어둡게, 1024×768의 화면 글자 200%와 한국어 1400×950/200%를 기록했어요. 화면은 별도 수동 검수하며 자동 대비 검사는 지정한 팔레트 쌍에 한정해요.

관련 headless 검사는 import, scene-load, app controller, authoring UI, blocks, control flow, core authoring, flag mission, preferences, keyboard navigation, localization, manual control, stage authoring, viewport framing, workshop UI의 **15종**이에요. [첫 실행](focused-initial.json)에서 14종이 통과했고 flag mission은 새 autoload의 조기 클래스 컴파일로 실패했어요. 설정 의존성을 `_ready`에서 조회하도록 고친 [재검사](focused-recheck.json)에서 flag mission과 preferences가 통과했어요. 실패 기록을 성공으로 덮어쓰지 않아요.

최신 main 통합 후 [17종 검사](integrated-focused.json)는 모두 통과했어요. 브라우저 검수에서 발견한 메뉴 글자/창 제목/체크박스 보완 후 [관련 7종 재검사](theme-browser-recheck.json)도 모두 통과했어요. 메뉴 pressed 대비 [단일 재검사](pressed-recheck.json)와 네 언어 확대 경계 [관련 4종 재검사](enlarged-recheck.json)도 통과했어요. 최종 네이티브 검사는 메뉴 선택 대비와 unfocused 창 팔레트, 네 언어 200%의 패널 경계까지 포함한 105개이고 실제 PNG 12장을 모두 검수했어요.

```sh
python3 tools/ci/verify.py --match 'import|scene-load|interface_preferences_check|localization_check|keyboard_navigation_check|block_program_check|viewport_framing_check|workshop_ui_check|stage_authoring_check|authoring_ui_check|app_controller_check|control_flow_check|flag_mission_check|manual_control_check|core_authoring_check' --output build/settings-verification/final-focused
python3 tools/ci/verify.py --match '^flag_mission_check$|^interface_preferences_check$' --output build/settings-verification/final-recheck
XDG_DATA_HOME="$PWD/build/settings-verification/accepted-native-data" XDG_CONFIG_HOME="$PWD/build/settings-verification/accepted-native-config" godot --path . --language en --script tests/interface_preferences_check.gd -- --screenshots
```

## Web/Linux

`python3 tools/ci/build.py --version settings-38-accepted-20260930 --output build/settings-accepted-release`를 실행했어요. [release.json](release.json)의 소스는 **81914b6c4f70f6d2691cd05658e6ae42330c8f4a**, `dirty_worktree: false`예요. Web은 single-threaded이고 양쪽 pack의 리소스 검사와 Linux headless 실행이 통과했어요. ZIP은 로컬 `build/settings-accepted-release/`에 있으며 manifest에 SHA256과 크기를 기록했어요. 최종 증거 문서/브라우저 테스트 보정 커밋은 앱 코드가 같은 별도 후속 커밋이에요.

agent-browser 0.38.1에서 실제 Web 화면과 canvas, 엔진 관측, 오류/console를 확인했어요. Chromium 153.0.8010.12 설정 입력·저장·새로고침 검사는 `tools/ci/browser_settings.py`에서 **14개/0실패**, console/page 오류 0으로 통과했어요([결과](browser-result.json), [console](browser-console.json)). 한국어 전환, 두 글자 배율, 음소거/25%음량, 원본/초안 해시 보존, 시스템 변경/명시 테마 유지, 새로고침 복원과 한국어200% 패널 경계를 실제 입력으로 확인했어요. 첫 Web 검사는 headless popup 좌표가 실제 창 크기와 달라 실패했어요([첫 기록](browser-initial.json)). 좌표 수정 후 메뉴 입력이 선택 항목보다 하나 적게 이동한 [재검사 실패](browser-coordinate-recheck.json)도 보존했어요. Godot 메뉴는 마우스로 열 때 키보드 항목 포커스가 없으므로 실제 프레임 사이에서 `index + 1`번 이동하도록 테스트를 보정했어요. 이 실패는 설정 앱의 저장 실패로 해석하지 않아요.

## 범위

새 설정 16개 원문과 ko/zh_CN/ja 카탈로그를 함께 갱신했어요. 코드·그래프·블록 초안·탭·모드·실행 VM 보존, 언어 포커스, Esc 복귀, 저장값 검증/실패 안내, 확대, 음소거를 검사했어요. 모든 OS 외관 콜백, 모든 해상도, 스크린리더, WCAG 전체 준수를 인증하는 결과는 아니에요. 보행 연구 정책과 물리 성공 판정은 변경하지 않았어요.

브라우저의 앞선 `f77c1ed` 전체 설정 검사는 [13개 모두 통과](browser-previous-pass.json)했어요. 마지막 pressed 대비와 한국어 확대 경계 보완을 포함한 `81914b6`에서도 동일 흐름과 패널 경계까지 14개를 다시 통과했어요. 중간 [프로세스 중단](browser-interrupted.json)은 3개 통과 이후 종료 코드 143으로 끝났으며 성공으로 계산하지 않아요. 원격 작업을 제출하지 않았고 모든 검사는 로컬에서 진행했어요.

메뉴를 연 채 포인터를 두는 추가 상태의 글자 대비는 `7ad1ab4`에서 `font_hover_pressed_color`로 보완했어요. 실제 엔진 기본 테마의 상태 목록을 조회해 확인했고, 설정 저장·입력 계약은 이 변경에서 그대로예요. 후속 네이티브·깨끗한 export·실제 Web 메뉴 검수를 이어서 기록해요.
