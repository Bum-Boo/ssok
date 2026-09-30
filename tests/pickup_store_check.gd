extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _created_ids: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var snapshot: Dictionary = MotionSnapshot.encode(HumanoidPreset.build())
	# Synthetic telemetry tests serialization only; pickup_trial_check measures physics.
	var metrics: Dictionary = {
		"finite": true, "fallen": false, "success": true, "lift_m": 0.40,
		"hold_seconds": 1.0, "min_upright": 0.89, "score": 170.0,
		"simulation_seconds": 9.0, "graph_fingerprint": MotionSnapshot.fingerprint(snapshot),
		"engine_version": "4.7.2", "physics_hz": 60, "phase": "succeeded",
		"contact_before_grasp": true, "cancelled": false,
	}
	var result: Dictionary = {"policy": PickupPolicy.defaults(), "metrics": metrics}
	var record: Dictionary = {
		"version": 1, "name": "Serialization fixture", "graph": snapshot,
		"result": result, "provider": "local", "created_utc": "2026-09-15T00:00:00",
	}
	_check(PickupScenarioStore.valid_record(record), "synthetic valid schema accepted")
	var modular_record: Dictionary = record.duplicate(true)
	modular_record.graph = MotionSnapshot.encode(ModularHumanoidPreset.build())
	modular_record.result.metrics.graph_fingerprint = MotionSnapshot.fingerprint(modular_record.graph)
	_check(PickupScenarioStore.valid_record(modular_record), "assembled modular graph is accepted by scenario persistence")
	for value: Variant in [null, false, [], "scenario", {}, 1.0]:
		_check(not PickupScenarioStore.valid_record(value), "invalid top-level type rejected")
	for key: String in record:
		var invalid: Dictionary = record.duplicate(true)
		invalid.erase(key)
		_check(not PickupScenarioStore.valid_record(invalid), "missing schema key rejected: " + key)
	for key: String in ["name", "created_utc", "provider", "graph", "result"]:
		var invalid: Dictionary = record.duplicate(true)
		invalid[key] = false
		_check(not PickupScenarioStore.valid_record(invalid), "wrong schema type rejected: " + key)
	for value: Variant in [0, 2, true, "1", 1.5]:
		var invalid: Dictionary = record.duplicate(true)
		invalid.version = value
		_check(not PickupScenarioStore.valid_record(invalid), "incompatible version rejected")
	var extra: Dictionary = record.duplicate(true)
	extra.executable = "not permitted"
	_check(not PickupScenarioStore.valid_record(extra), "unexpected top-level property rejected")
	var mismatched: Dictionary = record.duplicate(true)
	mismatched.graph.parts[-1].transform[11] += 0.01
	_check(not PickupScenarioStore.valid_record(mismatched), "saved metrics cannot be associated with a changed graph")
	for value: Variant in [INF, -INF, NAN, true, "0.4"]:
		var invalid: Dictionary = record.duplicate(true)
		invalid.result.metrics.lift_m = value
		_check(not PickupScenarioStore.valid_record(invalid), "non-finite or nonnumeric metrics rejected")
	var missing_contact: Dictionary = record.duplicate(true)
	missing_contact.result.metrics.erase("contact_before_grasp")
	_check(not PickupScenarioStore.valid_record(missing_contact), "successful record requires contact evidence")
	var cancelled: Dictionary = record.duplicate(true)
	cancelled.result.metrics.cancelled = true
	cancelled.result.metrics.phase = "cancelled"
	cancelled.result.metrics.success = false
	_check(PickupScenarioStore.valid_record(cancelled), "cancelled failure remains an inspectable scenario")
	for id: String in ["../../project", "/tmp/escape", "user://other", "res://project.godot", "abc.json", "", "G".repeat(24), "0".repeat(25), "0".repeat(23)]:
		_check(PickupScenarioStore.load_scenario(id).is_empty(), "path-like or malformed identifier rejected")
	_check(PickupScenarioStore.save_scenario(" ", snapshot, result, "local").has("error"), "blank scenario name rejected")
	_check(PickupScenarioStore.save_scenario("fixture", snapshot, result, "unknown").has("error"), "unknown proposal source rejected")
	_check(PickupScenarioStore.save_scenario("fixture", snapshot, missing_contact.result, "local").has("error"), "invalid results are not written")
	var prior: Array[Dictionary] = PickupScenarioStore.list_scenarios()
	if prior.size() > PickupScenarioStore.MAX_FILES - 2:
		_check(false, "two free scenario slots required; existing user records were preserved")
	else:
		_check_file_roundtrip(snapshot, result)
	_cleanup_owned_files()
	for entry: Dictionary in prior:
		_check(not PickupScenarioStore.load_scenario(entry.id).is_empty(), "pre-existing user record is untouched")
	print("pickup_store_check: %d checks, %d failures; removed only %d test-created records" % [_checks, _failures, _created_ids.size()])
	quit(1 if _failures else 0)


