# 작업 B — 제어 구조와 기계 부품 5종 (2026-10-22)

## 현재 결과와 소스

사용자 문제는 "75종이라는 숫자에 비해 조합해서 새 행동을 만들 기능이 부족하다"였어요.
기준 소스를 확인하니 변수·산술·비교·논리·if/elif/else·while·break/continue와 실제
DC 모터/초음파는 이미 있었어요(ADR 0023). 이번에는 그 구현을 보존하면서 부족한 부분을
추가했어요. **전체 기능 부품 팩 v1의 완료나 전체 검사 통과를 주장하지 않아요.**

- 작업실: 제공된 `work/repo`, 브랜치 `feat/parts-freedom-20261022`.
- 시작/현재 HEAD: `b3570c650bd0fa285af94fd9136708b1df41bdc8` (v0.3.1), 변경은 미커밋이에요.
- 엔진: 저장소 `build/toolchain/godot`, `4.7.2.stable.official.ed1daf0bf`.
- UI/화면/씬/Stage 레벨 파일은 수정하지 않았어요. 엔진·의존성 설치도 없었어요.
- 라이브 `quality-loop-20261022`는 다른 작업실의 Claude 소유라 인수하지 않았어요.
- `gh` 인증은 없었고 연결 GitHub 도구로 이슈를 조회했어요. 별도 작업 B 이슈 생성은 도구가
  승인을 요구했지만 이 환경은 승인을 허용하지 않아 실행되지 않았어요. 기존 이슈는 수정하지 않았어요.

## 바뀐 것

| 범위 | 전 → 후 |
|---|---|
| 반복 | while만 → `for i in range(...)`의 1/2/3인자 형식, 음수 step, 중첩, break/continue |
| 안전 | 틱당 128연산만 → 전체 루프 본문 진입 10,000회, 시뮬레이션/단조 실시간 각각 60초 상한, 초과 시 실패·DC 제동 |
| range | 미지원 → 경계는 한 번 평가, 리스트 할당 없음, 정수 절댓값 1e9 이내, 0 step/10,000 초과 계획 반복 거부 |
| 모터 | `Motor(a).motor_on(...)` → 호환 유지 + 같은 드라이버 채널의 순서 있는 두 핀 `Motor(a,b)`, `forward`, `backward`, 무인자 `stop` |
| 센서 | `distance_cm()` → 같은 실제 9-ray 관측을 반환하는 `distance()` 별칭, 단위 cm/무효 401 유지 |
| 블록 | 기존 조건/while 카드 유지 + range·break·두 핀 모터·전후진·센서값 카드, 원문/주석/들여쓰기 왕복 |
| 부품 | 키트 25종 → 검증한 수동 힌지·40/90 mm 바퀴·100/300 g 추만 추가, 전체 카탈로그 75→80종 |

전체 소스의 문법·이름·배선을 실행 전에 검사하는 경로와 기존 Stop/제어권 전환을 유지했어요.
상수 range의 오류는 사전 검증하고 변수로 정해지는 경계는 해당 줄에서 검사해요. `running_time()`은
계속 시뮬레이션 틱의 ms이며, 실시간은 안전 타임아웃에만 써요. 모든 반복은 전체 예산을 공유해요.
기존 번역된 한계/수치 오류 문구를 재사용해 기존 UI 문구 키를 바꾸지 않았어요.

```python
left = Motor(pin0, pin8)
right = Motor(pin12, pin16)
sonar = Sonar(pin1, pin2)
for i in range(1000):
    distance = sonar.distance()
    if distance <= 10:
        break
    left.forward(25)
    right.forward(25)
    sleep(20)  # micro:bit milliseconds
stop()
```

이 예는 micro:bit 드라이버의 기존 실제 배선을 전제로 해요. 보드별 sleep 단위는 그대로고
Uno/generic은 초예요.

새 부품은 같은 카탈로그 JSON에서 단순 ArrayMesh·기존 공유 재질·MECH 포트·충돌·질량을
생성해요. 새 전기 장치가 없으므로 허구의 전기 포트/API/명령 카드는 추가하지 않았어요.
마운트는 20 mm 간격과 실제 4 mm 개구부, 축 연결은 키트 8 mm 인터페이스를 써요.
바퀴 반대편에는 기존 TT 모터용 가상 hub도 있어요. 상용 호환 인증은 아니에요.

수동 힌지는 `passive_hinge` 정의에 의해 ServoDrive 없이 제한 HingeJoint3D만 만들어요.
기본 ±45° 제한은 카탈로그 `min_deg/max_deg`를 바꿔 재생성할 수 있어요. 인스턴스별 UI
설정/저장은 없어요. 실제 충격 후 양방향 최대 47.311°를 관측했어요(솔버 과도 오차 포함).
새 바퀴는 원통 충돌과 기존 0.078 N·m 한도의 DC 물리를 재사용하며 실제 회전을 확인했어요.
추의 실제 solver 질량은 0.1/0.3 kg이고 둘 다 중력으로 낙하했어요.

