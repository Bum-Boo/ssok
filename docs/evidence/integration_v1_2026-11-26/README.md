# 통합 v1 검증 기록 (2026-11-26)

- 브랜치: `Aura-the-Guillotine/ssok-integrate-v1`, 로컬 전용(push·PR 없음). 기준은 `origin/feat/part-cards-20261112` = `cf7a21d`.
- 병합: `37d80a3` 1단계 단순화(`673c28e`) → `5af00e8` E2 부품 정격(`a6ebf67`) → `a40023a` 벽 앞 정지 캐스터(`61f40cb`) →
  `65f2a61` 3D 배선(`c1ab787`) → `206e1ef` E3 초급 과정(`be3f293`). 이어서 `b999170` 정합화, `b755bd9` 릴리스 문서 번들, `1e5b99d` 첫 기록,
  `1ad5eaf` 정지 물리 수정(주인 결정 항목 44), 이 기록 갱신 커밋.
- 환경: Windows 11, Godot `4.7.2.stable.official.ed1daf0bf`(console). `tools/ci/verify.py`가 APPDATA·LOCALAPPDATA·`user://`를
  임시 폴더로 격리했어요. Python 3.14.7 venv(`tools/ci/requirements-lock.txt`, `mcp 2.2.0`), `PYTHONUTF8=1`.

## 충돌 해결과 정합화

- ADR 번호: 두 갈래 타이틀은 0043을 유지하고 초급 과정은 [0044](../../adr/0044-beginner-course-progressive-unlocks.md)로 옮겼어요.
  파일명·제목·INDEX·ADR 0036·DATA_MODEL·FLOWS·STATUS·테스트 주석을 함께 고쳤어요.
- 벽 앞 정지: 장면과 답지는 모두 `KitCarPreset.build_wall(0.8)`와 원래 `BRAKE_CODE`예요. E3 초안의 레거시 차·12 cm 제동 예외는 뺐어요.
  4단계 해금은 `car_chassis` 대신 소형 차의 `kit_plate_60_40`, `kit_beam_60`을 열어요(`wheel_65`, `hc_sr04` 유지).
- `scenes/main.gd`: 1단계 도움 메뉴·Lab 실험 묶음, 3D 배선·X-ray 갱신, E3 반조립 시작·레벨 탭은 자동 병합됐고 검사로 공존을 확인했어요.
- 번역: ko/ja/zh_CN은 E2·3D 배선·E3 항목을 모두 합쳤어요. 각 962개 msgid, 중복 0, `localization_check` 통과.
- 테스트: `game_flow_check`는 스테이지 도움 메뉴 검사와 E3 시작 코드 검사를 함께 둬요. `parts_tray_check`는 벽 예외 제거판에
  과정 트레이 무제한 열기를 더했어요. `stage_own_build_check`는 벽 접촉 구간 전에 대체 차 편집 그래프를 비워요.
  런 모드를 직접 만들면 편집기의 선택용 충돌체(레이어 1)가 x = 0.8에 남아 블록을 밀어냈어요. 실제 실행 모드에서는 조립이 비활성화돼요.
- 릴리스 문서: CODE_MAP이 링크하는 `presets/beginner_builds.gd`, `src/assembly/wire_visuals.gd`를 문서 번들에 추가했어요.

## 결과 (`1ad5eaf` 기준)

| 범위 | 결과 |
|---|---|
| import, scene-load | PASS |
| 헤드리스 Godot 검사 91개(변형 포함) | 91 PASS |
| Python 검사 14개 | 14 PASS |
| 반복 확인 | `power_net_check` 3/3, `kit_robot_runtime_check` 3/3 PASS. 세 번 모두 벽 0.05179 m, 0.00147 m/s, 접촉 0 |
| 렌더 모드 17개 | 미실행: 카메라 수명주기 13종, `bridge_stop_owner_check`, `agent_camera_rest_check`, `agent_camera_loop_check-rendered`, `agent_goal_ui_check-rendered`. 사용자 작업 중 창 팝업 금지 지시로 분기별 일괄 렌더 검증 대기 |
| 문서 | `maintain.py --check` 통과, `test_maintain` 10개 통과 |
| Web export | 4.7.2 공식 `web_nothreads` 템플릿으로 `--headless --export-release Web` exit 0, 오류·경고 0, `GODOT_THREADS_ENABLED = false`, `check_export.gd` 1098개 파일 0 실패, 수정 런타임 포함. 브라우저 실행·`browser_layout`·Playwright 게이트는 미실행 |

초급 5단계 답지 모두 물리 통과. 4단계 벽 앞 정지(배터리 탑재 소형 차)는 `kit_robot_runtime` 0.05179 m,
`beginner_course`·`stage_own_build` 0.0518 m, 0.0015 m/s, 접촉 0이에요. 결승선 0.506 m, 깃발 0.198 m예요.
첫 기록(`1e5b99d`)의 헤드리스 결과는 106/107이었고 `power_net_check`만 실패했어요.

## 정지 물리 수정 (`1ad5eaf`, 주인 결정 항목 44)

