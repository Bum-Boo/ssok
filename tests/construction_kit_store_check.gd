extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: ConnectionGraph = ConstructionKitHumanoidPreset.build()
	var snapshot: Dictionary = MotionSnapshot.encode(graph)
	var fingerprint: String = MotionSnapshot.fingerprint(snapshot)
	_check(graph.parts.size() > 64 and graph.links.size() > 128, "elementary assembly exceeds the retired small-graph limits")
	_check(not snapshot.is_empty() and fingerprint.length() == 64, "large elementary graph safely encodes")
	var trial: PickupTrial = PickupTrial.new()
	root.add_child(trial)
	var completed: Array[Dictionary] = []
	trial.completed.connect(func(result: Dictionary) -> void: completed.append(result.duplicate(true)))
	var error: String = trial.start_trial(graph, PickupPolicy.defaults(), false)
	_check(error.is_empty(), "one real kit physics episode starts: " + error)
	if not error.is_empty():
		trial.free()
		_finish()
		return
	for frame: int in range(PickupTrial.MAX_FRAMES + 2):
		await physics_frame
		if not trial.is_running:
			break
	_check(not trial.is_running and completed.size() == 1, "episode finalizes one measured result")
	if completed.size() != 1:
		trial.free()
		_finish()
		return
	var measured: Dictionary = completed[0]
	_check(PickupPolicy.valid_metrics(measured.metrics), "success or failure is valid physical evidence")
	_check(measured.metrics.graph_fingerprint == fingerprint, "trial evidence refers to the exact large assembly")
	_check(measured.metrics.phase in ["succeeded", "failed"], "test stores the actual observed terminal outcome")
	_check(MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)) == fingerprint, "episode did not mutate editable kit parts")
	trial.free()
	await process_frame
	var prior: Dictionary = _existing_records()
	if prior.size() >= PickupScenarioStore.MAX_FILES:
		_check(false, "one free scenario slot is required; no user record was removed")
		_finish()
		return
	var label: String = "ssok-construction-store-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var saved: Dictionary = PickupScenarioStore.save_scenario(label, snapshot, measured, "local")
	_check(saved.has("id") and saved.has("path"), "large graph and real outcome save without truncation")
	var bytes: int = 0
	if saved.has("id") and saved.has("path"):
		var id: String = saved.id
		var path: String = saved.path
		var validated_path: bool = RegEx.create_from_string("^[a-f0-9]{24}$").search(id) != null and path == PickupScenarioStore.DIRECTORY + id + ".json" and not prior.has(id)
		_check(validated_path, "save created a unique exact local target")
		var restored: Dictionary = PickupScenarioStore.load_scenario(id)
		_check(not restored.is_empty(), "large scenario loads through the strict schema validator")
		if not restored.is_empty():
			_check(restored.name == label and restored.provider == "local", "scenario name and provenance survive")
			_check(restored.graph.parts.size() == graph.parts.size() and restored.graph.links.size() == graph.links.size(), "no individual stock or link was dropped from saved graph")
			_check(MotionSnapshot.fingerprint(restored.graph) == fingerprint, "full graph fingerprint survives disk JSON exactly")
			_check(restored.result.metrics.success == measured.metrics.success and restored.result.metrics.phase == measured.metrics.phase, "failed evidence is not rejected or relabeled successful")
			_check(restored.result.metrics.contact_before_grasp == measured.metrics.contact_before_grasp, "bilateral contact evidence is preserved without fabrication")
			_check(_same_values(restored.result.policy, measured.policy), "all seven policy values are preserved exactly")
			_check(_same_values(restored.result.metrics, PickupScenarioStore._clean_result(measured).metrics, 0.000000000001), "physical metrics retain measurement precision through JSON decimal conversion")
			var replay_graph: ConnectionGraph = MotionSnapshot.decode(restored.graph)
			_check(replay_graph != null, "saved elementary graph is decodable for a future fresh replay")
			if replay_graph != null:
				for index: int in graph.parts.size():
					_check(replay_graph.parts[index].part_def.id == graph.parts[index].part_def.id and replay_graph.parts[index].transform.is_equal_approx(graph.parts[index].transform), "saved replay retains each independent part identity and pose")
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			_check(file != null, "scenario file is readable")
			if file != null:
				bytes = file.get_length()
				file.close()
				_check(bytes > 0 and bytes <= PickupScenarioStore.MAX_BYTES, "complete larger scenario fits the unchanged 262 KiB cap")
			var listed: Array[Dictionary] = PickupScenarioStore.list_scenarios()
			_check(listed.any(func(item: Dictionary) -> bool: return item.id == id), "saved large scenario appears in the user's library")
		if validated_path and not restored.is_empty() and restored.name == label:
			_check(DirAccess.remove_absolute(path) == OK, "remove only the exact newly created test scenario")
			_check(not FileAccess.file_exists(path), "test scenario cleanup completed")
		else:
			_check(false, "unsafe cleanup target refused; no other scenario was touched")
	var after: Dictionary = _existing_records()
	_check(after.size() == prior.size(), "scenario library count returns to its initial value")
	for id: String in prior:
		_check(after.has(id) and after[id] == prior[id], "pre-existing scenario bytes were not changed")
	print("construction_kit_store_metrics: parts=%d links=%d bytes=%d outcome=%s lift=%.6f m hold=%.3f s" % [graph.parts.size(), graph.links.size(), bytes, measured.metrics.phase, measured.metrics.lift_m, measured.metrics.hold_seconds])
	_finish()


func _existing_records() -> Dictionary:
	var records: Dictionary = {}
	for entry: Dictionary in PickupScenarioStore.list_scenarios():
		var path: String = PickupScenarioStore.DIRECTORY + String(entry.id) + ".json"
		records[String(entry.id)] = FileAccess.get_sha256(path)
	return records


func _same_values(a: Dictionary, b: Dictionary, tolerance: float = 0.0) -> bool:
	if a.size() != b.size():
		return false
	for key: String in a:
		if not b.has(key):
			return false
		if typeof(a[key]) in [TYPE_INT, TYPE_FLOAT] and typeof(b[key]) in [TYPE_INT, TYPE_FLOAT]:
			if absf(float(a[key]) - float(b[key])) > tolerance:
				return false
		elif a[key] != b[key]:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)


func _finish() -> void:
	print("construction_kit_store_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)
