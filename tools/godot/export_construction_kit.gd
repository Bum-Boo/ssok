extends SceneTree


func _initialize() -> void:
	var assemblies: Array[Dictionary] = []
	for item: Array in [["humanoid", "Construction-kit humanoid", ConstructionKitHumanoidPreset.build()], ["bridge", "Construction-kit bridge", ConstructionKitHumanoidPreset.build_bridge()]]:
		var graph: ConnectionGraph = item[2]
		var parts: Array[Dictionary] = []
		for index: int in graph.parts.size():
			var entry: Dictionary = graph.parts[index]
			var transform: Transform3D = entry.transform
			parts.append({"catalog_id": String(entry.part_def.id), "instance_id": index,
				"position": _vector(transform.origin), "basis": [_vector(transform.basis.x), _vector(transform.basis.y), _vector(transform.basis.z)]})
		assemblies.append({"id": item[0], "name": item[1], "parts": parts, "links": graph.links})
		print("export_construction_kit: %s parts=%d links=%d" % [item[0], parts.size(), graph.links.size()])
	var file := FileAccess.open("res://assets/construction_kit/assemblies.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "source": "ConnectionGraph", "assemblies": assemblies}, "\t"))
	file.close()
	quit()


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
