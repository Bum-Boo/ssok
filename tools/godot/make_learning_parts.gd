extends SceneTree

const PartMaterials = preload("res://tools/godot/part_materials.gd")

func _init() -> void:
	var microbit := _box(&"microbit", "micro:bit V2", Vector3(0.052, 0.005, 0.043), 0.015, Color(0.16, 0.20, 0.27))
	microbit.board_profile_id = "microbit"
	for number: int in [0, 1, 2, 8, 12, 16]:
		microbit.ports.append(_port(StringName("pin_%d" % number), Port.Kind.ELEC, Vector3(-0.024 + microbit.ports.size() * 0.008, 0.0025, 0.019), Vector3.UP, &"board_digital_pwm", [&"pwm_signal", &"digital_io", &"driver_input"]))
	microbit.ports.append(_port(&"mount_bottom", Port.Kind.MECH, Vector3(0, -0.0025, 0), Vector3.DOWN, &"board_mount", [&"base_mount"]))
	_save(microbit)
	for driver_id: StringName in [&"motor_driver", &"tb6612_driver"]:
		var driver := _box(driver_id, "Motor Driver V2 (DRV8833)" if driver_id == &"motor_driver" else "Motor Driver (TB6612FNG)", Vector3(0.04, 0.008, 0.028), 0.01, Color(0.12, 0.50, 0.38))
		var pins: Array[int] = []
		pins.assign([0, 8, 12, 16] if driver_id == &"motor_driver" else [3, 4, 6, 7])
		for number: int in pins:
			driver.ports.append(_port(StringName("input_%d" % number), Port.Kind.ELEC, Vector3(-0.015 + driver.ports.size() * 0.01, 0.004, -0.014), Vector3.UP, &"driver_input", [&"board_digital_pwm", &"board_digital"]))
		for channel: int in [1, 2]:
			driver.ports.append(_port(StringName("motor_%d" % channel), Port.Kind.ELEC, Vector3(-0.01 if channel == 1 else 0.01, 0.004, 0.014), Vector3.UP, &"driver_output", [&"motor_power"]))
		driver.ports.append(_port(&"mount_bottom", Port.Kind.MECH, Vector3(0, -0.004, 0), Vector3.DOWN, &"board_mount", [&"base_mount"]))
		_save(driver)
	var chassis := _box(&"car_chassis", "Robot Car Chassis", Vector3(0.14, 0.008, 0.11), 0.08, Color(0.3, 0.48, 0.72))
	chassis.ports.append(_port(&"motor_left", Port.Kind.MECH, Vector3(-0.004, 0.004, -0.06), Vector3.UP, &"base_mount", [&"motor_mount"]))
	chassis.ports.append(_port(&"motor_right", Port.Kind.MECH, Vector3(-0.004, 0.004, 0.06), Vector3.UP, &"base_mount", [&"motor_mount"]))
	chassis.ports.append(_port(&"board_mount", Port.Kind.MECH, Vector3(0.025, 0.004, 0), Vector3.UP, &"base_mount", [&"board_mount"]))
	chassis.ports.append(_port(&"driver_mount", Port.Kind.MECH, Vector3(-0.035, 0.004, 0), Vector3.UP, &"base_mount", [&"board_mount"]))
	chassis.ports.append(_port(&"sensor_mount", Port.Kind.MECH, Vector3(0.070, 0.060, 0), Vector3.RIGHT, &"base_mount", [&"sensor_mount"]))
	chassis.ports.append(_port(&"caster_mount", Port.Kind.MECH, Vector3(0.055, -0.004, 0), Vector3.DOWN, &"base_mount", [&"caster_mount"]))
	_save(chassis)
	var caster := _box(&"ball_caster", "Ball Caster", Vector3.ONE * 0.024, 0.005, Color(0.6, 0.6, 0.65))
	caster.caster_radius = 0.012
	caster.merge_fixed_connections = false
	caster.ports.append(_port(&"mount", Port.Kind.MECH, Vector3(0, 0.0015, 0), Vector3.UP, &"caster_mount", [&"base_mount"]))
	_save(caster)
	var wall := _box(&"stage_wall", "Stage Wall", Vector3(0.02, 0.2, 0.6), 2.0, Color(0.8, 0.55, 0.30))
	_save(wall)
	var uno: PartDef = load("res://assets/parts/arduino_uno.tres")
	uno.board_profile_id = "uno"
	for port: Port in uno.ports:
		if port.kind == Port.Kind.ELEC and &"driver_input" not in port.accepts:
			port.accepts.append(&"driver_input")
	_save(uno)
	var motor: PartDef = load("res://assets/parts/tt_motor.tres")
	motor.dc_motor = true
	motor.merge_fixed_connections = true
	if motor.ports.size() == 3:
		motor.ports.append(_port(&"power", Port.Kind.ELEC, Vector3(0.03, 0, 0), Vector3.RIGHT, &"motor_power", [&"driver_output"]))
	_save(motor)
	var sensor: PartDef = load("res://assets/parts/hc_sr04.tres")
	sensor.merge_fixed_connections = true
	_save(sensor)
	var wheel: PartDef = load("res://assets/parts/wheel_65.tres")
	wheel.wheel_radius = 0.0325
	wheel.wheel_width = 0.026
	_save(wheel)
	quit()


