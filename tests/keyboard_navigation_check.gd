extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1400, 950)
	root.gui_embed_subwindows = true
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	for control: Control in [main.projects_button, main.mode_button, main.run_button, main.language_picker, main.control_source, main.part_category, main.biped_button]:
		_check(control.focus_mode == Control.FOCUS_ALL, "primary controls participate in keyboard navigation")
	await _key(root, KEY_TAB)
	_check(root.gui_get_focus_owner() == main.projects_button, "first Tab enters the toolbar from the 3D workspace")
	await _key(root, KEY_ENTER)
	_check(main.projects.visible, "Enter opens the focused Projects button")
	_check(main.projects.gui_get_focus_owner() == main.projects.title_edit, "project dialog starts at its name field")
	await _key(main.projects, KEY_TAB)
	_check(main.projects.gui_get_focus_owner() == main.projects.save_button, "Tab reaches Save from the project name")
	var title: String = "Keyboard review %d" % OS.get_process_id()
	main.projects.title_edit.text = title
	await _key(main.projects, KEY_ENTER)
	var saved: Array[Dictionary] = []
	for item: Dictionary in ProjectStore.list_projects():
		if item.record.title == title:
			saved.append(item)
	_check(saved.size() == 1, "Enter on Save creates the named project snapshot")
	main.projects.title_edit.grab_focus()
	await _key(main.projects, KEY_ESCAPE)
	_check(not main.projects.visible and main.navigation.navigation_enabled, "Escape in the project name closes Projects and restores navigation")
	if main.projects.visible:
		main.projects.close_panel()
	main._on_answer_pressed()
	main.code_edit.grab_focus()
	var source: String = main.code_edit.text
	await _key(root, KEY_ESCAPE)
	_check(root.gui_get_focus_owner() == main.program_tabs.get_tab_bar(), "Escape leaves the code editor for its tab bar")
	_check(main.code_edit.text == source, "leaving the editor preserves source")
	await _key(root, KEY_RIGHT)
	await _key(root, KEY_RIGHT)
	_check(main.program_tabs.current_tab == 2, "arrow keys select the Blocks tab")
	var apply: Button = _button(main.blocks, "Apply blocks to code")
	var found_apply: bool = await _tab_until(root, apply, 48)
	_check(found_apply, "Tab reaches Apply blocks to code")
	if found_apply:
		_check(main.blocks.scroll.get_global_rect().intersects(apply.get_global_rect()), "focused block action scrolls into view")
	main._open_tutorial()
	await _key(main.tutorial, KEY_ESCAPE)
	_check(not main.tutorial.visible, "Escape closes the tutorial")
	main._open_motion_lab()
	await _key(main.motion_lab, KEY_ESCAPE)
	_check(not main.motion_lab.visible, "Escape closes the biped motion lab")
	main._on_modular_pressed()
	main._open_motion_lab()
	await _key(main.pickup_lab, KEY_ESCAPE)
	_check(not main.pickup_lab.visible, "Escape closes the pickup lab")
	main._on_biped_pressed()
	main.mode_button.button_pressed = true
	main.projects_button.grab_focus()
	var movement := InputEventKey.new()
	movement.keycode = KEY_W
	movement.physical_keycode = KEY_W
	movement.pressed = true
	main.manual_controller.handle_event(movement)
	_check(main.manual_controller.get_move_input().is_zero_approx(), "focused toolbar controls prevent robot movement keys")
	main.mode_button.button_pressed = false
	main.assembly.select_part(main.assembly._part_nodes[0])
	main.projects_button.grab_focus()
	await _key(root, KEY_G)
	_check(not main.assembly.transform_active, "focused toolbar controls prevent assembly transform keys")
	main.code_edit.grab_focus()
	await _key(root, KEY_S, true)
	_check(main.projects.visible, "Ctrl+S opens Projects from the code editor")
	await _key(main.projects, KEY_ESCAPE)
	main.free()
	for item: Dictionary in saved:
		ProjectStore.remove(item.id)
	print("keyboard_navigation_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _key(window: Window, code: Key, control: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = control
	event.pressed = true
	window.push_input(event, true)
	await process_frame
	event.pressed = false
	window.push_input(event, true)
	await process_frame


func _tab_until(window: Window, target: Control, limit: int) -> bool:
	for index: int in limit:
		await _key(window, KEY_TAB)
		if window.gui_get_focus_owner() == target:
			return true
	return false


func _button(parent: Node, text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and child.text == text:
			return child
		var found: Button = _button(child, text)
		if found != null:
			return found
	return null


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + description)
