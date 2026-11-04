extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _graph_checks(graph: ConnectionGraph) -> void:
	_check(not ProjectStore.document("Kit", graph, "").is_empty(), "kit graph validates and serializes")
	for part: Dictionary in graph.parts:
		_check(String(part.part_def.id) in PartTray.ids(), "answer uses tray part " + String(part.part_def.id))
	var connected: Array[int] = [0]
	for link: Dictionary in graph.links:
		var pa: Port = RunMode._port(graph.parts[link.a_part].part_def, link.a_port)
		var pb: Port = RunMode._port(graph.parts[link.b_part].part_def, link.b_port)
		if pa.kind != Port.Kind.MECH:
			continue
		var a: Transform3D = graph.parts[link.a_part].transform
		var b: Transform3D = graph.parts[link.b_part].transform
		_check((a * pa.local_position).distance_to(b * pb.local_position) < 0.0001, "coincident attachment " + String(pa.id) + " " + String(pb.id))
		_check((a.basis * pa.local_normal).dot(b.basis * pb.local_normal) < -0.999, "opposite attachment normals " + String(pa.id) + " " + String(pb.id))
	var cursor: int = 0
	while cursor < connected.size():
		var part: int = connected[cursor]
		cursor += 1
		for link: Dictionary in graph.links:
			if RunMode._port(graph.parts[link.a_part].part_def, link.a_port).kind != Port.Kind.MECH:
				continue
			var other: int = link.b_part if part == link.a_part else (link.a_part if part == link.b_part else -1)
			if other >= 0 and other not in connected:
				connected.append(other)
	for index: int in graph.parts.size():
		_check(index in connected or graph.parts[index].part_def.id == &"stage_wall", "all robot parts mechanically attached")


func _run() -> void:
	_graph_checks(KitCarPreset.build())
	_graph_checks(KitFlagArmPreset.build())
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.1, 20)
	collision.shape = box
	floor_body.add_child(collision)
	world.add_child(floor_body)
	var run := RunMode.new()
	world.add_child(run)
	var vm := MiniRuntime.new()
	vm.hardware = run
	world.add_child(vm)
	var graph: ConnectionGraph = KitCarPreset.build(0.8)
	run.build(graph)
	_check(run.profile().id == "microbit", "kit car resolves microbit profile")
	_check(run.motor_on_pin(0) != null and run.motor_on_pin(12) != null and run.motors.size() == 2, "microbit driver wiring resolves two TT motors")
	for tick: int in 30:
		await physics_frame
	var sensor: SonarSensor = run.sonar_on_pins(1, 2)
	_check(sensor != null, "sonar resolves from trig/echo graph wires")
	var baseline: float = sensor.distance_cm()
	_check(sensor.last_valid and baseline > 50 and baseline < 90, "sonar reads actual wall distance")
	var wall: RigidBody3D = run.bodies[-1]
	wall.position.x += 0.2
	for tick: int in 2:
		await physics_frame
	var moved: float = sensor.distance_cm()
	_check(sensor.last_valid and absf(moved - baseline - 20.0) < 1.0, "sonar follows real wall displacement by 20 cm")
	var before: Vector3 = run.part_global_transform(0).origin
	vm.run(RobotCarPreset.ANSWER_CODE)
	for tick: int in 150:
		await physics_frame
	var dx: float = run.part_global_transform(0).origin.x - before.x
	_check(dx > 0.3, "unchanged answer program moves kit car along +X")
	print("KIT_RUNTIME_MEASUREMENTS ", JSON.stringify({"left_pin": 0, "right_pin": 12, "sonar_pins": [1, 2], "sonar_cm": baseline, "moved_wall_cm": moved, "drive_dx_m": dx}))
	vm.stop()
	run.teardown()
	for level: Dictionary in StageLevels.all():
		var stage: Dictionary = StageLevels.stage_definition(level)
		graph = StageLevels.starting_graph(level, stage)
		run.build(graph)
		var judge := StageEvaluator.new()
		judge.configure(stage, graph)
		_check(judge.start(graph), level.id + " kit stage evaluation starts")
		vm.run(stage.author_solution.source)
		var stopped_ticks: int = 0
		for tick: int in 1200:
			await physics_frame
			judge.observe(run, graph, 1.0 / 60.0)
			stopped_ticks = 0 if vm.is_running() else stopped_ticks + 1
			if judge.success or stopped_ticks > 90:
				break
		print("KIT_STAGE_RESULT ", level.id, " ", JSON.stringify(judge.result()))
		if not judge.success:
			var velocities: Array[Dictionary] = []
			for index: int in graph.parts.size():
				velocities.append({"id": String(graph.parts[index].part_def.id), "speed_m_s": run.bodies[index].linear_velocity.length()})
			print("KIT_STAGE_BODY_SPEEDS ", JSON.stringify(velocities))
		_check(judge.success, level.id + " unchanged answer physically clears kit stage")
		vm.stop()
		run.teardown()
	world.free()
	await process_frame
	print("kit_robot_runtime_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
