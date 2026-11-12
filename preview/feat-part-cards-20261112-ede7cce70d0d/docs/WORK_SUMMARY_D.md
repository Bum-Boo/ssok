# 작업 D — 빈 작업대에서 직접 만들어 깨는 스테이지

2026-10-22 · Codex · feat/own-build-20261022 로컬 후보. 통합·공개 배포는 하지 않았어요.
시작 소스 b1ce03e8d8147d70b660e59e9f54a05f6c5a8b9e, 시작 dirty 없음.
B ref는 fbf2d6392e0222e62010aa98a7318dce256e479c예요.
B 병합 커밋 bea708a. 최종 앱/검사/자산/도구 소스는 e9aadea47d26f43f4822db22e14af93557903a7b예요.
최종 검사 전후 959개 추적 소스의 SHA-256이 같고 불일치 0개예요.
manifest SHA-256: 7df8311a69b51ede84af92932643b7b262e1e7cc8f54368bdab91cd77b21cff7. 파일별 해시는 build/own-build-final3/source-sha256.json,
재확인은 source-verify.json이에요. 뒤의 인계 커밋은 문서뿐이에요.

## 바뀐 것

새 스테이지는 빈 그래프/코드와 전체 81종 부품으로 시작해요. 80종에서 과제 깃발 1종만 추가했어요.
Blocks·Code·Wiring·Controls와 뷰포트 도구를 열 수 있고 A-5 목표 스트립과 화면 규칙은 유지해요.
깃발은 기존 OBJ→공유 Orange 재질→ArrayMesh 경로를 쓰며 make_stage_flag.gd로 재생성해요.
답지 보기/처음부터 만들기는 확인 후 교체해요. 답지 사용과 통과 배지, 스테이지별 조립·코드는 로컬에 남아요.
Back/list/next 저장에 실패하거나 블록 초안이 충돌하면 편집기를 떠나지 않아요. 복원은 코드를 실행하지 않아요.

## 판정과 선택 이유

v2를 확장해 기존 v1/v2와 명시적 대상·증거 계약을 유지했어요. 전체 대상은 part_id="*", target_index=-1이에요.
min_x는 모든 로봇 부품 경계의 최소 x, max_height는 최고 y, robot_speed는 최대 몸체 선속도예요.
wall_distance는 환경 벽과 로봇 부품 사이의 최소 경계 거리(m)예요. 센서 위치/값을 성공 기준에 넣지 않아요.
경계는 실제 변환을 적용한 메쉬 AABB예요. 회전하거나 둥근 부품에는 보수적인 외접 경계이며 임의 형상의 정확한 삼각형 간 최단거리라고 주장하지 않아요.
wall_contact는 어느 부품이든 실제 벽 접촉이 한 번 있으면 해당 시도 내내 유지해요.

깃발은 과제 부품이에요. 표준 마운트로 다른 받침에도 붙일 수 있고 기존 팔에는 끝 연결점만 추가했어요.
기존 팔의 메쉬/질량/서보 물리는 그대로예요. 기존 답지에 깃발만 덧붙였고 답지 코드는 유지했어요.
접촉으로 환경 깃발을 퍼올리는 방식보다 연결·실행·높이 관측이 안정적이고 학습자가 깃발을 다른 기구에 붙일 수 있어 선택했어요.
모든 깃발의 최고 높이가 0.155 m 이상 1초면 통과하며 서보·팔·핀을 판정 전제에 넣지 않아요.
결승선은 모든 부품 경계가 x=0.5 m를 넘으면 통과하고 자세 제한은 없어요.
벽은 가장 가까운 경계가 5~10 cm, 최대 속도 <=0.015 m/s를 0.3초 유지하며 접촉 이력이 없어야 해요.
벽은 스테이지 환경의 실제 StaticBody3D예요. 기존 Lab 답지의 그래프 벽은 유지하며 스테이지 로더에서 중복만 제거해요.
대체 섀시·4바퀴와 센서/서보 없는 구성은 규칙 fixture 검사예요. 이 구성들의 실제 주행/기구 성공까지 주장하지 않아요.

## 직접 커밋

1. bea708a — B를 두 부모 merge로 결합.
2. e018ed2 — 전체 로봇 지표·과제 깃발·환경 벽.
3. 22fff16 — 빈 진입·스테이지 작업 보존·확인 후 답지.
4. 83e4d7e — 조립 안내와 네 언어.
5. 1325c42 — 확인창 크기와 내 조립 안내.
6. be1a739 — 새 빈 작업대/회귀 검사.
7. 0f31f39 — 릴리스 문서의 작업실 소스 누락 보완.
8. fbc2908 — 깃발 OBJ/공유 재질 경로.
9. c1ac185 — 저장 실패로 남은 실행/관측 중단.
10. e9aadea — 깃발 원본 메쉬 버퍼 보존.

