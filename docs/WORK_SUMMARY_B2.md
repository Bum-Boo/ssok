# 작업 B-2 — 기능 부품 팩 후속 (2026-10-22)

사용자 문제는 “구조 부품 수에 비해 새 행동을 만드는 부품이 부족하다”였어요.
기어·축, 라인 센서·검은 선, 버튼, LED, 경사판·공·컵을 추가했어요.
**서보 집게와 트레이의 별도 환경 카테고리는 미완료**이며 전체 팩 완료를 주장하지 않아요.

## 소스와 경계

- 작업실: 제공된 `work/repo`, 브랜치 `feat/parts-freedom-r2-20261022`.
- 시작: `fbf2d6392e0222e62010aa98a7318dce256e479c`; 최종 앱 내용: `7968d6f`(아래 검사 source hash와 일치).
- 엔진: `build/toolchain/godot`, Godot `4.7.2.stable.official.ed1daf0bf`.
- 항목별 커밋: `a2d59df` 기어·축, `c73059c` 라인 센서·선, `2f01f68` 버튼,
  `c9ed95d` LED, `a93535a` 경사판·공·컵, `7968d6f` 기존 트레이 필터·문서 링크 호환. 영어 제목, 트레일러 없이 커밋했어요.
- 지정한 scenes/UI/screens/Stage/기존 Stage·workshop 검사 및 `.github` 파일은 수정하지 않았어요.
  문서 패키지의 `tools/ci/build.py` 소스 링크 목록만 새 파일 4개에 맞췄어요.
  물리 공통 설정·엔진·의존성을 바꾸지 않았고 push·merge·export도 하지 않았어요.
- `quality-loop-20261022`는 다른 작업실의 Claude 라이브 소유라 인수하지 않았어요.
  공유 agent-task·위키·arch는 허용 쓰기 범위 밖이어서 로컬 인계로 남겨요.
- 전체 카탈로그 80→92종, construction catalog 30→42종, 기능 생성기 대상 5→17종이에요.

## 부품별 설계와 실제 수치

| 항목 | 구현·관측 | 실제 결과와 한계 |
|---|---|---|
| 기어 1:2/1:3 + 8×40 mm 축 | 하우징·입출력 회전자, 축에 고정한 부하와 같은 강체. 각속도 구속 `wi+r*wo=(1+r)*wh`, 위상 오차 보정, 세 몸체의 각운동량 반작용 | 최종 체인 감속비 2.00001 / 3.00000, 출력 반대 회전. 단위 관성 측정의 출력 토크는 입력 반작용의 각각 2배·3배. 모터 입력 0.078 N·m 한도 유지. 치형 접촉·백래시·손실 모델은 없음 |
| 서보 집게 | 한 서보와 두 손가락 초안을 접촉·마찰로 시험 | 100 g 파지·상승 실패. 카탈로그·런타임에서 초안을 제거함 |
| 라인 센서 + 선 2종 | 아래 방향 3-ray/150 mm, 검은 재질 밝기. `LineSensor(pin).value()` 0~1023(검정→흰색), `is_dark()` <512. 보드 공통 단위 | 선 144 / 바닥 1023. 실제 차동 바퀴 코드로 굽은 선을 따라 차체 x=1.270138 m, z=0.269231 m; 81회 중 33회 선 감지. 선은 40 mm 폭 직선·모서리 표시이며 물리 턱을 만들지 않음 |
| 접촉 버튼 | `Button(pin).is_pressed()`, 합쳐진 차체에서도 전면 충돌 형상만 판독. 50 ms 해제 디바운스와 `held_seconds` | 벽 접촉 분기로 모터 정지, 연속 2.0333초 눌림, 후진 후 해제·시간 초기화. 차체의 바닥 접촉은 무시 |
| LED | `LED(pin).on()/off()/set(0..1)`, 발광면의 인스턴스별 재질 복사 | 밝기 0.35→emission energy 0.7; 다른 LED·공유 재질 불변. Stop·실행 실패·`stop()`은 소등, 취소한 VM의 뒤늦은 재점등 없음 |
| 경사판 10°/20° | 볼록 쐐기 충돌, 기존 anchored 경로 | 최대 차체 높이 0.08335 / 0.18736 m. 20°는 90 mm 바퀴 사용; 기본 65 mm 바퀴의 차체는 걸림 |
| 공 40 mm·컵 | 자유 구체 25 g, 고정된 열린 5-box 컵 | 차가 옆으로 놓은 컵에 공을 밀어 넣고 Stop 후 count=1 유지. 바로 선 컵의 벽을 뚫는 식의 삽입은 안 됨 |
| 환경 관측 | `RunMode.cup_object_count()`는 컵 지역 좌표 내부에 완전히 든 자유 강체 수. SKU와 컵 방향 무관, 병합 몸체 중복 제외 | 구는 회전에 불변인 실제 반지름, 나머지는 보수적 mesh bounds. 기존 솔버 침투 허용값 1 mm를 관측 오차로 사용. 다른 ID·테두리 걸침·외부 물체·teardown 검사 포함 |

