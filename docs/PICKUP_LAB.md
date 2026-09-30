# 모듈형 휴머노이드 · Luna 집기 실험실

2026-09-15. Blender 기본 부품으로 휴머노이드와 연습 상자를 조립하고,
최대 4개 독립 물리 실험을 관찰하며 집기 파라미터를 비교·선택·저장한다.
이는 GPT 가중치 훈련이나 범용 강화학습이 아니라 **후보 제안 → 실제 물리 평가 → 측정값 피드백**이다.
Luna가 더 좋은 결과를 찾는다는 보장도 없다. 기존 관절 프로그램과 성공 기준은 고정돼 있다.

현재 기본 부품 키트는 실제 양손 접촉까지 관측됐으나 들어 올릴 때 균형을 잃어 집기에 실패한다.
실패 결과도 관찰·선택·저장할 수 있다. 아래의 구형 프리팹 성공 기록은 새 키트의 성공을 뜻하지 않는다.

## 가장 빠른 시작: 키 없이 로컬 실험

```sh
godot --path . --language ko --script tools/godot/play_construction_kit.gd
```

1. 왼쪽 조립 키트 휴머노이드 예제를 선택한다. 예제를 불러오면 현재 조립/코드를 교체한다.
2. 상단 `AI 실험실`을 누른다. 사람형에서는 새 **집기 학습실**이 열린다.
3. `실험` 탭에서 **로컬 탐색(GPT 미사용)**, 병렬 수 1~4, 라운드 1~4를 고르고 탐색을 시작한다.
4. 먼저 기준 동작 1개를 측정한 뒤, 라운드마다 4개 후보를 평가한다. 총 5~17개다.
   병렬 수는 실행 중에도 바꿀 수 있다. 줄이면 이미 진행 중인 실험은 끝내고 새 작업 수부터 줄인다.
5. 화면 아래 측정 결과 목록에서 성공 또는 실패 결과를 선택하고 이름을 붙여 **선택한 시나리오 저장**을 누른다.
   네 화면을 켠 작은 창에서는 아래로 스크롤하면 결과/저장 버튼에 도달한다.
6. `저장된 시나리오` 탭에서 선택한 뒤 **물리로 재실행**한다. 불러오기는 작업실 조립/코드를 바꾸지 않는다.
7. 새 검증에 성공하고 현재 편집 중인 조립이 동일할 때만 **선택한 집기 적용**이 가능하다.
   창을 닫고 실행 모드를 켜서 2~3초 안정화 후 E로 집기/놓기를 시험한다.

로컬 탐색은 제한된 주변 값을 비교하는 탐색기로 **GPT를 전혀 호출하지 않는다**.
각 미리보기는 실제 `SubViewport`/`World3D`이며 마지막 측정 시점에 에피소드를 정지해 결과를 보존한다.
성공하려고 물체를 멈추는 방식이 아니다. 완료 이전의 양손 접촉·상승 높이·유지 시간으로 판정한다.
병렬은 독립 실험을 함께 진행한다는 뜻으로, 멀티코어 가속이나 더 빠른 실행을 보장하지 않는다.

## Luna 연결