이번 커밋은 영어 imperative 메시지이며 사용자 요청대로 trailer를 넣지 않았어요.
최종 문서/인계 커밋은 이 목록 뒤에 있어요.

## 실제 검사 출력

엔진 build/toolchain/godot, 4.7.2.stable.official.ed1daf0bf, Linux headless, --fixed-fps 60.
각 실행은 /tmp의 XDG data/config/cache를 격리했어요. 표준 실행:

    python3 tools/ci/verify.py --godot build/toolchain/godot --output build/own-build-strict-final

위 명령은 mock HTTP 서버 생성에서 PermissionError: [Errno 1] Operation not permitted로 종료했어요.
strict-runner.log에 보존했으며 전체 검사를 실행했다고 세지 않아요. 같은 CI 목록·명령·timeout·engine-error
gate를 재사용한 진단 명령은 다음이에요. mock/render 실패를 제외하거나 통과로 바꾸지 않아요.

    python3 docs/evidence/own_build_2026-10-22/run_checks.py --output build/own-build-final3

**최종 109개 suite: 83 PASS / 26 FAIL. 전체 suite 통과 기준은 미충족이에요.**
[전체 결과·재현 도구](evidence/own_build_2026-10-22/README.md)와 build/own-build-final3/results.json,
SUMMARY.md, 각 NAME.log에 명령·시간·exit·출력을 남겼어요. 관련 최종 실제 출력:

```text
stage_own_build_check: 164 checks, 0 failures
stage_contract_check: 31 checks, 0 failures
stage_authoring_check: 42 checks, 0 failures
stage_ui_check: 36 checks, 0 failures
game_flow_check: 43 checks, 0 failures
scene_workshop_ui_check: 382 checks, 0 failures
workshop_compact_check: 2320 checks, 0 failures
workshop_emphasis_check: 6816 checks, 0 failures
workshop_goal_space_check: 10032 checks, 0 failures
workshop_goal_observation_check: 4392 checks, 0 failures
workshop_presentation_check: 504 checks, 0 failures
workshop_road_check: 98 checks, 0 failures
workshop_run_label_check: 72 checks, 0 failures
workshop_ui_check: 444 checks, 0 failures
localization_check: 56306 checks, 0 failure(s)
sonar_stage_check: 15 checks, 0 failures
flag_mission_check: 10 checks, 0 failure(s)
material_assets_check: 27 materials, 20 parts, 96 surfaces, 0 failure(s)
mesh_assets_check: 0 failure(s)
```

- 세 답지는 실제 물리 성공을 확인했고, 짧은 주행은 program_finished / not_met였어요.
  다른 섀시·4바퀴의 전체 위치 규칙, 한 바퀴 미달, 센서 없는 벽 거리, 속도 미달,
  실제 벽 충돌과 이후 접촉 이력, 여러 깃발/서보 없는 대상, 1초 유지, 잘못된 집합 target_index를 검사해요.
- 답지 확인/취소/교체, 실제 답지 통과 배지와 카드 표시, 스테이지별 왕복 복원·자동 실행 없음,
  v1 진행 기록 보존, 독립 통과 우선, 저장 실패 시 편집 복귀/실행 취소, 충돌한 블록 초안 보존을 확인했어요.
- 새 확인창은 네 언어 × 밝게/어둡게 × 기본/200% × 큰/작은 창에서 번역·범위·취소 키보드 포커스를 확인했어요.
  기존 작업실 검사도 네 언어·테마·확대 기하/툴팁/글리프 존재 검사를 유지했어요.
- import는 exit 0이나 editor TCP 소켓 오류로 FAIL이에요. scene-load는 exit 0 / 오류 없음이에요.
- python3 tools/docs/maintain.py --check: PASS. 문서 도구 unittest 10개: OK.
  릴리스 문서 압축/해제 검사: PASS. git diff --check: PASS.

## 병합 기준선·실패 수정 이력

- bea708a의 별도 복사본을 CI 목록으로 실행했어요. 복사본과 해당 Git tree의 blob 불일치 0개예요.
  최초 번역 검사 파일이 불완전해 timeout한 기록을 남겼고, 양 부모의 전체 파일을 복원해 병합 커밋을 정정한 뒤
  같은 기준선의 localization_check를 별도 재실행해 통과했어요. 이 보완을 명시한 병합 기준선은 108개 / 27 FAIL이에요.
  첫 원본 집계 108개 / 28 FAIL과 후속 로그를 모두 보존했어요. 병합 당시 기능 변경은 없었어요.
- 두 브랜치의 독립 ADR 0030은 내용 합집합을 유지한 뒤 B를 0035로 재번호하고 링크/색인을 갱신했어요.
  D는 0036이에요. 문서 검사에서 드러난 모호성을 해결했으며 B의 결정 본문/범위는 유지했어요.
