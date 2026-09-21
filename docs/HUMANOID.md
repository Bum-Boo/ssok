# 실제 물리 사람형 로봇 — 실험용

2026-09-22. **걷기·느린 후진·접촉 후 상자 집기/놓기를 검증했다. 달리기는 실제 공중 구간과 20초 자세 유지 기준을 통과했으나 직진 제어는 미완료다.**
기존 네 서보 이족 로봇과 별도 예제이며, 사람 동작을 학습한 모델이나 실제 하드웨어용 제어기가 아니다.

## 직접 실행

**새 기본 부품 조립 키트**는 아래 진입점에서 연다. 빔·판·브래킷·연결 부품이 각각
별도 오브젝트이며, 같은 카탈로그로 휴머노이드와 다리 구조물을 조립한다.

```sh
godot --path . --language ko --script tools/godot/play_construction_kit.gd
```

최종 Blender 편집 원본은 `assets/blender/ssok_construction_kit_verified.blend`다.
이전 `ssok_modular_humanoid.blend`는 몸통/팔다리가 하위 조립품으로 합쳐진 구형 프리팹이며
과학상자식 기본 부품 키트가 아니다. [키트 구성](CONSTRUCTION_KIT.md),
병렬 학습/저장은 [집기 실험실](PICKUP_LAB.md) 참고.

아래는 호환성을 위해 유지한 **기존 블록형 물리 프로토타입**의 진입점이다.

```sh
godot --path . --language ko --script tools/godot/play_humanoid.gd
```

일반 앱에서도 왼쪽 `예제: 사람형 로봇 (실험용)`을 고르면 같다. 상단 실행 모드를 켜고
3D 화면을 클릭한다. 처음에는 2~3초 자세가 안정될 때까지 기다린 뒤 E를 눌러 집기를 체험한다.
실행 진입점은 편집 상태로 시작하며 자동으로 조종하거나 유료 API를 호출하지 않는다.

- W/S 또는 스틱 위/아래: 전진 / 느린 후진. A/D 회전은 아직 지원하지 않는다.
- Shift 또는 게임패드 B 누르고 이동: **달리기 실험**. 평지 회귀 검사에서 비행·착지·자세 유지 기준을 통과했지만 옆으로 흐르며 방향 제어를 보장하지 않는다.
- E 또는 게임패드 X: 가까운 정면 상자를 집거나 놓는다. 웅크리기·양손 뻗기·들어 올리기에 몇 초가 걸린다.
- Space/게임패드 A: 이동 제동. 정지·코드 조종 전환·튜토리얼 열기는 잡기도 해제한다.
- 넘어지거나 집기가 실패하면 실행 모드를 껐다 켜서 원래 그래프 자세로 초기화한다.

기본 상자는 바로 앞에 있어 걷기 경로를 막는다. 걷기만 시험할 때는 편집 상태에서 상자를 선택해
G X 1000 Enter로 옆에 옮긴다. 평지와 기본 치수·질량·관절 구성을 대상으로 하며 지형 적응,
자율 접근/방향 정렬, 낙상 복구, 운반 보행은 보장하지 않는다. 책 아이콘의 7번째 안내에서도 설명한다.

## 물리와 제어

`HumanoidPreset`의 그래프가 14개 강체(몸통·머리·가상 보드·10개 관절 부품·상자),
기계 연결 12개와 배선 10개를 소유한다. 초기 배선은 가상 보드의 20~29지만, 프로그램은 번호를
하드코딩하지 않고 실제 연결에서 역할별 핀을 해석한다. 기존 보드/언어 계층은 변경하지 않았다.

`ServoDrive`는 사람형 부품에만 지정한 토크 제한과 해부학적 각도 한계를 사용한다. 위치 오차를
힌지 모터의 제한 각속도로 바꾸고 프레임당 임펄스를 토크/물리 주파수로 제한한다. 고관절·무릎
35 Nm, 발목 30 Nm, 어깨·팔꿈치 12 Nm는 이 가상 모델의 설정이지 실물 모터 측정값이 아니다.
이동은 관절 반작용과 바닥 접촉으로 발생한다. 몸통 추진력, 위치 덮어쓰기, 중력 해제는 없다.

보행은 교대 다리 목표와 몸통 피치 피드백, 집기는 웅크리기/팔 도달/들기/유지 상태를 사용한다.
양손 강체가 상자에 실제 접촉한 뒤에만 임시 PinJoint 두 개로 잡기를 유지한다. 손가락의 마찰만으로
버티는 정교한 파지 모델은 아니며, 상자는 두 접촉점을 축으로 흔들릴 수 있다. 잡기는 그래프에
저장하지 않고 놓기·제어 전환·노드 해제 시 제거한다.