[기어 최종 실제 출력](evidence/parts_pack_v1_2026-10-22/gears.txt)과
아래 최종 검증 기록에 같은 소스의 수치를 남겼어요.
20 mm 마운트 간격·실제 4 mm 개구부·8 mm 축 포트는 유지했어요.
새 전기 kind를 만들지 않고 기존 `digital_io`와 그래프 pin map으로 장치 종류를 검사해요.
범위 밖 핀·다른 장치·중복 주소는 실행 전 기존 전체 소스 검사 경로에서 거부해요.
일반 가상 서보 보드는 PWM 전용 포트를 유지하므로 새 신호 장치는 micro:bit/Uno를 권장해요.

## 검증

실행 환경 변수는 작업 전용 `XDG_DATA_HOME=/tmp/ssok-b2-data`,
`XDG_CONFIG_HOME=/tmp/ssok-b2-config`, `XDG_CACHE_HOME=/tmp/ssok-b2-cache`예요.
항목 검사는 다음 형식으로 실행했어요.

```sh
build/toolchain/godot --headless --path . --language en --script tests/parts_pack_gears_check.gd
```

최종 실제 출력:

```text
parts_pack_gears_check: 36 checks, 0 failures
parts_pack_line_check: 13 checks, 0 failures
parts_pack_button_check: 11 checks, 0 failures
parts_pack_led_check: 19 checks, 0 failures
parts_pack_environment_check: 14 checks, 0 failures
parts_pack_inventory_check: 114 checks, 0 failures
parts_freedom_runtime_check: 28 checks, 0 failures
parts_freedom_blocks_check: 51 checks, 0 failures
parts_freedom_mechanics_check: 79 checks, 0 failures
parts_freedom_workshop_check: 50 checks, 0 failures
localization_check: 53542 checks, 0 failure(s)
construction_kit_check: 13655 checks, 0 failures
```

근거: [검증 기록](evidence/parts_pack_v1_2026-10-22/README.md).
생성기 `make_functional_parts.gd`는 17종을 생성하고 exit 0이에요.
Import는 exit 0이지만 이 sandbox의 소켓 생성 오류가 있어 clean PASS로 세지 않아요.
scene-load와 B의 최종 통과 suite 74개를 재실행했어요. 기본 명령은 위에
`--audio-driver Dummy --fixed-fps 60`을 더한 `tools.ci.verify.checks()` 계획이에요.
새 물리/API/블록 5 suites를 합친 79개 중 **78 PASS / 1 FAIL**, 이후 재고 검사
114/0을 더해 **80 suites 중 79 PASS / 1 FAIL**이에요. 신규 6 suites의 207 checks는
모두 통과했어요. [명령·결과 JSON](evidence/parts_pack_v1_2026-10-22/results.json)과
[소스 해시](evidence/parts_pack_v1_2026-10-22/source.json)에 출처를 보존했어요.
기존 B 통과 suite는 73/74여서 완료 기준의 “기존 검사 전부 유지”는 미달이에요.
B에서 실패했던 렌더·소켓·외부 의존성 검사는 이번 통과 주장에 넣지 않아요.
첫 최종 batch는 79 suites 중 76 PASS / 3 FAIL이었어요. 환경 ID가 `kit_` 필터를
따르도록 정리하고 문서 패키지의 새 런타임 소스 링크 4개를 추가했어요.
`workshop_ui_check`의 80종 고정 검사는 수정 금지 파일이라 잔여 실패로 남겨요.

