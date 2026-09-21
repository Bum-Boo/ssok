# rl_lab — 오프라인 정책 학습과 검증

현재 결과와 Godot 전이 한계, 재현 명령은 [RL_LAB.md](../../docs/RL_LAB.md)를 참고하세요.

조립한 biped를 MuJoCo로 옮겨 **실제로 정책을 학습**하고, `gpt-5.6-luna`가 라운드마다
**보상 가중치**를 제안하는 Eureka 방식 루프. GPU·torch 없이 CPU 4코어에서 돈다.

```text
Godot 조립 그래프 ─ export_rl_robot.gd ─> robots/biped.json ─ robot_to_mjcf.py ─> MuJoCo
                                                                                  │
Luna(또는 mock) ── 보상 가중치 7개 + 노브 2개 (숫자만) ──> ARS 학습 (선형 정책, env.py)
      ↑                                                                           │
      └──── 과제 지표(성공률·넘어짐·전진·옆밀림·yaw) + 보상 항 평균 ◀── 고정 시드 평가
```

| 참고한 것 | 가져온 아이디어 | 가져오지 않은 것 |
|---|---|---|
| Isaac Lab (Isaac Sim) | 관측/행동/보상 항 × 가중치/종료 조건을 분리한 manager 스타일 설정 (`env.py`) | GPU 병렬 시뮬레이션, USD |
| MuJoCo | 학습용 물리, MJCF | MJX(GPU) — Himmel-PC 확장 단계(#17, #22) |
| LIBERO | 언어 과제 설명 + **보상과 분리된 성공 판정** + 시드별 성공률 (`tasks/*.json`) | 조작 과제 모음, BDDL |
| cuRobo | 관절 한계·액추에이터 한계를 로봇 설정에서 생성 (`robot_to_mjcf.py`) | GPU 모션 플래닝 |
| Eureka | LLM 보상 제안 → RL → 보상 항별 측정값 피드백 | LLM이 보상 **코드**를 작성·실행 (여기선 숫자만) |

## 실행

```sh
python3 -m venv .venv-rl
touch .venv-rl/.gdignore
.venv-rl/bin/pip install -r tools/rl_lab/requirements.txt

# 로봇을 바꿨을 때만: Godot에서 다시 내보내기
godot --headless --path . --script tools/godot/export_rl_robot.gd -- --out "$PWD/tools/rl_lab/robots/biped.json"

# 무료 mock (규칙 기반, AI 아님)
.venv-rl/bin/python -m tools.rl_lab.run --rounds 3 --iterations 25

# 실제 Luna (유료) — 키는 이 터미널 환경에만
read -rsp 'OpenAI API key: ' OPENAI_API_KEY; export OPENAI_API_KEY
.venv-rl/bin/python -m tools.rl_lab.run --live --allow-paid --max-calls 3 --rounds 3

# 학습된 정책을 ssok의 Godot 물리에서 다시 평가 (sim2sim)
godot --headless --path . --fixed-fps 60 --script tools/godot/play_rl_policy.gd -- --policy tools/rl_lab/runs/<run>/best_policy.json
```

결과는 `tools/rl_lab/runs/<시각>/` (`summary.json`, 라운드별·최선 정책 JSON, git 무시).
라운드당 Luna 호출 1회, 호출 전에 횟수를 센다. 자동 재시도·모델 대체·코드 실행 없음.
최선 라운드는 Luna가 조정한 보상이 아니라 **과제 지표**로 고른다.

## 한계 (정직하게)

- MuJoCo 서보는 토크 제한 위치 제어, Godot `ServoDrive`는 힌지를 목표각에 고정하는 방식이라
  물리가 다르다. MJCF는 자가 충돌을 끈다. MuJoCo에서 걷는 정책이 ssok 앱에서 걷는다는 보장은
  없고, `play_rl_policy.gd` 결과로만 말한다(#19, #24).
- 선형 정책 + 시계 입력은 작은 슬라이스용이다. 복잡한 로봇은 PPO/MLP(#21, #22)가 필요하다.
- 지원 로봇은 biped 하나, 과제는 전진 하나다.

## 테스트

```sh
.venv-rl/bin/python -m unittest tools.rl_lab.test_rl_lab -v
```
