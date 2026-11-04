# M2b 캐스터 진단 — 미해결

2026-11-05, Codex. 앱 기준 `e5991492ce3081db25ad9a937116b597cd261c99`, Windows native,
Godot `4.7.2.stable.official.ed1daf0bf`. **채택한 수정은 없어요.** 모든 실험용 프리셋과
변환 변경은 복원했으며, 진단 도구와 근거만 전달해요. 푸시하지 않아요.

- [계약·진단 표·실험별 수치·검사 결과](../../WORK_SUMMARY_M2.md#m2b--벽-앞-정지-진단과-수정-2026-11-05)
- [최종 동일 조건 비교](final.json), [소스 해시](source-identity.json)
- [옛 차 60 Hz 시계열](final-legacy.csv), [키트 차 60 Hz 시계열](final-kit.csv)

재현 명령:

```powershell
& $env:GODOT --headless --path . --fixed-fps 60 --script tools/ci/diagnose_kit_car.gd
```

바닥 상자 20×0.1×20 m(윗면 y=0.05), 벽 x=0.8, 같은 BRAKE_CODE를 초기 물리 생성 직후
실행해요. 옛 차만 미리 안정화하지 않아요. graph와 평가 기준은 바꾸지 않아요.
출력 `M2B_DIAGNOSTIC`의 JSON에는 군집별 부품/질량, 장착점/축 높이, 피치,
캐스터 선속도·각속도 벡터, 접촉 대상, 차체 속도와 성공 상태가 있어요.

`stop_tick`은 **VM 종료**이며 물리 정지나 판정 성공 시점이 아니에요. `success_tick`은
성공 판정 시점이고 -1은 미달성이에요. 최종 옛 차 기록 tick130..310은 성공 tick225의
전후 1초와 0.3초 유지 창을 포함해요. 키트는 판정 창을 성립시키지 못했으므로
VM 종료 tick848의 전 1초~후 2초(tick788..968)를 남겨요. 성공으로 해석하지 않아요.
종료하지 못한 실험은 20초에서 관측을 마치고 마지막 2초만 CSV로 보존해요.
초기 실험은 VM 종료 후 1.5초까지이며 `final`/`order`는 2초까지예요.
피치는 초기 전진 방향 +X가 수평면에서 올라가는 각도로 정의해요.

각 JSON의 `trace`는 CSV 경로·LF 정규화 SHA-256(`sha256_lf`)·샘플 수·구간을, `tail_1s`는 마지막 60개 샘플의
요약을 담아요. 판정 `result`는 성공 후 동결되므로 옛 차의 마지막 CSV 값과 다를 수 있어요.
별도 원본 JSON을 그대로 보존하는 대신 속도/접촉 샘플만 CSV로 분리했어요.

실험 키:

| 키 | 조건 |
|---|---|
| baseline | 시작 커밋 형상, VM 종료 후 1.5초 관측 |
| light | 120×80 판, 60 mm 빔 2개, 보드/드라이버를 판에 직접 장착; 캐스터 x=90 mm |
| lever | light에서 캐스터 x=30 mm로 이동 |
| height | lever에서 20 mm 캐스터 스페이서 제거 |
| height_long | height에서 캐스터 x=90 mm로 복귀 |
| compact | 80×60 판, 아래쪽 모터 빔 2개, 65 mm 바퀴, 캐스터 x=20 mm, 20 mm 스페이서 |
| double | compact에서 두 번째 캐스터 구멍에 20 mm 스페이서 추가 |
| minimal | 60×40 판, 위쪽 모터 빔 2개, 65 mm 바퀴, 캐스터 x=10 mm, 20 mm 스페이서 |
| minimal_level | minimal에서 모터를 판 아래로, 캐스터에 4 mm 두께 빔 추가 |
| center | 시작 형상에서 키트 캐스터 고정 관절 기준점만 구 중심으로 이동 |
| pin | center에서 고정 관절 대신 구 중심 PinJoint3D; 의미 변경도 있어 기각 |
| order | 시작 형상에서 키트 캐스터를 고정 관절 node_a로 배정 |
| final | 앱/프리셋 복원 후 최종 진단 도구로 다시 관측 |

전부 FAIL이며 각 JSON은 동일 조건 옛 차 PASS도 함께 담아요. 실험의 실제 부품 목록·질량·
캐스터/축 좌표는 해당 JSON에서 확인해요. no-stop 실험에는 정지 후 측정이 없어요.
초기 최소 형상의 중복 포트는 진단용 그래프로 부적합해 폐기하고 고친 뒤 `minimal`을 측정했어요.
이 경험을 반영해 최종 도구는 Stage 시작 거부와 VM 오류를 exit 1로 보고해요.

독립 Astra 검토는 진단의 동일 조건·군집·질량비·벡터 크기·기록 창에서 차단 결함을
발견하지 못했어요. 검토는 실행 검사나 해결안 승인과 구분해요. CSV 해시는 총괄이 확인해요.

## Verification

- [Target results](target-summary.md)
- [Full results](full-summary.md)
- [Exact target output](target-console.log)
- [Exact full output](full-console.log)
