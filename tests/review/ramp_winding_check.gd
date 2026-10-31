extends SceneTree

## Review audit: generated ramp wedge triangles face outward, so GL culling shows them.
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	for id: String in ["kit_env_ramp_10", "kit_env_ramp_20"]:
		var mesh: ArrayMesh = (load("res://assets/construction_kit/parts/%s.tres" % id) as PartDef).mesh as ArrayMesh
		var faces: PackedVector3Array = mesh.get_faces()
		# The AABB centre lies on a wedge slope; the vertex mean is strictly interior.
		var center: Vector3 = Vector3.ZERO
		for vertex: Vector3 in faces:
			center += vertex / faces.size()
		var arrays: Array = mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var outward: int = 0
		var stored: int = 0
		for index: int in range(0, faces.size(), 3):
			# Godot front faces are clockwise; Plane(a, b, c) follows the same convention.
			var plane := Plane(faces[index], faces[index + 1], faces[index + 2])
			var centroid: Vector3 = (faces[index] + faces[index + 1] + faces[index + 2]) / 3.0
			outward += int(plane.normal.dot(centroid - center) > 0.0)
		for normal: Vector3 in normals:
			stored += int(normal.length() > 0.5)
		print("WINDING %s triangles=%d outward_front_faces=%d nonzero_normals=%d/%d" % [id, faces.size() / 3, outward, stored, normals.size()])
		_check(outward == faces.size() / 3, id + " all front faces point outward")
	print("ramp_winding_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
