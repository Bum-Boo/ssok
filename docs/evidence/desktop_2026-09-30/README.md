# Windows 설치 프로그램·macOS Universal 앱 패키지 — 2026-09-30

## 빌드 정체성

최종 설치 파일은 clean source `b374211e12a3ec1495229f6dfa188786121d24a0`,
Godot `4.7.2.stable.official.ed1daf0bf`에서 만들었다. 빌드 시작/끝 HEAD와 작업실 상태를
대조했으며 `dirty_worktree=false`, `source_changed_during_build=false`다.
[메타데이터](release.json)와 [SHA256](SHA256SUMS)에 6개 파일의 크기·해시가 있다.
다운로드 회수 후 6개 파일 모두 원본 SHA256과 일치했다.
로컬 최종 파일: `build/desktop-packages/` (Git에는 바이너리 미포함).

- Windows x86_64: per-user `setup.exe`, 해당 파일만 담은 installer ZIP, portable ZIP.
- macOS Universal 2: Intel x86_64와 Apple Silicon arm64를 포함한 `ssok.app` ZIP.
- Web·Linux 기존 대상도 같은 frozen source에서 export 성공.

기존 6개 이슈 통합 코드 `ed6ed32`를 바탕으로 별도 `feat/39-desktop-installers` 작업실에서
패키징했다. 동시 진행된 main 통합과 설정 UI 작업을 이 설치 파일에 포함했다고 주장하지 않는다.
앱 GDScript·장면·부품·PO 변경은 없다. Apple Silicon texture import 설정 하나를 추가했으며
GL Compatibility, GodotPhysics3D, 정확 엔진 pin, ADR0001/0013/0023을 유지했다.
NSIS 설치 UI는 en/ko/zh_CN/ja 4언어이며 사용자 권한만 사용한다.

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

## 개인 Himmel 작업

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
