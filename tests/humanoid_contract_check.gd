extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: ConnectionGraph = HumanoidPreset.build()
	var hardware := RunMode.new()
	root.add_child(hardware)
	var motion := HumanoidMotion.new()
	root.add_child(motion)
	var first_wire: Dictionary
	var second_wire: Dictionary
	for link: Dictionary in graph.links:
		if link.a_port == &"signal":
			if first_wire.is_empty():
				first_wire = link
			elif second_wire.is_empty():
				second_wire = link
	var pin: StringName = first_wire.b_port
	first_wire.b_port = second_wire.b_port
	second_wire.b_port = pin
	hardware.build(graph)
	_check(motion.configure(hardware, graph), "rewired graph remains supported")
	_check(motion.role_pins.left_hip == Wiring.pin_number(RunMode._port(graph.parts[first_wire.b_part].part_def, first_wire.b_port)), "role follows rewired pin, not a constant")
	motion.set_enabled(true)
	for drive: ServoDrive in hardware.servos.values():
		_check(drive.joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT), "anatomical joint limits remain active")
		drive.write_relative(999)
		_check(drive.target_deg == drive.relative_max_deg, "positive relative target is bounded")
		drive.write_relative(-999)
		_check(drive.target_deg == drive.relative_min_deg, "negative relative target is bounded")
		drive.write(180)
		_check(drive.target_deg <= drive.relative_max_deg, "learner commands cannot exceed anatomical limits")
		drive._apply()
		var iterations: int = int(PhysicsServer3D.space_get_param(drive.joint.get_world_3d().space,
			PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS))
		var whole_step_budget: float = drive.joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE) * iterations * drive.joint.solver_priority
		_check(is_equal_approx(whole_step_budget, drive.torque_limit_nm / Engine.physics_ticks_per_second), "all motor solver passes share the physical torque budget")
	motion.set_enabled(false)
	graph.links.erase(first_wire)
	hardware.build(graph)
	_check(not motion.configure(hardware, graph), "missing joint wiring is rejected")
	_check(not motion.is_supported() and not motion._enabled, "invalid graph cannot run stale program")
	graph = HumanoidPreset.build()
	graph.parts[-1].transform.origin.z = 2.0
	hardware.build(graph)
	_check(motion.configure(hardware, graph), "fresh graph replaces invalid configuration")
	motion.set_enabled(true)
	_check(not motion.request_pickup() and motion._grips.is_empty(), "distant box cannot be attached remotely")
	motion.set_sprint_requested(true)
	_check(motion.running, "sprint is a high-level request")
	motion.set_enabled(false)
	_check(not motion.running, "handoff cancels sprint")
	motion.free()
	hardware.free()
	await process_frame
	print("humanoid_contract_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