## 실제 검증

기본 실행 형태는 `XDG_DATA_HOME=/tmp/... XDG_CONFIG_HOME=/tmp/... XDG_CACHE_HOME=/tmp/...`
으로 이 작업 전용 데이터를 둔 뒤 다음 명령을 실행했어요. 출처와 집계는
[evidence](evidence/parts_freedom_2026-10-22/README.md)에 보존해요.

| 명령 (`GODOT=build/toolchain/godot`) | 실제 결과 |
|---|---|
| `$GODOT --headless --path . --script tests/parts_freedom_runtime_check.gd` | 28 PASS / 0 FAIL |
| `$GODOT --headless --path . --script tests/parts_freedom_blocks_check.gd` | 51 PASS / 0 FAIL |
| `$GODOT --headless --path . --script tests/parts_freedom_mechanics_check.gd` | 79 PASS / 0 FAIL |
| `$GODOT --headless --path . --script tests/parts_freedom_workshop_check.gd` | 50 PASS / 0 FAIL |
| `$GODOT --headless --path . --language en --script tests/localization_check.gd` | 52,774 PASS / 0 FAIL |
| `$GODOT --headless --path . --script tests/construction_kit_check.gd` | 12,894 PASS / 0 FAIL |
| `$GODOT --headless --path . --script tools/godot/make_functional_parts.gd` | 5종 생성, exit 0 |
| `$GODOT --headless --path . --quit` | exit 0, 오류 없음 |
| `$GODOT --headless --path . --import --quit` | exit 0이나 소켓 생성 오류가 있어 PASS로 세지 않음 |
| `python3 tools/docs/maintain.py --check` | PASS |
| `python3 -m unittest discover -s tools/docs -p 'test_*.py'` | 10 PASS / 0 FAIL |
| `git diff --check` | PASS |

런타임 검사는 실제 sonar 값의 모터 분기, 핀 쌍 불일치의 전체 사전 거부, 중첩 반복,
음수/빈 range, 경계값 한 번 평가, 잘못된 동적 경계, 정확히 10,000회 허용, 초과 거부,
실시간/시뮬레이션 시간 상한, 실행 중 모터의 한계 제동과 Stop을 포함해요.

기계 검사의 첫 실행은 49개 중 6개 실패였어요. float 간격의 exact 비교와 마지막 회전 프레임만
보는 관측을 고쳤고, 편집용 선택 StaticBody가 물리 fixture에 남아 있음을 찾아 앱처럼 collision
layer를 제외했어요. 수치 기준/회전 한계는 완화하지 않았고 그 뒤 비대칭 제한의 부호/링크 순서 문제를 실제 회전으로 재현해 보정했고, 양방향·두 연결 순서까지
확장한 최종 검사는 79 PASS / 0 FAIL이에요. 키트 트레이 25종과
전체 75종의 기존 고정 개수 검사는 새 카탈로그에 맞게 갱신했고, 새 ID 전부의 도달 검사를 추가했어요.

공식 전체 명령 `python3 tools/ci/verify.py --godot "$PWD/build/toolchain/godot"`은 mock HTTP
서버를 만들 때 `PermissionError: [Errno 1] Operation not permitted`로 검사 시작 전에 중단됐어요.
대신 같은 `checks()` 계획과 `run()` 오류 판정을 import해 각 검사 명령을 실행했어요. mock 서버
fixture는 제공하지 못했으므로 공식 release 검증과 동등하지 않아요. 첫 99 suite는 71 PASS /
28 FAIL이었고 첫 실패 출력은 `build/verification-b/all-progress.log`에 남겼어요.
최종 100 suites는 73 PASS / 27 FAIL이었고, 그중 작성 중이던 문서 링크 실패 1개는 후속 검사로
해소했어요. 그 뒤 최종 비대칭 힌지 수정에 대해 관련 12 suites를 재실행해 12 PASS / 0 FAIL을 확인했어요.
잔여 실패는 26개예요. 모든 결과/실패 목록은 evidence의 `results.json`에 있어요.

네 언어의 부품/블록 이름 10개 원문과 번역 30개를 명시적으로 검사했어요. 번역 검사는 글꼴
has_char도 확인하지만 실제 렌더 글리프·잘림 검수를 대신하지 않아요. DISPLAY가 없고 Xvfb도
소켓 생성에 실패하여 실제 네 언어 화면 검수와 Web/desktop export는 **미실행**이에요.
API/유료 호출 0회, 비용 영향 없음.

## 못 한 것과 이유

