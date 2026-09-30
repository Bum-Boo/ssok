extends SceneTree

## Derive canvas test anchors from the same controls and fonts as the exported client.
var _points: Dictionary = {}


func _initialize() -> void:
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
	main.projects._confirmation.dialog_text = "Replace the current assembly and code? Save a snapshot first if you want to keep them."
	main.projects._confirmation.popup_centered()
	await _settle()
	_point("project_confirm", main.projects._confirmation.get_ok_button())
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
	_point("add_block", _button(main.blocks, "+"))
	main.blocks.operation_picker.select(3)
	main.blocks._add_block()
	await _settle()
	main.blocks.scroll.scroll_vertical = 1000000
	await _settle()
	var last_card: Control = main.blocks.rows.get_child(main.blocks.rows.get_child_count() - 1)
	_point("block_seconds", last_card.get_child(1).get_child(1))
	_point("apply_blocks", _button(main.blocks, "Apply blocks to code"))
	var output: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	output.store_string(JSON.stringify({"viewport": [root.size.x, root.size.y], "points": _points}, "  ") + "\n")
	main.free()
	print("Browser layout: %d control anchors" % _points.size())
	quit()


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
	assert(control != null, "Missing browser control: " + name)
	_rect(name, control, Rect2(Vector2.ZERO, control.size))


func _rect(name: String, control: Control, rectangle: Rect2) -> void:
	var center: Vector2 = control.get_global_transform_with_canvas() * rectangle.get_center()
	var window: Window = control.get_window()
	if window != root:
		center += Vector2(window.position)
	assert(Rect2(Vector2.ZERO, root.size).has_point(center), "Control outside browser viewport: " + name)
	_points[name] = [center.x, center.y]
