extends SceneTree

var main: Node3D
var checks: int = 0
var failures: int = 0
var pointer := Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 900)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if "--screenshots" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		# Native pointer events can interleave synthetic gestures; capture independently.
		main._load_preset(ConnectionGraph.new(), "", "")
		main.flag_mission.hide()
		var capture_plate: PartNode = main.assembly.spawn_part(load("res://assets/construction_kit/parts/kit_plate_120_80.tres"), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.06, 0)))
		await _capture_placements(capture_plate)
		main.free()
		print("snap_build_input_capture: %d checks, %d failures" % [checks, failures])
		quit(1 if failures else 0)
		return
	main._load_preset(ConnectionGraph.new(), "", "")
	# Empty legacy presets have zero bounds; keep this input test at a usable view.
	main.navigation.frame_bounds(AABB(Vector3(-0.15, 0, -0.1), Vector3(0.3, 0.15, 0.2)))
	var beam_button: Button
	for button: Button in main.part_buttons:
		if button.get_meta("part_definition").id == &"kit_beam_60":
			beam_button = button
			break
	# Use the actual translated title so this check does not depend on saved locale.
	main.part_search.text = TranslationServer.translate(beam_button.get_meta("part_definition").display_name)
	main._filter_parts()
	await process_frame
	await process_frame
	var tray: Vector2 = beam_button.get_global_rect().get_center()
	var floor_point := Vector2(950, 750)
	_check(beam_button.is_visible_in_tree(), "beam is reachable in actual tray")
	await _motion(tray)
	await _button(MOUSE_BUTTON_LEFT, true)
	_check(main.assembly.placement_active and main.assembly.graph.parts.is_empty(), "real tray button down starts ghost without graph edit")
	await _button(MOUSE_BUTTON_LEFT, false)
	_check(main.assembly.placement_active and main.assembly.graph.parts.is_empty(), "short tray click retains placement")
	# GUI clicks remain available while holding a part: choose another tray row.
	main.part_search.text = ""
	main._filter_parts()
	await process_frame
	var other_button: Button
	for button: Button in main.part_buttons:
		if button != beam_button and button.is_visible_in_tree() and main._parts_scroll.get_global_rect().encloses(button.get_global_rect()):
			other_button = button
			break
	_check(other_button != null, "another tray row is available for switching")
	if other_button != null:
		await _motion(other_button.get_global_rect().get_center())
		await _button(MOUSE_BUTTON_LEFT, true)
		await _button(MOUSE_BUTTON_LEFT, false)
		_check(main.assembly.placement_state().definition_id == other_button.get_meta("part_definition").id, "GUI click switches the held tray part")
	await _motion(main.part_search.get_global_rect().get_center())
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	_check(not main.assembly.placement_active and root.gui_get_focus_owner() == main.part_search, "search focus cancels placement and retains GUI input")
	var text_key := InputEventKey.new()
	text_key.keycode = KEY_R
	text_key.unicode = 114
	text_key.pressed = true
	Input.parse_input_event(text_key)
	Input.flush_buffered_events()
	await process_frame
	_check(main.part_search.text.contains("r"), "focused search receives R as learner text")
	main.part_search.text = TranslationServer.translate(beam_button.get_meta("part_definition").display_name)
	main._filter_parts()
	await process_frame
	await _motion(tray)
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	await _motion(floor_point)
	var before_camera: Transform3D = main.navigation._camera.global_transform
	await _button(MOUSE_BUTTON_WHEEL_UP, true)
	_check(main.assembly.placement_state().twist == 1, "wheel up rotates placement")
	_check(main.navigation._camera.global_transform.is_equal_approx(before_camera), "placement wheel never zooms camera")
	await _button(MOUSE_BUTTON_WHEEL_DOWN, true)
	_check(main.assembly.placement_state().twist == 0, "wheel down reverses placement rotation")
	await _key(KEY_R)
	_check(main.assembly.placement_state().twist == 1, "R rotates placement")
	await _key(KEY_R, true)
	_check(main.assembly.placement_state().twist == 0, "Shift R reverses placement rotation")
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	_check(not main.assembly.placement_active and main.assembly.graph.parts.size() == 1, "second viewport click commits tray selection")
	main._load_preset(ConnectionGraph.new(), "", "")
	main.navigation.frame_bounds(AABB(Vector3(-0.15, 0, -0.1), Vector3(0.3, 0.15, 0.2)))
	await _motion(tray)
	await _button(MOUSE_BUTTON_LEFT, true)
	await _motion(floor_point, MOUSE_BUTTON_MASK_LEFT)
	_check(main.assembly.placement_active and main.assembly.placement_state().transform.origin.length() > 0.0, "GUI owned drag updates placement ray")
	await _button(MOUSE_BUTTON_LEFT, false)
	_check(not main.assembly.placement_active and main.assembly.graph.parts.size() == 1, "tray drag release in viewport commits")
	main._load_preset(ConnectionGraph.new(), "", "")
	main.navigation.frame_bounds(AABB(Vector3(-0.15, 0, -0.1), Vector3(0.3, 0.15, 0.2)))
	await _motion(tray)
	await _button(MOUSE_BUTTON_LEFT, true)
	await _motion(tray + Vector2(0, 8), MOUSE_BUTTON_MASK_LEFT)
	await _button(MOUSE_BUTTON_LEFT, false)
	_check(not main.assembly.placement_active and main.assembly.graph.parts.is_empty(), "tray drag release over tray cancels")
	await _motion(tray)
	await _button(MOUSE_BUTTON_LEFT, true)
	await _motion(floor_point, MOUSE_BUTTON_MASK_LEFT)
	await _motion(tray, MOUSE_BUTTON_MASK_LEFT)
	await _button(MOUSE_BUTTON_LEFT, false)
	_check(not main.assembly.placement_active and main.assembly.graph.parts.is_empty(), "drag returning exactly to tray press point still cancels")
	await _motion(tray)
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	await _motion(floor_point)
	await _button(MOUSE_BUTTON_RIGHT, true)
	await _button(MOUSE_BUTTON_RIGHT, false)
	_check(not main.assembly.placement_active and main.assembly.graph.parts.is_empty(), "right click cancels without graph edit")
	await _motion(tray)
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	await _key(KEY_ESCAPE)
	_check(not main.assembly.placement_active and main.assembly.graph.parts.is_empty(), "Escape cancels without graph edit")
	# A plain beam is picked through its collision boxes; use its solid centre.
	var beam: PartNode = main.assembly.spawn_part(load("res://assets/construction_kit/parts/kit_beam_60.tres"), Transform3D(Basis.IDENTITY, Vector3(0, 0.06, 0)))
	await physics_frame
	await process_frame
	main.flag_mission.hide()
	var screen: Vector2 = root.get_camera_3d().unproject_position(beam.global_position)
	await _motion(screen)
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	_check(main.assembly.selected_part == beam and not main.assembly.placement_active, "placed part short click selects without moving")
	# Start the body drag away from the selected object's advanced-edit gizmo.
	main.assembly.select_part(null)
	await physics_frame
	await process_frame
	await _motion(screen)
	await _button(MOUSE_BUTTON_LEFT, true)
	await _motion(screen + Vector2(3, 0), MOUSE_BUTTON_MASK_LEFT)
	_check(not main.assembly.placement_active, "drag below four pixels retains selection")
	await _motion(screen + Vector2(8, 0), MOUSE_BUTTON_MASK_LEFT)
	_check(main.assembly.placement_active, "held placed part drag above four pixels begins move")
	await _key(KEY_ESCAPE)
	await _button(MOUSE_BUTTON_LEFT, false)
	_check(not main.assembly.placement_active and beam.global_position.is_equal_approx(Vector3(0, 0.06, 0)), "Escape during re-placement restores transform")
	main._load_preset(ConnectionGraph.new(), "", "")
	main.navigation.frame_bounds(AABB(Vector3(-0.15, 0, -0.1), Vector3(0.3, 0.15, 0.2)))
	var plate: PartNode = main.assembly.spawn_part(load("res://assets/construction_kit/parts/kit_plate_120_80.tres"), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.06, 0)))
	await physics_frame
	await process_frame
	await _motion(tray)
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	await _motion(root.get_camera_3d().unproject_position(plate.get_port_global_position(&"h2_front")))
	_check(main.assembly.placement_state().target_part == 0, "cursor ray targets plate while picking anchor")
	var anchor: StringName = main.assembly.placement_state().anchor_port
	await _key(KEY_TAB)
	_check(main.assembly.placement_state().anchor_port != anchor and root.gui_get_focus_owner() == null, "Tab cycles compatible anchor without entering UI focus")
	anchor = main.assembly.placement_state().anchor_port
	await _key(KEY_F)
	_check(main.assembly.placement_state().anchor_port != anchor, "F flips anchor to opposite face")
	await _key(KEY_ESCAPE)
	# Formatting metadata must survive language changes after a committed action.
	main.assembly.begin_place(load("res://assets/construction_kit/parts/kit_beam_60.tres"))
	main.assembly.update_place_ray(plate.get_port_global_position(&"h2_front") + Vector3.UP, Vector3.DOWN)
	var attached: int = main.assembly.commit_place()
	_check(attached > 0, "status locale fixture attaches at real holes")
	for locale: String in ["ko", "ja", "zh_CN", "en"]:
		SsokLocale.select_locale(locale, false)
		await process_frame
		_check(main.status.text == main.tr("Attached at %d holes.") % attached, "attached count re-renders in " + locale)
	var moved: PartNode = main.assembly._part_nodes[1]
	main.assembly.begin_move(moved)
	for locale: String in ["ko", "ja", "zh_CN", "en"]:
		SsokLocale.select_locale(locale, false)
		await process_frame
		_check(main.status.text == main.tr("Moving %s. Pick a hole to attach it again.") % main.tr(moved.part_def.display_name), "moving part name re-renders in " + locale)
	main.assembly.cancel_place()
	main.assembly.undo()
	main.free()
	await process_frame
	print("snap_build_input_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _motion(position: Vector2, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - pointer
	event.button_mask = mask
	pointer = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _button(index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pointer
	event.global_position = pointer
	event.button_index = index
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if index == MOUSE_BUTTON_LEFT and pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _key(code: Key, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.shift_pressed = shift
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _capture_placements(plate: PartNode) -> void:
	# Freeze pointer polling while reviewing an exact API placement in native GL.
	main.set_process(false)
	var prefs: InterfacePreferences = root.get_node("Preferences")
	var original: Dictionary = prefs.values.duplicate(true)
	var prefs_path: String = "user://m1_capture_preferences.cfg"
	var directory: String = "user://snap_build_input_previews"
	DirAccess.make_dir_recursive_absolute(directory)
	main.part_search.text = ""
	main._filter_parts()
	for appearance: String in ["light", "dark"]:
		prefs.set_preference("appearance", appearance, prefs_path)
		for viewport_size: Vector2i in [Vector2i(1440, 900), Vector2i(1152, 648)]:
			root.size = viewport_size
			await process_frame
			await process_frame
			main.navigation.frame_bounds(AABB(Vector3(-0.08, 0.03, -0.06), Vector3(0.16, 0.1, 0.12)))
			for locale: String in ["en", "ko", "ja", "zh_CN"]:
				SsokLocale.select_locale(locale, false)
				await process_frame
				await process_frame
				main.assembly.begin_place(load("res://assets/construction_kit/parts/kit_beam_60.tres"))
				main.assembly.update_place_ray(plate.get_port_global_position(&"h2_front") + Vector3.UP, Vector3.DOWN)
				await process_frame
				_check(not main.assembly.placement_state().blocked, "capture has valid attached ghost: " + locale)
				await RenderingServer.frame_post_draw
				var name: String = "%s-%s-%dx%d.png" % [locale, appearance, viewport_size.x, viewport_size.y]
				_check(root.get_texture().get_image().save_png(directory + "/" + name) == OK, "capture " + name)
				main.assembly.cancel_place()
	prefs.values = original
	prefs.changed.emit()
	print("INPUT_PREVIEWS ", ProjectSettings.globalize_path(directory))
