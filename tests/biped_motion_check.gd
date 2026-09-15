extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	call_deferred(&"_run_check")


func _run_check() -> void:
	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(12.0, 0.05, 12.0)
	collision.shape = box
	floor.add_child(collision)
	floor.position.y = BipedPreset.FLOOR_TOP - box.size.y * 0.5
	root.add_child(floor)
	_check_graph_resolution()
	var commands: Array[Vector2] = [Vector2.ZERO, Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() > 3:
		commands = [commands[int(arguments[3])]]
	for command: Vector2 in commands:
		await _check_motion(command)
	if arguments.is_empty():
		await _check_startup_and_reverse()
	print("biped_motion_check: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)


func _check_graph_resolution() -> void:
	var hardware: RunMode = RunMode.new()
	root.add_child(hardware)
	var motion: BipedMotion = BipedMotion.new()
	root.add_child(motion)
	hardware.build(ServoArmPreset.build())
	_assert(not motion.configure(hardware, ServoArmPreset.build()), "servo arm must not claim a biped gait")
	var graph: ConnectionGraph = BipedPreset.build()
	for link: Dictionary in graph.links:
		if String(link.b_port).begins_with("pin_"):
			match link.b_port:
				&"pin_3": link.b_port = &"pin_11"
				&"pin_5": link.b_port = &"pin_10"
				&"pin_6": link.b_port = &"pin_9"
				&"pin_9": link.b_port = &"pin_6"
	graph.parts.reverse()
	for link: Dictionary in graph.links:
		var previous_a: int = link.a_part
		var previous_port: StringName = link.a_port
		link.a_part = graph.parts.size() - 1 - int(link.b_part)
		link.a_port = link.b_port
		link.b_part = graph.parts.size() - 1 - previous_a
		link.b_port = previous_port
	hardware.build(graph)
	_assert(motion.configure(hardware, graph), "rewired biped must resolve its graph")
	_assert(motion.body_part == graph.parts.size() - 1, "body role must not assume a fixed part index")
	_assert(motion.role_pins.get(&"left_hip") == 10, "left hip must follow actual wiring")
	_assert(motion.role_pins.get(&"right_hip") == 11, "right hip must follow actual wiring")
	_assert(motion.role_pins.get(&"left_ankle") == 6, "left ankle must follow actual wiring")
	_assert(motion.role_pins.get(&"right_ankle") == 9, "right ankle must follow actual wiring")
	var drive: ServoDrive = hardware.servo_on_pin(10)
	drive.write(-20.0)
	_assert(drive.target_deg == 0.0, "learner write must still clamp negative input to zero")
	drive.write(200.0)
	_assert(drive.target_deg == 180.0, "learner write must still clamp above 180 degrees")
	drive.write_relative(-200.0)
	_assert(drive.target_deg == -90.0, "relative program angle must clamp at -90 degrees")
	drive.write_relative(200.0)
	_assert(drive.target_deg == 90.0, "relative program angle must clamp at 90 degrees")
	motion.set_enabled(true)
	motion.set_move_input(Vector2(0, 1))
	motion._physics_process(0.6)
	_assert(hardware.servo_on_pin(10).target_deg > 0, "gait must write the rewired left hip")
	motion.set_enabled(false)
	var target: float = hardware.servo_on_pin(10).target_deg
	motion._physics_process(0.5)
	_assert(hardware.servo_on_pin(10).target_deg == target, "disabled gait must not overwrite code control")
	graph.links.pop_back()
	hardware.build(graph)
	_assert(not motion.configure(hardware, graph), "missing ankle wiring must reject movement")
	motion.free()
	hardware.free()


func _check_motion(command: Vector2) -> void:
	var graph: ConnectionGraph = BipedPreset.build()
	var hardware: RunMode = RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var motion: BipedMotion = BipedMotion.new()
	root.add_child(motion)
	_assert(motion.configure(hardware, graph), "stock biped must configure")
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() >= 3:
		motion.stride_degrees = float(arguments[0])
		motion.lean_degrees = float(arguments[1])
		motion.cycle_seconds = float(arguments[2])
	if arguments.size() > 4:
		motion.posture_degrees = float(arguments[4])
	motion.set_enabled(true)
	for frame: int in range(180):
		await physics_frame
	var start: Vector3 = hardware.bodies[motion.body_part].global_position
	var initial_basis: Basis = hardware.bodies[motion.body_part].global_basis
	motion.set_move_input(command)
	var minimum_height: float = INF
	for frame: int in range(720):
		await physics_frame
		var body: RigidBody3D = hardware.bodies[motion.body_part]
		minimum_height = minf(minimum_height, body.global_position.y - BipedPreset.FLOOR_TOP)
		for part: RigidBody3D in hardware.bodies:
			_assert(part.global_transform.is_finite() and part.linear_velocity.is_finite(), "joint gait must remain finite")
	motion.set_move_input(Vector2.ZERO)
	for frame: int in range(90):
		await physics_frame
	var body: RigidBody3D = hardware.bodies[motion.body_part]
	var displacement: Vector3 = body.global_position - start
	var local_displacement: Vector3 = initial_basis.inverse() * displacement
	var yaw: float = initial_basis.z.signed_angle_to(body.global_basis.z, Vector3.UP)
	print("BIPED_GAIT command=%s displacement=%s yaw=%.4f minimum_height=%.4f upright=%.4f" % [command, displacement, yaw, minimum_height, body.global_basis.y.dot(Vector3.UP)])
	_assert(body.global_position.y - BipedPreset.FLOOR_TOP > 0.09, "gait must finish standing")
	_assert(body.global_basis.y.dot(Vector3.UP) > 0.9, "gait must finish upright")
	if not command.is_zero_approx() and absf(command.y) > absf(command.x):
		_assert(local_displacement.z * command.y > 0.001, "forward/back command must produce signed physical displacement")
	elif not command.is_zero_approx():
		_assert(yaw * command.x > 0.03, "turn command must produce signed physical yaw")
	for servo: ServoDrive in hardware.servos.values():
		_assert(servo.target_deg == 0.0, "released movement must return to standing pose")
	motion.free()
	hardware.free()
	await physics_frame


func _check_startup_and_reverse() -> void:
	var graph: ConnectionGraph = BipedPreset.build()
	var hardware: RunMode = RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var motion: BipedMotion = BipedMotion.new()
	root.add_child(motion)
	_assert(motion.configure(hardware, graph), "startup biped must configure")
	motion.set_enabled(true)
	for command: Vector2 in [Vector2(0, 1), Vector2.ZERO, Vector2(0, -1), Vector2.ZERO]:
		motion.set_move_input(command)
		var frames: int = 90 if command.is_zero_approx() else 360
		for frame: int in range(frames):
			await physics_frame
			for part: RigidBody3D in hardware.bodies:
				_assert(part.global_transform.is_finite() and part.linear_velocity.is_finite(), "startup and reversal must stay finite")
		var body: RigidBody3D = hardware.bodies[motion.body_part]
		print("BIPED_STARTUP command=%s height=%.4f upright=%.4f" % [command, body.global_position.y - BipedPreset.FLOOR_TOP, body.global_basis.y.dot(Vector3.UP)])
		_assert(body.global_position.y - BipedPreset.FLOOR_TOP > 0.09, "immediate movement and reversal must stay standing")
		_assert(body.global_basis.y.dot(Vector3.UP) > 0.9, "immediate movement and reversal must stay upright")
	motion.free()
	hardware.free()
	await physics_frame


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
