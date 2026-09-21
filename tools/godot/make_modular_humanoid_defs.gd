extends SceneTree

const ROOT: String = "res://assets/modular_humanoid/"
const MATERIALS = preload("res://tools/godot/part_materials.gd")
var _failed: bool = false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "parts")
	DirAccess.make_dir_recursive_absolute(ROOT + "meshes")
	for filename: String in DirAccess.get_files_at(ROOT + "obj"):
		if filename.ends_with(".obj"):
			_bind_mesh(filename.get_basename())
	if _failed:
		quit(1)
		return
	var torso: PartDef = _part("modular_torso_frame", "Modular torso frame", 2.88, 100)
	for shape: Array in [[Vector3(0, 0, -0.035), Vector3(0.09, 0.30, 0.07)],
		[Vector3(0, 0.13, 0), Vector3(0.39, 0.045, 0.065)],
		[Vector3(0, -0.14, 0), Vector3(0.27, 0.04, 0.08)],
		[Vector3(-0.115, 0, -0.025), Vector3(0.018, 0.25, 0.05)],
		[Vector3(0.115, 0, -0.025), Vector3(0.018, 0.25, 0.05)]]:
		torso.collision_boxes.append(AABB(shape[0] - shape[1] * 0.5, shape[1]))
	for side: String in ["left", "right"]:
		var sign_x: float = -1.0 if side == "left" else 1.0
		_mount(torso, "hip_" + side, Vector3(sign_x * 0.12, -0.16, 0))
		_mount(torso, "shoulder_" + side, Vector3(sign_x * 0.20, 0.13, 0))
	_mount(torso, "chest", Vector3.ZERO, &"modular_bolt", Vector3.BACK)
	_mount(torso, "pelvis", Vector3(0, -0.12, 0))
	_mount(torso, "neck", Vector3(0, 0.16, 0), &"modular_bolt", Vector3.UP)
	_mount(torso, "board", Vector3(0, 0, -0.075), &"modular_bolt", Vector3.FORWARD)
	_save(torso)
	var shell: PartDef = _part("modular_chest_shell", "Removable chest shell", 0.4)
	_mount(shell, "mount", Vector3.ZERO, &"modular_bolt", Vector3.FORWARD)
	_save(shell)
	shell = _part("modular_pelvis_shell", "Removable pelvis shell", 0.2)
	_mount(shell, "mount", Vector3.ZERO, &"modular_bolt", Vector3.UP)
	_save(shell)
	var head: PartDef = _part("modular_head_shell", "Optical head module", 0.8)
	_mount(head, "mount", Vector3(0, -0.085, 0))
	_save(head)
	var board: PartDef = _part("modular_controller", "Modular PWM controller", 0.12)
	_mount(board, "mount", Vector3.ZERO, &"modular_bolt", Vector3.BACK)
	for pin: int in range(20, 30):
		_electrical(board, "pin_%d" % pin, Vector3(-0.046 if pin < 25 else 0.046, (pin % 5 - 2) * 0.016, -0.014), true)
	_save(board)
	_motor("hip", "Hip servo module (35 Nm)", 0.16, 35, -110, 70, false)
	_motor("knee", "Knee servo module (35 Nm)", 0.16, 35, -5, 140, false)
	_motor("ankle", "Ankle servo module (30 Nm)", 0.16, 30, -75, 75, false)
	_motor("shoulder", "Shoulder servo module (12 Nm)", 0.10, 12, -140, 70, true)
	_motor("elbow", "Elbow servo module (12 Nm)", 0.10, 12, -140, 10, true)
	for arm: bool in [false, true]:
		var bracket: PartDef = _part("modular_arm_bracket" if arm else "modular_leg_bracket",
			"Arm output U-bracket" if arm else "Leg output U-bracket", 0.03 if arm else 0.06)
		_mount(bracket, "input", Vector3.ZERO, &"modular_output", Vector3.LEFT)
		_mount(bracket, "frame", Vector3(0, -0.032 if arm else -0.04, 0))
		_save(bracket)
	_frame("modular_thigh_frame", "Passive thigh frame", 0.78, 0.08, -0.12, "knee")
	_frame("modular_shin_frame", "Passive shin frame", 0.48, 0.08, -0.12, "ankle")
	_frame("modular_upper_arm_frame", "Passive upper-arm frame", 0.32, 0.078, -0.11, "elbow")
	_frame("modular_forearm_frame", "Passive forearm frame", 0.26, 0.078, -0.08, "hand")
	var hand: PartDef = _part("modular_gripper_hand", "Padded gripper hand", 0.06)
	_mount(hand, "mount", Vector3.ZERO, &"modular_bolt", Vector3.UP)
	_mount(hand, "grip", Vector3(0, -0.03, 0.03))
	_save(hand)
	var foot: PartDef = _part("modular_foot", "Rubber-soled foot module", 0.44, 100)
	_mount(foot, "mount", Vector3(0, -0.01, -0.035), &"modular_bolt", Vector3.UP)
	_save(foot)
	print("make_modular_humanoid_defs: 18 separate part definitions, 15 Blender meshes; failed=%s" % _failed)
	quit(1 if _failed else 0)


