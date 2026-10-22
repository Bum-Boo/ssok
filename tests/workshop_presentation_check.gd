extends SceneTree

var checks: int = 0
var _prefs: InterfacePreferences
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
	_prefs = root.get_node("Preferences")
	root.size = Vector2i(1440, 900)
	for level: Dictionary in StageLevels.all():
		var main: Node3D = load("res://scenes/main.tscn").instantiate()
		main.session = {"mode": "stage", "level": level}
		root.add_child(main)
		await _settle()
		_check_framing(main, level.id + " entry")
		var scene_env: Environment = main._workbench_environment
		var sky: ProceduralSkyMaterial = scene_env.sky.sky_material
		var ground: MeshInstance3D = main._level.get_node("Ground/WorkbenchMat")
		var grid: MeshInstance3D = main._level.get_node("Ground/MatGrid")
		var edge: MeshInstance3D = main._level.get_node("Ground/WorkbenchEdge")
		_check(edge.mesh.get_aabb().size.x > ground.mesh.get_aabb().size.x and edge.mesh.get_aabb().size.z > ground.mesh.get_aabb().size.z, "rim exposes a finite mat boundary")
		_check(edge.position.y + edge.mesh.get_aabb().end.y < ground.position.y + ground.mesh.get_aabb().end.y, "rim remains below the work surface")
		_check(main._level.get_node("Ground").find_children("*", "CollisionShape3D", true, false).size() == 1, "decoration adds no collision shape")
		_check(not main._level.get_node("Ground/Mesh").visible, "outside the finite mat the original ground is hidden")

		_prefs.values.appearance = "dark"
		_prefs.changed.emit()
		_check(sky.sky_top_color.get_luminance() < 0.1 and sky.ground_bottom_color.get_luminance() < 0.1, "dark scene background switches immediately")
		_check(ground.material_override.albedo_color.get_luminance() < 0.3 and grid.material_override.albedo_color.get_luminance() < 0.4, "dark mat and grid switch immediately")
		_check(scene_env.fog_light_color.get_luminance() < 0.2, "dark fog color switches immediately")
		_prefs.values.appearance = "light"
		_prefs.changed.emit()
		_check(sky.sky_top_color == Color(0.78, 0.88, 0.91) and ground.material_override.albedo_color == Color("c2d8cd"), "light background and mat retain original colors")

		for locale: String in ["en", "ko", "ja", "zh_CN"]:
			SsokLocale.select_locale(locale, false)
			for dimensions: Vector2i in [Vector2i(1440, 900), Vector2i(1152, 648)]:
				root.size = dimensions
				await _settle()
				var strip: Rect2 = main.stage_hud.goal_card.get_global_rect()
				_check(strip.size.y <= 100, "two-row strip " + locale + str(dimensions) + " actual=" + str(strip.size))
				_check(main._camera_framing_rect().encloses(main.goal_display.card.get_global_rect()), "screen label fits " + locale + str(dimensions))
				for chip: Button in main.stage_hud.chips:
					_check(chip.get_global_rect().position.y == main.stage_hud.chips[0].get_global_rect().position.y, "four chips share a row")
					_check(not chip.clip_text and chip.size.x >= chip.get_combined_minimum_size().x, "pill icon/name/check remain visible " + locale)
				var goal: Label = main.stage_hud.find_child("GoalSentence", true, false)
				_check(goal.get_theme_font_size("font_size") == 28 and goal.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS and tr(goal.tooltip_text) == tr(level.goal), "goal keeps title size and full tooltip " + locale)
				var hint: Label = main.stage_hud.hint_label
				_check(hint.get_theme_font("font").get_string_size(hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint.get_theme_font_size("font_size")).x <= hint.size.x, "current hint fits without trimming " + locale)
		root.size = Vector2i(1440, 900)
		await _settle()
		var display: StageGoalDisplay = main.goal_display
		_check(display.label is Label and display.get_parent() == main._ui_root, "goal is on UI layer")
		_check(main._camera_framing_rect().encloses(display.card.get_global_rect()), "screen label fits available area")
		var anchor: Vector3 = display.anchor
		for point: Vector3 in [Vector3(100, 0, 0), Vector3(-100, 0, 0), Vector3(0, 100, 0), Vector3(0, -100, 0), main.get_node("Camera3D").global_position + main.get_node("Camera3D").global_basis.z, main.get_node("Camera3D").global_position, main.get_node("Camera3D").global_position + main.get_node("Camera3D").global_basis.x]:
			display.anchor = point
			await _settle()
			_check(main._camera_framing_rect().encloses(display.card.get_global_rect()), "offscreen label stays on edge")
			_check(main._camera_framing_rect().has_point(display.projected_anchor), "leader remains in available area")
			var safe: Rect2 = main._camera_framing_rect().grow(-8)
			_check(is_equal_approx(display.projected_anchor.x, safe.position.x) or is_equal_approx(display.projected_anchor.x, safe.end.x) or is_equal_approx(display.projected_anchor.y, safe.position.y) or is_equal_approx(display.projected_anchor.y, safe.end.y), "offscreen anchor is pinned to an edge")
		display.anchor = anchor

		main.stage_hud.program_requested.emit()
		await _settle()
		_check_framing(main, level.id + " panel")
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_MIDDLE
		press.pressed = true
		main.navigation._unhandled_input(press)
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(20, 10)
		main.navigation._unhandled_input(motion)
		press.pressed = false
		main.navigation._input(press)
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
