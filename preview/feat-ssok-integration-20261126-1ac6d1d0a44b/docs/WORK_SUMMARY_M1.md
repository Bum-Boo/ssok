# M1 구멍에 끼우는 조립 조작

2026-11-05, Codex. 사용자 피드백인 “구멍끼리 끼워 쌓는 느낌이 없어요”를 해결하는 로컬 구현이에요.
브리프의 1~7을 대상으로 작업했으며 M2, 물리 파라미터, 보드 API, 블록 파서, 스테이지 판정,
워크플로와 기존 화면·글꼴 위계는 변경하지 않았어요. 푸시·병합·배포하지 않았어요.

## 소스와 작업 계약

- 작업실: `C:/Users/Hojun/agent-jobs/ssok-M1-20261105/repo`
- 브랜치: `feat/modular-build-20261105`
- 시작: `bf7faa2e611ab7e8bb0c2f1637e7e9229b3ab56a`, clean 상태였어요.
- 구현·번역·조작 검사: `e2b7753e567e0194525540e4eeecd0d1e0215ecf`
- 합격 기준: 시험 가능한 끼우기 API, 실제 입력, 다중 구멍 연결의 단일 Undo, 이동 취소·배선 보존,
  충돌 상자 피킹, 테마별 링·볼트·고스트, 네 언어 문구와 대상 검사예요.
- 작업 분리: AssemblyMode/API 검사는 총괄, main/camera 입력, 시각 표시/피킹, 번역/튜토리얼은
  각각 파일 소유를 나눠 구현했어요. 독립 Sol 검수의 입력 경계 지적 3건은 수정하고 실제 이벤트로 재검증했어요.

## 바뀐 것

- `AssemblyMode`의 `begin_place`, `begin_move`, `update_place_ray`, `rotate_place`, `cycle_anchor`,
  `flip_place`, `commit_place`, `cancel_place`, `placement_state`를 구현했어요.
- 기존 `snap()`과 새 고스트가 순수 함수 `align_port_transform()`을 함께 써요. 법선을 반대로
  맞춘 뒤 대상 법선 축으로 90도씩 돌려요. 같은 부품의 마지막 확정 앵커를 기억해요.
- 커서가 맞은 부품에서 빈 호환 구멍을 고르고, 빈 곳은 10 mm 바닥 격자에 놓아요.
  고스트의 각 충돌 상자를 2 mm씩 줄여 다른 부품과 비교하며, 회전 상자의 SAT로 막힘을 판정해요.
- 확정 시 앵커와 0.5 mm 이내의 빈 호환 반대 법선 구멍을 모두 연결해요. 1024 링크 한도를
  확인하고 부품·링크를 `_record_action()` 한 번으로 기록해요.
- 다시 끼우기는 기계 링크만 풀어요. 취소·Undo는 원래 위치와 기계 링크를 복원하고 배선을 보존해요.
- 트레이를 누르면 즉시 고스트를 집어요. 클릭 후 다음 클릭, 끌어서 3D에 놓기, 트레이로 되돌려
  놓기, 우클릭/Esc, R/Shift+R/휠, Tab/F, 4 px 초과 재이동을 연결했어요.
- GUI가 버튼을 잡고 있어도 레이를 갱신해요. 끼우기 중 휠은 카메라 확대를 하지 않아요.
  다른 트레이 부품을 누를 수 있고, 검색창에 포커스를 주면 취소해 입력한 R/F를 보존해요.
- 피킹은 `collision_boxes`를 사용해 빈 프레임을 통과해요. 기즈모는 레이어 2, 부품은 1을 쓰고
  선택 레이는 둘 다 봐요. 기존 G/R/숫자/Enter 경로는 유지해요.
- `PortIndicators`는 빈 기계 구멍 링과 링크당 육각 볼트 머리를 각각 MultiMesh로 그려요.
  대상 크기·축 색·밝고 어두운 테마를 적용하고, 실행 중에는 링을 숨기고 볼트가 실제 몸체를 따라가요.
- 영어 키 14개와 ko/ja/zh_CN 번역 42개를 PO와 JSON에 함께 넣었어요. 확정 개수와 이동 부품 이름은
  언어 전환 뒤에도 다시 번역돼요. 튜토리얼·작업실 안내는 끼우기를 먼저 가르쳐요.
- [작성 안내](AUTHORING.md), [조작법](CONTROLS.md), [흐름](FLOWS.md), [데이터 관계](DATA_MODEL.md),
  `context.json`과 생성 지도를 갱신했어요. 새 클래스의 오프라인 문서 링크가 패키지에서도 열리도록
  문서 소스 포함 목록을 추가하고 문서 패키지 검사는 UTF-8을 명시했어요.

