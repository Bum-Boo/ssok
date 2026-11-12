class_name WorkshopFraming
extends RefCounted

## Stage presentation interests. Ground and decorative scenery never dilute the subject.
const INTERESTS: Dictionary = {
	"raise-flag": ["Markers"],
	"finish-line": ["Markers"],
	"wall-brake": ["Markers"],
}


static func interest_bounds(graph: ConnectionGraph, level: Node3D, level_id: String) -> AABB:
	var bounds := AABB()
	var found: bool = false
	for part: Dictionary in graph.parts:
		var part_bounds: AABB = part.transform * part.part_def.mesh.get_aabb()
		bounds = bounds.merge(part_bounds) if found else part_bounds
		found = true
	if level != null:
		for path: String in INTERESTS.get(level_id, []):
			var root: Node = level.get_node(path)
			for visual: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
				var marker_bounds: AABB = visual.global_transform * visual.mesh.get_aabb()
				bounds = bounds.merge(marker_bounds) if found else marker_bounds
				found = true
	return bounds if found else AABB(Vector3(-0.08, 0.05, -0.08), Vector3(0.16, 0.12, 0.16))


static func goal_anchor(level: Node3D, level_id: String) -> Vector3:
	var names: Dictionary = {"raise-flag": "GoalLine", "finish-line": "ArchPostRight", "wall-brake": "StopZone"}
	var marker: MeshInstance3D = level.get_node("Markers/" + names[level_id])
	var bounds: AABB = marker.mesh.get_aabb()
	return marker.global_transform * Vector3(bounds.get_center().x, bounds.get_center().y, bounds.end.z)
