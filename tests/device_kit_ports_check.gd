extends SceneTree

const DEVICES := [&"microbit", &"arduino_uno", &"motor_driver", &"tb6612_driver", &"hc_sr04", &"tt_motor", &"servo", &"ball_caster", &"flag"]
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var beam: PartDef = load("res://assets/construction_kit/parts/kit_beam_60.tres")
	for id: StringName in DEVICES:
		var definition: PartDef = load("res://assets/parts/%s.tres" % id)
		var holes: Array[Port] = []
		var ids: Dictionary = {}
		for port: Port in definition.ports:
			_check(not ids.has(port.id), "%s unique port %s" % [id, port.id])
			ids[port.id] = true
			if port.tag == &"kit_m4":
				holes.append(port)
		var count: int = 4 if id in [&"microbit", &"arduino_uno", &"motor_driver", &"tb6612_driver"] else 2
		_check(holes.size() == count * 2, "%s has %d paired holes" % [id, count])
		for index: int in count:
			var front := _port(definition, StringName("kit_h%d_front" % index))
			var back := _port(definition, StringName("kit_h%d_back" % index))
			_check(front != null and back != null, "%s hole %d named faces" % [id, index])
			if front == null or back == null:
				continue
			_check(front.kind == Port.Kind.MECH and back.kind == Port.Kind.MECH and not front.rotates and not back.rotates, "%s bolted hole semantics" % id)
			_check(front.accepts == [&"kit_m4"] and back.accepts == [&"kit_m4"], "%s reciprocal kit interface" % id)
			_check(front.local_normal.is_equal_approx(-back.local_normal), "%s opposite face normals" % id)
			_check((front.local_position - back.local_position).normalized().is_equal_approx(front.local_normal), "%s face offset follows normal" % id)
			if index > 0:
				var first := _port(definition, &"kit_h0_front")
				var distance := front.local_position.distance_to(first.local_position)
				_check(is_equal_approx(distance, 0.02) or is_equal_approx(distance, sqrt(2.0) * 0.02), "%s 20 mm lattice" % id)
		var assembly := AssemblyMode.new()
		root.add_child(assembly)
		var node := assembly.spawn_part(definition, Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)))
		var indicators := PortIndicators.new()
		root.add_child(indicators)
		indicators.refresh(assembly.graph, -1, {"active": true})
		var mechanical_count := 0
		for port: Port in definition.ports:
			if port.kind == Port.Kind.MECH:
				mechanical_count += 1
		_check(indicators.ring_count() == mechanical_count, "%s free mechanical ports have M1 rings" % id)
		for face: String in ["front", "back"]:
			var target_id := StringName("kit_h0_" + face)
			var normal := node.get_port_global_normal(target_id)
			var position := node.get_port_global_position(target_id)
			_check(assembly.begin_place(beam), "%s begins kit placement" % id)
			assembly.update_place_ray(position + normal, -normal)
			var state := assembly.placement_state()
			_check(state.target_part == node.graph_index and state.target_port == target_id, "%s %s face is picked by the M1 ray" % [id, face])
			assembly.cancel_place()
		# Shared snap validates the same reciprocal interface and derives the graph link.
		var mounted := assembly.spawn_part(beam, Transform3D.IDENTITY)
		_check(assembly.snap(mounted, &"h0_back", node, &"kit_h0_front"), "%s kit hole snaps through the shared API" % id)
		indicators.refresh(assembly.graph, -1, {"active": true})
		_check(indicators.bolt_count() == 1, "%s linked kit hole shows a bolt" % id)
		_check(indicators.ring_count() == mechanical_count + beam.ports.size() - 2, "%s occupied endpoints hide their rings" % id)
		assembly.free()
		indicators.free()
	var motor: PartDef = load("res://assets/parts/tt_motor.tres")
	_check(motor.dc_motor and _port(motor, &"power") != null, "TT functional generator retains graph-wired power")
	for id: StringName in [&"shaft_left", &"shaft_right"]:
		var shaft := _port(motor, id)
		_check(shaft.rotates and shaft.tag == &"motor_shaft" and shaft.accepts == [&"wheel_hub", &"kit_axle_8"], "TT shaft extends accepts and retains rotation/tag")
	var assembly := AssemblyMode.new()
	root.add_child(assembly)
	var motor_node := assembly.spawn_part(motor, Transform3D.IDENTITY)
	var axle := assembly.spawn_part(load("res://assets/construction_kit/parts/kit_axle_40.tres"), Transform3D.IDENTITY)
	_check(assembly.snap(axle, &"front", motor_node, &"shaft_left"), "TT shaft mounts an actual kit axle reciprocally")
	assembly.free()
	var servo: PartDef = load("res://assets/parts/servo.tres")
	var output := _port(servo, &"output_shaft")
	_check(output.rotates and output.tag == &"servo_output" and output.accepts == [&"arm_mount", &"kit_axle_8"], "servo output retains legacy rotation/tag and extends accepts")
	assembly = AssemblyMode.new()
	root.add_child(assembly)
	var servo_node := assembly.spawn_part(servo, Transform3D.IDENTITY)
	axle = assembly.spawn_part(load("res://assets/construction_kit/parts/kit_axle_40.tres"), Transform3D.IDENTITY)
	_check(assembly.snap(axle, &"front", servo_node, &"output_shaft"), "servo output mounts an actual kit axle reciprocally")
	assembly.free()
	await process_frame
	print("device_kit_ports_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _port(definition: PartDef, id: StringName) -> Port:
	for port: Port in definition.ports:
		if port.id == id:
			return port
	return null


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