## 명세와 다른 점과 이유

1. 트레이 안내는 목록의 첫 행에 있어요. 고정 제목 아래에 별도 행을 넣으면 1152×577 창에서
   기존 부품 스크롤 높이 100 px를 못 지켜서 목록 안으로 옮겼어요. 안내를 읽고 바로 부품을 집을 수 있어요.
2. 볼트는 두 접합 포트가 만나는 내부 면이 아니라 같은 구멍의 바깥 면에 표시해요. 접합면에
   그리면 인접한 빔 속에 묻혀서 보이지 않았어요. 그래프는 그대로이고 링크당 머리는 하나예요.
3. 두께 4 mm 이하 상자는 2 mm 축소 후 중심의 1 µm 평면을 남겨요. 음수 크기나 완전히 사라진
   충돌 상자로 깊은 침범을 놓치지 않게 했어요. 면 접촉은 허용해요.
4. 충돌 상자가 없는 옛 부품은 메시 AABB를 폴백으로 써요. 기존 카탈로그를 열고 선택할 수 있게 해요.
5. 다시 끼우는 부품의 원래 위치에는 링을 남기지 않아요. 숨긴 원본 위치에 링만 떠 보이는 문제를 피했어요.

## 실제 검증

환경은 Windows 네이티브, Python 3.13, Godot `4.7.2.stable.official.ed1daf0bf`,
GL Compatibility, NVIDIA RTX 4060이에요. 앱 소스와 주요 검사는 위 구현 커밋이에요.
문서 패키징 보완과 시각 검사 이미지의 `user://` 저장 경로 정리는 이 요약과 함께 후속 커밋에 들어가요.

```powershell
& $env:GODOT --headless --path . --import --quit
& $env:GODOT --headless --path . --quit
python tools/ci/verify.py --godot "$env:GODOT" --match '^(assembly_snap|blender_edit|blender_camera|core_authoring|construction_kit|construction_kit_ui|mesh_assets|parts_pack_inventory|stage_authoring|localization|snap_build|snap_build_input|port_indicators|authoring_ui)_check$' --output build/verification-target-m1
```

Import/load는 exit 0이에요. 대상 검사 실제 출력은 아래와 같아요.

```text
PASS assembly_snap_check
PASS authoring_ui_check
PASS blender_camera_check
PASS blender_edit_check
PASS construction_kit_check
PASS construction_kit_ui_check
PASS core_authoring_check
PASS localization_check
PASS mesh_assets_check
PASS parts_pack_inventory_check
PASS port_indicators_check
PASS snap_build_check
PASS snap_build_input_check
PASS stage_authoring_check
14 checks; 0 failures.
```

- `snap_build_check`: 35 checks, 0 failures예요. 순수 정렬, 법선 축 회전, 앵커 변경, 다중 링크,
  단일 Undo/Redo, 재이동 확정/취소, 배선 보존, 찬 구멍 제외, 겹침과 비호환 표면 거부,
  그래프 무변경, 바닥/격자/무링크 배치, 링·볼트 수를 검사했어요.
- `snap_build_input_check`: 35 checks, 0 failures예요. `Input.parse_input_event()`로 실제 GUI
  버튼·검색창·3D 입력을 통과시켰어요. 위 입력 경계와 언어 전환 뒤 상태 메시지도 확인했어요.
- `localization_check`: 58,817 checks, 0 failures예요. 새 키의 세 PO 등록과 자리표시자를 명시적으로 확인했어요.
- 튜토리얼: headless 576/0, 실제 GL 캡처 모드 624/0이에요. 바뀐 단계 0/2/3을 네 언어로 봤어요.
- 실제 끼우기 GL 캡처: 32 checks, 0 failures예요. 4언어 × 2테마 × 2크기 16장에 고스트,
  대상 링, 트레이 안내와 상태 문구가 보여요. GPU 버퍼 속성·런타임 볼트 이동은 실제 GL
  `port_indicators_check`에서 확인했어요. headless는 GPU 버퍼 검사를 대신하지 않아요.
- `python tools/docs/maintain.py --write`, `--review execution-flow`, `--review data-model`,
  `--check` 통과, 문서 도구 unittest 10개 통과예요. 저장 스키마·물리/VM 도식은 그대로이고
  새 조립의 임시 상태와 확정 흐름을 추가했어요.

전체 첫 실행 명령은 `python tools/ci/verify.py --godot "$env:GODOT" --output build/verification-full-m1`이에요.
개발 중 소스를 대상으로 117종을 실행해 실제 출력은 `117 checks; 4 failures.`였어요.

