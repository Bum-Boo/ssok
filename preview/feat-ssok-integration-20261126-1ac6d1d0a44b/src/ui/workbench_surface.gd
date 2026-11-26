class_name WorkbenchSurface
extends RefCounted

## Cutting mat on a desk above the existing collision surface; physics dimensions remain untouched.
## The mat, its rim and the desk are decoration only (ADR 0031, 0045).

const MAT_SIZE: Vector3 = Vector3(1.8, 0.018, 1.4)
const MAT_POSITION: Vector3 = Vector3(0.25, 0.041, 0)
const DESK_SIZE: float = 7.0
const MAT_SHADER: Shader = preload("res://assets/shaders/cutting_mat.gdshader")
const DESK_SHADER: Shader = preload("res://assets/shaders/workbench_desk.gdshader")


static func decorate(ground: MeshInstance3D) -> void:
	ground.visible = false
	var parent: Node3D = ground.get_parent()
	# The shaders work in world space; levels keep their ground at the origin, but follow it anyway.
	var anchor: Transform3D = parent.global_transform if parent.is_inside_tree() else parent.transform
	var center: Vector3 = anchor * MAT_POSITION
	var mat := MeshInstance3D.new()
	mat.name = "WorkbenchMat"
	var shape := BoxMesh.new()
	shape.size = MAT_SIZE
	mat.mesh = shape
	mat.position = MAT_POSITION
	var surface := ShaderMaterial.new()
	surface.shader = MAT_SHADER
	surface.set_shader_parameter("mat_center", Vector2(center.x, center.z))
	surface.set_shader_parameter("mat_half_size", Vector2(MAT_SIZE.x, MAT_SIZE.z) * 0.5)
	mat.material_override = surface
	parent.add_child(mat)
	# A lowered rim exposes thickness without lifting the graph or adding collision shapes.
	var edge := MeshInstance3D.new()
	edge.name = "WorkbenchEdge"
	var rim := BoxMesh.new()
	rim.size = shape.size + Vector3(0.028, 0.008, 0.028)
	edge.mesh = rim
	edge.position = mat.position - Vector3(0, 0.009, 0)
	var border := StandardMaterial3D.new()
	border.roughness = 0.9
	edge.material_override = border
	parent.add_child(edge)
	# The desk sits at the rim's base and dissolves into the backdrop; objects on the mat never touch it.
	var desk := MeshInstance3D.new()
	desk.name = "WorkbenchDesk"
	var plane := PlaneMesh.new()
	plane.size = Vector2(DESK_SIZE, DESK_SIZE)
	desk.mesh = plane
	desk.position = Vector3(MAT_POSITION.x, edge.position.y - rim.size.y * 0.5, MAT_POSITION.z)
	desk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var top := ShaderMaterial.new()
	top.shader = DESK_SHADER
	top.render_priority = Material.RENDER_PRIORITY_MIN
	top.set_shader_parameter("fade_center", Vector2(center.x, center.z))
	desk.material_override = top
	parent.add_child(desk)
	_stabilize_road_paint(parent.get_parent())


static func _stabilize_road_paint(level: Node) -> void:
	if not level.has_node("Props/Road"):
		return
	# Submillimeter paint sits on a shadow-casting mat. Keep lighting, but exclude
	# these instructional surfaces from shadow-map comparisons and their bias artifacts.
	for branch: String in ["Props", "Markers"]:
		for visual: MeshInstance3D in level.get_node(branch).find_children("*", "MeshInstance3D", true, false):
			if not visual.mesh is BoxMesh or visual.mesh.size.y >= 0.001:
				continue
			var paint: StandardMaterial3D = visual.material_override.duplicate()
			paint.disable_receive_shadows = true
			visual.material_override = paint


static func apply_theme(root: Node, dark: bool) -> void:
	var values: Dictionary = WorkshopLook.palette(dark)
	for visual: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if visual.name == "WorkbenchMat" and visual.material_override is ShaderMaterial:
			var surface: ShaderMaterial = visual.material_override
			surface.set_shader_parameter("mat_color", values.mat)
			surface.set_shader_parameter("band_color", values.mat_band)
			surface.set_shader_parameter("side_color", values.mat_side)
			surface.set_shader_parameter("minor_color", values.mat_minor)
			surface.set_shader_parameter("major_color", values.mat_major)
			surface.set_shader_parameter("minor_strength", values.mat_minor_strength)
			surface.set_shader_parameter("major_strength", values.mat_major_strength)
		elif visual.name == "WorkbenchEdge":
			visual.material_override.albedo_color = values.mat_edge
		elif visual.name == "WorkbenchDesk" and visual.material_override is ShaderMaterial:
			visual.material_override.set_shader_parameter("desk_color", values.desk)
