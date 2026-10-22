extends SceneTree

var checks: int = 0
var failures: int = 0
const PARTS: String = "res://assets/construction_kit/parts/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5, 0.02, 5)
	collider.shape = box
	floor.add_child(collider)
	root.add_child(floor)
	floor.position.y = -0.01
	for angle: int in [10, 20]:
		var graph: ConnectionGraph = RobotCarPreset.build()
		graph.parts.append({"part_def": load(PARTS + "env_ramp_%d.tres" % angle), "transform": Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0.5, 0, 0))})
		if angle == 20:
			graph.links = graph.links.filter(func(link: Dictionary) -> bool: return link.a_part not in [3, 4] and link.b_part not in [3, 4])
			for part: int in [3, 4]:
				graph.parts[part].part_def = load(PARTS + "kit_wheel_90.tres")
			RobotCarPreset._place(graph, 1, &"shaft_left", 3, &"hub", Basis(Vector3.UP, PI))
			RobotCarPreset._place(graph, 2, &"shaft_right", 4, &"hub")
		var hardware := RunMode.new()
		root.add_child(hardware)
		hardware.build(graph)
		_check(hardware.bodies[-1].freeze, "ramp defaults anchored")
		var maximum_y: float = 0.0
		hardware.motor_on_pin(0).forward(65)
		hardware.motor_on_pin(12).forward(65)
		for tick: int in 240:
			await physics_frame
			var pose: Transform3D = hardware.part_global_transform(0)
			if pose.origin.x > 0.35:
				maximum_y = maxf(maximum_y, pose.origin.y)
		print("RAMP angle=%d max_chassis_y=%.5f final=%s" % [angle, maximum_y, hardware.part_global_transform(0).origin])
		_check(maximum_y > 0.045 if angle == 10 else maximum_y > 0.08, "real wheel torque climbs ramp")
		hardware.free()
		await process_frame

	var graph: ConnectionGraph = RobotCarPreset.build()
	graph.parts.append({"part_def": load(PARTS + "env_ball.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(0.22, 0.022, 0))})
	# Rotate the cup onto its side: the learner can push through its open mouth.
	graph.parts.append({"part_def": load(PARTS + "env_cup.tres"), "transform": Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0.8, 0.084, 0))})
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	_check(not hardware.bodies[9].freeze and hardware.bodies[10].freeze, "ball is free, cup is anchored")
	_check(hardware.cup_object_count() == 0, "object outside cup not counted")
	hardware.motor_on_pin(0).forward(65)
	hardware.motor_on_pin(12).forward(65)
	var peak_count: int = 0
	for tick: int in 360:
		await physics_frame
		peak_count = maxi(peak_count, hardware.cup_object_count())
	print("CUP ball=%s chassis=%s object_count=%d peak=%d" % [hardware.part_global_transform(9).origin, hardware.part_global_transform(0).origin, hardware.cup_object_count(), peak_count])
	_check(peak_count == 1, "car pushes a real ball into the open cup")
	hardware.stop_motors()
	for tick: int in 60:
		await physics_frame
	_check(hardware.cup_object_count() == 1, "ball remains contained after Stop")
	var fingerprint: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(graph))
	_check(ProjectStore.graph_from(ProjectStore.document("Cup", graph, "stop()")) != null, "environment resources serialize through normal graph")
	_check(fingerprint == MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)), "observations do not change graph")
	hardware.free()
	await process_frame
	var observation := ConnectionGraph.new()
	var container: PartDef = load(PARTS + "env_cup.tres").duplicate() as PartDef
	container.id = &"test_container"
	var object: PartDef = load(PARTS + "env_ball.tres").duplicate() as PartDef
	object.id = &"test_object"
	observation.parts.append({"part_def": container, "transform": Transform3D.IDENTITY})
	observation.parts.append({"part_def": object, "transform": Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0))})
	var reader := RunMode.new()
	root.add_child(reader)
	reader.build(observation)
	reader.bodies[0].freeze = true
	_check(reader.cup_object_count() == 1, "containment derives from environment geometry rather than SKU IDs")
	reader.bodies[1].position.y = 0.16
	_check(reader.cup_object_count() == 0, "object extending over rim is not fully contained")
	reader.bodies[1].position = Vector3(0.12, 0.03, 0)
	_check(reader.cup_object_count() == 0, "outside object center is not counted")
	reader.teardown()
	_check(reader.cup_object_count() == 0, "teardown clears observation")
	reader.free()
	floor.free()
	await process_frame
	print("parts_pack_environment_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
