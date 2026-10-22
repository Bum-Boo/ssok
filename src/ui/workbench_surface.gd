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
