extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: ConnectionGraph = ModularHumanoidPreset.build()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var action: String = arguments[0] if not arguments.is_empty() else "pick"
	if "--reverse-links" in arguments:
		for link: Dictionary in graph.links:
			var part: int = link.a_part
			var port: StringName = link.a_port
			link.a_part = link.b_part
			link.a_port = link.b_port
			link.b_part = part
			link.b_port = port
	_check(graph.parts.size() == 38, "38 separately editable graph modules including box")
	for entry: Dictionary in graph.parts:
		var definition: PartDef = entry.part_def
		if definition.id == &"cargo_box":
			continue
		_check(definition.mesh is ArrayMesh, "module uses Blender-authored geometry")
		_check(definition.mesh.resource_path.begins_with("res://assets/modular_humanoid/meshes/"), "modular mesh catalog")
		for surface: int in definition.mesh.get_surface_count():
			_check(definition.mesh.surface_get_material(surface).resource_path.begins_with("res://assets/materials/"), "shared external PBR material")
	for link: Dictionary in graph.links:
		var a: Port = RunMode._port(graph.parts[link.a_part].part_def, link.a_port)
		var b: Port = RunMode._port(graph.parts[link.b_part].part_def, link.b_port)
		_check(a.accepts.has(b.tag) and b.accepts.has(a.tag), "compatible real mechanical/electrical ports")
		if a.kind == Port.Kind.MECH:
			var a_position: Vector3 = graph.parts[link.a_part].transform * a.local_position
			var b_position: Vector3 = graph.parts[link.b_part].transform * b.local_position
			_check(a_position.distance_to(b_position) < 0.0001, "mechanical port anchors coincide")
			var a_normal: Vector3 = graph.parts[link.a_part].transform.basis * a.local_normal
			var b_normal: Vector3 = graph.parts[link.b_part].transform.basis * b.local_normal
			_check(a_normal.dot(b_normal) < -0.999, "opposing port normals allow actual assembly snapping")
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20, 0.10, 20)
	floor_shape.shape = floor_box
	floor.add_child(floor_shape)
	root.add_child(floor)
	if action != "pick":
		graph.parts[-1].transform.origin.z = 3.0
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var bodies: Dictionary = {}
	var graph_mass: float = 0.0
	var solver_mass: float = 0.0
	for index: int in graph.parts.size():
		var body: RigidBody3D = hardware.bodies[index]
		graph_mass += graph.parts[index].part_def.mass_kg
		if not bodies.has(body):
			bodies[body] = true
			solver_mass += body.mass
		_check(hardware.part_global_transform(index).is_equal_approx(graph.parts[index].transform), "merged body preserves each part transform")
		_check(not body.freeze and body.gravity_scale == 1.0, "gravity remains enabled")
	_check(bodies.size() == 12, "38 graph parts derive twelve rigid bodies")
	_check(is_equal_approx(graph_mass, solver_mass), "fixed merge preserves total physical mass")
	_check(hardware.servos.size() == 10, "ten independent wired motor housings")
	var motion := HumanoidMotion.new()
	root.add_child(motion)
	_check(motion.configure(hardware, graph), "modular graph resolves motion roles")
	if not motion.is_supported():
		quit(1)
		return
	for role: String in motion.role_parts:
		_check(graph.parts[motion.role_parts[role]].part_def.actuator_torque_nm == 0.0, "structural link is passive, motor is a different module")
		_check(hardware.servo_on_pin(motion.role_pins[role]) == motion._drives[role], "motors are programmed through actual wiring")
	var torso: RigidBody3D = hardware.bodies[motion.body_part]
	var box: RigidBody3D = hardware.bodies[-1]
	var start: Vector3
	var box_height: float = 0.15
	var lift: float = 0.0
	var min_up: float = 1.0
	var saw_grasp: bool = false
	var release_height: float = 0.0
	var contact_evidence: Array[bool] = [false]
	motion.pickup_contact_confirmed.connect(func() -> void: contact_evidence[0] = true)
	motion.set_enabled(true)
	for frame: int in range(1200):
		if frame == 180:
			start = torso.global_position
			box_height = box.global_position.y
			if action == "pick":
				_check(motion.request_pickup(), "pickup accepted for nearby box")
			elif action == "walk":
				motion.set_move_input(Vector2(0, 1))
		if frame == 720 and action == "pick":
			_check(motion.pickup_state == "holding" and motion.grasped, "contact grasp reached stable holding")
			release_height = box.global_position.y
			motion.release_box()
		await physics_frame
		lift = maxf(lift, box.global_position.y - box_height)
		min_up = minf(min_up, torso.global_basis.y.dot(Vector3.UP))
		saw_grasp = saw_grasp or motion.grasped
		if frame % 120 == 0 and "--verbose" in arguments:
			var angles: Array = []
			for drive: ServoDrive in motion._drives.values():
				angles.append(snappedf(drive.measured_deg, 0.1))
			print("modular t=%.1f body=%s up=%.3f state=%s box=%s angles=%s" % [frame / 60.0, torso.global_position, torso.global_basis.y.dot(Vector3.UP), motion.pickup_state, box.global_position, angles])
			if action == "pick":
				for side: String in ["left", "right"]:
					var hand: RigidBody3D = hardware.bodies[motion.role_parts[side + "_elbow"]]
					print("%s palm=%s contact=%s" % [side, hand.to_global(Vector3(0, -0.11, 0)), hand.get_colliding_bodies()])
		if motion.fallen:
			break
	_check(not motion.fallen and min_up > 0.85, "modular robot stays upright for twenty simulated seconds")
	var distance: float = torso.global_position.z - start.z
	if action == "pick":
		_check(contact_evidence[0], "bilateral physical contact precedes grip constraint creation")
		_check(saw_grasp and lift > 0.30, "actual grasp lifts box more than thirty cm")
		_check(release_height - box.global_position.y > 0.25, "release removes constraints and gravity drops the box")
	if action == "walk":
		_check(distance > 0.30, "physical forward motion exceeds thirty cm")
	motion.free()
	var runtime := MiniRuntime.new()
	runtime.hardware = hardware
	root.add_child(runtime)
	var code_errors: Array[String] = []
	runtime.failed.connect(func(_line: int, message: String) -> void: code_errors.append(message))
	var source: String = ModularHumanoidPreset.answer_code(graph)
	await runtime.run(source)
	_check(code_errors.is_empty() and not runtime.is_running(), "generated signed standing example executes through learner runtime")
	for channel: Dictionary in hardware.wired_servo_channels():
		_check(source.contains("Servo(%d)" % channel.pin), "learner source uses actual wired motor addresses")
	runtime.free()
	hardware.teardown()
	_check(hardware.bodies.is_empty() and hardware.get_child_count() == 0, "teardown removes unique bodies once")
	hardware.free()
	print("modular_humanoid_check: action=%s checks=%d failures=%d distance=%.3f lift=%.3f min_up=%.3f" % [action, _checks, _failures, distance, lift, min_up])
	quit(1 if _failures else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
