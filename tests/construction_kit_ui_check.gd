extends SceneTree

var _main: Node3D
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1400, 950)
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	_main.modular_button.pressed.emit()
	_check(_main.motion_program is KitHumanoidMotion, "new starter selects graph-derived construction-kit control")
	_check(_main.part_category.selected == 4, "new starter exposes elementary kit rather than legacy prefab catalog")
	var graph: ConnectionGraph = _main.assembly.graph
	var snapshot: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(graph))
	var humanoid_ids: Dictionary = _ids(graph)
	_check(graph.parts.size() > 38 and not snapshot.is_empty(), "many independent elementary nodes are a valid bounded graph")
	for entry: Dictionary in graph.parts:
		_check(String(entry.part_def.id).begins_with("kit_") or entry.part_def.id == &"cargo_box", "no old joined torso/limb prefab in new robot")
	var beam: PartNode
	for part: PartNode in _main.assembly._part_nodes:
		if String(part.part_def.id).begins_with("kit_beam_"):
			beam = part
			break
	_check(beam != null, "robot exposes individual beam objects")
	if beam != null:
		_check(not (beam.get_node("PortHints") as MultiMeshInstance3D).visible, "unselected kit shows actual drilled holes without overlay caps")
		_main.assembly.select_part(beam)
		_check((beam.get_node("PortHints") as MultiMeshInstance3D).visible, "selection reveals batched per-hole attachment hints")
		root.gui_release_focus()
		var before: Transform3D = beam.global_transform
		var beam_index: int = beam.graph_index
		await _key(KEY_G)
		await _key(KEY_X)
		await _key(KEY_5)
		await _key(KEY_0)
		await _key(KEY_0)
		await _key(KEY_ENTER)
		var moved_beam: PartNode = _main.assembly._part_nodes[beam_index]
		_check(not moved_beam.global_transform.is_equal_approx(before), "G X 500 moves one beam independently")
		_check(_main.assembly.undo(), "elementary transform supports undo")
		_check(MotionSnapshot.fingerprint(_main._motion_snapshot()) == snapshot, "undo restores both elementary geometry and connections")
	for locale: String in ["ko", "zh_CN", "ja"]:
		SsokLocale.select_locale(locale, false)
		await process_frame
		await process_frame
		var pack: Translation = load("res://assets/locales/" + locale + ".po") as Translation
		for message: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://tools/localization/construction_messages.json")):
			_check(not pack.get_message(message.en).is_empty(), locale + " new construction source translated")
		var visible_count: int = 0
		for button: Button in _main.part_buttons:
			if button.visible:
				visible_count += 1
				_check(String((button.get_meta("part_definition") as PartDef).id).begins_with("kit_"), "construction category has only kit components")
		_check(visible_count == 25, "all elementary catalog SKUs including the sixteen-channel controller are reachable")
		await _capture(locale + "-humanoid")
		root.size = Vector2i(1152, 648)
		await process_frame
		await process_frame
		_check(_main.examples_menu.visible and Rect2(Vector2.ZERO, root.size).encloses(_main.examples_menu.get_global_rect()), locale + " compact starter menu reachable")
		_check(_main.examples_menu.get_popup().item_count == 6, locale + " all six starters available in compact menu")
		await _capture(locale + "-compact")
		root.size = Vector2i(1400, 950)
		_main.kit_bridge_button.pressed.emit()
		await process_frame
		var bridge_ids: Dictionary = _ids(_main.assembly.graph)
		var shared: int = 0
		for id: StringName in bridge_ids:
			shared += int(humanoid_ids.has(id))
		_check(shared >= 3, "alternative structure reuses at least three identical catalog parts")
		_check(not KitHumanoidMotion.recognizes(_main.assembly.graph), "bridge never pretends to be a controllable humanoid")
		await _capture(locale + "-bridge")
		_main.tutorial_button.pressed.emit()
		_main.tutorial.show_step(0)
		await process_frame
		await _capture(locale + "-tutorial", _main.tutorial)
		_main.tutorial.close_panel()
		_main.modular_button.pressed.emit()
		await process_frame
	_main.free()
	await process_frame
	print("construction_kit_ui_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _ids(graph: ConnectionGraph) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in graph.parts:
		result[entry.part_def.id] = true
	return result


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.unicode = int(key)
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame


func _capture(name: String, viewport: Viewport = null) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://construction_kit_previews")
	var target: Viewport = root if viewport == null else viewport
	_check(target.get_texture().get_image().save_png("user://construction_kit_previews/" + name + ".png") == OK, "capture " + name)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
