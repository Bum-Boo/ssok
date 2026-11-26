# Godot 애드온 재사용 분리 검사

판단과 한계: [이식 후보 조사](../reuse-shortlist-2026-09-30.md).

Godot `4.7.2.stable.official.ed1daf0bf`, GL Compatibility 설정의 별도 임시 프로젝트에서 실행했다. 렌더링 없는 headless 검사다. 실제 Ssok 코드와 물리 제어기를 호출하지 않는다.

## 결과

| 자료 | 결과 |
|---|---|
| [import.log](import.log) | 두 애드온 import 종료 0, 오류·경고 없음 |
| [initial-harness.log](initial-harness.log) | 최초 드라이버의 singleton 누락·frozen API 오용과 Beehave 디버거 오류. 통과로 집계하지 않음 |
| [upstream-check.log](upstream-check.log) | 드라이버 수정 후 검사 12개는 참이나 원본 Beehave가 디버거 관련 오류 6개 출력. 깨끗한 통과 아님 |
| [partial-patch-check.log](partial-patch-check.log) | 메시지 전송만 보완한 중간 결과. 종료 시 캡처 오류 1개 잔존 |
| [patched-check.log](patched-check.log) | 디버거 활성 여부 두 곳 보완 후 검사 12/12, 전체 로그 오류·경고 0, 종료 0 |

합성 동작의 실행 순서·진행·실패·중단 전달 8검사와 임무 시작·이벤트 전환·성공·재도전 4검사다. frozen 중 이벤트 전송은 라이브러리가 오류로 거부하는 API 사용이므로 최종 정상 사용 검사에서는 보내지 않는다. 물리적 정지·실제 집기·언어 이해·Web·렌더링·연결된 에디터 디버거의 검증은 포함하지 않는다.

## 재현 자료

- [출처·버전·SHA-256 manifest](manifest.json)
- [최종 드라이버](reuse_check.gd.txt) / [최초 드라이버](initial-harness.gd.txt)
- [Beehave 수정 diff](beehave-headless-debugger.patch) / [해당 MIT 허가문](Beehave-LICENSE.txt)

재현할 때 빈 Godot 프로젝트에 manifest의 정확한 revision에서 `addons/beehave/`와 `addons/godot_state_charts/`를 받는다. State Charts의 선택적 `csharp/` 래퍼와 양쪽 저장소의 테스트 애드온·데모는 제외한다. 각 저장소의 원본 LICENSE를 유지한다. 아래 설정으로 import 후, 드라이버를 `reuse_check.gd`로 복사해 실행한다.

```ini
config_version=5
[application]
config/name="Ssok isolated reuse probe"
[rendering]
renderer/rendering_method="gl_compatibility"
[editor_plugins]
enabled=PackedStringArray("res://addons/beehave/plugin.cfg", "res://addons/godot_state_charts/plugin.cfg")
```

```sh
godot --headless --path /path/to/isolated-probe --editor --import
godot --headless --path /path/to/isolated-probe --script reuse_check.gd
# Apply the saved Beehave diff in the isolated project, then rerun the same driver.
```

드라이버는 `SceneTree --script` 실행에서 두 Beehave singleton을 명시적으로 초기화한다. 실제 앱에서는 플러그인의 autoload 등록까지 검증해야 한다. 최종 결과 판정에는 종료 코드와 assertion뿐 아니라 전체 엔진 로그를 함께 확인한다.

Beehave 수정은 분리 복사본에만 적용했다. Ssok 앱의 애드온 도입·릴리스 버전 고정·Web 내보내기는 아직 하지 않았다. 보관한 GDScript는 `.gd.txt`이므로 조사 자료 때문에 Ssok가 미설치 애드온 클래스를 import하지 않는다.
