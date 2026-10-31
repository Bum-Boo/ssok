extends SceneTree

## Review repro: environment stock added from the real tray is anchored in Run mode.
## Measure the gap between each anchored object's lowest point and the workbench below.
const IDS: Array[String] = ["kit_env_ramp_10", "kit_env_ramp_20", "kit_env_cup", "kit_env_line_straight"]
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var inventory: Dictionary = {}
	for button: Button in main.part_buttons:
		inventory[String((button.get_meta("part_definition") as PartDef).id)] = button
	for id: String in IDS:
		inventory[id].pressed.emit()
	await process_frame
	var hardware := RunMode.new()
	main.add_child(hardware)
	hardware.build(main.assembly.graph)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = hardware.get_world_3d().direct_space_state
	for index: int in main.assembly.graph.parts.size():
		var definition: PartDef = main.assembly.graph.parts[index].part_def
		var pose: Transform3D = hardware.part_global_transform(index)
		var bottom: float = (pose * definition.mesh.get_aabb()).position.y
		var origin: Vector3 = Vector3(pose.origin.x, bottom - 0.0001, pose.origin.z)
		var ray := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 1.0)
		ray.exclude = hardware.robot_rids(index)
		ray.collision_mask = 1
		var hit: Dictionary = space.intersect_ray(ray)
		var gap: float = bottom - (hit.position.y if not hit.is_empty() else -INF)
		print("TRAY %s frozen=%s bottom_y=%.4f floor_y=%.4f gap_mm=%.1f" % [definition.id, hardware.bodies[index].freeze, bottom, hit.position.y if not hit.is_empty() else NAN, gap * 1000.0])
		_check(hardware.bodies[index].freeze, "tray environment stock is anchored: " + String(definition.id))
		_check(not hit.is_empty() and gap < 0.002, "anchored tray environment stock rests on workbench: " + String(definition.id))
	hardware.teardown()
	main.free()
	await process_frame
	print("tray_environment_floor_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
