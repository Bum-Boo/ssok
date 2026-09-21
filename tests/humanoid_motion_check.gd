extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var action: String = args[0] if not args.is_empty() else "walk"
	var settle_frames: int = 180
	for argument: String in args:
		if argument.begins_with("--settle-frames="):
			settle_frames = clampi(argument.get_slice("=", 1).to_int(), 60, 300)
	if action not in ["walk", "backward", "pick", "run"]:
		push_error("Expected walk, backward, pick or run")
		quit(1)
		return
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 0.10, 20)
	collision.shape = shape
	floor.add_child(collision)
	floor.position.y = HumanoidPreset.FLOOR_TOP - 0.05
	root.add_child(floor)
	var graph: ConnectionGraph = HumanoidPreset.build()
	if action == "pick":
		_check_initial_grip_geometry(graph)
	if action != "pick":
		graph.parts[-1].transform.origin.z = 3.0
	if "--reverse-links" in args:
		for link: Dictionary in graph.links:
			var a: int = link.a_part
			var port: StringName = link.a_port
			link.a_part = link.b_part
			link.a_port = link.b_port
			link.b_part = a
			link.b_port = port
	var snapshot: Dictionary = MotionSnapshot.encode(graph)
	var fingerprint: String = MotionSnapshot.fingerprint(snapshot)
	_check(graph.parts.size() == 14, "graph owns every robot part and box")
	_check(MotionSnapshot.decode(snapshot) != null, "humanoid catalog snapshot round trip")
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var motion := HumanoidMotion.new()
	root.add_child(motion)
	_check(motion.configure(hardware, graph), "graph-derived humanoid roles and pins")
	if not motion.is_supported():
		quit(1)
		return
	_check(hardware.servos.size() == 10 and motion.role_pins.size() == 10, "ten wired motors")
	for body: RigidBody3D in hardware.bodies:
		_check(not body.freeze and body.gravity_scale == 1.0, "all humanoid bodies are dynamic with gravity")
	var torso: RigidBody3D = hardware.bodies[motion.body_part]
	var box: RigidBody3D = hardware.bodies[-1]
	var left: RigidBody3D = hardware.bodies[motion.role_parts.left_ankle]
	var right: RigidBody3D = hardware.bodies[motion.role_parts.right_ankle]
	var left_hand: RigidBody3D = hardware.bodies[motion.role_parts.left_elbow]
	var right_hand: RigidBody3D = hardware.bodies[motion.role_parts.right_elbow]
	var start: Vector3
	var air_frames: int = 0
	var air_streak: int = 0
	var max_air_streak: int = 0
	var min_up: float = 1.0
	var max_box_height: float = 0.0
	var contact_before_grasp: bool = false
	var saw_grasp: bool = false
	var released_height: float = 0.0
	var initial_box_height: float = 0.0
	motion.set_enabled(true)
	for frame: int in range(1200):
		if frame == settle_frames:
			start = torso.global_position
			initial_box_height = box.global_position.y
			if action == "pick":
				_check(motion.request_pickup(), "nearby box pickup accepted")
			else:
				motion.set_sprint_requested(action == "run")
				motion.set_move_input(Vector2(0, -1 if action == "backward" else 1))
		if action == "pick" and frame == 720:
			_check(motion.grasped and motion.pickup_state == "holding", "completed lift and hold")
			released_height = box.global_position.y
			motion.interact()
			_check(not motion.grasped and motion._grips.is_empty(), "E removes both grip constraints")
		await physics_frame
		if not motion.grasped and box in left_hand.get_colliding_bodies() and box in right_hand.get_colliding_bodies():
			contact_before_grasp = true
		if motion.grasped and not saw_grasp:
			saw_grasp = true
			_check(contact_before_grasp, "both hands contacted box before grasp")
			_check(motion._grips.size() == 2, "bilateral contact creates two constraints")
		max_box_height = maxf(max_box_height, box.global_position.y)
		min_up = minf(min_up, torso.global_basis.y.dot(Vector3.UP))
		if frame > settle_frames:
			var airborne: bool = floor not in left.get_colliding_bodies() and floor not in right.get_colliding_bodies() and _sole_height(left) > 0.002 and _sole_height(right) > 0.002
			air_streak = air_streak + 1 if airborne else 0
			air_frames += int(airborne)
			max_air_streak = maxi(max_air_streak, air_streak)
		if motion.fallen:
			break
	var displacement: Vector3 = torso.global_position - start
	_check(not motion.fallen and min_up > 0.85, "stays upright for twenty simulated seconds")
	if action == "pick":
		_check(saw_grasp and max_box_height - initial_box_height > 0.30, "contact-grasp lifts box by over 30 cm")
		_check(released_height - box.global_position.y > 0.25 and not motion.grasped, "released box falls under gravity")
	else:
		var minimum_distance: float = 0.10 if action == "backward" else 0.30
		_check(displacement.z * (-1 if action == "backward" else 1) > minimum_distance, "measurable commanded motion (30 cm forward, 10 cm slow reverse)")
		if action == "run":
			_check(max_air_streak >= 2 and air_frames >= 8, "running requires measured flight, not just a faster pose cycle")
			_check(motion._run_bodies.size() == 13 and box not in motion._run_bodies, "running balances connected robot mass without remote cargo")
			_check(motion._physical_mass_center(left_hand).distance_to(left_hand.global_position) > 0.02, "running reads collision-derived hand COM instead of the zero custom property")
	_check(MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)) == fingerprint, "simulation never mutates assembly graph")
	for drive: ServoDrive in hardware.servos.values():
		_check(drive.torque_limit_nm > 0 and drive.target_deg >= drive.relative_min_deg and drive.target_deg <= drive.relative_max_deg, "motor torque and target bounds")
	motion.set_enabled(false)
	_check(motion._grips.is_empty() and not motion.running, "control handoff clears grasp and sprint")
	motion.free()
	hardware.teardown()
	_check(hardware.get_child_count() == 0 and hardware.bodies.is_empty(), "teardown removes physics and interactions")
	hardware.free()
	print("humanoid_motion_check: action=%s displacement=%s min_up=%.3f lift=%.3f air_frames=%d longest_flight=%d checks=%d failures=%d" % [action, displacement, min_up, max_box_height - initial_box_height, air_frames, max_air_streak, _checks, _failures])
	quit(1 if _failures else 0)


