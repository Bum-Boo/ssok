extends RefCounted

# Procedural hardware meshes can differ by a few ULPs across libm implementations.
# A normal can also land in an adjacent bin when Godot octahedrally packs it.
const POSITION_TOLERANCE_M: float = 0.00001
const NORMAL_TOLERANCE: float = 0.0001


static func surface_matches(mesh: ArrayMesh, expected: ArrayMesh, index: int) -> bool:
	if mesh.surface_get_primitive_type(index) != expected.surface_get_primitive_type(index) \
			or mesh.surface_get_format(index) != expected.surface_get_format(index):
		return false
	var actual: Array = mesh.surface_get_arrays(index)
	var generated: Array = expected.surface_get_arrays(index)
	for slot: int in Mesh.ARRAY_MAX:
		match slot:
			Mesh.ARRAY_VERTEX:
				if not _vectors_match(actual[slot], generated[slot], POSITION_TOLERANCE_M):
					return false
			Mesh.ARRAY_NORMAL:
				if not _vectors_match(actual[slot], generated[slot], NORMAL_TOLERANCE):
					return false
			_:
				if actual[slot] != generated[slot]:
					return false
	return true


static func _vectors_match(actual: Variant, expected: Variant, tolerance: float) -> bool:
	if actual == null or expected == null:
		return actual == expected
	if actual.size() != expected.size():
		return false
	var limit: float = tolerance * tolerance
	for index: int in actual.size():
		if not (actual[index] as Vector3).distance_squared_to(expected[index]) <= limit:
			return false
	return true
