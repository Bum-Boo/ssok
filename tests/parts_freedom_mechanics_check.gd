extends SceneTree

const ROOT: String = "res://assets/construction_kit/parts/"
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var assembly := AssemblyMode.new()
	root.add_child(assembly)
	for id: String in ["kit_passive_hinge", "kit_weight_100", "kit_weight_300"]:
		assembly.load_graph(ConnectionGraph.new())
		var plate: PartNode = assembly.spawn_part(load(ROOT + "kit_plate_60_40.tres"), Transform3D.IDENTITY)
		var part: PartNode = assembly.spawn_part(load(ROOT + id + ".tres"), Transform3D(Basis.IDENTITY, Vector3(0.2, 0.3, 0.1)))
		_check(assembly.snap(part, &"mount_0_back", plate, &"h0_front"), id + " snaps to standard 4 mm mounting face")
		_check(part.get_port_global_position(&"mount_0_back").distance_to(plate.get_port_global_position(&"h0_front")) < 0.00001, "snapped anchors coincide")
		_check(is_equal_approx(part.get_port(&"mount_1_back").local_position.distance_to(part.get_port(&"mount_0_back").local_position), 0.02), "20 mm mounting pitch")
		_check(MotionSnapshot.decode(MotionSnapshot.encode(assembly.graph)) != null, "new part snapshot round trip")
		for port: Port in part.part_def.ports:
			_check(port.kind == Port.Kind.MECH, "passive stock has no fictional electrical ports")

	for diameter: int in [40, 90]:
		assembly.load_graph(ConnectionGraph.new())
		var motor: PartNode = assembly.spawn_part(load("res://assets/parts/tt_motor.tres"), Transform3D.IDENTITY)
		var wheel: PartNode = assembly.spawn_part(load(ROOT + "kit_wheel_%d.tres" % diameter), Transform3D.IDENTITY)
		_check(assembly.snap(wheel, &"hub", motor, &"shaft_left"), "wheel %d snaps to TT output" % diameter)
		var hardware := RunMode.new()
		root.add_child(hardware)
		_disable_editor_collisions(assembly)
		hardware.build(assembly.graph)
		_check(hardware.motors.size() == 1 and hardware.servos.is_empty(), "DC motor retains rotational physics")
		var collider: CylinderShape3D
		for child: Node in hardware.bodies[1].get_children():
			if child is CollisionShape3D:
				collider = child.shape as CylinderShape3D
		_check(collider != null and is_equal_approx(collider.radius * 2000, diameter), "actual cylindrical wheel radius")
		hardware.bodies[0].freeze = true
		hardware.bodies[1].gravity_scale = 0
		await physics_frame
		await physics_frame
		var initial: Vector3 = hardware.bodies[1].global_basis.x
		var drive: DriveMotor = hardware.motors[0]
		drive.forward(40)
		var moved: float = 0
		for tick: int in 45:
			await physics_frame
			moved = maxf(moved, initial.distance_to(hardware.bodies[1].global_basis.x))
		print("WHEEL diameter=%d movement=%.4f speed=%.4f" % [diameter, moved, drive.measured_rad_s])
		_check(moved > 0.05, "motor rotates new wheel under actual physics")
		_check(absf(drive.applied_torque_nm) <= drive.stall_torque_nm + 0.00001, "existing motor torque cap retained")
		hardware.free()
		await process_frame

	var hinge_cases: Array[Dictionary] = [
		{"direction": -1.0, "min": -45.0, "max": 45.0, "reverse": false},
		{"direction": 1.0, "min": -45.0, "max": 45.0, "reverse": false},
		{"direction": -1.0, "min": -20.0, "max": 30.0, "reverse": false},
		{"direction": 1.0, "min": -20.0, "max": 30.0, "reverse": true},
		{"direction": 1.0, "min": -20.0, "max": 30.0, "reverse": false},
		{"direction": -1.0, "min": -20.0, "max": 30.0, "reverse": true},
	]
	for scenario: Dictionary in hinge_cases:
		var direction: float = scenario.direction
		assembly.load_graph(ConnectionGraph.new())
		var definition: PartDef = load(ROOT + "kit_passive_hinge.tres").duplicate() as PartDef
		definition.actuator_min_deg = scenario.min
		definition.actuator_max_deg = scenario.max
		var bearing: PartNode = assembly.spawn_part(definition, Transform3D.IDENTITY)
		var coupler: PartNode = assembly.spawn_part(load(ROOT + "kit_coupler_8.tres"), Transform3D.IDENTITY)
		_check(assembly.snap(coupler, &"bore_back", bearing, &"output"), "8 mm rotating shaft connects to standard axle")
		var graph: ConnectionGraph = assembly.graph
		if scenario.reverse:
			var link: Dictionary = graph.links[0]
			graph.links[0] = {"a_part": link.b_part, "a_port": link.b_port, "b_part": link.a_part, "b_port": link.a_port}
		var fingerprint: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(graph))
		var hardware := RunMode.new()
		root.add_child(hardware)
		_disable_editor_collisions(assembly)
		hardware.build(graph)
		_check(hardware.servos.is_empty() and hardware.motors.is_empty(), "passive hinge creates no powered actuator")
		var hinge: HingeJoint3D
		for child: Node in hardware.get_children():
			if child is HingeJoint3D:
				hinge = child
		_check(hinge != null and hinge.get_flag(HingeJoint3D.FLAG_USE_LIMIT) and not hinge.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR), "limited free hinge has motor disabled")
		hardware.bodies[0].freeze = true
		hardware.bodies[1].gravity_scale = 0
		await physics_frame
		await physics_frame
		var initial: Vector3 = hardware.bodies[1].global_basis.x
		hardware.bodies[1].angular_damp = 0
		hardware.bodies[1].angular_velocity = Vector3.BACK * direction * 5.0
		var minimum: float = 0
		var maximum: float = 0
		for tick: int in 90:
			await physics_frame
			var angle: float = rad_to_deg(initial.signed_angle_to(hardware.bodies[1].global_basis.x, Vector3.BACK))
			minimum = minf(minimum, angle)
			maximum = maxf(maximum, angle)
		print("PASSIVE_HINGE direction=%s configured=[%s,%s] observed=[%.3f,%.3f] reverse=%s" % [direction, scenario.min, scenario.max, minimum, maximum, scenario.reverse])
		_check(minimum >= scenario.min - 5 and maximum <= scenario.max + 5, "both configured stops hold independent of link ordering (solver tolerance)")
		_check(minimum < scenario.min + 10 if direction < 0 else maximum > scenario.max - 10, "injected rotation actually reaches the configured stop")
		_check(fingerprint == MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)), "physics leaves editor graph unchanged")
		hardware.teardown()
		_check(hardware.get_child_count() == 0 and hardware.bodies.is_empty(), "teardown removes passive physics")
		hardware.free()
		await process_frame

	var graph := ConnectionGraph.new()
	for id: String in ["kit_weight_100", "kit_weight_300"]:
		graph.parts.append({"part_def": load(ROOT + id + ".tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0))})
	graph.parts[1].transform.origin.x = 0.1
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	_check(is_equal_approx(hardware.bodies[0].mass, 0.1) and is_equal_approx(hardware.bodies[1].mass, 0.3), "actual 100 g and 300 g solver masses")
	for tick: int in 20:
		await physics_frame
	_check(hardware.bodies[0].position.y < 0.4 and hardware.bodies[1].position.y < 0.4, "both weights fall under gravity")
	hardware.free()
	assembly.free()
	await process_frame
	print("parts_freedom_mechanics_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _disable_editor_collisions(assembly: AssemblyMode) -> void:
	# Match the application mode switch: editor picking proxies cannot enter run physics.
	for collider: StaticBody3D in assembly.find_children("*", "StaticBody3D", true, false):
		collider.collision_layer = 0


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