`power_net_check`의 두 실패(무전원 0.013 m, 스위치 끔 0.294 m)는 벽 캐스터 브랜치 `61f40cb`에서 넘어왔어요.
기준 `cf7a21d`는 통과했어요. 헤드리스 탐침으로 원인 세 가지를 찾았어요.

1. 볼 캐스터의 키트 구멍은 공 중심에서 10 mm 옆에 있어요. 구멍에 건 고정 관절은 바닥 반력을 각도 구속과 싸우는
   토크로 바꿨어요. 그래서 5 g은 떨리고 20 g은 큰 키트 차를 6.6 mm/s로 밀었어요. 레거시 마운트는 공 바로 위라 해당이 없어요.
   키트 구멍 캐스터 관절을 공 중심에 걸었어요.
2. 관절이 붙든 접촉 위의 미끄럼 마찰(0.01)이 래칫처럼 정지한 차를 1.7 mm/s로 밀었어요. 바퀴를 잠가도 같았고, 캐스터 마찰 0에서는
   사라졌어요. 4단계 차는 판정 뒤에도 15초 동안 0.0543 m에서 0.0362 m로 벽에 다가갔어요. 실제 공은 굴러요.
   그래서 공 구는 마찰 없이 미끄러지고, RunMode가 접촉 하중 비례 굴림 저항 0.01을 공의 움직임 반대 방향으로만 줘요.
   저항은 공을 멈추게 할 뿐 되돌리지 않아요. 측정 하중은 차 무게의 32%(2.08 N)예요.
3. `DriveMotor`는 구동하지 않는 축에 저항이 없었어요. 정착 충격이나 떨어진 배터리가 차를 계속 굴렸어요(0.157 m/s 유지).
   5 g 캐스터의 떨림이 우연한 제동으로 이를 가렸어요. 관성 주행·제동·무전원 TT 모터에 기어박스 마찰을 줬어요.
   크기는 정지 토크의 10%예요(사양 무부하 150 mA / 정지 1.5 A). 구동 중 모델은 무부하 속도에 마찰이 들어 있어 바꾸지 않았어요.

| 헤드리스 탐침 | 수정 전 | 수정 후 |
|---|---|---|
| 무전원 큰 키트 차, 2초 | 0.013 m | −0.0002 m |
| 스위치 끔 + 떨어진 배터리, 2초 | 0.294 m | −0.00002 m |
| 정지 소형 차 캐스터 최대 속도 | 0.0059 m/s | 0.0015 m/s 이하 |
| 4단계 판정 시점 → 15초 뒤 벽 간격 | 0.0543 → 0.0362 m | 0.0518 → 0.0515 m |
| 전원 켠 큰 키트 차 2초 주행(55%) | 1.02 m | 1.06 m |

레거시 캐스터 마운트의 질량(5 g)과 미끄럼 구는 그대로예요. 4단계 답지의 벽 간격 여유는 하한 0.05 m 대비 1.8 mm예요.
렌더 모드 카메라 검사는 TT 모터 차를 쓰므로 일괄 렌더 검증에서 확인해야 해요.

## 번역 영향

새 사용자 문구는 각 브랜치가 추가한 그대로예요. 통합에서 새로 만든 문구는 없어요.

## 그래픽 A안 후속 통합 (항목 49)

작업 범위는 `Aura-the-Guillotine/ssok-integrate-v1`에서 부품 메시·공작실 룩 두 브랜치를
통합하고 배선·물리·릴리스 번들을 같은 제품 흐름에서 검증하는 것이에요. 기준은 `50f4c47`,
병합은 `0118dd7`(메시 `3d74f50`)와 `e6d46ee`(룩 `9d19221`)예요.
헤드리스 전체 재검증은 앱·테스트 소스 `ba1077c`, Web 패키지는 CI 도구 보완을 포함한
깨끗한 `62997b4`에서 실행했어요. 그 사이 커밋에는 빌드 도구만 있어요.

- **결정과 씬.** 타이틀 ADR 0043과 초급 과정 ADR 0044를 유지하고 룩 결정은
  [ADR 0045](../../adr/0045-miniature-workshop-look.md)로 옮겼어요. ADR 색인, 문서 라우트와
  코드·검사 참조를 맞췄어요. `scenes/main.gd`는 타이틀·Lab 도움 메뉴, 초급 과정 탭·반조립 시작,
  3D 배선과 공작실 룩을 함께 연결해요.
- **배선과 재질.** `WorkshopMaterials`는 부품 표면별 재정의를 적용해요. 구조 부품에만
  알파 0.22의 전체 메시 `material_override`를 올리고, 토글을 끄거나 배선 패널을 닫으면 기존
  표면 재질을 복원해요. 패널 가시성 변경도 연결해 같은 탭으로 다시 열 때 상태를 갱신해요.
  `WireVisuals`가 포트 선택·배선 호버·미전원 표시를 별도 메시로 그려요. Lab의 전원선이 빠진
  키트 차로 X-ray와 세 표시의 공존, 토글·탭 전환·재열기를 확인했어요.
