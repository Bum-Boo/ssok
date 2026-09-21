extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_policy()
	await _check_physics()
	await _check_modular_physics()
	await _check_lifecycle()
	print("pickup_trial_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _check_policy() -> void:
	var defaults: Dictionary = PickupPolicy.defaults()
	var motion: HumanoidMotion = HumanoidMotion.new()
	_check(defaults == motion.pickup_policy, "policy defaults preserve the verified hand-authored controller")
	_check(PickupPolicy.validate(defaults).is_empty(), "default policy is valid")
	for value: Variant in [null, [], true, "policy", {}, 3.0]:
		_check(not PickupPolicy.validate(value).is_empty(), "non-policy rejected")
	for key: String in PickupPolicy.LIMITS:
		var bounds: Array = PickupPolicy.LIMITS[key]
		for value: Variant in [true, "1", null, INF, -INF, NAN, bounds[0] - 0.01, bounds[1] + 0.01]:
			var invalid: Dictionary = defaults.duplicate(true)
			invalid[key] = value
			_check(not PickupPolicy.validate(invalid).is_empty(), "unsafe parameter rejected: " + key)
			_check(not PickupPolicy.apply(motion, invalid), "invalid policy application rejected")
			_check(motion.pickup_policy == defaults, "invalid application preserves current policy")
		for value: float in [bounds[0], bounds[1]]:
			var boundary: Dictionary = defaults.duplicate(true)
			boundary[key] = value
			_check(PickupPolicy.validate(boundary).is_empty(), "inclusive bounds accepted")
	var extra: Dictionary = defaults.duplicate(true)
	extra.code = "not executable"
	_check(not PickupPolicy.validate(extra).is_empty(), "arbitrary generated code rejected")
	var assigned: Dictionary = defaults.duplicate(true)
	_check(PickupPolicy.apply(motion, assigned), "valid policy applies")
	assigned.crouch_height = 0.24
	_check(motion.pickup_policy == defaults, "caller cannot mutate an applied policy")
	for round_index: int in range(8):
		var candidates: Array[Dictionary] = PickupPolicy.mock_candidates(4, round_index, [])
		_check(candidates.size() == 4, "four bounded local proposals")
		for candidate: Dictionary in candidates:
			_check(PickupPolicy.validate(candidate.policy).is_empty(), "local proposal obeys bounds")
	motion.free()


func _check_physics() -> void:
	var graph: ConnectionGraph = HumanoidPreset.build()
	var initial: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(graph))
	var trial: PickupTrial = PickupTrial.new()
	root.add_child(trial)
	var result: Dictionary = {}
	var progress: Array[Dictionary] = []
	trial.completed.connect(func(value: Dictionary) -> void: result.merge(value, true))
	trial.progress_changed.connect(func(value: Dictionary) -> void: progress.append(value))
	_check(trial.start_trial(graph, PickupPolicy.defaults(), false).is_empty(), "default trial starts")
	_check(not trial.start_trial(graph, PickupPolicy.defaults(), false).is_empty(), "duplicate active trial rejected")
	for frame: int in range(PickupTrial.MAX_FRAMES + 2):
		await physics_frame
		if not trial.is_running:
			break
	_check(not trial.is_running and result.has("metrics"), "bounded episode completes")
	if not result.has("metrics"):
		trial.free()
		return
	print("PICKUP_BASELINE=" + JSON.stringify(result))
	_check(PickupPolicy.valid_metrics(result.metrics), "result telemetry validates")
	_check(result.metrics.success, "default controller actually lifts and holds the box")
	_check(result.metrics.contact_before_grasp, "bilateral real contact precedes attachment")
	_check(result.metrics.lift_m >= 0.25 and result.metrics.hold_seconds >= 1.0, "lift and continuous stable hold meet success threshold")
	_check(progress.size() >= 30 and progress[0].phase == "settling", "observable five-Hz intermediate progress")
	_check(trial.viewport != null and trial.viewport.is_inside_tree(), "completed trial remains observable")
	_check(MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)) == initial, "physical episode never changes assembly graph")
	_check_metrics(result.metrics)
	await _check_paused_episode(trial)
	var old_world: RID = trial.viewport.find_world_3d().space
	_check(trial.start_trial(graph, PickupPolicy.defaults(), false).is_empty(), "completed trial can start a fresh episode")
	_check(trial.viewport.find_world_3d().space != old_world and PhysicsServer3D.space_is_active(trial.viewport.find_world_3d().space), "restarted episode owns a new active physics space")
	for frame: int in range(3):
		await physics_frame
	_check(trial.is_running and trial.metrics.simulation_seconds > 0.0 and trial._motion.is_physics_processing(), "restarted controller and evaluation process resume normally")
	trial.cancel()
	_check(trial.viewport == null and not trial.is_running, "restarted episode cancels cleanly")
	trial.free()
	await process_frame
	await process_frame

	var trials: Array[PickupTrial] = []
	var independent_results: Array[Dictionary] = [{}, {}, {}, {}]
	var worlds: Dictionary = {}
	for index: int in range(4):
		var candidate: PickupTrial = PickupTrial.new()
		root.add_child(candidate)
		candidate.completed.connect(func(value: Dictionary) -> void: independent_results[index].merge(value, true))
		_check(candidate.start_trial(graph, PickupPolicy.defaults(), false).is_empty(), "parallel trial starts")
		worlds[candidate.viewport.find_world_3d().space] = true
		_check(candidate._graph != graph, "each episode has its own decoded graph")
		trials.append(candidate)
	_check(worlds.size() == 4, "four concurrent episodes use four separate physics spaces")
	trials[3].cancel()
	_check(not trials[3].is_running and trials[3].viewport == null, "cancel removes world and stops episode")
	_check(independent_results[3].metrics.cancelled and not independent_results[3].metrics.success, "cancel is recorded as a non-success")
	for frame: int in range(PickupTrial.MAX_FRAMES + 2):
		await physics_frame
		if not trials.any(func(value: PickupTrial) -> bool: return value.is_running):
			break
	for index: int in range(3):
		_check(independent_results[index].has("metrics"), "uncancelled parallel episode completes")
		if independent_results[index].has("metrics"):
			_check(independent_results[index].metrics.success, "independent parallel default succeeds")
			_check(PickupPolicy.valid_metrics(independent_results[index].metrics), "parallel metrics validate")
	_check(MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)) == initial, "parallel episodes preserve original graph")
	for candidate: PickupTrial in trials:
		candidate.free()
	await process_frame
	await process_frame

	var distant_graph: ConnectionGraph = HumanoidPreset.build()
	distant_graph.parts[-1].transform.origin.z = 2.0
	var failed: PickupTrial = PickupTrial.new()
	root.add_child(failed)
	_check(failed.start_trial(distant_graph, PickupPolicy.defaults(), false).is_empty(), "out-of-reach scenario enters evaluation")
	for frame: int in range(PickupTrial.MAX_FRAMES + 2):
		await physics_frame
		if not failed.is_running:
			break
	_check(not failed.metrics.success and failed.metrics.phase == "failed", "out-of-reach box is measured failure, never fake success")
	_check(PickupPolicy.valid_metrics(failed.metrics) and failed.metrics.lift_m < 0.01, "failed episode preserves measured telemetry")
	await _check_paused_episode(failed)
	failed.free()
	await process_frame
	await process_frame


