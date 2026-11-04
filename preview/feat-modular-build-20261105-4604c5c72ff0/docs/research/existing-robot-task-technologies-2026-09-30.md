# 자연어 로봇 과제: 기존 기술과 Ssok 재사용 후보

확인일: 2026-09-30 · 상태: 공식 문서·저장소·논문 비교 완료, 설치·Ssok 통합 실험 전.

후속: [구체적인 이식 후보와 분리 실행 결과](reuse-shortlist-2026-09-30.md). 최신 사용자 방향인 깃발 과제 우선에 맞춰 State Charts·Beehave·Kenney를 좁혔으며, 두 Godot 애드온의 합성 네이티브 실행까지 추가했다. 아래 표는 이 후속 실험 전 조사 기록이다.

사용자 질문: “기존 기술들이 있는지도 찾아봄?”

기존 [LLM 동작 선행연구](llm-motion-prior-work.md)와 [동작 도구 조사](motion-tooling.md)는 2026-09-15에 SayCan, Code as Policies, Godot RL Agents 등을 다뤘다. 당시 중심은 제한된 보행 파라미터 탐색이었다. 이번에는 **“선반에 저 책을 꽂아줘”를 실행하는 데 어떤 구현을 가져다 쓸 수 있는가**까지 비교 범위를 넓혔다.

## 1. 재사용할 수 있는 것은 이미 있다

