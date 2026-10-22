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


func _settle() -> void:
	for index: int in 8:
		await process_frame


func _check_framing(main: Node3D, context: String) -> void:
	var bounds: AABB = main._workshop_bounds()
	var area: Rect2 = main._camera_framing_rect()
	var camera: Camera3D = main.get_node("Camera3D")
	var projected := Rect2(camera.unproject_position(bounds.position), Vector2.ZERO)
	for index: int in 8:
		var point: Vector3 = bounds.get_endpoint(index)
		_check(not camera.is_position_behind(point) and area.has_point(camera.unproject_position(point)), context + " interest endpoint %d inside available scene" % index)
		projected = projected.expand(camera.unproject_position(point))
	_check(maxf(projected.size.x / area.size.x, projected.size.y / area.size.y) >= 0.55, context + " subject fills available scene")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	for level: Dictionary in StageLevels.all():
		var main: Node3D = load("res://scenes/main.tscn").instantiate()
		main.session = {"mode": "stage", "level": level}
		root.add_child(main)
		await _settle()
		_check_framing(main, level.id + " entry")
		main.stage_hud.program_requested.emit()
		await _settle()
		_check_framing(main, level.id + " panel")
		main.navigation._orbit(Vector2(20, 10))
		main.navigation.user_navigated.emit()
		var pose: Transform3D = main.get_node("Camera3D").global_transform
		main.stage_hud.program_requested.emit()
		await _settle()
		_check(main.get_node("Camera3D").global_transform == pose, "manual camera survives panel changes")
		main._reset_attempt()
		await _settle()
		_check_framing(main, level.id + " retry")
		main.free()
		await _settle()
	var lab: Node3D = load("res://scenes/main.tscn").instantiate()
	lab.session = {"mode": "lab"}
	root.add_child(lab)
	await _settle()
	_check_framing(lab, "empty Lab")
	lab._on_microbit_arm_pressed()
	await _settle()
	_check_framing(lab, "Lab assembly")
	lab.free()
	print("workshop_presentation_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
