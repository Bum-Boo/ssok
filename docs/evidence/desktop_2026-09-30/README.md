# Windows 설치 프로그램·macOS Universal 앱 패키지 — 2026-09-30

## 최종 전달 파일·통합 빌드

최종 전달 파일은 main `6eacf39`를 합친 clean source
`d7a0b54b77b6ce60e4953b0facae37586a597248`, Godot `4.7.2.stable.official.ed1daf0bf`다.
빌드 시작/끝 HEAD와 작업실 상태가 같으며 `dirty_worktree=false`,
`source_changed_during_build=false`다. [최종 메타데이터](integrated/release.json),
[최종 SHA256](integrated/SHA256SUMS), [4대상 빌드 로그](integrated/build.log)를 보존했다.
Windows와 Mac 파일을 개인 Himmel에서 회수하고 파일 크기·SHA256 일치를 확인했다.

- Windows per-user setup: `build/desktop-main-windows/ssok-desktop-main-20260930-windows-x86_64-setup.exe`
  (110,048,203 bytes, SHA256 `286b4ac0d26d60f1b4a401ce55d23913a58df3b1c9e447936f2c7f9387a0fef7`).
- Mac Universal 2 app ZIP: `build/desktop-main-macos/ssok-desktop-main-20260930-macos-universal.zip`
  (135,235,648 bytes, SHA256 `7cf1a37bc9fd83e40c8678cf2d6a8d3cf0b8c8b7271df2b79555f02de91960d7`).
- 동일 source의 Web/Linux/Windows portable/installer ZIP도 remote export 성공.
  최종 전달 두 파일만 좁은 경로로 로컬 회수했다. binaries는 Git 미포함.

최종 native Windows **17항목/0실패**:
[checks](integrated/windows-native/checks.json), [정상 실행](integrated/windows-native/native.stdout),
[깃발](integrated/windows-native/stage-raise-flag.png),
[결승선](integrated/windows-native/stage-finish-line.png),
[벽 앞 정지](integrated/windows-native/stage-wall-brake.png).
actual UI에서 Stage3개를 각각 성공한 뒤 gated JSON export했고 정상 종료·설치 제거·등록/shortcut 해제·
추가 사용자 파일 보존까지 확인했다. 새 3개 PNG를 직접 검수했다.
PNG에서 기존 깃발 미션 상단 오버레이가 차량 Stage에서도 남는 현상은 있으나,
Stage picker/실측 성공 표시/검증된 각 stage.id의 export는 정상이다. 앱 UI 개선은 별도 출시 UX 범위다.
JSON들은 fresh-success export gate를 통과한 답안이며 별도 측정값 observer dump는 아니다.
[최종 Mac 구조/서명 존재 검사](integrated/export-logs/macos-bundle.json)는 두 아키텍처·실행 비트·
ad-hoc signature·resource seal 7개 성공; 실제 Mac 상호작용 미검증, Developer ID/notarization 없음.