| 필요한 부분 | 기존 기술·1차 출처 | 가져다 쓸 수 있는 것 | Ssok에 남는 작업 / 판단 |
|---|---|---|---|
| 행동 순서와 상태 관리 | [Beehave](https://github.com/bitbrain/beehave) | Godot용 행동 트리, 순서·조건·성공/실패 처리, 시각 디버거. GDScript 소스에 `tick()`·`interrupt()` 구현이 있다. | **가장 가까운 도입 검증 후보.** 각 leaf action을 Ssok 제어기와 연결해야 한다. 트리 중단만으로 모터/그립의 물리적 중단이 보장되지는 않는다. Godot 4.x 지원 표는 있으나 정확한 4.7.2·Web 내보내기는 미검증. 단순한 첫 과제에 트리 의존성이 필요한지도 비교한다. |
| 집기·옮기기 경로 계획 | [MoveIt 2 / MoveIt Task Constructor](https://moveit.picknik.ai/main/doc/tutorials/pick_and_place_with_moveit_task_constructor/pick_and_place_with_moveit_task_constructor.html) | 접근→그립 자세 생성→역기구학→들기→배치→놓기→후퇴의 단계별 계획과 공식 데모. | **외부 계획 서비스 후보.** ROS 2, URDF/SRDF, 좌표계, 충돌 형상, 관절 한계·그리퍼·제어기 매핑이 필요하다. 기존 Panda 예제를 임의 조립 Kit의 해결책으로 간주하지 않는다. 궤적을 구해도 현재 Godot의 토크·접촉·균형 하에서 실제 수행되는지 재검증해야 한다. 상용 MoveIt Pro와 구분한다. |
| 생활 과제와 성공 조건 | [BEHAVIOR-1K / OmniGibson](https://behavior.stanford.edu/behavior_components/behavior_tasks.html) | 물체·초기 상태·목표 조건으로 표현한 생활 과제, 장면과 평가 구조. **책을 책장에 다시 꽂는 과제도 존재한다.** | 과제 명세·평가 방식의 재사용 가치가 높다. OmniGibson 전체는 Omniverse/Isaac Sim 기반 별도 환경이며 [설치 요구](https://behavior.stanford.edu/getting_started/installation.html)가 크다. Godot에 그대로 넣는 플러그인으로 취급하지 않는다. |
| 상호작용 장면과 물체 API | [AI2-THOR](https://ai2thor.allenai.org/ithor/documentation/interactive-physics/) / [ManipulaTHOR](https://ai2thor.allenai.org/manipulathor/documentation/) | 물체 ID, 집기·놓기, 상태 관측, 로봇 팔 조작용 환경. Unity 환경과 Python 인터페이스는 [공식 저장소](https://github.com/allenai/ai2thor)에 공개돼 있다. | 명령/관측 계약 및 독립 비교 환경 후보. iTHOR의 기본 `PickupObject`는 물체를 손으로 순간이동시키는 추상화도 사용한다. Ssok의 접촉·토크 기준을 만족한 로봇 집기로 인용할 수 없다. ManipulaTHOR의 팔 제어도 별도 연결 검증이 필요하다. |
| 언어→사용 가능한 동작 선택 | [SayCan](https://say-can.github.io/) / [Code as Policies](https://github.com/google-research/google-research/blob/master/code_as_policies/README.md) | 언어 계획을 로봇 능력과 연결하는 연구, 로봇 API를 조합하는 공개 예제. | 계획 구조의 근거. 대상 ID와 지원 동작 목록을 넘겨 제한된 행동을 선택하게 한다. Ssok에서는 생성된 Python/GDScript를 그대로 실행하지 않는다. 연구 결과가 현재 Kit의 동작 능력을 보증하지 않는다. |
| 이미 학습된 로봇 정책과 학습 도구 | [LeRobot](https://huggingface.co/docs/lerobot/main/index) / [openpi](https://github.com/Physical-Intelligence/openpi) | 데이터셋·시연·정책 학습/추론 도구, ACT·VLA 계열과 공개 π0/π0.5 체크포인트. | **후속 실험 후보.** 관측·관절/행동 공간 연결, 로봇별 데이터와 평가가 필요하다. openpi도 다른 로봇에서의 동작을 보장하지 않으며 GPU 요구를 명시한다. 모든 행동을 처음부터 학습할 필요는 없지만, 임의 조립 로봇에 체크포인트만 꽂으면 되는 것도 아니다. |
| 조작 과제의 시연·학습 데이터 | [ManiSkill](https://maniskill.readthedocs.io/en/latest/user_guide/data_collection/index.html) | 스크립트 동작 계획·원격 조작으로 시연 생성. 공식 [PickCube 계획 예제](https://maniskill.readthedocs.io/en/latest/user_guide/demos/scripts.html)가 있다. | 학습이 필요한 단계의 외부 실험 도구. 다른 시뮬레이터의 결과를 Ssok의 물리 성공으로 대체하지 않는다. 첫 명령창 구현의 필수 의존성은 아니다. |

## 2. 책꽂기 자체의 선행 사례

[BEHAVIOR의 `re_shelving_library_books-0`](https://behavior.stanford.edu/knowledgebase/tasks/re_shelving_library_books-0.html)은 탁자 위 책 세 권을 책장 안에 두는 과제다. 공개 정의는 책·책장·탁자·바닥, 초기 상태, 모든 책이 어떤 책장 안에 있어야 한다는 목표를 명시한다. [책 분류 과제 `sorting_books_on_shelf-0`](https://behavior.stanford.edu/knowledgebase/tasks/sorting_books_on_shelf-0.html)도 공식 지식베이스에 등재돼 있다.

이것은 **과제 정의와 장면의 존재**를 확인한 것이다. 임의 로봇이 곧바로 수행하는 완성 모델이 제공된다는 증거는 아니다. `inside` 조건만 가져오면 사용자가 기대하는 똑바른 정렬·손을 놓은 뒤 안정성까지 보장하지 않으므로 Ssok 목표 조건은 별도로 구체화한다.

[Yang 등의 책 삽입 연구](https://arxiv.org/abs/2411.04374)는 주변 책을 밀어 공간을 만들면서 빽빽한 책장에 책을 끼우는 접촉 계획을 다룬다(2024 제출, 2025 개정). 간소화된 접촉 모델로 끼워 넣는 전략을 계획한다. 빈 칸에 놓는 과제와 주변 책을 밀어야 하는 과제의 기술적 차이를 보여 주는 직접적인 사례다. 이번에 확인한 논문 소개의 영상 링크만으로 재사용 가능한 SDK·공개 구현·Ssok 재현 성공을 확인했다고 쓰지 않는다.

## 3. 우선 검증할 조합

현재 판단은 **Godot 유지 + 기존 제공자 연결 방식 + 검증된 행동 실행 + 필요할 때 외부 동작 계획**이다. 아래는 도입 제안이며 새 ADR 승인이나 구현 완료가 아니다.

1. **기존 실행 기반 확인:** 현재 상자 집기 제어기의 지원 범위와 수정된 토크 모델에서의 관측 결과를 먼저 고정한다. 과거 성공 기록을 현재 모델의 보증으로 쓰지 않는다([ADR0020](../adr/0020-whole-step-actuator-torque-budget.md)).
2. **Beehave 소규모 비교:** 버전·커밋을 고정해 별도 검증 장면에서 Godot 4.7.2 import와 Web 실행, 진행/성공/실패/중단을 확인한다. 현재 집기 행동과 연결하여 실행 도중 중단 후 늦은 응답이 동작을 재개하지 않는지 본다. 같은 범위의 작은 상태 머신보다 이점이 없으면 추가 의존성을 채택하지 않아도 된다.
3. **명령과 실제 수행 연결:** “이 상자를 들어줘”를 선택된 물체 ID와 허용 행동으로 변환한다. 비용 없는 테스트 어댑터와 실제 제공자 경로를 구별하고, 성공은 Godot 관측으로 판정한다. 이 범위에서 자체 대규모 모델 학습은 필수 작업이 아니다.
4. **한 로봇의 책 배치로 확장:** BEHAVIOR의 상태/목표 표현을 참고한다. 기존 제어기로 도달하지 못하는 자세·경로가 필요하면 MoveIt Task Constructor 공식 데모와 한 로봇의 기구학 매핑을 독립 검증한다. 열린 조립 전부의 URDF 변환부터 만들지 않는다. 로봇 표현은 ConnectionGraph에서 유도한다.
5. **접촉 삽입·여러 물체는 다음 단계:** 책끼리 밀리는 접촉 과제나 익숙하지 않은 물체에서 기존 계획/제어의 한계가 관측되면, 전용 접촉 제어 또는 LeRobot/openpi 정책의 적용 가능성을 실제 데이터로 비교한다.

이 순서는 구현량을 줄이기 위한 기술 판단이다. Beehave의 실행 성능, MoveIt의 Ssok 성공률, VLA의 데이터 효율을 측정한 결론은 아니다.

## 4. 라이선스·비용·제품 경계

- 확인한 저장소 기준: Beehave는 MIT, MoveIt 2와 MoveIt Task Constructor는 BSD-3-Clause, AI2-THOR·LeRobot·openpi·ManiSkill은 Apache-2.0, BEHAVIOR-1K 저장소 루트는 MIT다. [Beehave LICENSE](https://github.com/bitbrain/beehave/blob/godot-4.x/LICENSE), [MoveIt 2](https://github.com/moveit/moveit2), [MTC](https://github.com/moveit/moveit_task_constructor/tree/ros2), [AI2-THOR](https://github.com/allenai/ai2thor), [LeRobot](https://github.com/huggingface/lerobot), [openpi](https://github.com/Physical-Intelligence/openpi), [ManiSkill](https://github.com/mani-skill/ManiSkill), [BEHAVIOR](https://github.com/StanfordVL/BEHAVIOR-1K).
- 도입할 때 실제 고정 버전의 LICENSE/NOTICE를 다시 검토한다. 저장소 코드 라이선스를 모든 물체 자산·데이터셋·모델 가중치에 확대 적용하지 않는다. openpi에는 별도 Gemma 라이선스 파일도 있다.
- 오픈소스 도구를 사용하는 것과 외부 AI 요청의 과금은 별개다. 연결 계정·구독/API 청구·호스팅/추론 비용은 [제품 비용 고지 기준](../PRODUCT_EXPERIENCE.md)에 따라 표시한다. 이번 조사는 유료 AI 요청을 발생시키지 않았다.
- 브라우저 앱에서 직접 CLI/ROS 프로세스를 실행하지 않는다. 외부 서비스 제안은 [ADR0001](../adr/0001-engine-and-deployment-targets.md)·[ADR0008](../adr/0008-bounded-motion-learning-bridge.md)의 경계를 따른다. 일반 로봇 과제 지원은 [자연어 수행 설계](../NATURAL_LANGUAGE_TASKS.md)에 적힌 후속 ADR 범위다.

## 5. 실제 조사 범위와 남은 검증

공식 프로젝트 페이지·문서, 논문 초록/소개, 저장소 README와 라이선스/메타데이터를 대조했다. Beehave 행동 트리 소스, MoveIt Task Constructor 공식 튜토리얼 원문, BEHAVIOR 책 과제의 실제 정의까지 확인했다. 기존 로컬 선행연구와 중복·차이를 기록했다.

외부 패키지를 설치하거나 모델을 내려받지 않았고, Ssok의 앱 코드·엔진·물리·번역은 바꾸지 않았다. 언어팩 변경 대상은 없다. 유료 호출·원격 GPU 작업·배포도 없다. 이번 완료 범위는 **재사용 후보 조사와 개발노트 반영**이며, 도구를 Ssok에 연결하고 실행한 결과는 후속 검증으로 남는다.
