extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _background_result: Dictionary = {}


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if "--transport" in OS.get_cmdline_user_args():
		await _check_transport_diagnostic()
		quit(0)
		return
	_check_policy()
	_check_snapshot()
	_check_engine_version()
	await _check_trials()
	await _check_trial_lifecycle()
	print("motion_lab_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check_transport_diagnostic() -> void:
	var graph: ConnectionGraph = BipedPreset.build()
	var snapshot: Dictionary = MotionSnapshot.encode(graph)
	var trial: MotionTrial = MotionTrial.new()
	root.add_child(trial)
	for mode: int in range(3):
		var text: String = JSON.stringify(snapshot, "", true, mode == 2)
		var copy: ConnectionGraph = graph if mode == 0 else MotionSnapshot.decode(JSON.parse_string(text))
		var changes: Array[Dictionary] = []
		for index: int in range(graph.parts.size()):
			var original: Transform3D = graph.parts[index].transform
			var decoded: Transform3D = copy.parts[index].transform
			if original != decoded:
				changes.append({"index": index, "original": str(original), "decoded": str(decoded)})
		print("TRANSPORT_GRAPH_%d=" % mode + text)
		print("TRANSPORT_BITS_%d=" % mode + JSON.stringify(changes))
		var result: Dictionary = await trial.run_trial(copy, MotionPolicy.defaults())
		print("TRANSPORT_METRICS_%d=" % mode + JSON.stringify(result))
	trial.free()


func _check_policy() -> void:
	var policy: Dictionary = MotionPolicy.defaults()
	_assert(MotionPolicy.validate(policy).is_empty(), "default policy is valid")
	for value: Variant in [null, false, [], "policy", 2.4]:
		_assert(not MotionPolicy.validate(value).is_empty(), "non-object policy rejected")
	var program: BipedMotion = BipedMotion.new()
	_assert(program.get_policy() == policy, "policy default matches existing movement program")
	for field: String in MotionPolicy.LIMITS:
		var bounds: Array = MotionPolicy.LIMITS[field]
		for value: Variant in [true, "1", null, INF, -INF, NAN, float(bounds[0]) - 0.1, float(bounds[1]) + 0.1]:
			var invalid: Dictionary = policy.duplicate(true)
			invalid[field] = value
			_assert(not MotionPolicy.validate(invalid).is_empty(), "invalid parameter rejected: " + field)
			_assert(not program.apply_policy(invalid), "invalid policy cannot be applied")
			_assert(program.get_policy() == policy, "policy application is atomic")
		for value: float in [bounds[0], bounds[1]]:
			var boundary: Dictionary = policy.duplicate(true)
			boundary[field] = value
			_assert(MotionPolicy.validate(boundary).is_empty(), "inclusive parameter boundary accepted")
	_assert(MotionPolicy.validate({"cycle_seconds": 0.8, "stride_degrees": 0, "lean_degrees": 35, "posture_degrees": -10}).is_empty(), "JSON literal minimum cycle accepted without float32 rounding")
	var extra: Dictionary = policy.duplicate(true)
	extra["code"] = "print('not executable')"
	_assert(not MotionPolicy.validate(extra).is_empty(), "extra policy fields rejected")
	var missing: Dictionary = policy.duplicate(true)
	missing.erase("cycle_seconds")
	_assert(not MotionPolicy.validate(missing).is_empty(), "missing parameter rejected")
	policy.stride_degrees = 12
	_assert(program.apply_policy(policy) and program.stride_degrees == 12.0, "valid numeric policy applies")
	program.free()


func _check_snapshot() -> void:
	var graph: ConnectionGraph = BipedPreset.build()
	var encoded: Dictionary = MotionSnapshot.encode(graph)
	_assert(not encoded.is_empty(), "biped graph can be encoded")
	var decoded: ConnectionGraph = MotionSnapshot.decode(JSON.parse_string(JSON.stringify(encoded, "", true, true)))
	_assert(decoded != null, "JSON round trip decodes")
	if decoded == null:
		return
	_assert(decoded.parts.size() == graph.parts.size() and decoded.links == graph.links, "round trip retains parts and wiring")
	for index: int in range(graph.parts.size()):
		_assert(decoded.parts[index].transform == graph.parts[index].transform, "full precision JSON round trip retains every transform bit")
		_assert(decoded.parts[index].part_def == graph.parts[index].part_def, "round trip resolves trusted catalog resource")
	_assert(MotionSnapshot.fingerprint(encoded).length() == 64, "snapshot fingerprint is SHA-256")
	_assert(MotionSnapshot.fingerprint(encoded) == MotionSnapshot.fingerprint(MotionSnapshot.encode(decoded)), "fingerprint stable across JSON round trip")
	var lossy: Dictionary = JSON.parse_string(JSON.stringify(encoded))
	_assert(MotionSnapshot.fingerprint(encoded) != MotionSnapshot.fingerprint(lossy), "lossy JSON transforms must not share exact graph identity")
	var shifted: Dictionary = encoded.duplicate(true)
	shifted.parts[0].transform[9] = -0.0000000002235174
	_assert(MotionSnapshot.fingerprint(encoded) != MotionSnapshot.fingerprint(shifted), "sub-micrometre pose changes invalidate evaluated graph identity")
	var rewired: Dictionary = encoded.duplicate(true)
	for link: Dictionary in rewired.links:
		if link.b_port == "pin_5":
			link.b_port = "pin_10"
	var rewired_graph: ConnectionGraph = MotionSnapshot.decode(rewired)
	_assert(rewired_graph != null, "compatible rewiring remains valid")
	_assert(MotionSnapshot.fingerprint(encoded) != MotionSnapshot.fingerprint(rewired), "rewiring changes graph fingerprint")
	_assert(Wiring.pin_map(rewired_graph).has(10) and not Wiring.pin_map(rewired_graph).has(5), "snapshot pin map follows rewiring")
	for value: Variant in [null, false, [], "graph", {"version": 1}, {"version": 1, "parts": [], "links": []}]:
		_assert(MotionSnapshot.decode(value) == null, "malformed graph rejected")
	for id: String in ["../../scenes/main.gd", "res://assets/parts/servo.tres", "unknown", "user://robot.tres"]:
		var invalid: Dictionary = encoded.duplicate(true)
		invalid.parts[0].id = id
		_assert(MotionSnapshot.decode(invalid) == null, "unknown or path-like part ID rejected")
	for value: Variant in [false, "1", null, INF, NAN]:
		var invalid: Dictionary = JSON.parse_string(JSON.stringify(encoded))
		invalid.parts[0].transform[0] = value
		_assert(MotionSnapshot.decode(invalid) == null, "non-finite/non-numeric transform rejected")
	for value: float in [2.0, 0.0, -1.0]:
		var invalid: Dictionary = encoded.duplicate(true)
		invalid.parts[0].transform[0] = value
		_assert(MotionSnapshot.decode(invalid) == null, "scale/singular/reflected basis rejected")
	var sheared: Dictionary = encoded.duplicate(true)
	sheared.parts[0].transform[1] = 0.2
	_assert(MotionSnapshot.decode(sheared) == null, "shear rejected")
	var distant: Dictionary = encoded.duplicate(true)
	distant.parts[0].transform[9] = 101.0
	_assert(MotionSnapshot.decode(distant) == null, "unsafe coordinate rejected")
	var oversized: Dictionary = encoded.duplicate(true)
	for index: int in range(MotionSnapshot.MAX_PARTS + 1):
		oversized.parts.append(encoded.parts[0].duplicate(true))
	_assert(MotionSnapshot.decode(oversized) == null, "excess parts rejected")
	oversized = encoded.duplicate(true)
	for index: int in range(MotionSnapshot.MAX_LINKS + 1):
		oversized.links.append(encoded.links[0].duplicate(true))
	_assert(MotionSnapshot.decode(oversized) == null, "excess links rejected")
	for value: Variant in [-1, 64, 0.5, INF, true, "0"]:
		var invalid: Dictionary = encoded.duplicate(true)
		invalid.links[0].a_part = value
		_assert(MotionSnapshot.decode(invalid) == null, "invalid part index rejected")
	for value: Variant in ["missing", "signal_pin", 1, false, null]:
		var invalid: Dictionary = encoded.duplicate(true)
		invalid.links[0].a_port = value
		_assert(MotionSnapshot.decode(invalid) == null, "invalid or incompatible port rejected")
	var duplicate: Dictionary = encoded.duplicate(true)
	duplicate.links.append(duplicate.links[0].duplicate(true))
	_assert(MotionSnapshot.decode(duplicate) == null, "occupied port cannot be linked twice")
	var self_link: Dictionary = encoded.duplicate(true)
	self_link.links[0].b_part = self_link.links[0].a_part
	_assert(MotionSnapshot.decode(self_link) == null, "self link rejected")
	var extra: Dictionary = encoded.duplicate(true)
	extra["resource"] = "res://scenes/main.gd"
	_assert(MotionSnapshot.decode(extra) == null, "unknown snapshot field rejected")
	extra = encoded.duplicate(true)
	extra.parts[0]["mass"] = 1000
	_assert(MotionSnapshot.decode(extra) == null, "part mass cannot be overridden")
	extra = encoded.duplicate(true)
	extra.links[0]["script"] = "res://scenes/main.gd"
	_assert(MotionSnapshot.decode(extra) == null, "link scripts cannot be supplied")


func _check_engine_version() -> void:
	_assert(MotionTrial._engine_version_error(Engine.get_version_info()).is_empty(), "actual engine matches the exact trial pin")
	_assert(MotionTrial._engine_version_error({"major": 4, "minor": 7, "patch": 2}).is_empty(), "pinned engine accepted")
	for version: Dictionary in [{}, {"major": 3, "minor": 7, "patch": 2}, {"major": 4, "minor": 6, "patch": 2}, {"major": 4, "minor": 7, "patch": 1}, {"major": 4, "minor": 7, "patch": 3}]:
		_assert(MotionTrial._engine_version_error(version).contains("4.7.2"), "other engine versions fail with the exact required version")


func _check_trials() -> void:
	var trial: MotionTrial = MotionTrial.new()
	root.add_child(trial)
	var graph: ConnectionGraph = BipedPreset.build()
	var original: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(graph))
	var invalid: Dictionary = await trial.run_trial(graph, {})
	_assert(invalid.has("error") and not trial.is_running(), "invalid policy fails before world construction")
	invalid = await trial.run_trial(graph, MotionPolicy.defaults(), Vector2(INF, 0))
	_assert(invalid.has("error"), "non-finite command rejected")
	invalid = await trial.run_trial(graph, MotionPolicy.defaults(), Vector2.ONE)
	_assert(invalid.has("error"), "out-of-range command rejected")
	Engine.physics_ticks_per_second = 30
	invalid = await trial.run_trial(graph, MotionPolicy.defaults())
	Engine.physics_ticks_per_second = 60
	_assert(invalid.has("error"), "non-standard physics frequency rejected")
	Engine.time_scale = 2.0
	invalid = await trial.run_trial(graph, MotionPolicy.defaults())
	Engine.time_scale = 1.0
	_assert(invalid.has("error"), "global time acceleration rejected")
	invalid = await trial.run_trial(ServoArmPreset.build(), MotionPolicy.defaults())
	_assert(invalid.has("error") and trial.get_child_count() == 0, "unsupported robot fails and cleans up")
	_run_background(trial, graph)
	_assert(trial.is_running(), "trial marks itself busy before its first await")
	invalid = await trial.run_trial(graph, MotionPolicy.defaults())
	_assert(invalid.has("error"), "concurrent trial rejected")
	var viewport: SubViewport = trial.get_child(0) as SubViewport
	_assert(viewport.own_world_3d and viewport.find_world_3d().space != root.find_world_3d().space, "trial owns a separate physics space")
	for frame: int in range(5):
		await physics_frame
	trial.cancel()
	while _background_result.is_empty():
		await physics_frame
	_assert(_background_result.get("cancelled", false), "cancel ends in an explicit cancelled result")
	_assert(not trial.is_running() and trial.get_child_count() == 0, "cancel removes all trial nodes")
	var obstacle: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 4, 4)
	collision.shape = box
	obstacle.add_child(collision)
	root.add_child(obstacle)
	var result: Dictionary = await trial.run_trial(graph, MotionPolicy.defaults())
	print("MOTION_LAB_BASELINE=" + JSON.stringify(result))
	_assert(not result.has("error"), "full physical baseline completes")
	if not result.has("error"):
		_assert(result.finite and not result.fallen, "default trial remains finite and standing despite main-world obstacle")
		_assert(result.simulation_seconds == 16.5 and result.physics_hz == 60, "episode duration and frequency remain fixed")
		_assert(result.engine_version == "4.7.2", "result records the pinned engine for reproducibility")
		_assert(result.program_id == MotionPolicy.PROGRAM_ID, "trial identifies the evaluated controller family")
		_assert(result.min_upright > 0.9 and result.min_height_m > 0.09, "metrics include actual supported body posture")
		_assert(absf(result.forward_m) + absf(result.lateral_m) > 0.0001, "metrics report physical displacement")
		var expected_score: float = 100.0 * float(result.forward_m) - 30.0 * absf(result.lateral_m) - 2.0 * absf(result.yaw_rad) - 10.0 * (1.0 - clampf(result.min_upright, 0.0, 1.0))
		_assert(is_equal_approx(result.score, expected_score), "fixed score follows measured quantities")
		_assert(result.graph_fingerprint == original, "trial result identifies source graph")
	_assert(trial.get_child_count() == 0 and not trial.is_running(), "completed trial cleans up")
	_assert(MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)) == original, "trial never mutates assembly graph")
	obstacle.free()
	var transported: ConnectionGraph = MotionSnapshot.decode(JSON.parse_string(JSON.stringify(MotionSnapshot.encode(graph), "", true, true)))
	var transported_result: Dictionary = await trial.run_trial(transported, MotionPolicy.defaults())
	_assert(not transported_result.has("error"), "serialized graph physical trial completes")
	for field: String in ["forward_m", "lateral_m", "yaw_rad", "min_upright", "min_height_m", "score", "fallen", "finite", "graph_fingerprint"]:
		_assert(transported_result.get(field) == result.get(field), "full precision transport reproduces physical metric: " + field)
	var tipped: ConnectionGraph = MotionSnapshot.decode(MotionSnapshot.encode(graph))
	var rotation: Transform3D = Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3.ZERO)
	for entry: Dictionary in tipped.parts:
		entry.transform = rotation * entry.transform
	result = await trial.run_trial(tipped, MotionPolicy.defaults())
	_assert(result.get("fallen", false), "fall recorded during an initially tipped episode")
	_assert(result.get("score", 0) < -50, "fall receives fixed negative penalty")
	trial.free()
	await process_frame


