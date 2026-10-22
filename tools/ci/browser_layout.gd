extends SceneTree

## Derive canvas test anchors from the same controls and fonts as the exported client.
var _points: Dictionary = {}
var _native_solutions: Dictionary = {}
var _started_ms: int = 0
var _failed: bool = false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)


func _watchdog() -> void:
	if Time.get_ticks_msec() - _started_ms > 45000:
		_fail("Browser layout exceeded its 45 second deadline")


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	process_frame.connect(_watchdog)
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected browser layout output path")
		quit(1)
		return
	root.size = Vector2i(1400, 950)
	root.gui_embed_subwindows = true
	SsokLocale.select_locale("en", false)
	await _native_routes()
	if _failed:
		return
	print("Browser layout: legacy opt-in workshop compatibility")
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	_point("starter", main.biped_button)
	_point("flag_starter", _button(main._empty_panel, "Try the servo arm"))
	_point("flag_action", main.flag_mission._action)
	_point("projects", main.projects_button)
	_point("run_mode", main.mode_button)
	_point("stop", main.stop_button)
	_point("learned_starter", main.learned_biped_button)
	_points["world_focus"] = [root.size.x * 0.5, root.size.y * 0.5]
	_point("run_code", main.run_button)
	main._on_biped_pressed()
	await _settle()
	var tab_bar: TabBar = main.program_tabs.get_tab_bar()
	_rect("blocks_tab", tab_bar, tab_bar.get_tab_rect(2))
	_rect("wiring_tab", tab_bar, tab_bar.get_tab_rect(3))
	_rect("code_tab", tab_bar, tab_bar.get_tab_rect(0))
	_rect("stages_tab", tab_bar, tab_bar.get_tab_rect(4))
	var right_width: float = tab_bar.get_theme_icon("increment").get_width()
	var left_width: float = tab_bar.get_theme_icon("decrement").get_width()
	_rect("tabs_scroll_right", tab_bar, Rect2(Vector2(tab_bar.size.x - right_width, 0), Vector2(right_width, tab_bar.size.y)))
	_rect("tabs_scroll_left", tab_bar, Rect2(Vector2(tab_bar.size.x - right_width - left_width, 0), Vector2(left_width, tab_bar.size.y)))
	# A scrolled-out tab's cached rect can alias a different visible tab.
	# Browser/native gates first scroll through real arrow buttons to these endpoints.
	tab_bar.ensure_tab_visible(tab_bar.tab_count - 1)
	await _settle()
	var stage_tab_rect: Rect2 = tab_bar.get_tab_rect(4)
	if tab_bar.get_tab_idx_at_point(stage_tab_rect.get_center()) != 4:
		_fail("Stages tab did not scroll into view")
		return
	_rect("stages_tab_scrolled", tab_bar, stage_tab_rect)
	main.program_tabs.current_tab = 4
	await _settle()
	_point("stage_picker", main.stages._picker)
	_point("stage_load", _button(main.stages, "Load challenge"))
	_point("stage_answer", _button(main.stages, "Try author solution"))
	main.stages.get_child(0).scroll_vertical = 1000000
	await _settle()
	_point("stage_export", _button(main.stages, "Export verified challenge"))
	main.stages.get_child(0).scroll_vertical = 0
	main._replace_dialog.popup_centered()
	await _settle()
	_point("stage_confirm", main._replace_dialog.get_ok_button())
	main._replace_dialog.hide()
	main.program_tabs.current_tab = 0
	await _settle()
	tab_bar.ensure_tab_visible(0)
	await _settle()
	var code_tab_rect: Rect2 = tab_bar.get_tab_rect(0)
	if tab_bar.get_tab_idx_at_point(code_tab_rect.get_center()) != 0:
		_fail("Code tab did not scroll into view")
		return
	_rect("code_tab_scrolled", tab_bar, code_tab_rect)
	_point("code_editor", main.code_edit)
	main.program_tabs.current_tab = 3
	await _settle()
	_point("wire_disconnect_first", main.wiring_panel.connections.get_child(0).get_child(1))
	_point("wire_pin", main.wiring_panel.pin_choice)
	_point("wire_connect", main.wiring_panel.connect_button)
	main.program_tabs.current_tab = 0
	main._open_projects()
	var requested_size: Vector2i = root.size - 2 * main.projects.position
	await _settle()
	# Recover popup_centered's requested size when the headless backend reports its minimum.
	main.projects.size = requested_size
	await _settle()
	_point("project_name", main.projects.title_edit)
	_point("save", main.projects.save_button)
	_point("export", _button(main.projects, "Export project"))
	_point("close_projects", _button(main.projects, "Close"))
	main.projects.title_edit.text = "Browser saved biped"
	main.projects.save_current()
	await _settle()
	if main.projects.library.item_count != 1:
		push_error("Layout capture requires isolated user data and one saved project")
		quit(1)
		return
	_rect("saved_first", main.projects.library, main.projects.library.get_item_rect(0))
	_point("open", main.projects.open_button)
	# Use the same bounded confirmation sizing as an actual saved-project Open.
	main.projects.library.select(0)
	main.projects._refresh_actions()
	main.projects.request_open()
	var confirmation: ConfirmationDialog = main.projects._confirmation
	var confirmation_size: Vector2i = root.size - 2 * confirmation.position
	await _settle()
	# The headless backend reports 200px despite the requested width. Reflow first,
	# then center at that width before restoring its requested rect, as above.
	confirmation.size = confirmation_size
	await _settle()
	confirmation.popup_centered(Vector2i(confirmation_size.x, 0))
	confirmation_size = root.size - 2 * confirmation.position
	await _settle()
	# Prevent the dummy backend's stale wrapped-content minimum from expanding it.
	confirmation.wrap_controls = false
	confirmation.min_size = Vector2i.ZERO
	confirmation.size = confirmation_size
	await _settle()
	_point("project_confirm", confirmation.get_ok_button())
	main.projects._confirmation.hide()
	main.projects.tabs.current_tab = 1
	await _settle()
	_point("transfer_text", main.projects.transfer_edit)
	_point("import", main.projects.import_button)
	main.projects.close_panel()
	main.program_tabs.current_tab = 2
	await _settle()
	_point("blocks_scroll", main.blocks.scroll)
	main.blocks.scroll.scroll_vertical = 1000000
	await _settle()
	_point("block_operation", main.blocks.operation_picker)
	_point("add_block", _button(main.blocks, "Add block"))
	var wait_operation: int = -1
	for index: int in main.blocks.profile.api.size():
		if main.blocks.profile.api[index].id == "sleep":
			wait_operation = index
			break
	if wait_operation < 0:
		push_error("Browser authoring requires a Wait block")
		quit(1)
		return
	main.blocks.operation_picker.select(wait_operation)
	main.blocks._add_block()
	await _settle()
	main.blocks.scroll.scroll_vertical = 1000000
	await _settle()
	var last_card: Control = main.blocks.rows.get_child(main.blocks.rows.get_child_count() - 1)
	_point("block_seconds", last_card.find_child("Argument_seconds", true, false))
	_point("apply_blocks", _button(main.blocks, "Apply blocks to code"))
	_point("settings_button", main.settings_button)
	main._open_settings()
	var settings_requested_size: Vector2i = root.size - 2 * main.settings.position
	await _settle()
	main.settings.size = settings_requested_size
	await _settle()
	_point("settings_language", main.settings.language_picker)
	_point("settings_appearance", main.settings.appearance_picker)
	_point("settings_text", main.settings.text_picker)
	_point("settings_code", main.settings.code_picker)
	_point("settings_mute", main.settings.mute_button)
	_point("settings_volume", main.settings.volume_slider)
	_point("settings_close", main.settings.close_button)
	main.settings.close_panel()
	var program_tab_count: int = tab_bar.tab_count
	main.free()
	await _settle()
	if _failed:
		return
	var output: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	if output == null:
		_fail("Cannot write browser layout: " + args[0])
		return
	output.store_string(JSON.stringify({"viewport": [root.size.x, root.size.y], "points": _points, "block_wait_index": wait_operation, "program_tab_count": program_tab_count, "native_solutions": _native_solutions}, "  ") + "\n")
	print("Browser layout: %d control anchors" % _points.size())
	quit()


