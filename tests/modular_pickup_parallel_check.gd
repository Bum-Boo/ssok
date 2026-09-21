extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: ConnectionGraph = ModularHumanoidPreset.build()
	var fingerprint: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(graph))
	var trials: Array[PickupTrial] = []
	var worlds: Dictionary = {}
	var world_refs: Array[WeakRef] = []
	for index: int in range(4):
		var trial: PickupTrial = PickupTrial.new()
		root.add_child(trial)
		_check(trial.start_trial(graph, PickupPolicy.defaults(), false).is_empty(), "modular parallel trial starts")
		if trial.viewport != null:
			worlds[trial.viewport.find_world_3d().space] = true
			world_refs.append(weakref(trial.viewport))
		trials.append(trial)
	_check(worlds.size() == 4, "four modular robots own four independent physics spaces")
	for frame: int in range(PickupTrial.MAX_FRAMES + 2):
		await physics_frame
		if not trials.any(func(trial: PickupTrial) -> bool: return trial.is_running):
			break
	for index: int in range(trials.size()):
		var trial: PickupTrial = trials[index]
		print("MODULAR_PARALLEL_%d=" % index + JSON.stringify(trial.metrics))
		_check(not trial.is_running and PickupPolicy.valid_metrics(trial.metrics), "parallel modular episode completes with valid evidence")
		if trial.metrics.is_empty():
			continue
		_check(trial.metrics.success and trial.metrics.contact_before_grasp, "parallel modular success requires bilateral collision contact")
		_check(trial.metrics.lift_m >= PickupTrial.REQUIRED_LIFT and trial.metrics.hold_seconds >= PickupTrial.REQUIRED_HOLD, "each modular robot physically lifts and holds its own box")
		_check(trial.metrics.graph_fingerprint == fingerprint, "every candidate uses exactly the same initial assembly")
	_check(MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)) == fingerprint, "concurrent evaluation never changes authored assembly")
	var final_states: Array[Dictionary] = []
	for trial: PickupTrial in trials:
		_check(not PhysicsServer3D.space_is_active(trial.viewport.find_world_3d().space), "ended parallel lane no longer consumes physics simulation")
		final_states.append({"box": trial._hardware.bodies[trial._motion._box_part].global_transform, "torso": trial._hardware.bodies[trial._motion.body_part].global_transform})
	for frame: int in range(90):
		await physics_frame
	for index: int in range(trials.size()):
		var trial: PickupTrial = trials[index]
		_check(trial._hardware.bodies[trial._motion._box_part].global_transform == final_states[index].box and trial._hardware.bodies[trial._motion.body_part].global_transform == final_states[index].torso, "all ended lanes retain measured final poses without background evolution")
	for trial: PickupTrial in trials:
		trial.free()
	await process_frame
	await process_frame
	for reference: WeakRef in world_refs:
		_check(reference.get_ref() == null, "parallel world is freed after its owning trial")
	print("modular_pickup_parallel_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