func _check_metrics(valid: Dictionary) -> void:
	for field: String in ["lift_m", "hold_seconds", "min_upright", "score", "simulation_seconds"]:
		for value: Variant in [true, INF, -INF, NAN, "1", null]:
			var invalid: Dictionary = valid.duplicate(true)
			invalid[field] = value
			_check(not PickupPolicy.valid_metrics(invalid), "unsafe metric rejected: " + field)
	for field: String in ["finite", "fallen", "success"]:
		var invalid: Dictionary = valid.duplicate(true)
		invalid[field] = 1
		_check(not PickupPolicy.valid_metrics(invalid), "non-boolean result rejected")
	var missing_contact: Dictionary = valid.duplicate(true)
	missing_contact.erase("contact_before_grasp")
	_check(not PickupPolicy.valid_metrics(missing_contact), "success cannot omit contact evidence")
	var fabricated: Dictionary = valid.duplicate(true)
	fabricated.hold_seconds = 0.1
	_check(not PickupPolicy.valid_metrics(fabricated), "success cannot omit a stable hold")
	var bad_identity: Dictionary = valid.duplicate(true)
	bad_identity.graph_fingerprint = "../not-a-fingerprint"
	_check(not PickupPolicy.valid_metrics(bad_identity), "malformed graph identity rejected")
	bad_identity = valid.duplicate(true)
	bad_identity.engine_version = "future"
	_check(not PickupPolicy.valid_metrics(bad_identity), "incompatible engine metrics rejected")
	for key: String in ["engine_version", "physics_hz", "phase", "graph_fingerprint"]:
		for value: Variant in [true, null, [], {}]:
			var wrong_type: Dictionary = valid.duplicate(true)
			wrong_type[key] = value
			_check(not PickupPolicy.valid_metrics(wrong_type), "malformed metadata rejected without runtime exception")