- 병합 기준선의 릴리스 문서에 끊긴 소스 링크 8개가 있어, 작업실 소스 5개를 패키지의 기존 복사 목록에 추가했어요.
- 첫 전체 D 검사에서 깃발의 inline BoxMesh/재질 규약이 자산 검사 2개를 깨뜨렸어요.
  OBJ와 공유 Orange/ArrayMesh로 전환했고, 첫 변환의 버퍼 재조립 오차도 원본 mesh 복제로 수정했어요.
  자산 검사 기준은 완화하지 않았고 새 부품 수 19→20만 반영했어요. 마지막 전체 검사에서는 둘 다 PASS예요.
- 첫 확인창 검사 24개 실패는 Label.text의 원문을 번역 결과와 직접 비교한 잘못된 assertion이었어요.
  자동 번역 원문은 유지하며 tr() 결과로 검증하고, 창 범위/포커스 검사는 유지했어요.
  중간 실패 출력은 build/own-build-own4, own-build-final, own-build-fix-assets에 보존해요.
- 물리·모터·센서 모델·VM·보드 API·project.godot·.github/workflows는 B 병합 뒤 diff가 없어요.
  추가 외부 의존성·제공자·과금 변경은 없어요. 새 task flag와 팔 끝 연결점만 추가했어요.

## 못 한 것·인계 checkpoint

남은 26 FAIL은 아래와 같아요. 실패를 숨기거나 Linux 전체 통과로 보고하지 않아요.

| 환경/선행 조건 | 실패 suite 수 | 실제 원인 |
|---|---:|---|
| GL 디스플레이 | 17 | X11/Wayland 초기화 실패. 렌더 카메라·브리지 및 lifecycle 변형 |
| 소켓/mock | 7 | import, motion_lab_ui, desktop client/session, pickup bridge, motion races/service의 socket 생성 권한 거부 |
| 기존 Python 패키지 | 2 | mcp 및 mujoco 모듈 없음 |

실제 GL에서 네 언어 글리프·클리핑·새 깃발 외관 검수, Web/desktop export는 미실행이에요.
임의 구성의 실제 주행 성공, 출발 구역 제한, 강제 종료/브라우저 저장소 삭제 복구도 보장하지 않아요.
저장은 나가기·다음·답지·초기화 시점이며 초 단위 자동 저장이나 이전 조립 이력은 추가하지 않았어요.

agent-task list --project ssok --cwd "$PWD"는 []였고 gh auth status는 미로그인이었어요.
사용자 지정 D 작업실만 수정했으며 GitHub 이슈/PR 생성·push·main 병합은 하지 않았어요.
**feat/own-build-20261022를 최신 Claude Fable에게 로컬 검증 후보로 인계**해요.
다음은 소켓·GL·기존 lock 패키지가 준비된 Linux에서 위 표준 verify 명령 전체 실행,
실제 네 언어 GL 검수, 통합 담당자의 rebase와 human merge예요.

공유 위키 조회는 Serie 정책 조회기에서 Frieren (arch)의 30_Projects/ssok.md를 확인했어요.
프로젝트 포인터/과거 기록 근거이며 이번 사용자 결정과 저장소 소스를 우선했어요.
공유 위키·작업 로그·arch 상태/Now 기록은 저장소와 /tmp 외 쓰기가 허용되지 않아 **미완료**예요.
이 문서와 evidence가 접수 대기 기록이에요. 호스트에서 기존 ssok 기록·현재 상태에 소스/검증/남은 일을 반영하고
agent-context refresh가 필요해요. 기록을 썼다고 주장하지 않아요.

DATA_MODEL·AUTHORING·FLOWS·FLAG_MISSION·STAGE_CONTRACTS·LOCALIZATION·STATUS·context·ADR 색인을 갱신했어요.
기존 실행/Stop/독립 튜토리얼 도식의 전이는 같아서 유지했고, Stage 집합/환경/저장 확장은 별도 절로 설명했어요.
영어와 ko/ja/zh_CN 새 메시지 26개를 같은 변경에 반영했어요. 제공자 전송·비용 영향은 없어요.

## 사용자가 해 볼 것 5줄

1. 결승선 스테이지를 열어 빈 작업대와 전체 부품 트레이를 확인해요.
2. 섀시에 보드·모터 드라이버·모터·바퀴를 붙여 내 로봇을 만들어요.
3. Wiring에서 보드 핀을 드라이버에, 드라이버를 모터에 연결해요.
4. Blocks나 Code에서 같은 핀으로 전진→대기→정지를 쓰고 실행해요.
5. 모든 부품이 결승선을 넘도록 시간/조립을 바꾸고, 나갔다 들어와 내 조립이 남는지 봐요.
