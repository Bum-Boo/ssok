extends SceneTree

const PARTS: String = "res://assets/construction_kit/parts/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.physics_ticks_per_second = 60
	var floor := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5, 0.02, 5)
	collider.shape = box
	floor.add_child(collider)
	root.add_child(floor)
	floor.position.y = -0.01
	for speed: int in [20, 35, 50, 80]:
		for shift: float in [-0.02, 0.0, 0.02]:
			for lateral: float in [0.0, 0.015]:
				for early: bool in [true, false]:
					await _trial(speed, shift, lateral, early)
	quit(0)


func _trial(speed: int, shift: float, lateral: float, early: bool) -> void:
	var graph: ConnectionGraph = RobotCarPreset.build()
	graph.parts.append({"part_def": load(PARTS + "kit_env_ball.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(0.61 + shift, 0.022, lateral))})
	graph.parts.append({"part_def": load(PARTS + "kit_env_cup.tres"), "transform": Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0.8, 0.080, 0))})
	for part: Dictionary in graph.parts.slice(0, 9):
		part.transform.origin.x += 0.46 + shift
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	for tick: int in 30:
		await physics_frame
	hardware.motor_on_pin(0).forward(speed)
	hardware.motor_on_pin(12).forward(speed)
	var peak: int = 0
	var stopped_at: int = -1
	for tick: int in 120:
		await physics_frame
		peak = maxi(peak, hardware.cup_object_count())
		if early and hardware.cup_object_count() == 1 and hardware.part_global_transform(9).origin.x >= 0.70:
			stopped_at = tick
			break
	hardware.stop_motors()
	for tick: int in 240:
		await physics_frame
	print("TRIAL speed=%d shift=%.3f lateral=%.3f early=%s stop_tick=%d peak=%d settled=%d ball=%s chassis_x=%.3f" % [speed, shift, lateral, early, stopped_at, peak, hardware.cup_object_count(), hardware.part_global_transform(9).origin, hardware.part_global_transform(0).origin.x])
	hardware.free()
	await process_frame