func _check_trial_lifecycle() -> void:
	var graph: ConnectionGraph = BipedPreset.build()
	var trial: MotionTrial = MotionTrial.new()
	root.add_child(trial)
	_background_result = {}
	_run_background(trial, graph)
	var viewport: SubViewport = trial.get_child(0) as SubViewport
	root.remove_child(trial)
	while _background_result.is_empty():
		await physics_frame
	_assert(_background_result.get("cancelled", false), "removing a trial cancels its pending await")
	_assert(not trial.is_running() and trial.get_child_count() == 0, "removed trial releases its world children")
	await process_frame
	_assert(not is_instance_valid(viewport), "removed trial viewport is freed")
	root.add_child(trial)
	_background_result = {}
	_run_background(trial, graph)
	_assert(trial.is_running(), "cancelled removed trial can be reattached and reused")
	trial.cancel()
	while _background_result.is_empty():
		await physics_frame
	_assert(_background_result.get("cancelled", false), "reattached trial still cancels cleanly")
	trial.free()
	await process_frame
	var orphan_count: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var freed_trial: MotionTrial = MotionTrial.new()
	root.add_child(freed_trial)
	_run_background(freed_trial, graph)
	var freed_viewport: SubViewport = freed_trial.get_child(0) as SubViewport
	var freed_hardware: RunMode = freed_trial._hardware
	freed_trial.free()
	await physics_frame
	await process_frame
	_assert(not is_instance_valid(freed_viewport) and not is_instance_valid(freed_hardware), "freeing during await releases the entire isolated world")
	_assert(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphan_count, "freeing during await leaks no orphan nodes")


func _run_background(trial: MotionTrial, graph: ConnectionGraph) -> void:
	_background_result = await trial.run_trial(graph, MotionPolicy.defaults())


func _assert(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
