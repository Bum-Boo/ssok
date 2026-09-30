extends SceneTree

const TORQUE_NM: float = 0.25
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var original_hz: int = Engine.physics_ticks_per_second
	for iterations: int in [1, 16, 64]:
		for priority: int in [1, 3]:
			for direction: float in [-1.0, 1.0]:
				await _check_rotor(iterations, priority, direction, 60)
	for hz: int in [30, 120]:
		for direction: float in [-1.0, 1.0]:
			await _check_rotor(64, 2, direction, hz)
	Engine.physics_ticks_per_second = original_hz
	_check(_checks == 384, "all sixteen physical rotor cases complete")
	print("servo_torque_budget_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _check_rotor(iterations: int, priority: int, direction: float, hz: int) -> void:
	Engine.physics_ticks_per_second = hz
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(2, 2)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	PhysicsServer3D.space_set_param(viewport.find_world_3d().space,
		PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS, iterations)
	var anchor := RigidBody3D.new()
	anchor.freeze = true
	viewport.add_child(anchor)
	var rotor := RigidBody3D.new()
	rotor.mass = 1.0
	rotor.inertia = Vector3.ONE
	rotor.gravity_scale = 0.0
	rotor.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	rotor.angular_damp = 0.0
	rotor.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	rotor.linear_damp = 0.0
	rotor.can_sleep = false
	viewport.add_child(rotor)
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	rotor.add_child(shape)
	var hinge := HingeJoint3D.new()
	hinge.solver_priority = priority
	viewport.add_child(hinge)
	hinge.node_a = hinge.get_path_to(anchor)
	hinge.node_b = hinge.get_path_to(rotor)
	var drive := ServoDrive.new()
	drive.joint = hinge
	viewport.add_child(drive)
	var definition := PartDef.new()
	definition.actuator_torque_nm = TORQUE_NM
	drive.configure_torque_actuator(anchor, rotor, definition)
	for frame: int in 3:
		await physics_frame
	var previous: float = rotor.angular_velocity.z
	drive.write_relative(direction * 90.0)
	var peak_torque: float = 0.0
	for frame: int in 8:
		await physics_frame
		var velocity: float = rotor.angular_velocity.z
		# Unit inertia, no contact or damping: angular acceleration directly measures motor torque.
		var measured_torque: float = absf(velocity - previous) * hz
		peak_torque = maxf(peak_torque, measured_torque)
		_check(measured_torque <= TORQUE_NM + 0.0001, "motor impulse stays within the whole-step torque budget")
		_check(measured_torque >= TORQUE_NM * 0.999, "a saturated free rotor receives its declared torque")
		_check(velocity * direction > 0.0, "both command signs rotate the physical rotor correctly")
		previous = velocity
	print("SERVO_TORQUE ", JSON.stringify({"iterations":iterations,"priority":priority,
		"direction":direction,"physics_hz":hz,"declared_nm":TORQUE_NM,"peak_measured_nm":peak_torque}))
	viewport.free()
	await physics_frame


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
