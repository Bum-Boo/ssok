extends SceneTree

const OUT: String = "res://assets/humanoid/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var torso: PartDef = _part("humanoid_torso", "Humanoid torso", Vector3(0.30, 0.32, 0.16), 4.0, Color("d9e6ec"))
	for side: String in ["left", "right"]:
		var sign_x: float = -1.0 if side == "left" else 1.0
		_mount(torso, "hip_" + side, Vector3(sign_x * 0.12, -0.16, 0))
		_mount(torso, "shoulder_" + side, Vector3(sign_x * 0.20, 0.13, 0))
	_mount(torso, "neck", Vector3(0, 0.16, 0))
	_mount(torso, "board", Vector3(0, 0, -0.095))
	_save(torso)
	var head: PartDef = _part("humanoid_head", "Humanoid head", Vector3(0.16, 0.17, 0.15), 0.8, Color("71d9bd"))
	_mount(head, "mount", Vector3(0, -0.085, 0))
	_save(head)
	var board: PartDef = _part("humanoid_board", "Virtual humanoid controller", Vector3(0.12, 0.10, 0.015), 0.12, Color("1a7a59"))
	_mount(board, "mount", Vector3.ZERO)
	for pin: int in range(20, 30):
		_electrical(board, "pin_%d" % pin, Vector3((pin - 24.5) * 0.009, 0.04, 0), true)
	_save(board)
	_segment("humanoid_thigh", "Humanoid thigh actuator", Vector3(0.095, 0.24, 0.10), 1.0, 35.0, -110, 70, "knee")
	_segment("humanoid_shin", "Humanoid knee actuator", Vector3(0.075, 0.24, 0.08), 0.7, 35.0, -5, 140, "ankle")
	_segment("humanoid_upper_arm", "Humanoid shoulder actuator", Vector3(0.07, 0.22, 0.075), 0.45, 12.0, -140, 70, "elbow")
	_segment("humanoid_forearm", "Humanoid elbow and hand", Vector3(0.06, 0.22, 0.07), 0.35, 12.0, -140, 10, "grip")
	var foot: PartDef = _part("humanoid_foot", "Humanoid ankle and foot", Vector3(0.22, 0.06, 0.22), 0.5, Color("263d4e"))
	_actuator(foot, Vector3(0, 0.03, -0.035), 30.0, -75, 75)
	_save(foot)
	_save(_part("cargo_box", "Practice box (0.4 kg)", Vector3(0.34, 0.20, 0.20), 0.4, Color("c49557")))
	quit()


func _segment(id: String, label: String, size: Vector3, mass: float, torque: float, lower: float, upper: float, distal: String) -> void:
	var part: PartDef = _part(id, label, size, mass, Color("879fb4"))
	_actuator(part, Vector3(0, size.y * 0.5, 0), torque, lower, upper)
	_mount(part, distal, Vector3(0, -size.y * 0.5, 0))
	if id == "humanoid_forearm":
		_add_palm(part, size)
	_save(part)


func _add_palm(part: PartDef, forearm_size: Vector3) -> void:
	var palm_size: Vector3 = Vector3(0.09, 0.045, 0.085)
	var palm_center: Vector3 = Vector3(0, -0.105, 0)
	var palm := BoxMesh.new()
	palm.size = palm_size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("263d4e")
	material.roughness = 0.9
	palm.material = material
	var mesh := ArrayMesh.new()
	_append_box(mesh, part.mesh as BoxMesh, Vector3.ZERO)
	_append_box(mesh, palm, palm_center)
	part.mesh = mesh
	part.collision_boxes = [AABB(-forearm_size * 0.5, forearm_size), AABB(palm_center - palm_size * 0.5, palm_size)]


func _append_box(target: ArrayMesh, source: BoxMesh, offset: Vector3) -> void:
	var arrays: Array = source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index: int in vertices.size():
		vertices[index] += offset
	arrays[Mesh.ARRAY_VERTEX] = vertices
	target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	target.surface_set_material(target.get_surface_count() - 1, source.material)


func _part(id: String, label: String, size: Vector3, mass: float, color: Color) -> PartDef:
	var part := PartDef.new()
	part.id = StringName(id)
	part.display_name = label
	part.mass_kg = mass
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.3 if id != "cargo_box" else 0.0
	material.roughness = 0.55
	mesh.material = material
	part.mesh = mesh
	return part


func _mount(part: PartDef, id: String, position: Vector3) -> Port:
	var port := Port.new()
	port.id = StringName(id)
	port.local_position = position
	port.local_normal = Vector3.RIGHT
	port.tag = &"humanoid_joint"
	port.accepts = [&"humanoid_joint"]
	part.ports.append(port)
	return port


func _actuator(part: PartDef, position: Vector3, torque: float, lower: float, upper: float) -> void:
	var port: Port = _mount(part, "pivot", position)
	port.rotates = true
	part.actuator_torque_nm = torque
	part.actuator_min_deg = lower
	part.actuator_max_deg = upper
	_electrical(part, "signal", Vector3.ZERO, false)


func _electrical(part: PartDef, id: String, position: Vector3, board: bool) -> void:
	var port := Port.new()
	port.id = StringName(id)
	port.kind = Port.Kind.ELEC
	port.local_position = position
	port.tag = &"board_digital_pwm" if board else &"pwm_signal"
	port.accepts.append(&"pwm_signal" if board else &"board_digital_pwm")
	part.ports.append(port)


func _save(part: PartDef) -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--part" and args[1] != String(part.id):
		return
	var error: Error = ResourceSaver.save(part, OUT + String(part.id) + ".tres")
	if error != OK:
		push_error("Could not save humanoid part: " + String(part.id))
		quit(1)
