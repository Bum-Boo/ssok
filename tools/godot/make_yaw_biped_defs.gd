extends SceneTree

const DIRECTORY: String = "res://assets/learning_biped/parts/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var body: PartDef = _copy("biped_body", "yaw_biped_body", "Yaw Biped Body")
	for port: Port in body.ports:
		if port.id == &"hip_left":
			port.local_position = Vector3(-0.0115, -0.03, 0)
			port.local_normal = Vector3.LEFT
		elif port.id == &"hip_right":
			port.local_position = Vector3(0.0115, -0.03, 0)
			port.local_normal = Vector3.RIGHT
	_save(body)
	var leg: PartDef = _copy("leg_link", "yaw_leg_link", "Yaw Leg Link")
	for port: Port in leg.ports:
		if port.id == &"hip_mount":
			port.local_position = Vector3(0.006, 0.02, 0)
			port.local_normal = Vector3.UP
	_save(leg)
	var servo: PartDef = _copy("servo", "torque_micro_servo", "Torque Micro Servo")
	servo.actuator_torque_nm = 0.25
	servo.actuator_drives_connected_body = true
	_save(servo)
	var sensor_source: PartDef = load("res://assets/parts/hc_sr04.tres")
	_save(_copy("hc_sr04", "learning_hc_sr04", sensor_source.display_name))
	quit(0)


func _copy(source: String, id: String, label: String) -> PartDef:
	var original: PartDef = load("res://assets/parts/" + source + ".tres")
	var definition: PartDef = original.duplicate() as PartDef
	definition.id = StringName(id)
	definition.display_name = label
	definition.merge_fixed_connections = true
	definition.ports = []
	for port: Port in original.ports:
		definition.ports.append(port.duplicate() as Port)
	return definition


func _save(definition: PartDef) -> void:
	var error: Error = ResourceSaver.save(definition, DIRECTORY + String(definition.id) + ".tres")
	if error != OK:
		push_error("Could not write learning robot definition")
		quit(1)
