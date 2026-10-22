extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + message)


func _collisions(node: Node) -> String:
	var shapes: Array = []
	for shape: CollisionShape3D in node.find_children("*", "CollisionShape3D", true, false):
		shapes.append([str(node.get_path_to(shape)), shape.transform, shape.shape.get("size")])
	return var_to_str(shapes)


func _run() -> void:
	var light := DirectionalLight3D.new()
	print("road shadow diagnostic: bias=%s normal_bias=%s max_distance=%s map_size=%s" % [light.shadow_bias, light.shadow_normal_bias, light.directional_shadow_max_distance, ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")])
	light.free()
	for id: String in ["finish_line", "wall_brake"]:
		var level: Node3D = load("res://stages/" + id + "/level.tscn").instantiate()
		root.add_child(level)
		var before: String = _collisions(level)
		var road: MeshInstance3D = level.get_node("Props/Road")
		var normals: PackedVector3Array = road.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var upward: int = 0
		for normal: Vector3 in normals:
			_check(normal.is_finite() and is_equal_approx(normal.length(), 1), id + " finite unit road normals")
			if normal.dot(Vector3.UP) > 0.99:
				upward += 1
		_check(upward == 4, id + " BoxMesh top normals face up")
		WorkbenchSurface.decorate(level.get_node("Ground/Mesh"))
		var mat: MeshInstance3D = level.get_node("Ground/WorkbenchMat")
		var road_top: float = road.position.y + road.mesh.get_aabb().end.y
		var mat_top: float = mat.position.y + mat.mesh.get_aabb().end.y
		print("%s: mat_top=%.7f road_top=%.7f gap=%.7f road_cast=%d receive_disabled=%s" % [id, mat_top, road_top, road_top - mat_top, road.cast_shadow, road.material_override.disable_receive_shadows])
		_check(road_top > mat_top + 0.0005, id + " road surface is separated from mat")
		_check(road.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, id + " road never casts a self shadow")
		for visual: MeshInstance3D in level.find_children("*", "MeshInstance3D", true, false):
			if visual.mesh is BoxMesh and visual.mesh.size.y < 0.001:
				_check(visual.material_override.disable_receive_shadows, id + str(visual.name) + " painted surfaces cannot receive shadow bands")
		_check(_collisions(level) == before, id + " decorative correction preserves every collision transform and size")
		level.free()
	print("workshop_road_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