func _check_file_roundtrip(snapshot: Dictionary, result: Dictionary) -> void:
	var contaminated: Dictionary = result.duplicate(true)
	contaminated.metrics.transport_only = "must not persist"
	contaminated.transport_only = "must not persist"
	for index: int in range(2):
		var saved: Dictionary = PickupScenarioStore.save_scenario("테스트 / 测试 / テスト", snapshot, contaminated, "local")
		_check(saved.has("id") and saved.has("path"), "local scenario saves successfully")
		if not saved.has("id"):
			continue
		_created_ids.append(saved.id)
		_check(saved.path == PickupScenarioStore.DIRECTORY + saved.id + ".json", "display name cannot control the storage path")
		var restored: Dictionary = PickupScenarioStore.load_scenario(saved.id)
		_check(not restored.is_empty(), "saved scenario reloads")
		if restored.is_empty():
			continue
		_check(restored.result.metrics.contact_before_grasp and not restored.result.metrics.cancelled, "contact and cancellation evidence survives persistence")
		_check(_same_numeric_record(restored.result.policy, result.policy) and _same_numeric_record(restored.result.metrics, result.metrics), "safe policy and metric values round-trip exactly")
		_check(MotionSnapshot.fingerprint(restored.graph) == result.metrics.graph_fingerprint, "full-precision graph identity survives disk JSON")
		_check(not restored.result.has("transport_only") and not restored.result.metrics.has("transport_only"), "transport-only fields never enter saved scenario")
	if _created_ids.size() != 2:
		return
	_check(_created_ids[0] != _created_ids[1], "same-name saves get unique identifiers without overwriting")
	var listed: Array[Dictionary] = PickupScenarioStore.list_scenarios()
	for id: String in _created_ids:
		_check(listed.any(func(entry: Dictionary) -> bool: return entry.id == id), "saved scenario is discoverable")
	var path: String = PickupScenarioStore.DIRECTORY + _created_ids[0] + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[]")
	file.close()
	_check(PickupScenarioStore.load_scenario(_created_ids[0]).is_empty(), "wrong JSON document schema rejected on load")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(" ".repeat(PickupScenarioStore.MAX_BYTES + 1))
	file.close()
	_check(PickupScenarioStore.load_scenario(_created_ids[0]).is_empty(), "oversized file rejected before JSON parsing")


func _cleanup_owned_files() -> void:
	for id: String in _created_ids:
		if RegEx.create_from_string("^[a-f0-9]{24}$").search(id) == null:
			_check(false, "refusing cleanup of an unvalidated target")
			continue
		var path: String = PickupScenarioStore.DIRECTORY + id + ".json"
		_check(DirAccess.remove_absolute(path) == OK, "remove only record created by this test")


func _same_numeric_record(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: String in a:
		if not b.has(key):
			return false
		if typeof(a[key]) in [TYPE_INT, TYPE_FLOAT] and typeof(b[key]) in [TYPE_INT, TYPE_FLOAT]:
			if float(a[key]) != float(b[key]):
				return false
		elif a[key] != b[key]:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