네 언어의 새 부품/블록/오류 원문과 번역을 `functional_messages.json` 및 세 PO에 함께
추가했어요. 툴팁은 기존 UI가 같은 부품 이름을 사용하므로 해당 번역을 공유해요.
새 원문 23개·번역 69개의 세 PO 포함 여부를 명시적으로 대조했어요.
신규 재고 검사는 네 언어에서 실제 노드의 native auto-translation 설정·원문·번역 조회·
검색 및 카탈로그 접근을 확인했어요. 첫 검사는 Button.text가 번역된 값이라고 잘못
기대한 36건을 실패했고, 원문 property와 Godot native 자동 번역의 차이를 반영했어요. 실제 렌더의 글리프·잘림·발광 외관은
DISPLAY가 없는 환경이라 **미실행**이에요. 두 테마·크기별 새 화면 검수도 미실행이에요.
API 호출·유료 호출·새 의존성·export 비용 0이에요.

## 못 한 것과 이유

- 집게: 접촉은 발생했지만 두 손가락 동기화·마찰 파지가 100 g 상승/유지에 실패했어요.
  첫 7개 중 3개 실패 출력은 [실패 기록](evidence/parts_pack_v1_2026-10-22/gripper-failed.txt)에
  남겼어요. 파지용 임시 고정 조인트나 위치 덮어쓰기로 대체하지 않았어요.
  초안 fixture는 `build/verification-b2/gripper-experiment.gd`에만 있고 배포 소스에는 없어요.
- 별도 환경 카테고리: 카탈로그에 `categories.environment`를 넣고 번역된 “환경:” 이름으로
  노출하지만, 실제 카테고리 선택지는 `scenes/main.gd`에 하드코딩되어 있어요.
  메타데이터만으로 선택 항목을 만들 수 없고 해당 파일은 D 경계라 수정하지 않았어요.
  새 센서·LED도 기존 Electronics 필터에는 분류되지 않으며 Structure/Construction kit에서 접근해요.
  환경 ID도 `kit_env_*`이므로 전체/구조/Construction kit 목록에서 접근할 수 있어요.
- Stage metric 등록은 D 후속이에요. 이번에는 ID를 받지 않는 컵 물체 수 관측 함수만 제공해요.
- 전체 팩의 모든 형태/조립/기어 연쇄·부하와 모든 차의 라인 추종·경사 주행을 보장하지 않아요.
  테스트의 조립·표면·출력·선 폭과 컵 방향이 검증 범위예요.
- 공유 위키 기록·작업 로그·arch Now·agent-task checkpoint는 쓰기 범위 밖이라 미완료예요.
  [로컬 기록 인계](WIKI_HANDOFF_B2.md)와 이 요약으로 쓰기 가능한 통합 담당자에게 넘겨요.

문서 검사 `python3 tools/docs/maintain.py --check`, 문서 도구 unittest 10개,
`git diff --check`는 PASS예요. 금지 경로 변경 0개를 base diff로 검사했어요.
공식 verify 전체 실행은 mock HTTP 소켓 제한 때문에 사용하지 않았고, 기존 B 통과 명령만
같은 checks()/run()으로 실행했어요. 이 결과를 공식 release PASS로 해석하면 안 돼요.

## 문서와 인계

ADR 0031 하나로 ADR 0030 및 기존 graph/물리/보드/토크 결정을 확장했어요.
DATA_MODEL/FLOWS/AUTHORING의 새 필드·API·LED Stop 의미를 반영하고 source review를 갱신했어요.
ERD와 실행 도식은 같은 graph 정본·저장 v1·VM 제어권을 사용하므로 유지했어요.
STATUS는 통합 상태 정본이어서 미통합 브랜치의 수치로 바꾸지 않았어요.

인계 브랜치는 `feat/parts-freedom-r2-20261022`예요. Fable 통합 담당자가 D의 UI 흐름과
카테고리 요구를 조정하고 디스플레이가 있는 4090 환경에서 네 언어·Web/desktop 검증을
이어가세요. 사람 merge 전 integration-ready나 release-ready 판정은 아니에요.

## 사용자가 해 볼 것 5줄

1. 모터→축→1:2/1:3 기어→90 mm 바퀴를 조립해 속도와 하중 차이를 비교하기.
2. micro:bit 차의 라인 센서로 검은 직선·꺾인 선의 밝기를 읽고 두 바퀴 출력을 바꿔 따라가기.
3. 차 앞의 접촉 버튼이 벽에 닿으면 멈추고 LED를 켜는 코드를 만들기.
4. LED 밝기를 0→0.5→1로 바꾸고 Stop으로 꺼지는지 보기.
5. 큰 바퀴로 경사판을 오르고 공을 옆으로 놓은 컵에 밀어 넣어 `cup_object_count()`를 관측하기.
