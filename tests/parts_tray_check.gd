extends SceneTree

const EXPECTED: Array = [
	["kit_beam_60", "kit_beam_100", "kit_beam_140", "kit_beam_180", "kit_beam_240", "kit_beam_260", "kit_plate_60_40", "kit_plate_60_60", "kit_plate_80_60", "kit_plate_120_80", "kit_plate_160_60", "kit_plate_220_120", "kit_angle_bracket", "kit_u_bracket_large", "kit_u_bracket_small", "kit_spacer_20", "kit_coupler_8", "kit_rubber_pad", "kit_weight_100", "kit_weight_300"],
	["kit_motor_12", "kit_motor_35", "tt_motor", "servo", "kit_passive_hinge", "kit_gear_2", "kit_gear_3", "kit_axle_40", "kit_wheel_40", "kit_wheel_90", "wheel_65", "ball_caster"],
	["microbit", "arduino_uno", "motor_driver", "tb6612_driver", "kit_led"],
	["hc_sr04", "kit_line_sensor", "kit_contact_button"],
	["kit_env_ramp_10", "kit_env_ramp_20", "kit_env_ball", "kit_env_cup", "kit_env_line_straight", "kit_env_line_corner", "stage_wall", "flag"],
]
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(PartTray.TABS == ["All", "Structure", "Motion", "Electronics", "Sensors", "Environment"], "specified tab order")
	var expected_all: Array[String] = []
	for group: Array in EXPECTED:
		for id: String in group:
			expected_all.append(id)
	var catalog: Dictionary = MotionSnapshot._catalog()
	for id: String in expected_all:
		_check(catalog.has(id), "allowed part remains loadable: " + id)
		if not catalog.has(id):
			continue
		var definition: PartDef = catalog[id]
		if id.begins_with("kit_env_") or id == "stage_wall":
			continue # Environment props are free-standing rather than robot mechanisms.
		var mountable: bool = false
		for port: Port in definition.ports:
			if port.kind == Port.Kind.MECH and port.tag in [&"kit_m4", &"kit_axle_8", &"kit_shaft_8", &"wheel_hub"]:
				mountable = true
		_check(mountable, "robot part has a kit hole or shaft interface: " + id)
	var legacy: ConnectionGraph = RobotCarPreset.build()
	var encoded: Dictionary = MotionSnapshot.encode(legacy)
	var restored: ConnectionGraph = MotionSnapshot.decode(encoded)
	_check(restored != null and MotionSnapshot.fingerprint(encoded) == MotionSnapshot.fingerprint(MotionSnapshot.encode(restored)), "legacy car graph round trips despite hidden chassis")
	_check(catalog.has("car_chassis") and catalog.has("arm_link") and catalog.has("kit_controller"), "hidden definitions retained in saved-file catalog")
	var lab: Node3D = await _open({"mode": "lab"})
	_verify_tray(lab, expected_all, "Lab")
	await _visuals(lab)
	lab.free()
	await process_frame
	for level: Dictionary in StageLevels.all():
		_verify_answer_parts(level)
		var main: Node3D = await _open({"mode": "stage", "level": level})
		_verify_tray(main, expected_all, level.id)
		# A stage filter may restrict the allowlist but must never expose a legacy id.
		main.session.level.parts = ["car_chassis", "kit_beam_60", "servo"]
		main.part_category.select(0)
		main._filter_parts()
		_check(_visible_ids(main) == ["kit_beam_60", "servo"], level.id + " restricted tray intersects allowlist")
		main.part_search.text = "servo"
		main._filter_parts()
		_check(_visible_ids(main) == ["servo"], level.id + " search preserves stage restriction")
		main.part_search.text = ""
		main._filter_parts()
		_check(_visible_ids(main) == ["kit_beam_60", "servo"], level.id + " clearing search preserves stage restriction")
		main.free()
		await process_frame
	print("parts_tray_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _verify_answer_parts(level: Dictionary) -> void:
	var stage: Dictionary = StageLevels.stage_definition(level)
	var answer: ConnectionGraph = ProjectStore.graph_from(stage.author_solution)
	var hidden: Array[String] = []
	for part: Dictionary in answer.parts:
		var id: String = String(part.part_def.id)
		if id not in PartTray.ids():
			hidden.append(id)
	_check(hidden.is_empty(), level.id + " answer contains only curated tray parts")


func _open(session: Dictionary) -> Node3D:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.session = session
	root.add_child(main)
	for frame: int in 5:
		await process_frame
	return main


func _verify_tray(main: Node3D, expected: Array[String], context: String) -> void:
	var actual: Array[String] = []
	for button: Button in main.part_buttons:
		actual.append(String((button.get_meta("part_definition") as PartDef).id))
	_check(actual == expected, context + " exact ordered allowlist excludes every hidden catalog part")
	for category: int in range(1, 6):
		main.part_category.select(category)
		main._filter_parts()
		_check(_visible_ids(main) == EXPECTED[category - 1], context + " exact tab membership/order " + str(category))
	main.part_category.select(0)
	main._filter_parts()
	_check(_visible_ids(main) == expected, context + " all restores curated inventory")
	var hint: Label = main._ui_root.get_node("PartsLibrary").find_child("PlacementHint", true, false)
	_check(hint != null and hint.text == "Drag a part onto a hole to attach it", context + " M1 tray guidance preserved")


func _visible_ids(main: Node3D) -> Array[String]:
	var result: Array[String] = []
	for button: Button in main.part_buttons:
		if button.visible:
			result.append(String((button.get_meta("part_definition") as PartDef).id))
	return result


func _visuals(main: Node3D) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("user://parts_tray_previews")
	var preferences: InterfacePreferences = root.get_node("Preferences")
	for locale: String in ["en", "ko", "ja", "zh_CN"]:
		SsokLocale.select_locale(locale, false)
		for theme: String in ["light", "dark"]:
			preferences.values.appearance = theme
			preferences.changed.emit()
			for size: Vector2i in [Vector2i(1152, 648), Vector2i(1400, 950)]:
				root.size = size
				for frame: int in 5:
					await process_frame
				await RenderingServer.frame_post_draw
				var path: String = "user://parts_tray_previews/%s-%s-%d.png" % [locale, theme, size.x]
				_check(root.get_texture().get_image().save_png(path) == OK, "rendered tray capture " + path)
	print("PARTS_TRAY_SCREENSHOTS ", ProjectSettings.globalize_path("user://parts_tray_previews"))


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + message)
