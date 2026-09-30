extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var starter: ConnectionGraph = BipedPreset.build()
	var original: ConnectionGraph = BipedPreset.build()
	for index: int in original.parts.size():
		if original.parts[index].part_def.id == &"arduino_uno":
			var transform: Transform3D = original.parts[index].transform
			transform.origin.x = 0.0
			original.parts[index].transform = transform
	var original_snapshot: Dictionary = MotionSnapshot.encode(original)
	var restored: ConnectionGraph = MotionSnapshot.decode(original_snapshot)
	_check(MotionSnapshot.fingerprint(MotionSnapshot.encode(restored)) == MotionSnapshot.fingerprint(original_snapshot), "old saved layouts must not be silently relocated")
	_check(MotionSnapshot.fingerprint(MotionSnapshot.encode(starter)) != MotionSnapshot.fingerprint(original_snapshot), "layout changes must invalidate old graph-bound evidence for the new starter")
	await _sweep_feet(starter, false)
	await _sweep_feet(restored, true)
	print("biped_board_clearance_check: %d failures" % _failures)
	quit(1 if _failures else 0)


func _sweep_feet(graph: ConnectionGraph, expect_obstacle: bool) -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(2, 2)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var hardware := RunMode.new()
	viewport.add_child(hardware)
	hardware.build(graph)
	var ignored: Array[RID] = []
	var feet: Array[Dictionary] = []
	var board_count: int = 0
	for index: int in graph.parts.size():
		var body: RigidBody3D = hardware.bodies[index]
		var definition: PartDef = graph.parts[index].part_def
		if definition.id == &"arduino_uno":
			board_count += 1
			_check(body.freeze and body.collision_layer != 0, "standalone board remains a stationary physical obstacle")
			continue
		ignored.append(body.get_rid())
		if definition.id == &"foot":
			for child: Node in body.get_children():
				if child is CollisionShape3D:
					feet.append({"shape": child.shape, "transform": child.global_transform})
	_check(board_count == 1 and feet.size() == 2, "exercise the real board and both actual foot colliders")
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = viewport.find_world_3d().direct_space_state
	for foot: Dictionary in feet:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = foot.shape
		query.transform = foot.transform
		query.motion = Vector3(0.0, 0.0, -0.5)
		query.margin = 0.0001
		query.exclude = ignored
		var travel: PackedFloat32Array = space.cast_motion(query)
		_check(travel.size() == 2, "physics returns safe and unsafe motion fractions")
		if travel.size() != 2:
			continue
		_check(travel[0] < 0.2 if expect_obstacle else is_equal_approx(travel[0], 1.0), "original placement obstructs the backward lane; the new layout clears it")
		print("BOARD_LANE original=%s safe_fraction=%.6f" % [expect_obstacle, travel[0]])
	viewport.free()
	await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