- **메시와 동작.** 새 LED는 `lens` 표면을 발광시키고 `glass` 돔 위치에 빌보드 후광을 붙여요.
  런타임 밝기 0.5에서 후광 강도 0.8, Stop 뒤 비표시를 확인했어요. 초급 1단계는
  `led_lit=1.0`을 1초 유지해 통과했어요. 키트 휠·기어·LED의 내장 PBR은 생성기와
  버텍스 배열·재질 이름·색·금속성·거칠기·투명도를 대조해요. 캐스터·휠·램프의 물리 회귀 검사도 통과했어요.
- **빌드와 문서.** 배포 문서에 메시 생성기와 재질 문서의 링크 대상을 추가했어요.
  브라우저 좌표 도구는 배선 전용 1·2단계를 열 때 숨겨진 프로그램 앵커를 건너뛰어요.
  다섯 초급 단계와 Lab을 순회해 앵커 100개를 생성했고 런타임 식별 해시를 갱신했어요.

| 검증 | 결과 |
|---|---|
| Godot 4.7.2 Windows headless | 108/108 통과. import·앱 시작 2개, Godot 92개, Python 14개 스위트. Windows에서 POSIX 실행 권한 왕복 케이스 1개는 조건부 건너뜀 |
| 배선·룩·키트 재질 | `wire_visuals_check` 31개, `workshop_look_check` 49개, `construction_kit_check` 13,702개 통과. `mesh_assets_check`, `material_assets_check` 통과 |
| 전원·물리·초급 과정 | `power_net_check` 30개, `kit_robot_runtime_check` 110개, `beginner_course_check` 214개, `stage_own_build_check` 194개, `parts_pack_environment_check` 21개 통과. 벽 간격 0.05179–0.05180 m, 속도 0.00147–0.00156 m/s, 접촉 0. 10°·20° 램프 등판 통과 |
| 씬·트레이·번역 | `game_flow_check`, `scene_workshop_ui_check`, `parts_tray_check`, `localization_check` 통과. 사용자 문구와 번역 변경 없음 |
| 문서 | `maintain.py --write`, `--review execution-flow`, `--check --base 50f4c47`, `test_maintain` 10개와 `test_release_documents` 1개 통과 |
| Web export | `build.py --platforms Web`, 공식 4.7.2 `web_nothreads_release.zip`, `--headless --export-release Web` exit 0, 오류·경고 0. `GODOT_THREADS_ENABLED = false` |
| Web 팩 | 기본 감사 1,101개 파일·실패 0. 추가 로드 감사 35/35(셰이더 7, 메시 12, 썸네일 12, 스크립트 4). PCK SHA-256 `63c4ac205cd57a575932c857a6d1a6b29dcd0319f78d0e5e70faca2f29feb394` |

초기 검증에서는 키트 재질 검사 23개와 배포 문서 링크 1개가 실패했어요. 키트 내장 PBR에는 생성기 대조를 적용했고 문서 번들에 링크 대상을 포함했어요. Web 빌드의 초기 실패는 배선 전용 단계의 숨은 프로그램 좌표와 좌표 생성 시간 초과였어요. 정합화 후 헤드리스 전체와 Web 빌드를 다시 실행했어요.

`verify.py --match '^(?!camera_evaluator_lifecycle_check-|bridge_stop_owner_check$|agent_camera_rest_check$|.*-rendered$).+'`로
헤드리스 목록만 실행했어요. 검사와 export의 APPDATA·LOCALAPPDATA를 각각 임시 폴더로 격리했어요.
로컬 근거는 `build/verification-integration-v2-final-task79400/` 및
`build/integration-v2-web-release-task79400/`에 있어요. Web ZIP은
`ssok-integration-v2-web.zip`(SHA-256 `602fee8e38a74785c24e152bc45526e67de9607fe427b58abca0b59faaae6475`)이에요.

### 분기별 일괄 렌더 검증 대기

| 분기 | 대기 항목 |
|---|---|
| `ssok-stage1-simplify` · `ssok-e3-beginner-stages` | 두 갈래 타이틀과 Lab 도움 메뉴, 초급 5단계 잠금·패널·결과 카드, 네 언어 화면 |
| `ssok-e2-part-specs` · `ssok-gfx-meshes` | 부품 정격 카드·트레이, 새 메시와 썸네일 12종, 램프 경계와 면 노멀 |
| `ssok-3d-wire-visuals` · `ssok-gfx-workshop-look` | 밝음·어두움 테마에서 빔·판의 X-ray와 복원, 포트 선택·호버·빨간 마커, 커팅매트·스냅·LED 후광·소나 시인성 |
| `ssok-wall-caster-fix` + `1ad5eaf` | 정지 상태와 TT 차의 카메라 정착. 카메라 수명주기 13종과 브리지/카메라/목표 UI 렌더 4종 |
| 통합 Web | 실제 WebGL 화면·스크린샷과 Playwright 게이트. 초기 잠금에 맞춰 기존 Raise a flag 바로가기 스모크 흐름도 확인 |

통합 검증에서는 사용자 요청에 따라 GUI·렌더 창과 브라우저를 열지 않았어요. GPU/WebGL의
셰이더 표시와 화면 시인성은 위 일괄 검증에 남아 있어요. 로컬 브랜치와 패키지까지 준비했어요.