- 축+1:2/1:3 기어: 실제 기어비·반작용 토크를 보장하는 그래프 전달 구속을 구현하지 않았어요.
  단순 회전 연출이나 이름만 있는 부품으로 대체하지 않고 카탈로그에 추가하지 않았어요.
- 서보 집게: 실제 접촉 후 잡힘/해제·Stop 동작을 새 독립 부품으로 검증하지 않았어요. 기존
  휴머노이드 실험을 이 작업의 부품 구현으로 세지 않았어요.
- 라인 센서/검은 선, 접촉 버튼, LED: 바닥 관측·접촉·발광과 그래프 배선/API/블록을 끝까지
  구현하지 않았어요. 새 기능 장치로 노출하지 않았어요.
- 경사판·공·컵: 충돌/관측 기준까지 포함한 환경 stock으로 구현·검증하지 않아 노출하지 않았어요.
- 게임 Stage 조립 트레이: 원래 세 Stage가 숨기는 UI라 사용자 지정 UI 변경 금지 범위를 지켰어요.
  Stage 그래프에 새 부품을 추가한 저장·실행 검사는 통과하지만 실제 게임 화면에서 자유 추가는 미완료예요.
- 카드 본문의 새 중첩 조립은 기존 flat 카드 편집기의 한계가 남아요. 새 range 카드는 빈 pass
  본문을 만들고, 코드에서 만든 중첩은 편집 가능한 카드로 왕복해요. 패널/레이아웃은 바꾸지 않았어요.
- 모든 기존 검사 PASS는 미확보예요. 환경 실패와 의존성 부재는 증거 표에 그대로 남겨요.
- 커밋: `git add`가 `.git/index.lock: Read-only file system`으로 거부돼 생성하지 못했어요.
  브랜치/HEAD를 바꾸거나 별도 저장소를 만들어 제한을 우회하지 않았어요.
  전체 변경의 portable binary patch는 `build/parts-freedom-b.patch`로 준비했어요.
- 공유 위키/arch/agent-task 기록은 쓰기 허용 범위 밖이에요. 로컬
  [기록 인계 후보](WIKI_HANDOFF_B.md)만 작성했으며 **공유 위키 기록 미완료**예요.

## 통합 담당 인계

[ADR 0030](adr/0030-bounded-ranges-and-passive-bearings.md)은 0002/0003/0004/0011/0023을
확장하며 기존 결정을 대체하지 않아요. DATA_MODEL/FLOWS의 관계 도식은 같은 graph 권한과
같은 실행/Stop 경로를 쓰므로 유지했고, 새 필드/한계 설명과 source-review 해시만 갱신했어요.
STATUS는 통합 상태 정본이므로 아직 미통합인 이 작업의 수치로 덮어쓰지 않았어요.

쓰기 가능한 Git 작업실에서 권장 커밋 단위는 다음과 같아요. 각 메시지 끝에는 `Agent: codex`를 둬요.

1. `Add bounded range loops and paired motor commands`: parser/VM/drive/sonar, run_mode의 motor_on_pins, runtime 검사.
2. `Add loop and sensor value block cards`: BoardProfile/ServoProgram, 블록 검사, 블록 이름 번역.
3. `Add graph-derived passive hinges`: PartDef/passive run_mode, 힌지 catalog/mesh/definition, 생성기.
4. `Add 40 and 90 mm wheels`: 두 바퀴 catalog/mesh/definition.
5. `Add calibrated ballast stock and regression coverage`: 두 추, 기계/작업실·카탈로그/번역 검사.
6. `Document runtime limits and partial parts delivery`: ADR/계약 설명/현재 인계·근거.

혼합 파일(특히 run_mode/catalog/locales)은 의미별로 나눠 stage해야 해요. 통합 후보 브랜치는
`feat/parts-freedom-20261022`이며 commit-ready 파일 초안이지 전체 integration-ready 판정은 아니에요.
다음 담당은 쓰기 가능한 원본 Git에서 커밋하고, 디스플레이·소켓·기존 의존성이 있는 환경에서
공식 verify를 실행한 뒤 Fable 검토/rebase와 사람 merge로 넘겨요. main 병합/배포는 하지 않았어요.

## 사용자가 해 볼 것

1. Lab의 초음파 차에서 `distance = sonar.distance()`를 읽고 `if`로 벽 앞 정지를 풀어 보기.
2. `for i in range(3)`으로 전진·멈춤을 세 번 반복하고 코드→블록→코드에서 횟수를 바꿔 보기.
3. 거리 조건이 참일 때 `break`로 빠져나와 모터를 멈추도록 고쳐 보기.
4. 40 mm와 90 mm 바퀴로 바꿔 같은 출력·시간의 이동과 차체 높이 차이를 관찰하기.
5. 수동 힌지에 키트 축 부품을 연결하고 100 g/300 g 추를 달아 중력에 따른 회전과 제한점을 비교하기.