[SIMBICON](https://www.cs.ubc.ca/~van/papers/Simbicon.htm)의 자세 상태/균형 피드백 접근을
참고했지만 전체 제어기를 재현한 것은 아니다. 구현 경계는
[ADR 0009](adr/0009-humanoid-actuation-and-contact-grasps.md)에 기록했다.

## 측정 결과

Godot 4.7.2, GodotPhysics, 60 Hz, 평지, 20초 시뮬레이션(3초 정착 후 명령).
거리/자세는 실제 강체에서 읽고 공중 구간은 양발의 바닥 접촉 부재와 발바닥 모서리의 2 mm 이상
높이를 함께 검사한다. 아래는 정해진 시작 조건의 회귀 결과이며 모든 환경에서의 성공률은 아니다.

| 검사 | 관측 | 결과 |
|---|---|---|
| 전진 | 약 0.840 m, 최소 몸통 수직 내적 0.998 | 33 검사 통과 |
| 느린 후진 | 약 -0.200 m, 최소 수직 내적 0.996 | 33 검사 통과; 전진보다 느림 |
| 링크 A/B 순서 반전 후 전진 | 약 0.813 m | 33 검사 통과 |
| 집기·유지·놓기 | 양손 접촉 후 약 0.424 m 상승, E 해제 후 중력 낙하 | 39 검사 통과 |
| 달리기 | 약 0.994 m 전진, 최소 수직 내적 0.971, 실제 공중 49프레임·최대 연속 5프레임 | 35 검사 통과; 옆으로 약 0.367 m 흐름 |

달리기는 양다리의 실제 신전/굴곡 주기와 로봇 전체 질량중심·속도 피드백을 발목 모터에
적용한다. 토크 한계, 관절 축, 질량, 충돌 형상과 중력은 바꾸지 않았다. 피드백 질량에는 기계적으로
연결된 로봇만 포함하며 떨어진 상자나 작업실의 별도 부품은 포함하지 않는다.

정착 시간을 119/120/179/180/181/239/240프레임으로 바꾸고 각 경우 링크 A/B도 뒤집은
원격 14개 조건 모두 원래의 전진·자세·비행 기준을 통과했다. 전진 0.529–1.160 m,
최소 수직 내적 0.964 이상, 공중 21–77프레임, 연속 2–7프레임이었다. 다만 좌우 변위의
절댓값은 최대 0.873 m였으므로 정밀 직진이나 사람 같은 달리기의 증거는 아니다.
[원격 검증 기록](evidence/legacy-humanoid-run.json)에 각 조건을 보존했다.

```sh
godot --headless --path . --script tests/humanoid_contract_check.gd
godot --headless --path . --fixed-fps 60 --script tests/humanoid_motion_check.gd -- walk
godot --headless --path . --fixed-fps 60 --script tests/humanoid_motion_check.gd -- backward
godot --headless --path . --fixed-fps 60 --script tests/humanoid_motion_check.gd -- pick
godot --headless --path . --fixed-fps 60 --script tests/humanoid_motion_check.gd -- walk --reverse-links
# Includes actual bilateral flight measurements; lateral drift remains a limitation.
godot --headless --path . --fixed-fps 60 --script tests/humanoid_motion_check.gd -- run
godot --headless --path . --script tests/humanoid_ui_check.gd
godot --path . --script tests/humanoid_ui_check.gd -- --screenshots
```

추가 검증: 계약 58개, 사람형 UI headless 96개 통과. 실제 GL 앱에서도 E 입력→집기→유지→안내 열기 시
놓기 흐름과 한중일 작업실 화면을 확인했다(화면 캡처 당시 27개; 이후 번역 누락 검사를 추가했다).
한중일 새 부품·상태·튜토리얼 문구를 함께 갱신했다. 언어팩 19,929개, 튜토리얼 headless 396개 /
GL 화면 포함 428개, 작업실 120개 검사 통과. 캡처는 `user://humanoid_previews/`, `user://tutorial_previews/`.

기존 run_mode, biped_motion, manual_control, control_flow, blender_edit, mesh_assets,
material_assets 검사도 통과했다. motion_lab 핵심 232개와 UI 36개는 통과했으나 외부 서버 통신 fixture는
환경 변수 미지정으로 건너뛰었다. headless import/씬 로드 및 git diff --check 통과.
웹 내보내기, 실물 게임패드 장치, 실제 GPT 호출/학습, 실물 로봇 전이는 이번 변경에서 검증하지 않았다.
위 검증 수치는 기존 블록형 구현 시점의 기록이다. 현재 사람형/모듈형에서는 AI 버튼이
별도 집기 실험실을 열며, 네 서보 로봇은 이전 보행 실험실을 사용한다.

## 구형 하위 조립품 모델의 검증 기록

이하 수치는 새 기본 부품 키트가 아닌 구형 `ModularHumanoidPreset`의 기록이다.
같은 Godot 4.7.2/60 Hz에서 전진 약 0.862 m, 최소 수직 내적 0.998,
집기 약 0.421 m 상승과 실제 양손 접촉·유지·중력 해제를 확인했다. 링크 A/B 순서를
뒤집어도 약 0.418 m 상승했다. 단독 계약/동작 검사는 각각 걷기 431개, 집기 435개,
링크 반전 집기 435개 통과했다. 병렬 월드 4개에서도 각 상자를 약 0.417 m 들고 1초 유지했다.
이는 정해진 초기 조건의 회귀 검사이며 범용 성공률이나 실물 안전성에 대한 보장이 아니다.
달리기와 독립 손가락 구동은 여전히 검증된 기능에 포함하지 않는다.
