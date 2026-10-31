extends SceneTree

## Review repro: a gear reducer bolted into a merged cluster whose representative
## part has a different local Z axis. The constraint axis should follow the gear part.
const ROOT: String = "res://assets/construction_kit/parts/"
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for case: Dictionary in [
		{"label": "plate (parallel z)", "carrier": "kit_plate_80_60", "carrier_port": &"h0_front"},
		{"label": "kit motor face (perpendicular z)", "carrier": "kit_motor_12", "carrier_port": &"mount_0_front"},
		{"label": "angle bracket base (perpendicular z)", "carrier": "kit_angle_bracket", "carrier_port": &"base_0_front"},
	]:
		await _case(case)
	print("gear_axis_cluster_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _case(case: Dictionary) -> void:
	var assembly := AssemblyMode.new()
	root.add_child(assembly)
	var carrier_def: PartDef = load(ROOT + String(case.carrier) + ".tres")
	var carrier: PartNode = assembly.spawn_part(carrier_def, Transform3D.IDENTITY)
	var carrier_port: StringName = case.carrier_port
	if carrier.get_port(carrier_port) == null:
		for port: Port in carrier_def.ports:
			if port.tag == &"kit_m4" and port.local_normal.z > 0.5:
				carrier_port = port.id
				break
	var gear: PartNode = assembly.spawn_part(load(ROOT + "kit_gear_2.tres"), Transform3D(Basis.IDENTITY, Vector3(0.2, 0, 0)))
	var snapped: bool = assembly.snap(gear, &"mount_0_back", carrier, carrier_port)
	_check(snapped, case.label + ": gear bolts to carrier")
	for collider: StaticBody3D in assembly.find_children("*", "StaticBody3D", true, false):
		collider.collision_layer = 0
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(assembly.graph)
	var transmission: GearConstraint = hardware.gears[1]
	var merged: bool = hardware.bodies[0] == hardware.bodies[1]
	var gear_axis: Vector3 = hardware.part_global_transform(1).basis.z.normalized()
	var used_axis: Vector3 = (transmission.housing.global_basis * transmission.axis_local).normalized()
	print("CASE %s merged=%s gear_axis=%s constraint_axis=%s |dot|=%.3f" % [case.label, merged, gear_axis, used_axis, absf(gear_axis.dot(used_axis))])
	for body: RigidBody3D in [transmission.input, transmission.output, transmission.housing]:
		body.gravity_scale = 0
		body.angular_damp = 0
	transmission.housing.freeze = true
	await physics_frame
	await physics_frame
	transmission.input.angular_velocity = gear_axis * 5.0
	for tick: int in 30:
		await physics_frame
	var wi: float = transmission.input.angular_velocity.dot(gear_axis)
	var wo: float = transmission.output.angular_velocity.dot(gear_axis)
	print("CASE %s input=%.4f output=%.4f expected_output=%.4f" % [case.label, wi, wo, -wi / transmission.ratio])
	_check(absf(gear_axis.dot(used_axis)) > 0.99, case.label + ": constraint axis follows gear part axis")
	_check(absf(wi) > 0.1 and absf(wo + wi / transmission.ratio) < 0.05 * absf(wi), case.label + ": output follows input by ratio")
	hardware.free()
	assembly.free()
	await process_frame


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