func _sole_height(foot: RigidBody3D) -> float:
	var lowest: float = INF
	for x: float in [-0.11, 0.11]:
		for z: float in [-0.11, 0.11]:
			lowest = minf(lowest, foot.to_global(Vector3(x, -0.03, z)).y)
	return lowest - HumanoidPreset.FLOOR_TOP


func _check_initial_grip_geometry(graph: ConnectionGraph) -> void:
	var cargo: Dictionary = graph.parts[-1]
	var cargo_bounds: AABB = cargo.transform * cargo.part_def.mesh.get_aabb()
	for entry: Dictionary in graph.parts.slice(0, -1):
		var definition: PartDef = entry.part_def
		var boxes: Array[AABB] = definition.collision_boxes.duplicate()
		if boxes.is_empty():
			boxes.append(definition.mesh.get_aabb())
		for box: AABB in boxes:
			_check(not (entry.transform * box).intersects(cargo_bounds), "cargo starts separated from every robot collider")
		if definition.id != &"humanoid_forearm":
			continue
		var mesh: ArrayMesh = definition.mesh as ArrayMesh
		_check(mesh != null and mesh.get_surface_count() == boxes.size(), "each hand collision box has a visible mesh surface")
		if mesh == null or mesh.get_surface_count() != boxes.size():
			continue
		for surface: int in mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var visible: AABB = AABB(vertices[0], Vector3.ZERO)
			for point: Vector3 in vertices:
				visible = visible.expand(point)
			_check(visible.is_equal_approx(boxes[surface]), "visible hand geometry matches its authored collision box")
		var hand_bounds: AABB = entry.transform * mesh.get_aabb()
		var lateral_overlap: float = minf(hand_bounds.end.x, cargo_bounds.end.x) - maxf(hand_bounds.position.x, cargo_bounds.position.x)
		_check(lateral_overlap >= 0.01, "visible palm has positive lateral contact margin")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
