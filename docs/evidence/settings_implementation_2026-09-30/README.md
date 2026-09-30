# 설정·테마·언어 구현 검증 — 2026-09-30

issue #38. 통합 소스 `ed6ed32` 위에 적용했어요. 감사 당시의 소스와 별개이며 [설정 계약](../../INTERFACE_PREFERENCES.md), [ADR 0024](../../adr/0024-interface-preferences.md)를 따릅니다.

## 네이티브

Godot `4.7.2.stable.official.ed1daf0bf`, GL Compatibility, Intel HD Graphics 530/Mesa 26.2.1, X11에서 실제 화면을 캡처했어요. `tests/interface_preferences_check.gd -- --screenshots`는 **90 checks, 0 failures**예요([원문 로그](native.log)). 4개 언어의 작업 화면과 설정 창, 밝게/어둡게, 1024×768의 화면 글자 200%를 기록했어요. 화면은 별도 수동 검수하며 자동 대비 검사는 지정한 팔레트 쌍에 한정해요.

관련 headless 검사는 import, scene-load, app controller, authoring UI, blocks, control flow, core authoring, flag mission, preferences, keyboard navigation, localization, manual control, stage authoring, viewport framing, workshop UI의 **15종**이에요. [첫 실행](focused-initial.json)에서 14종이 통과했고 flag mission은 새 autoload의 조기 클래스 컴파일로 실패했어요. 설정 의존성을 `_ready`에서 조회하도록 고친 [재검사](focused-recheck.json)에서 flag mission과 preferences가 통과했어요. 실패 기록을 성공으로 덮어쓰지 않아요.

```sh
python3 tools/ci/verify.py --match 'import|scene-load|interface_preferences_check|localization_check|keyboard_navigation_check|block_program_check|viewport_framing_check|workshop_ui_check|stage_authoring_check|authoring_ui_check|app_controller_check|control_flow_check|flag_mission_check|manual_control_check|core_authoring_check' --output build/settings-verification/final-focused
python3 tools/ci/verify.py --match '^flag_mission_check$|^interface_preferences_check$' --output build/settings-verification/final-recheck
XDG_DATA_HOME="$PWD/build/settings-verification/native-accepted-data" XDG_CONFIG_HOME="$PWD/build/settings-verification/native-accepted-config" godot --path . --language en --script tests/interface_preferences_check.gd -- --screenshots
```

## Web/Linux

깨끗한 소스 커밋의 Web/Linux export와 Chromium에서 설정·새로고침·시스템 테마 전환을 이어서 검증합니다. 결과와 빌드 소스 커밋은 완료 후 이 문서에 추가해요. 아직 공개 배포 결과로 해석하지 마세요.

## 범위

새 설정 16개 원문과 ko/zh_CN/ja 카탈로그를 함께 갱신했어요. 코드·그래프·블록 초안·탭·모드·실행 VM 보존, 언어 포커스, Esc 복귀, 저장값 검증/실패 안내, 확대, 음소거를 검사했어요. 모든 OS 외관 콜백, 모든 해상도, 스크린리더, WCAG 전체 준수를 인증하는 결과는 아니에요. 보행 연구 정책과 물리 성공 판정은 변경하지 않았어요.
