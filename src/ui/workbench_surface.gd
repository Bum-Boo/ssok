class_name WorkbenchSurface
extends RefCounted

## Visual mat above the existing collision surface; physics dimensions remain untouched.
static func decorate(ground: MeshInstance3D) -> void:
	ground.visible = false
	var mat := MeshInstance3D.new()
	mat.name = "WorkbenchMat"
	var shape := BoxMesh.new()
	shape.size = Vector3(1.8, 0.018, 1.4)
	mat.mesh = shape
	mat.position = Vector3(0.25, 0.041, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c2d8cd")
	material.roughness = 0.9
	mat.material_override = material
	ground.get_parent().add_child(mat)
	# A lowered rim exposes thickness without lifting the graph or adding collision shapes.
	var edge := MeshInstance3D.new()
	edge.name = "WorkbenchEdge"
	var rim := BoxMesh.new()
	rim.size = shape.size + Vector3(0.028, 0.008, 0.028)
	edge.mesh = rim
	edge.position = mat.position - Vector3(0, 0.009, 0)
	var border := StandardMaterial3D.new()
	border.roughness = 0.95
	edge.material_override = border
	ground.get_parent().add_child(edge)
	var grid := ImmediateMesh.new()
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	for index: int in 37:
		var x: float = -0.65 + index * 0.05
		grid.surface_add_vertex(Vector3(x, 0.0502, -0.7))
		grid.surface_add_vertex(Vector3(x, 0.0502, 0.7))
	for index: int in 29:
		var z: float = -0.7 + index * 0.05
		grid.surface_add_vertex(Vector3(-0.65, 0.0502, z))
		grid.surface_add_vertex(Vector3(1.15, 0.0502, z))
	grid.surface_end()
	var lines := MeshInstance3D.new()
	lines.name = "MatGrid"
	lines.mesh = grid
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color("9ab9ac")
	lines.material_override = ink
	ground.get_parent().add_child(lines)


static func apply_theme(root: Node, dark: bool) -> void:
	for visual: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if visual.name == "WorkbenchMat":
			visual.material_override.albedo_color = Color("293e3b" if dark else "c2d8cd")
		elif visual.name == "WorkbenchEdge":
			visual.material_override.albedo_color = Color("162a28" if dark else "6e8d80")
		elif visual.name == "MatGrid":
			visual.material_override.albedo_color = Color("48625c" if dark else "9ab9ac")


static func apply_environment(env: Environment, dark: bool) -> void:
	var sky: ProceduralSkyMaterial = env.sky.sky_material
	sky.sky_top_color = Color("101923") if dark else Color(0.78, 0.88, 0.91)
	sky.sky_horizon_color = Color("253341") if dark else Color(0.84, 0.89, 0.95)
	sky.ground_horizon_color = sky.sky_horizon_color
	sky.ground_bottom_color = Color("101818") if dark else Color(0.78, 0.84, 0.84)
	env.fog_light_color = Color("253341") if dark else Color(0.84, 0.89, 0.95)
