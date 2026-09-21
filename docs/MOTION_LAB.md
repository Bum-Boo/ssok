# AI motion lab — GPT로 동작 후보를 만들고 물리 결과로 개선하기

모델은 요청한 **`gpt-5.6-luna`**다. 공식 문서에서 Responses API, Structured
Outputs, MCP 지원을 확인했다. 계정별 접근 권한은 실제 요청 시 확인된다.
이번 구현은 GPT 가중치 훈련이나 강화학습이 아니라 **기존 관절 프로그램의
파라미터를 제안 → 시험 → 피드백으로 수정하는 탐색**이다.
([공식 모델 문서](https://developers.openai.com/api/docs/models/gpt-5.6-luna),
[Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs))

## 바로 사용하기

**모듈형 휴머노이드의 상자 집기**는 [별도 집기 실험실 안내](PICKUP_LAB.md)를 따른다.
1~4개 화면을 동시에 관찰하고, 결과를 선택해 조립 그래프와 함께 저장/재실행한다.
브리지 없이 로컬로 시작할 수 있다. 아래의 4개 보행 파라미터/서버 평가 설명은 기존
네 서보 이족 로봇 전용이며, 휴머노이드는 별도 7개 집기 파라미터/클라이언트 평가를 사용한다.

ssok 저장소에서 실행한다. HTTP 브리지는 Python 표준 라이브러리만 사용한다.

```sh
godot --headless --path . --import --quit
python3 -m tools.motion_lab.server
```

기본값은 **MOCK**다. GPT를 호출하지 않지만 후보마다 실제 Godot 물리를 실행한다.
터미널에 표시되는 **local bridge token**을 ssok에 입력한다. 이 토큰은 OpenAI
API 키가 아니다. 기본 주소는 `http://127.0.0.1:8765`다.

1. ssok에서 `Answer: biped` → `AI motion lab`을 연다.
2. `1. 연결` 탭에서 브리지 토큰을 입력하고 `Check connection`으로 MOCK/OPENAI 상태를 확인한다.
3. `2. 탐색` 탭에서 목표 설명, 평가 방향(W/S/A/D), 후보 수(1~4)를 선택하고 `Start search`를 누른다. 유료 요청 동의와 비용 경고는 이 탭에 함께 표시된다.
4. `3. 결과` 탭에서 기존 동작과 후보의 이동량·옆밀림·회전·최소 자세·넘어짐·점수를 확인한다. 적용/저장 버튼은 결과 영역 하단에 고정된다.
5. 편집 모드에서 `Apply best to WASD program`을 누른 뒤 창을 닫고 Run mode에서 조종한다.
6. `Save best locally` / `Load saved best`로 결과를 보관한다. 로드는 자동 적용이 아니다.

조립 그래프를 바꾸면 그 그래프에 적용했던 탐색 파라미터는 기본값으로 돌아간다.
브리지가 재시작되거나 연결이 끊겨 복구할 수 없으면 `Disconnect / forget`으로
경고를 확인한 뒤 토큰을 다시 설정한다. 이는 **서버 작업을 취소하는 기능이 아니다**.
기존 작업/과금을 먼저 확인하거나 브리지를 종료해야 한다. 시작 응답을 받지 못한 경우도
실행 여부 불명으로 표시하고 사용자가 확인하기 전 새 요청을 자동 반복하지 않는다.

### 실제 GPT 연결

기존 mock 브리지를 Ctrl+C로 종료한다. API 키는 **브리지를 실행할 터미널 환경**에만
설정한다. Bash에서는 아래처럼 입력하면 키를 명령 기록에 직접 적지 않아도 된다.

```sh
read -rsp 'OpenAI API key: ' OPENAI_API_KEY
export OPENAI_API_KEY
python3 -m tools.motion_lab.server --live --max-calls 8
```

새 브리지 토큰으로 다시 연결하고, 각 검색에서 `Allow paid OpenAI requests`를
직접 선택한다. 키를 채팅, Godot 입력란, 저장소, `.env` 커밋, 스크린샷에 넣지 않는다.
공식 권고대로 키는 서버 환경 변수/비밀 관리 시스템에 둔다.
([OpenAI 운영 권고](https://developers.openai.com/api/docs/guides/production-best-practices))

API 키가 없거나 모델 권한·크레딧이 부족하면 명시적으로 실패한다. 다른 모델로
몰래 바꾸거나 비용이 드는 요청을 자동 재시도하지 않는다. `store:false`를 사용하지만
이는 OpenAI의 모든 데이터 보관 정책을 끄는 설정이라는 뜻은 아니다.
([Responses API](https://developers.openai.com/api/reference/cli/resources/responses/methods/create))

## 무엇을 조정하는가

| 파라미터 | 허용 범위 | 초기값 | 기존 프로그램에서의 역할 |
|---|---:|---:|---|
| `cycle_seconds` | 0.8~4초 | 3.45 | 보행 주기 |
| `stride_degrees` | 0~35° | 10.5 | 엉덩이 앞뒤 흔들림 |
| `lean_degrees` | 0~35° | 18.5 | 발목 좌우 기울임 |
| `posture_degrees` | −10~10° | −9.8 | 전후진 때 자세 편향 |

기본 제어기는 측정한 몸통 기울기와 각속도로 관절 목표를 최대 ±15° 보정한다.
이 보정은 같은 물리 평가에 포함되며, 위 네 파라미터나 성공 기준을 대신하지 않는다.
현재 기본값은 자세 안정성을 개선했지만 실행 환경에 따라 전진·회전 방향 검사가
실패할 수 있다. 탐색 결과는 해당 실행의 실제 측정값으로 판단한다.

GPT는 이 네 숫자와 짧은 제안 이유만 반환한다. 새 GDScript/Python, 쉘 명령,
메쉬·질량·마찰·물리 엔진 변경은 생성하거나 실행하지 않는다. 실제 핀은 계속
`ConnectionGraph` 배선에서 해석한다. `MiniRuntime`의 사용자 코드도 수정하지 않는다.

목표 설명은 제안에 참고되지만 점수 함수를 바꾸지는 않는다. 선택한 방향이 실제
평가 목표를 정한다. 예를 들어 설명에 “춤춰”라고 적어도 새 춤 제어기가 만들어지지 않는다.
다른 형태의 로봇에는 별도의 프로그램·출력 스키마·평가기가 필요하다.

## 평가와 적용 조건

각 평가는 그래프를 검증한 후 **새로운 격리된 물리 월드**에서 시작한다.
60Hz로 3초 안정화 + 12초 방향 입력 + 1.5초 입력 해제, 총 16.5초를 시뮬레이션한다.
브리지는 고정된 Godot 스크립트만 실행하며 앱에 보이는 조립품은 움직이지 않는다.

`command = [turn, forward]`, 몸통의 안정화 후 수평 +Z가 전진 기준이다.
현재 점수는 다음처럼 고정돼 있다.

```text
100 × forward_m × forward + 2 × yaw_rad × turn
− 30 × abs(lateral_m) − 2 × abs(yaw_rad) × (1 − abs(turn))
− 10 × (1 − clamp(min_upright, 0, 1)) − 100 × fallen
```

평가 전체에서 몸통 up 방향과 세계 up의 내적이 0.5 미만이거나 바닥 기준 높이가
0.06m 미만이면 넘어짐으로 기록한다. 비유한 물리 상태도 거절한다. **넘어짐/비유한
후보는 높은 점수로 만회할 수 없고 정상 후보보다 우선할 수 없다.** 마지막 후보가
아니라 실제로 평가한 최선 후보를 보관한다. 개선이 없으면 기존 파라미터를 유지한다.

점수가 올라도 거의 움직이지 않는 후보일 수 있다. 실제 목표 방향 이동량과 회전을
반드시 함께 확인해야 한다. 한 방향만 평가하므로 다른 WASD 방향의 성능, 다른 마찰·질량,
외란, 실물 로봇에서의 안전성은 보장하지 않는다.

적용은 편집 모드에서, 평가한 그래프와 현재 그래프의 fingerprint가 같을 때만 가능하다.
전송 JSON은 전체 숫자 정밀도를 보존하며 fingerprint도 반올림하지 않은 그래프를
비교한다. 접촉 물리는 아주 작은 변환 차이에도 달라질 수 있어 허용 오차로 다른 그래프를
같다고 취급하지 않는다. 시뮬레이션 원본 변환을 양자화하지도 않는다. 저장 파일은
`user://motion_lab_best.json`이며 숫자 정책/측정치/그래프 fingerprint만 담는다.
저장 기록은 로컬 사용자 데이터이지 변조 불가능한 인증 결과는 아니다.

## API·MCP와 보안 경계

```text
Godot UI ── 비동기 HTTP ── 로컬 브리지 ── Responses API (gpt-5.6-luna)
                              │                    ↑ 실제 평가 이력
MCP 호스트 ── stdio ── 같은 서비스 코드 ── 고정 Godot 물리 평가기
```

MCP는 모델이 도구를 발견하고 호출하는 규약이지 학습 알고리즘이 아니다. 일반 Godot
편집 MCP를 설치하지 않고 describe/start/get/cancel 네 기능만 제공한다. 설치·호스트
연결 방법은 [MCP 안내](../tools/motion_lab/MCP.md)를 따른다. 사용자의 MCP 설정을
자동으로 변경하지 않는다. HTTP 브리지와 MCP를 별도로 시작하면 각자 독립 세션이다.

이번 MCP는 로컬 **stdio** 전용이다. Responses API의 원격 MCP는 Streamable HTTP
또는 HTTP/SSE 서버를 사용하므로 이 stdio 프로세스를 원격 URL처럼 넘기지 않는다.
([공식 MCP 연결 문서](https://developers.openai.com/api/docs/guides/tools-connectors-mcp))

- 기본 한도: 동시 검색 1개, 후보 1~4개, 세션 전체 live 호출 8개. 운영자가 최대 32개로 설정 가능.
- 요청 최대 64KiB, 그래프 최대 64파트/128링크, 각 응답 출력 토큰 최대 2048.
- API 요청 45초/물리 프로세스 75초 제한. 취소 시 후속 호출·평가를 중단한다.
  이미 전송된 API 호출은 완료/과금될 수 있다. 호출 횟수는 실패 요청도 소비한다.
  토큰 합계는 정상 응답에서 확인한 사용량이며 실패/시간초과 과금의 완전한 장부가 아니다.
- 키는 브리지에만 존재하고 자식 Godot 프로세스에 전달하지 않는다. 일반 로그에 요청/키를 남기지 않는다.
- HTTP는 127.0.0.1만 바인딩하고 bearer token, Host 검사, 명시적 Origin 허용을 사용한다.
  브라우저 개발 서버는 예를 들어 `--origin http://localhost:8060`으로 정확히 허용한다.
- Godot는 GDScript/GL Compatibility/비동기 HTTP를 유지한다. 로컬 데스크톱 검증은
  웹 배포 검증이 아니다. 공개 HTTPS 웹 앱에는 별도의 인증·HTTPS·CORS·사용자별
  비용 한도·운영용 게이트웨이가 필요하며 이번 로컬 개발 서버를 그대로 공개하지 않는다.

## 계획·선행 연구

[구현 계획](MOTION_LAB_PLAN.md), [ADR 0008](adr/0008-bounded-motion-learning-bridge.md),
[논문 검토](research/llm-motion-prior-work.md), [Godot/MCP 개발 검토](research/motion-tooling.md).
Exa로 2개 조사 흐름의 8개 검색 각도에서 총 59개 결과 요청을 검토하고 원저자 자료를
확인했다. 검색 수는 논문 59편 재현/정독을 뜻하지 않는다.

기존 스킬을 조합하는 SayCan/Code as Policies, 실제 피드백으로 개선하는 Eureka와
Iterative Policy Refinement를 참고했다. 연구 구조를 제한된 파라미터 탐색에 맞게
적용한 것이며, 해당 논문을 재현하거나 성능 수치를 가져온 것은 아니다.

## 검증

```sh
python3 -m unittest tools.motion_lab.test_service -v
python3 -m unittest tools.motion_lab.test_races -v
godot --headless --path . --fixed-fps 60 --script tests/motion_lab_check.gd
godot --headless --path . --script tests/motion_lab_ui_check.gd
.venv-motion/bin/python -m unittest tests.motion_mcp_check -v
```

2026-09-15 비용 없는 실제 물리 탐색에서 기본 정책과 후보 2개를 평가했다.
기본 전진은 약 **0.000198m**, yaw **−0.358rad**, 점수 **−1.0583**였다.
자세 편향 2° 후보는 뒤로 움직여 점수가 나빠졌고, 주기 2.8초 후보는 넘어졌다.
시스템은 올바르게 기존 정책을 최선으로 유지했다. **이 결과는 학습된 보행이나
GPT 개선 성능의 증거가 아니라 평가·실패 판별·최선 보존 기능의 검증이다.**

실제 OpenAI API 요청은 키 미설정으로 실행하지 않았다. 공개 웹 배포·실물 로봇·
실제 게임패드에 대한 추가 검증도 이 기능 검증에 포함되지 않는다.

최종 로컬 검증 결과:

- 정책·그래프·격리 물리·정확한 JSON 왕복·취소: **232 checks, 0 failures**.
- Godot UI 및 실제 mock HTTP 시작/조회/취소/적용/저장·복구: **47 checks, 0 failures**.
- Python 서비스·인증·비용 한도·취소 경쟁 조건: **23 tests, OK**.
- 실제 MCP SDK 최신/레거시 stdio 및 제한 도구: **14 tests, OK**.
- Godot import/main load, 기존 편집·입력·코드 전환·조립·물리·메쉬·재질 회귀: 통과.
- GL Compatibility 실제 화면 캡처로 설정/평가 결과 UI를 확인했다.

전송 정밀도 회귀에서는 원본과 full-precision JSON 그래프의 물리 측정값이 정확히
일치하는지 검사한다. UI에서 조립품을 변경했다 복원하는 테스트도 역산이 아니라 저장한
`Transform3D`를 정확히 복원한다. 작은 좌표 오차를 반올림한 fingerprint로 숨기지 않는다.