`feat/39-desktop-installers`에 최신 main을 통합해 빌드 도구/문서 2개 충돌을 해결했다.
Windows/macOS도 main의 Stage identity JSON을 명시적으로 포함한다.
[통합 focused 검사](integrated-focused/SUMMARY.md) 6묶음/0실패.
[최신 GitHub 전체 검사](integrated/github-ci-d7a0b54.log): `d7a0b54`,
[run36701908984](https://github.com/Bum-Boo/ssok/actions/runs/36701908984), **70묶음/0실패**.
artifact storage quota 때문에 결과 upload만 실패하고 CI export job은 skip됐으므로 전체 workflow 성공은 아니다.
별도 개인 Himmel clean all4 export/native17 결과가 이를 구분해 검증한다.
최종 evidence 추가 후 [offline documentation 검사](final-offline.txt) 1/1 성공.
동시 설정 UI 작업은 포함하지 않았다. origin/main 대비 앱 GDScript·장면·부품·PO 변경 없음.
Apple Silicon texture import 설정 한 개만 추가했다. GL Compatibility/GodotPhysics3D/
정확 엔진 pin과 ADR0001/0013/0023 유지. 설치 UI en/ko/zh_CN/ja 4언어.

## 최초 frozen 후보 (기록 보존)

기존 6이슈 통합 코드에서 만든 첫 clean source `b374211`의
[메타데이터](release.json), [SHA256](SHA256SUMS), export/실패 결과도 그대로 보존했다.
그 후보의 Web/Linux/Windows portable/setup/installer ZIP/Mac 6개 파일은 모두 회수·SHA256 일치,
`build/desktop-packages/`에 있다. 사용자에게 전달하는 최신 파일은 위 `d7a0b54`의 두 파일이다.

## 검사 결과

- [로컬 focused 검사](local-focused/SUMMARY.md): import, scene, localization, mesh,
  desktop packaging 및 offline documentation — 6묶음, 0실패.
- [GitHub 전체 검사](github-ci-b374211.log): `b374211`, run `36695257158`,
  **67묶음/0실패**. 뒤 artifact upload는 저장 용량 quota로 실패해서 build job이 skip됐다.
  따라서 Actions run 전체 성공으로 표기하지 않는다.
- [export logs](export-logs/): 개인 Himmel에서 별도로 4대상 export,
  개발용 resource exclusion audit, Linux startup, pinned NSIS installer 모두 성공.
- [macOS bundle 검사](export-logs/macos-bundle.json): 실행 비트,
  x86_64+arm64 Mach-O, 두 slice의 ad-hoc signature command, signed resource SHA256 7개 검증.
  실제 Mac 실행은 미검증이며 Apple Developer ID/notarization도 없다.
- Windows native: 개인 Himmel의 실제 Windows/OpenGL3.3에서 **17항목/0실패**.
  설치·등록·shortcut·exact engine, UI로 Stage3개 각각 성공 후 gated JSON export,
  세 PNG 실제 화면, 정상 종료/engine error 없음, 제거·등록/shortcut 해제·추가 사용자 파일 보존.
  원본 [결과](windows-native/results/checks.json), [실행 로그](windows-native/results/native.stdout).
  [깃발](windows-native/results/stage-raise-flag.png),
  [결승선](windows-native/results/stage-finish-line.png),
  [초음파 정지](windows-native/results/stage-wall-brake.png) 실제 화면을 육안 검수했다.
  JSON들은 과제의 fresh-success export gate를 통과한 답안이며 실제 측정값 별도 observer 출력은 아니다.

## 실패와 제한

첫 macOS export는 ETC2/ASTC import가 없어 실패했다.
[원본 실패](initial-macos-format-failure.log)를 보존하고 프로젝트 import 설정을 수정해 재export했다.
초기 Windows 검사기는 PowerShell Start-Process의 ExitCode 수집이 불안정했다.
Diagnostics.Process로 수정했으며 초기 Stage 검사 timeout의 stdout/stderr도 보존하도록 개선했다.
원인은 release template이 `--script`를 지원하지 않아 외부 검사기가 실행되지 않는 것이었다.
실제 실행 파일의 help와 [Godot 4.7.2 source](https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp)의
`OVERRIDE_PATH_ENABLED` 분기를 확인하고, 검사 도구를 실제 Windows UI 입력 방식으로 교체했다.
unsafe template으로 바꾸거나 배포앱에 테스트 스크립트를 넣지 않았다.
실제 Windows 기본 앱 실행은 headless와 OpenGL 3.3/NVIDIA RTX 4060에서 모두 exit 0,
SCRIPT ERROR/ERROR 없이 확인했다. 그래픽 Stage 검사와 기본 실행을 구분한다.

Windows publisher signing과 Mac Developer ID/notarization은 제공하지 않는다.
실제 Mac 상호작용 검증 전 macOS 검증 완료로 표시할 수 없다.
공용 연구실 Mac에는 코드·개인자료를 전송하지 않았다. 유료 자원·인증서 사용 없음.
이번 범위는 빌드 도구와 전달 가능한 후보 파일, PR이며 공개 release/Pages 게시와 main merge는 별도다.

## 최종 개인 Himmel 작업

`20260930-192047-ssok-desktop-main-verified-5851e793`: 최신 main 통합 clean `d7a0b54`,
4대상 export/PCK exclusion+Stage identity audit/Linux startup/NSIS/Mac seals 성공,
Windows 실제 UI/lifecycle **17/17 PASS**, 완료 exit0. 자원 해제 확인.
Task-owned app 종료·test install 제거·등록/shortcut 제거 확인, 추가 synthetic user file 유지.
각 platform archive만 좁은 fetch로 회수했으며 모든 native/빌드 원본은 위 integrated evidence에 있다.

## 이전 개인 Himmel 작업

- `20260930-182408-ssok-desktop-native-v3-b32841c6`: clean 4대상 빌드 성공,
  후속 초기 Windows ExitCode 검사 실패. 해당 job 전체 exit1을 빌드 실패와 구분한다.
- `20260930-182914-ssok-windows-install-verify-cdde273d`: 설치/version 7항목 통과 후
  Stage timeout, task-owned 프로세스 종료 및 finally uninstall. 원본 결과 보존.
- `20260930-184850-ssok-windows-startup-probe-v2-431e5e0e`: headless/GUI 기본 실행 성공,
  완료 exit0, 자원해제 확인.
- `20260930-185912-ssok-windows-final-check-b0bb6a8a`: 지원되지 않는 외부 --script timeout,
  [stdout·stderr 원본](windows-script-timeout/results/stages.stdout) 보존.
- `20260930-190714-ssok-windows-native-ui-d7cc78f9`: foreground 획득 실패 후 task app 종료/제거.
- `20260930-190931-ssok-windows-native-ui-v2-40b00f63`: UI Stage3/정상종료 성공,
  uninstaller가 spawned child에서 등록을 지우기 전에 확인한 race로 1실패.
  [실패 결과](windows-ui-initial-checks.json), [로그](windows-ui-initial-failure.txt) 보존.
  앱 파일 삭제뿐 아니라 등록/shortcut 제거 완료까지 기다리도록 checker만 수정했다.
- `20260930-191252-ssok-windows-native-ui-final-96117619`: **17/17 PASS**, 완료 exit0,
  task-owned 앱 종료와 test install 제거, 자원 해제 확인. 추가 synthetic user file은 유지.

처음 2개 bootstrap job은 gh 환경 격리/전역 Git SSH rewrite 문제로 실패 후 종료됐다.
작업 제출이 전송 대기로 불명확했던 probe는 prepared 상태를 확인하고 취소한 뒤 별도 ID로 재제출했다.
전체 대용량 out fetch는 중단하고 완전 회수된 6개 아카이브를 원본 해시로 검증했다.
이후 검사 결과는 바이너리를 제외한 좁은 out 경로만 회수한다.