func _bind_mesh(id: String) -> void:
	var source: ArrayMesh = load(ROOT + "obj/" + id + ".obj") as ArrayMesh
	if source == null:
		_failed = true
		return
	var mesh: ArrayMesh = source.duplicate(true) as ArrayMesh
	for surface: int in mesh.get_surface_count():
		var imported: Material = source.surface_get_material(surface)
		var path: String = MATERIALS.material_path(imported.resource_name)
		if not ResourceLoader.exists(path):
			push_error("Missing shared PBR material: " + path)
			_failed = true
			return
		mesh.surface_set_material(surface, load(path))
	mesh.resource_name = id
	if ResourceSaver.save(mesh, ROOT + "meshes/" + id + ".res", ResourceSaver.FLAG_COMPRESS) != OK:
		_failed = true


func _part(id: String, label: String, mass: float, priority: int = 0, mesh_id: String = "") -> PartDef:
	var part := PartDef.new()
	part.id = StringName(id)
	part.display_name = label
	part.mass_kg = mass
	part.merge_fixed_connections = true
	part.physics_frame_priority = priority
	part.mesh = load(ROOT + "meshes/" + (id if mesh_id.is_empty() else mesh_id) + ".res") as Mesh
	return part


func _motor(role: String, label: String, mass: float, torque: float, lower: float, upper: float, arm: bool) -> void:
	var part: PartDef = _part("modular_" + role + "_servo", label, mass, 0, "modular_arm_motor" if arm else "modular_leg_motor")
	_mount(part, "mount", Vector3.ZERO, &"modular_bolt", Vector3.UP)
	var output: Port = _mount(part, "output", Vector3.ZERO, &"modular_output", Vector3.RIGHT)
	output.rotates = true
	part.actuator_torque_nm = torque
	part.actuator_min_deg = lower
	part.actuator_max_deg = upper
	part.actuator_drives_connected_body = true
	_electrical(part, "signal", Vector3(0, 0.01, -0.034 if not arm else -0.025), false)
	_save(part)


func _frame(id: String, label: String, mass: float, top: float, bottom: float, distal: String) -> void:
	var part: PartDef = _part(id, label, mass, 100)
	_mount(part, "mount", Vector3(0, top, 0), &"modular_bolt", Vector3.UP)
	_mount(part, distal, Vector3(0, bottom, 0))
	_save(part)


func _mount(part: PartDef, id: String, position: Vector3, tag: StringName = &"modular_bolt", normal: Vector3 = Vector3.DOWN) -> Port:
	var port := Port.new()
	port.id = StringName(id)
	port.local_position = position
	port.local_normal = normal
	port.tag = tag
	port.accepts.append(tag)
	part.ports.append(port)
	return port


func _electrical(part: PartDef, id: String, position: Vector3, board: bool) -> void:
	var port := Port.new()
	port.id = StringName(id)
	port.kind = Port.Kind.ELEC
	port.local_position = position
	port.tag = &"board_digital_pwm" if board else &"pwm_signal"
	port.accepts.append(&"pwm_signal" if board else &"board_digital_pwm")
	part.ports.append(port)


func _save(part: PartDef) -> void:
	if part.mesh == null or ResourceSaver.save(part, ROOT + "parts/" + String(part.id) + ".tres") != OK:
		_failed = true