func _native_routes() -> void:
	# Default exported clients enter through this router, with current session layouts.
	StageProgress.path = "user://native-layout-progress.json"
	DirAccess.remove_absolute(StageProgress.path)
	var router: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(router)
	await _settle()
	print("Browser layout: router title")
	_point("game_title_play", router.current.play_button)
	_point("game_title_lab", _button(router.current, "Free building"))
	router.show_stages()
	await _settle()
	for level: Dictionary in StageLevels.all():
		_point("game_stage_" + level.id, router.current.play_buttons[level.id])
	for level: Dictionary in StageLevels.all():
		print("Browser layout: stage " + level.id)
		router.start_stage(level.id)
		if not await _workshop_ready(router, "stage"):
			return
		var workshop: Node3D = router.current
		_point("game_solution_" + level.id, workshop.stage_hud.find_child("SolutionMenu", true, false))
		workshop.stage_hud.solution_requested.emit()
		await _confirmation_point("game_confirm_" + level.id, workshop._stage_replace_dialog)
		workshop._stage_replace_dialog.confirmed.emit()
		workshop._stage_replace_dialog.hide()
		await _settle()
		_point("game_program_" + level.id, workshop.stage_hud.chips[2])
		workshop.stage_hud.phase_requested.emit(2)
		workshop.program_tabs.current_tab = 0
		await _settle()
		var bar: TabBar = workshop.program_tabs.get_tab_bar()
		_tab("game_code_tab_" + level.id, bar, 0)
		_point("game_code_editor_" + level.id, workshop.code_edit)
		_point("game_run_" + level.id, workshop.stage_hud.run_action)
		# Run becomes Reset robot in this session; no separate Stop button is visible.
		_point("game_stop_" + level.id, workshop.stage_hud.run_action)
		_native_solutions[level.id] = workshop.code_edit.text
		router.show_stages()
		await _settle()
	print("Browser layout: Lab")
	router.start_workshop({"mode": "lab"})
	if not await _workshop_ready(router, "lab"):
		return
	var lab: Node3D = router.current
	_point("lab_run", lab.stage_hud.run_action)
	_point("lab_stop", lab.stage_hud.run_action)
	_point("lab_help", lab.stage_hud.help_action)
	# Use the same Help example action to populate wiring and blocks for their anchors.
	lab._load_example_id(0)
	await _settle()
	lab.stage_hud.phase_requested.emit(2)
	lab.program_tabs.current_tab = 0
	await _settle()
	_point("lab_code_editor", lab.code_edit)
	var bar: TabBar = lab.program_tabs.get_tab_bar()
	_tab("lab_code_tab", bar, 0)
	_tab("lab_blocks_tab", bar, 2)
	_tab("lab_wiring_tab", bar, 3)
	_tab("lab_stages_tab", bar, 4)
	lab.program_tabs.current_tab = 3
	await _settle()
	_point("lab_wire_pin", lab.wiring_panel.pin_choice)
	_point("lab_wire_connect", lab.wiring_panel.connect_button)
	if lab.wiring_panel.connections.get_child_count() == 0:
		_fail("Lab example has no wiring rows")
		return
	_point("lab_wire_disconnect_first", lab.wiring_panel.connections.get_child(0).get_child(1))
	lab.program_tabs.current_tab = 4
	await _settle()
	lab.stages.get_child(0).scroll_vertical = 1000000
	await _settle()
	_point("lab_stage_export", _button(lab.stages, "Export verified challenge"))
	lab._open_projects()
	var projects_size: Vector2i = root.size - 2 * lab.projects.position
	await _settle()
	lab.projects.size = projects_size
	await _settle()
	_point("lab_project_name", lab.projects.title_edit)
	_point("lab_save", lab.projects.save_button)
	_point("lab_export", _button(lab.projects, "Export project"))
	_point("lab_close_projects", _button(lab.projects, "Close"))
	lab.projects.close_panel()
	router.free()
	await _settle()


