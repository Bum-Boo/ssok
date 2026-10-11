extends SceneTree

## Regenerates stage level scenes: godot --headless --path . --script res://tools/godot/make_levels.gd
## Scenes stay editable in the Godot editor afterwards. Rerunning overwrites manual edits,
## so after hand-tuning a level, stop regenerating that file.
## Robot-scale geometry: the servo arm is 8 cm long and the car 14 cm, so props stay small.
## Markers are visual only; only Ground (and graph parts such as stage_wall) collide.

const FLOOR_TOP: float = 0.05
const SURFACE: float = FLOOR_TOP + 0.0006
const OUT_DIR: String = "res://stages/"


func _initialize() -> void:
	_save(_raise_flag(), "raise_flag")
	_save(_finish_line(), "finish_line")
	_save(_wall_brake(), "wall_brake")
	quit()


func _save(root: StageLevel, folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + folder))
	_own(root, root)
	var scene := PackedScene.new()
	var error: Error = scene.pack(root)
	if error == OK:
		error = ResourceSaver.save(scene, OUT_DIR + folder + "/level.tscn")
	print("%s: %s" % [folder, error_string(error)])
	root.free()


func _own(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_own(child, owner_node)


func _level(name: String, ground: Color, play_area: AABB, yaw: float = 30.0, pitch: float = 25.0) -> StageLevel:
	var root := StageLevel.new()
	root.name = name
	root.play_area = play_area
	root.view_yaw_degrees = yaw
	root.view_pitch_degrees = pitch
	root.floor_top = FLOOR_TOP
	var body := StaticBody3D.new()
	body.name = "Ground"
	root.add_child(body)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = Vector3(6, 0.1, 6)
	mesh.mesh = box
	mesh.material_override = _material(ground, 0.95)
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	body.add_child(shape)
	for group: String in ["Props", "Markers"]:
		var node := Node3D.new()
		node.name = group
		root.add_child(node)
	return root


func _material(color: Color, roughness: float = 0.8, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = 0.6
	return material


func _box(parent: Node, name: String, size: Vector3, center: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = center
	mesh.material_override = _material(color, 0.8, glow)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if color.a < 1.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh)
	return mesh


func _cylinder(parent: Node, name: String, radius_top: float, radius_bottom: float, height: float, base: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius_top
	cylinder.bottom_radius = radius_bottom
	cylinder.height = height
	cylinder.radial_segments = 16
	mesh.mesh = cylinder
	mesh.position = base + Vector3(0, height * 0.5, 0)
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh


## Flat paint on the ground; thin enough that wheels never catch on it (no collision).
func _paint(parent: Node, name: String, from_x: float, to_x: float, half_width: float, color: Color, layer: int = 0) -> MeshInstance3D:
	var mesh := _box(parent, name, Vector3(to_x - from_x, 0.0008, half_width * 2.0), Vector3((from_x + to_x) * 0.5, SURFACE + 0.0004 * layer, 0), color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


func _tree(parent: Node, name: String, at: Vector2, scale: float) -> void:
	var tree := Node3D.new()
	tree.name = name
	tree.position = Vector3(at.x, FLOOR_TOP, at.y)
	parent.add_child(tree)
	_cylinder(tree, "Trunk", 0.006 * scale, 0.008 * scale, 0.05 * scale, Vector3.ZERO, Color(0.45, 0.32, 0.22))
	_cylinder(tree, "Leaves", 0.0, 0.035 * scale, 0.09 * scale, Vector3(0, 0.035 * scale, 0), Color(0.24, 0.52, 0.3))


func _cone(parent: Node, name: String, at: Vector2) -> void:
	_cylinder(parent, name, 0.002, 0.012, 0.035, Vector3(at.x, FLOOR_TOP, at.y), Color(0.98, 0.5, 0.18))


func _raise_flag() -> StageLevel:
	var root: StageLevel = _level("RaiseFlagLevel", Color(0.34, 0.47, 0.29), AABB(Vector3(-0.1, FLOOR_TOP, -0.12), Vector3(0.3, 0.16, 0.24)))
	var props: Node = root.get_node("Props")
	var markers: Node = root.get_node("Markers")
	# Stone courtyard under the arm and board.
	var yard := _cylinder(props, "Courtyard", 0.2, 0.2, 0.0008, Vector3(0.05, SURFACE - 0.0004, 0), Color(0.5, 0.48, 0.45))
	yard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Castle wall behind the robot with two towers.
	var stone := Color(0.5, 0.48, 0.46)
	_box(props, "CastleWall", Vector3(0.5, 0.1, 0.03), Vector3(0.05, FLOOR_TOP + 0.05, -0.24), stone)
	for index: int in 6:
		_box(props, "Crenel%d" % index, Vector3(0.04, 0.025, 0.03), Vector3(-0.15 + 0.08 * index, FLOOR_TOP + 0.1125, -0.24), stone)
	for side: float in [-0.21, 0.31]:
		_cylinder(props, "Tower%s" % ("Left" if side < 0 else "Right"), 0.045, 0.05, 0.16, Vector3(side, FLOOR_TOP, -0.24), stone.darkened(0.08))
		_cylinder(props, "Roof%s" % ("Left" if side < 0 else "Right"), 0.0, 0.06, 0.06, Vector3(side, FLOOR_TOP + 0.16, -0.24), Color(0.55, 0.25, 0.2))
	# Goal gate: the arm tip (x = 0.0165) must reach 15.5 cm. Posts sit outside the swing plane.
	var goal := Color(0.3, 0.92, 0.55)
	# The arm starts lying toward +Z (tip at z = 0.075), so the posts stand beyond its reach.
	for z: float in [-0.11, 0.11]:
		_cylinder(markers, "GoalPost%s" % ("Back" if z < 0 else "Front"), 0.003, 0.003, 0.16, Vector3(0.0165, FLOOR_TOP, z), Color(0.9, 0.92, 0.95))
	_box(markers, "GoalLine", Vector3(0.004, 0.004, 0.22), Vector3(0.0165, 0.155, 0), Color(goal.r, goal.g, goal.b, 0.85), true)
	_box(markers, "GoalBand", Vector3(0.001, 0.02, 0.22), Vector3(0.0165, 0.165, 0), Color(goal.r, goal.g, goal.b, 0.18), true)
	for index: int in 4:
		_tree(props, "Tree%d" % index, [Vector2(-0.35, 0.1), Vector2(0.42, -0.05), Vector2(-0.3, -0.35), Vector2(0.45, 0.25)][index], [1.2, 1.0, 1.5, 0.9][index])
	return root


func _road(root: StageLevel, to_x: float) -> void:
	var props: Node = root.get_node("Props")
	_paint(props, "Road", -0.35, to_x, 0.16, Color(0.24, 0.26, 0.29))
	for x: float in range(-30, int(to_x * 100.0), 12):
		_paint(props, "Lane%d" % x, x * 0.01, x * 0.01 + 0.05, 0.004, Color(0.95, 0.85, 0.4), 1)
	for index: int in int((to_x + 0.3) / 0.15) + 1:
		var x: float = -0.3 + 0.15 * index
		_cone(props, "ConeLeft%d" % index, Vector2(x, -0.2))
		_cone(props, "ConeRight%d" % index, Vector2(x, 0.2))
	_paint(root.get_node("Markers"), "StartLine", -0.1, -0.09, 0.16, Color(0.96, 0.96, 0.96), 1)


func _finish_line() -> StageLevel:
	var root: StageLevel = _level("FinishLineLevel", Color(0.42, 0.5, 0.4), AABB(Vector3(-0.15, FLOOR_TOP, -0.2), Vector3(0.8, 0.2, 0.4)), -35.0, 32.0)
	_road(root, 0.9)
	var markers: Node = root.get_node("Markers")
	# Checkered finish centered on the rule threshold x = 0.5 (chassis origin).
	for column: int in 2:
		for row: int in 8:
			var white: bool = (column + row) % 2 == 0
			var z: float = -0.16 + 0.04 * row + 0.02
			var tile := _box(markers, "Checker%d_%d" % [column, row], Vector3(0.02, 0.0008, 0.04), Vector3(0.49 + 0.02 * column, SURFACE + 0.0008, z), Color.WHITE if white else Color(0.08, 0.08, 0.1))
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for z: float in [-0.22, 0.22]:
		_cylinder(markers, "ArchPost%s" % ("Left" if z < 0 else "Right"), 0.006, 0.006, 0.22, Vector3(0.5, FLOOR_TOP, z), Color(0.92, 0.92, 0.94))
	_box(markers, "ArchBanner", Vector3(0.012, 0.04, 0.46), Vector3(0.5, FLOOR_TOP + 0.2, 0), Color(0.95, 0.3, 0.25))
	return root


func _wall_brake() -> StageLevel:
	var root: StageLevel = _level("WallBrakeLevel", Color(0.52, 0.45, 0.36), AABB(Vector3(-0.15, FLOOR_TOP, -0.3), Vector3(1.0, 0.2, 0.6)), -35.0, 32.0)
	_road(root, 0.79)
	var markers: Node = root.get_node("Markers")
	# stage_wall is a graph part at x = 0.8 (face at 0.79). The sonar front must end 5-10 cm from it.
	_paint(markers, "StopZone", 0.69, 0.74, 0.16, Color(0.98, 0.82, 0.2), 2)
	_paint(markers, "DangerZone", 0.74, 0.79, 0.16, Color(0.9, 0.3, 0.25), 2)
	var props: Node = root.get_node("Props")
	for index: int in 3:
		_box(props, "Crate%d" % index, Vector3(0.05, 0.05, 0.05), Vector3(0.86, FLOOR_TOP + 0.025 + 0.05 * (index / 2), -0.26 + 0.06 * (index % 2)), Color(0.6, 0.45, 0.28))
	return root