func _box(id: StringName, label: String, size: Vector3, mass: float, color: Color) -> PartDef:
	var result := PartDef.new()
	result.id = id
	result.display_name = label
	result.mass_kg = mass
	result.merge_fixed_connections = true
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	result.mesh = mesh
	var material_name: String = "DetailGraphite" if id == &"microbit" else "BoardBody" if id in [&"motor_driver", &"tb6612_driver"] else "ChassisMetal" if id == &"car_chassis" else "Silver" if id == &"ball_caster" else "ArmBody"
	_write_mesh_source(id, mesh, material_name)
	var source_path: String = "res://assets/parts/%s.obj" % id
	if FileAccess.file_exists(source_path + ".import"):
		var imported: ArrayMesh = load(source_path) as ArrayMesh
		if imported != null:
			var bound: ArrayMesh = imported.duplicate()
			for surface: int in bound.get_surface_count():
				bound.surface_set_material(surface, load(PartMaterials.material_path(material_name)))
			assert(ResourceSaver.save(bound, PartMaterials.mesh_path(id)) == OK)
			result.mesh = load(PartMaterials.mesh_path(id))
	return result


func _write_mesh_source(id: StringName, mesh: BoxMesh, material_name: String) -> void:
	var path: String = "res://assets/parts/%s.obj" % id
	if FileAccess.file_exists(path):
		return
	var obj: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	obj.store_line("# Generated learning hardware envelope; regenerate from make_learning_parts.gd")
	obj.store_line("mtllib %s.mtl\nusemtl %s" % [id, material_name])
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for vertex: Vector3 in vertices:
		obj.store_line("v %.9f %.9f %.9f" % [vertex.x, vertex.y, vertex.z])
	for normal: Vector3 in normals:
		obj.store_line("vn %.9f %.9f %.9f" % [normal.x, normal.y, normal.z])
	for uv: Vector2 in uvs:
		obj.store_line("vt %.9f %.9f" % [uv.x, uv.y])
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for triangle: int in range(0, indices.size(), 3):
		var face: Array[String] = []
		for corner: int in 3:
			var index: int = indices[triangle + 2 - corner] + 1
			face.append("%d/%d/%d" % [index, index, index])
		obj.store_line("f " + " ".join(face))
	var mtl: FileAccess = FileAccess.open("res://assets/parts/%s.mtl" % id, FileAccess.WRITE)
	mtl.store_string("newmtl %s\nKd 0.5 0.5 0.5\n" % material_name)


func _port(id: StringName, kind: Port.Kind, position: Vector3, normal: Vector3, tag: StringName, accepts: Array[StringName]) -> Port:
	var result := Port.new()
	result.id = id
	result.kind = kind
	result.local_position = position
	result.local_normal = normal
	result.tag = tag
	result.accepts = accepts
	return result


func _save(definition: PartDef) -> void:
	assert(ResourceSaver.save(definition, "res://assets/parts/%s.tres" % definition.id) == OK)
