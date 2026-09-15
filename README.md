# ssok (쏙)

마우스로 파츠를 **쏙** 끼워 로봇을 조립하고, 실제 보드 기반 코드로 구동하는 교육용 3D 시뮬레이터.
디지털 과학상자를 지향한다 — 공간·시간·비용의 제약 없이 로봇 조립과 코딩을 배울 수 있게.

- 설계와 첫 마일스톤: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- 결정 기록(ADR): [docs/adr/](docs/adr/)
- 기여 규칙(사람·에이전트 공통): [AGENTS.md](AGENTS.md)
- Blender식 편집·WASD/게임패드 조종: [docs/CONTROLS.md](docs/CONTROLS.md)
- GPT 동작 개선·로컬 MCP: [docs/MOTION_LAB.md](docs/MOTION_LAB.md)

## 실행

Godot **4.7.2** (버전 고정 — 올릴 땐 `AGENTS.md`의 업그레이드 절차를 따를 것).

```sh
godot --path .            # 에디터 없이 실행
godot --path . --editor   # 에디터로 열기
```