| 첫 전체 실패 | 관찰과 후속 |
|---|---|
| `authoring_ui_check` | 트레이 안내의 고정 행이 작은 창의 목록 높이를 줄였어요. 목록 첫 행으로 옮긴 뒤 최종 대상 검사에서 통과했어요. |
| `tests-motion_mcp_check.py` | `ModuleNotFoundError: No module named 'mcp'`예요. 새 의존성을 설치하지 않았어요. |
| `tests-test_release_documents.py` | 기본 cp949로 UTF-8 문서를 읽다 실패했어요. UTF-8 재실행에서 새 클래스/작성 중 요약 링크 누락도 발견해 문서 포함 목록과 요약을 보완했어요. |
| `tools-rl_lab-test_rl_lab.py` | `ModuleNotFoundError: No module named 'mujoco'`예요. 새 의존성을 설치하지 않았어요. |

브리프가 기준선으로 언급한 `workshop_run_label_check`는 이번 환경의 실제 실행에서는 PASS였어요.
고정한 앱 소스와 후속 문서/패키징 보완을 대상으로 최종 전체를 다시 실행했어요.

```powershell
$env:PYTHONUTF8 = '1'
python tools/ci/verify.py --godot "$env:GODOT" --output build/verification-full-final-m1
```

```text
PASS authoring_ui_check
PASS snap_build_check
PASS snap_build_input_check
PASS workshop_run_label_check
FAIL tests-motion_mcp_check.py
ModuleNotFoundError: No module named 'mcp'
PASS tests-test_release_documents.py
FAIL tools-rl_lab-test_rl_lab.py
ModuleNotFoundError: No module named 'mujoco'
118 checks; 2 failures.
```

116종 PASS, 환경 모듈 누락 2종 FAIL이에요. 실패를 통과나 skip으로 바꾸지 않았어요.
최종 전체에서도 import/load와 모든 Godot 검사가 통과했어요. 문서 패키지 검사는 기본 Windows
환경에서도 별도로 통과했고, CI 검증기와 함께 실행한 Python unittest 5개도 통과했어요.
[대상 전체 표](evidence/modular_build_m1_2026-11-05/target-summary.md)와
[최종 전체 표](evidence/modular_build_m1_2026-11-05/full-summary.md)를 저장했어요.

초기 병렬 작업 중 미완성 스크립트/클래스 캐시를 읽어 중단한 검사는 현재 PASS로 합산하지 않았어요.
사전 전역 instruction-health는 기존 신뢰되지 않은 스킬 마운트 33건 때문에 실패했어요.
해당 환경은 수정하지 않았고 저장소 지침·task 계약·실제 검증을 근거로 작업했어요.

## 화면 근거와 미검증

[한국어 작은 창](evidence/modular_build_m1_2026-11-05/ko-dark-1152x648.png)과
[영어 밝은 창](evidence/modular_build_m1_2026-11-05/en-light-1440x900.png),
[링·볼트 어두운 테마](evidence/modular_build_m1_2026-11-05/indicators-dark.png),
[링·볼트 밝은 테마](evidence/modular_build_m1_2026-11-05/indicators-light.png)를 보존해요.
전체 로컬 결과와 원본 이미지는 `build/verification-*-m1`,
`build/m1-input-user/Godot/app_userdata/ssok/snap_build_input_previews/`,
`build/m1-localization-user/Godot/app_userdata/ssok/tutorial_previews/`에 있어요.

Web export, 터치 조작, 실제 사용자 학습 효과와 M2는 미검증/미실행이에요.
실제 렌더에서 기존 영어 튜토리얼 Restart 및 일부 Add block 라벨의 말줄임을 관찰했어요.
이번에 바꾼 문구의 잘림은 없었고 기존 화면·글꼴 위계는 유지했어요.
유료 API 호출이나 제공자·과금 변경은 없어요. 트레이 탭/숨김 목록, 전자 부품 구멍과 답지 교체는 M2로 남아요.

## 사용자가 해 볼 것

1. Lab 빈 작업대에서 판을 집고 바닥을 클릭해 놓아 봐요.
2. 빔을 집고 판의 빈 구멍에 대면 링과 고스트가 맞는지 봐요.
3. R과 Tab, F를 눌러 빔 방향과 앵커를 고른 뒤 붙여 봐요.
4. 모터를 집고 빔의 빈 구멍에 끼워 볼트 머리가 생기는지 봐요.
5. 붙인 빔을 끌어 다시 끼우거나 Esc로 취소하고, Ctrl+Z 한 번으로 연결까지 돌아가는지 봐요.