브리지 실행과 API 키 설정은 [MOTION_LAB.md의 실제 GPT 연결](MOTION_LAB.md#실제-gpt-연결)을 따른다.
먼저 `python3 -m tools.motion_lab.server`의 mock 모드로 통신을 확인할 수 있다.
`Luna 연결` 탭에서 주소와 **브리지 인증 토큰**을 넣고 연결 확인 후 실제 공급자가 mock/openai인지 확인한다.
OpenAI 키를 Godot·채팅·저장소에 입력하지 않는다. 키는 외부 브리지 환경에만 둔다.

실제 호출은 정확히 `gpt-5.6-luna`와 Responses/Structured Outputs를 사용한다.
공식 모델 문서상 fine-tuning은 지원하지 않는다.
([모델](https://developers.openai.com/api/docs/models/gpt-5.6-luna),
[Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs))

- **한 라운드당 최대 1회** 요청으로 네 후보를 받는다. 병렬 수를 늘려도 호출 수가 곱해지지 않는다.
- 정해진 라운드 수와 보행/집기가 공유하는 서버 호출 한도 안에서만 요청한다.
- 매 탐색마다 유료 동의가 필요하며, 자동 재시도·다른 모델로 대체는 없다.
- 취소하면 로컬 평가/후속 후보를 중단한다. 이미 보낸 API 요청은 과금될 수 있다.
- 시작 응답을 잃으면 실행 여부 불명으로 잠그며, `연결 해제 / 기록 지우기`로 조용히 취소됐다고 주장하지 않는다.
  서버 상태와 비용을 확인한 뒤 명시적으로 로컬 연결 상태를 초기화해야 한다.
- 모델에는 목표와 제한된 정책/측정 피드백을 보내며, 학습자 코드·키·임의 파일을 보내거나 실행하지 않는다.

휴머노이드 집기는 현재 HTTP 브리지 경로를 사용한다. 기존 선택적 MCP 도구는 네 서보 보행용이며,
이번 집기 기능을 MCP로 제공한다고 주장하지 않는다. 프로토콜/경계는
[브리지 문서](../tools/motion_lab/PICKUP.md)에 있다. 공개 웹에서는 별도 인증 HTTPS 서비스가 필요하다.

## 모듈·코딩·재질

`assets/blender/ssok_construction_kit_verified.blend`에 편집 가능한 최종 Blender 원본이 있다.
기본 부품 24종의 공통 20 mm 간격·4 mm 체결 구멍과 실제 포트가 같은 정의에서 생성된다.
빔·판·브래킷·연결 부품은 각각 그래프의 별도 부품이며, 실행 때만 고정 연결을 강체로 묶는다.
10개 모터 주소는 실제 배선에서 해석한다. 치수/관절 범위는 가상 키트용이며 상용 기체 복제가 아니다.

`코드` 탭에는 현재 그래프 배선을 읽어 만든 관절 예제가 들어간다. `s20.write_relative(-14.36)`처럼
조립 자세 기준 양·음수 각도를 명령할 수 있다. `Servo(20)`은 예시 배선 주소이지 고정된 역할 번호가 아니다.
기존 `write(0..180)`도 유지한다. 지원 범위는 작은 Python 스타일 서보 언어이며 전체 Python은 아니다.
코드와 WASD 프로그램의 제어권은 동시에 활성화되지 않는다.

Blender/Godot 양쪽에 공유 PBR 금속·플라스틱·고무·기판 재질을 적용했다. 생성 절차와 연결 구조는
[키트 안내](CONSTRUCTION_KIT.md)에 있다. 앱의 G/R 편집은 물체 편집이고
정점/메쉬 수정은 Blender 원본에서 한다.

## 측정·저장 한계

각 실험은 최대 15초, 60 Hz다. 실제 양손-상자 접촉 후에만 두 점 구속을 만들며,
25cm 이상 들고 1초 유지하며 넘어지지 않은 결과를 성공으로 표시한다. 손가락 마찰만으로 드는 모델은 아니다.
저장에는 그래프·7개 제한 파라미터·측정값·출처·이름·시각만 들어간다. 프롬프트·토큰·생성 코드는 제외한다.
기록은 `user://pickup_scenarios/`의 고유 이름 JSON(최대 64개, 각 256 KiB)이다.
Linux 기본 위치는 `~/.local/share/godot/app_userdata/ssok/pickup_scenarios/`다.
로드 시 스키마/카탈로그/연결/숫자를 검증하고, 저장된 성공 표시는 재검증을 대신하지 않는다.

구형 하위 조립품 프리팹에서 검증한 기준 동작: 약 0.421m 상승·양손 접촉·중력 해제. 네 독립 실험에서도 각각
약 0.417m 상승, 1초 유지, 약 8.52초에 완료했다. 더 어려운 상자 위치, 자율 접근·회전,
운반 보행, 낙상 복구, 안정적인 달리기, 실물 전이는 검증하지 않았다.

아래 검증 기록은 해당 구형 프리팹의 기록이며 새 키트의 동작을 인증하지 않는다.
새 기본 부품 키트의 독립적인 검증은 [키트 안내](CONSTRUCTION_KIT.md)에 기록한다.

## 검증 명령

```sh
godot --headless --path . --import
godot --headless --path . --quit
godot --headless --path . --fixed-fps 60 --script tests/modular_humanoid_check.gd -- pick
godot --headless --path . --fixed-fps 60 --script tests/pickup_trial_check.gd
godot --headless --path . --fixed-fps 60 --script tests/modular_pickup_parallel_check.gd
godot --headless --path . --script tests/pickup_store_check.gd
godot --headless --path . --script tests/relative_code_check.gd
godot --headless --path . --fixed-fps 60 --language en --script tests/pickup_lab_ui_check.gd
godot --headless --path . --fixed-fps 60 --language en --script tests/pickup_bridge_ui_check.gd
godot --headless --path . --language en --script tests/localization_check.gd
python3 -m unittest discover -s tests -p 'test_pickup*.py'
```

통신 검증은 mock 서버를 별도 포트에서 실행하고 `SSOK_UI_TEST_URL`과 `SSOK_UI_TEST_TOKEN`을
지정한다. 해당 테스트는 공급자가 mock일 때만 요청한다. 실제 유료 GPT 호출은 수행하지 않았다.
한·중·일 UI와 현재 9단계 튜토리얼을 함께 갱신했다. 네이티브 화면 검사는 UI 명령에서
`--headless`를 빼고 `-- --screenshots`를 추가한다. 웹 내보내기/실물 패드는 별도 검증 대상이다.

### 구형 하위 조립품 기반 집기 기능의 검증 기록

- 집기 정책/물리/완료 후 월드 정지 415개, 모듈형 네 월드 동시 실험 34개, 저장 66개,
  배선이 바뀐 관절 코드 26개 검사 통과.
- 집기 화면 headless 27개 / 실제 GL·한중일·축소 창 48개, 모듈형 작업실의 E 집기와
  한중일 화면 174개 검사 통과. 튜토리얼 headless 441개 / GL 화면 포함 477개 통과.
- 번역/자리표시자/글꼴 및 새 집기 문구 명시적 등록 27,846개 검사 통과.
- mock 브리지 요청→폴링→두 라운드 실제 물리 평가→요청 직후 취소 검사 148개 통과.
  장시간 열린 임시 fixture가 SIGTERM으로 종료돼 통신 검사가 한 차례 실패했다.
  서버 수명을 테스트 셸에 묶어 재검증했으며, 종료된 서버를 정상 완료로 오인하지 않았다.
- 백엔드 43개 단위 검사(기존 23 + 집기 20) 통과. OpenAI 응답은 모두 mock이었다.
- 기존 조립/스냅·카메라·Blender 편집·수동/코드 전환·기존 메쉬/재질·보행/AI 코어 검사 통과.
  기존 보행 UI 36개는 통과했으나 그 테스트의 별도 외부 HTTP fixture는 이번 최종 실행에서 건너뛰었다.
- `godot --headless --path . --import`, `--quit`, `git diff --check` 통과.