func _check_paused_episode(trial: PickupTrial) -> void:
	var poses: Array[Transform3D] = []
	for body: RigidBody3D in trial._hardware.bodies:
		poses.append(body.global_transform)
	var observed: Dictionary = trial.metrics.duplicate(true)
	_check(not PhysicsServer3D.space_is_active(trial.viewport.find_world_3d().space), "completed physics space is inactive")
	_check(not trial._motion.is_physics_processing(), "completed pose controller no longer consumes physics frames")
	for drive: ServoDrive in trial._hardware.servos.values():
		_check(not drive.is_physics_processing(), "completed motor controller no longer consumes physics frames")
	for frame: int in range(90):
		await physics_frame
	for index: int in range(poses.size()):
		var body: RigidBody3D = trial._hardware.bodies[index]
		_check(body.global_transform == poses[index], "completed box and robot retain the final evaluated transform")
		_check(not body.freeze and body.gravity_scale == 1.0, "episode pause does not freeze bodies or disable gravity")
	_check(trial.metrics == observed, "paused final scene retains unchanged measured metrics")


func _check_lifecycle() -> void:
	var detached: PickupTrial = PickupTrial.new()
	_check(not detached.start_trial(HumanoidPreset.build(), PickupPolicy.defaults(), false).is_empty(), "detached trial is rejected")
	detached.free()
	var owner: Node = Node.new()
	root.add_child(owner)
	var trial: PickupTrial = PickupTrial.new()
	owner.add_child(trial)
	_check(trial.start_trial(HumanoidPreset.build(), PickupPolicy.defaults(), false).is_empty(), "nested trial starts")
	var viewport_ref: WeakRef = weakref(trial.viewport)
	var hardware_ref: WeakRef = weakref(trial._hardware)
	var motion_ref: WeakRef = weakref(trial._motion)
	for frame: int in range(800):
		await physics_frame
		if trial._motion.grasped:
			break
	_check(trial._motion.grasped, "ancestor deletion exercised with active grip constraints")
	owner.queue_free()
	await process_frame
	await process_frame
	_check(viewport_ref.get_ref() == null and hardware_ref.get_ref() == null and motion_ref.get_ref() == null, "ancestor deletion frees world, hardware, controller and grasps")


func _check_modular_physics() -> void:
	var graph: ConnectionGraph = ModularHumanoidPreset.build()
	var fingerprint: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(graph))
	var trial: PickupTrial = PickupTrial.new()
	root.add_child(trial)
	_check(trial.start_trial(graph, PickupPolicy.defaults(), false).is_empty(), "separately assembled modular humanoid trial starts")
	for frame: int in range(PickupTrial.MAX_FRAMES + 2):
		await physics_frame
		if not trial.is_running:
			break
	print("PICKUP_MODULAR=" + JSON.stringify(trial.metrics))
	_check(not trial.is_running and PickupPolicy.valid_metrics(trial.metrics), "modular trial produces bounded valid evidence")
	_check(trial.metrics.success and trial.metrics.contact_before_grasp, "modular robot lifts through real contact, not substituted animation")
	_check(trial.metrics.lift_m >= 0.25 and trial.metrics.hold_seconds >= 1.0, "modular pickup reaches the same success standard")
	_check(trial.metrics.graph_fingerprint == fingerprint and MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)) == fingerprint, "modular graph identity and authored assembly remain unchanged")
	trial.free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
