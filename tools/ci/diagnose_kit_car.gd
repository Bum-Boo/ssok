extends SceneTree

## Read-only 60 Hz comparison; never changes runtime physics or stage thresholds.
var world: Node3D
var run: RunMode
var vm: MiniRuntime
var runtime_failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.1, 20)
	collision.shape = box
	floor_body.add_child(collision)
	world.add_child(floor_body)
	run = RunMode.new()
	world.add_child(run)
	vm = MiniRuntime.new()
	vm.hardware = run
	world.add_child(vm)
	vm.failed.connect(func(line: int, message: String) -> void:
		runtime_failed = true
		push_error("Runtime line %d: %s" % [line, message]))
	var level: Dictionary = StageLevels.find("wall")
	if level.is_empty():
		for candidate: Dictionary in StageLevels.all():
			if String(candidate.id).contains("wall"):
				level = candidate
	var stage: Dictionary = StageLevels.stage_definition(level)
	if stage.is_empty():
		push_error("Wall stage is missing")
		quit(1)
		return
	for name: String in ["legacy", "kit"]:
		var graph: ConnectionGraph = RobotCarPreset.build(0.8) if name == "legacy" else KitCarPreset.build(0.8)
		run.build(graph)
		var caster: int = -1
		var wheel: int = -1
		var wheels: Array[int] = []
		var sonar: int = -1
		var robot_max_x: float = -INF
		var sonar_max_x: float = -INF
		var clusters: Array[Dictionary] = []
		var seen: Array[RigidBody3D] = []
		for index: int in graph.parts.size():
			var id: String = String(graph.parts[index].part_def.id)
			if id == "ball_caster":
				caster = index
			if graph.parts[index].part_def.wheel_radius > 0:
				wheel = index
				wheels.append(index)
			if id == "hc_sr04":
				sonar = index
			if id != "stage_wall":
				for corner: int in 8:
					var point: Vector3 = graph.parts[index].transform * graph.parts[index].part_def.mesh.get_aabb().get_endpoint(corner)
					robot_max_x = maxf(robot_max_x, point.x)
					if id == "hc_sr04":
						sonar_max_x = maxf(sonar_max_x, point.x)
			var body: RigidBody3D = run.bodies[index]
			if body in seen:
				continue
			seen.append(body)
			var members: Array[String] = []
			for other: int in graph.parts.size():
				if run.bodies[other] == body:
					members.append("%d:%s" % [other, graph.parts[other].part_def.id])
			clusters.append({"members": members, "mass_kg": body.mass, "frozen": body.freeze,
				"friction": body.physics_material_override.friction if body.physics_material_override != null else 1.0})
		var summary: Dictionary = {"name": name, "clusters": clusters, "mass_ratio": run.bodies[0].mass / run.bodies[caster].mass,
			"caster_center": _vec(graph.parts[caster].transform.origin), "wheel_axis": _vec(graph.parts[wheel].transform.origin),
			"caster_minus_axis_y_m": graph.parts[caster].transform.origin.y - graph.parts[wheel].transform.origin.y,
			"caster_shares_carrier_body": run.bodies[caster] == run.bodies[0]}
		summary["caster_ahead_axis_m"] = graph.parts[caster].transform.origin.x - graph.parts[wheel].transform.origin.x
		summary["wheel_track_m"] = absf(graph.parts[wheels[0]].transform.origin.z - graph.parts[wheels[1]].transform.origin.z)
		summary["chassis_com_world_m"] = _vec(run.bodies[0].transform * run.bodies[0].center_of_mass)
		summary["robot_max_x_m"] = robot_max_x
		summary["sonar_face_x_m"] = (graph.parts[sonar].transform * Vector3(0, 0, 0.012)).x
		summary["sonar_bound_max_x_m"] = sonar_max_x
		for link: Dictionary in graph.links:
			var caster_port: StringName
			if link.a_part == caster:
				caster_port = link.a_port
			elif link.b_part == caster:
				caster_port = link.b_port
			else:
				continue
			var port: Port = RunMode._port(graph.parts[caster].part_def, caster_port)
			if port.kind == Port.Kind.MECH:
				var mount: Vector3 = graph.parts[caster].transform * port.local_position
				summary["caster_mount"] = _vec(mount)
				summary["caster_mount_minus_axis_y_m"] = mount.y - graph.parts[wheel].transform.origin.y
		var judge := StageEvaluator.new()
		judge.configure(stage, graph)
		if not judge.start(graph):
			push_error("Invalid diagnostic graph: " + name)
			world.free()
			quit(1)
			return
		var samples: Array[Dictionary] = []
		# Stage attempts start immediately; the same initial drop and BRAKE_CODE apply to both.
		vm.run(RobotCarPreset.BRAKE_CODE)
		var stop_tick: int = -1
		var success_tick: int = -1
		for tick: int in 1200:
			await physics_frame
			judge.observe(run, graph, 1.0 / 60.0)
			if success_tick < 0 and judge.success:
				success_tick = tick
			if stop_tick < 0 and not vm.is_running():
				stop_tick = tick
			var caster_body: RigidBody3D = run.bodies[caster]
			var contacts: Array[String] = []
			for contact: Node in caster_body.get_colliding_bodies():
				contacts.append("floor" if contact == floor_body else String(contact.name))
			var axis: Vector3 = run.part_global_transform(0).basis * graph.parts[0].transform.basis.inverse() * Vector3.RIGHT
			samples.append({"tick": tick, "t_s": tick / 60.0, "linear_m_s": _vec(caster_body.linear_velocity),
				"angular_rad_s": _vec(caster_body.angular_velocity), "speed_m_s": caster_body.linear_velocity.length(),
				"pitch_deg": rad_to_deg(atan2(axis.y, Vector2(axis.x, axis.z).length())), "contacts": contacts,
				"chassis_speed_m_s": run.bodies[0].linear_velocity.length(), "success": judge.success})
			if stop_tick >= 0 and tick >= stop_tick + 120:
				break
		summary["stop_tick"] = stop_tick
		summary["success_tick"] = success_tick
		summary["result"] = judge.result()
		var window: Array[Dictionary] = []
		for sample: Dictionary in samples:
			if sample.tick >= (stop_tick - 60 if stop_tick >= 0 else samples.size() - 120):
				window.append(sample)
		summary["samples"] = window
		print("M2B_DIAGNOSTIC ", JSON.stringify(summary))
		vm.stop()
		run.teardown()
		await process_frame
		var finish_graph: ConnectionGraph = RobotCarPreset.build() if name == "legacy" else KitCarPreset.build()
		var finish := StageEvaluator.new()
		finish.configure(StageLevels.stage_definition(StageLevels.find("finish-line")), finish_graph)
		run.build(finish_graph)
		if not finish.start(finish_graph):
			push_error("Invalid finish diagnostic graph: " + name)
			runtime_failed = true
		else:
			vm.run(RobotCarPreset.ANSWER_CODE)
			for tick: int in 600:
				await physics_frame
				finish.observe(run, finish_graph, 1.0 / 60.0)
				if finish.success:
					break
			print("M2D_FINISH ", name, " ", JSON.stringify(finish.result()))
		vm.stop()
		run.teardown()
		await process_frame
	world.free()
	await process_frame
	quit(1 if runtime_failed else 0)


func _vec(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