func _confirmation_point(name: String, dialog: ConfirmationDialog) -> void:
	# As with the legacy project confirmation, reflow at the requested width before
	# recovering the rect that the dummy headless window backend discards.
	var requested_size: Vector2i = root.size - 2 * dialog.position
	await _settle()
	dialog.size = requested_size
	await _settle()
	dialog.popup_centered(Vector2i(requested_size.x, 0))
	requested_size = root.size - 2 * dialog.position
	await _settle()
	dialog.wrap_controls = false
	dialog.min_size = Vector2i.ZERO
	dialog.size = requested_size
	await _settle()
	_point(name, dialog.get_ok_button())


func _workshop_ready(router: Node, mode: String) -> bool:
	for frame: int in 120:
		await process_frame
		if router.current is Node3D and router.current.session.get("mode") == mode:
			await _settle()
			return true
	_fail("Router did not load " + mode + " session within 120 frames")
	return false


func _tab(name: String, bar: TabBar, index: int) -> void:
	var rectangle: Rect2 = bar.get_tab_rect(index)
	if bar.is_tab_hidden(index) or bar.get_tab_idx_at_point(rectangle.get_center()) != index:
		_fail("Browser tab is hidden or scrolled out: " + name)
		return
	_rect(name, bar, rectangle)


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _button(parent: Node, text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and child.text == text:
			return child
		var found: Button = _button(child, text)
		if found != null:
			return found
	return null


func _point(name: String, control: Control) -> void:
	if control == null:
		_fail("Missing browser control: " + name)
		return
	if not control.is_visible_in_tree():
		_fail("Hidden browser control: " + name)
		return
	_rect(name, control, Rect2(Vector2.ZERO, control.size))


func _rect(name: String, control: Control, rectangle: Rect2) -> void:
	var center: Vector2 = control.get_global_transform_with_canvas() * rectangle.get_center()
	var window: Window = control.get_window()
	if window != root:
		center += Vector2(window.position)
	if not Rect2(Vector2.ZERO, root.size).has_point(center):
		_fail("Control outside browser viewport: " + name)
		return
	_points[name] = [center.x, center.y]
