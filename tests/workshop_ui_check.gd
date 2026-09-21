extends SceneTree

var _main: Node3D
var _checks: int = 0
var _failures: int = 0
const UI_MESSAGES: Array[String] = [
	"Stop",
	"Robot program",
	"Code",
	"Controls",
	"Python-style servo program",
	"Move your robot",
	"W / S   Forward / backward\nA / D   Turn left / right\nSpace   Brake\nEsc   Stop input",
	"Choose WASD control, then enable Run mode. Click the 3D view before using the keyboard.",
	"Frame robot",
	"Build something that moves.",
	"Start with a robot example, or add parts from the library.",
	"Start with a biped",
	"Parts library",
	"Search parts...",
	"All parts",
	"Structure",
	"Actuators",
	"Electronics",
	"No matching parts",
	"STARTER ROBOTS",
	"%d parts / %d connections",
	"1. Connect",
	"2. Search",
	"3. Results",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1400, 950)
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	_check(_main._empty_panel.visible, "empty assembly has a starting point")
	_check(_main.delete_button.disabled, "delete unavailable without selection")
	_check(_main.part_buttons.size() == 64, "all catalogs present including the elementary kit")
	for locale: String in ["ko", "zh_CN", "ja", "en"]:
		SsokLocale.select_locale(locale, false)
		if locale != "en":
			var pack: Translation = load("res://assets/locales/" + locale + ".po") as Translation
			for message: String in UI_MESSAGES:
				_check(not pack.get_message(message).is_empty(), locale + " new UI string covered: " + message)
		await process_frame
		await process_frame
		_main.part_search.text = TranslationServer.translate("Servo Motor")
		_main.part_search.text_changed.emit(_main.part_search.text)
		var matching: int = 0
		var query: String = _main.part_search.text.to_lower()
		for button: Button in _main.part_buttons:
			var definition: PartDef = button.get_meta("part_definition")
			var expected: bool = query in definition.display_name.to_lower() or query in TranslationServer.translate(definition.display_name).to_lower() or query in definition.resource_path.get_file()
			matching += int(expected)
			_check(button.visible == expected, locale + " correct localized substring membership")
		_check(matching > 0 and _visible_parts() == matching, locale + " localized substring search")
		_main.part_search.text = "no-such-part-ssok"
		_main._filter_parts()
		_check(_visible_parts() == 0 and _main._no_parts.visible, "empty search feedback")
		_main.part_search.text = ""
		_main.part_category.select(2)
		_main.part_category.item_selected.emit(2)
		_check(_visible_parts() == 14, "actuator filter")
		_main.part_category.select(3)
		_main.part_category.item_selected.emit(3)
		_check(_visible_parts() == 7, "electronics filter")
		_main.part_category.select(0)
		_main._filter_parts()
		_check(_visible_parts() == 64 and not _main._no_parts.visible, "filters restore full catalog")
	SsokLocale.select_locale("ko", false)
	await process_frame
	await _capture("00-empty")
	_main.biped_button.pressed.emit()
	await process_frame
	_check(not _main._empty_panel.visible, "preset dismisses empty state")
	var snapshot: String = MotionSnapshot.fingerprint(_main._motion_snapshot())
	var source: String = _main.code_edit.text
	_main.program_tabs.current_tab = 1
	_main.program_tabs.current_tab = 0
	_check(_main.code_edit.text == source and MotionSnapshot.fingerprint(_main._motion_snapshot()) == snapshot, "tabs preserve code and graph")
	var part: PartNode = _main.assembly.get_child(1) as PartNode
	_main.assembly.select_part(part)
	_check(not _main.delete_button.disabled, "selection enables deletion")
	_main._begin_toolbar_transform(&"translate")
	_check(_main.assembly.transform_active, "toolbar starts real modal movement")
	_main.assembly.cancel_transform()
	_check(MotionSnapshot.fingerprint(_main._motion_snapshot()) == snapshot, "cancel preserves graph")
	_main.mode_button.button_pressed = true
	_check(_main.delete_button.disabled and _main._transform_buttons[0].disabled, "physics locks editing tools")
	_main.part_search.grab_focus()
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = true
	event.unicode = 119
	root.push_input(event, true)
	await process_frame
	_check(_main.manual_controller.get_move_input().is_zero_approx(), "typing a search cannot drive robot")
	event.pressed = false
	root.push_input(event, true)
	_main.part_search.text = ""
	_main._filter_parts()
	_main.mode_button.button_pressed = false
	root.gui_release_focus()
	var panel: MotionLabPanel = _main.motion_lab
	for locale: String in ["ko", "zh_CN", "ja"]:
		SsokLocale.select_locale(locale, false)
		await process_frame
		await _capture(locale + "-workshop")
		root.size = Vector2i(1152, 648)
		await process_frame
		await process_frame
		_check(_inside_root(_main.run_button) and _inside_root(_main.examples_menu) and _main.examples_menu.visible, locale + " compact starter menu and run action fit 1152x648")
		_check(_main._side_panel.position.x > 460, "usable central viewport remains")
		await _capture(locale + "-compact")
		root.size = Vector2i(1400, 950)
		await process_frame
		_main.motion_lab_button.pressed.emit()
		_check(panel.visible and not _main.navigation.navigation_enabled, "lab remains modal")
		for tab: int in range(3):
			panel.workflow_tabs.current_tab = tab
			await process_frame
			await _capture(locale + "-lab-" + str(tab), panel)
		_check(panel.apply_button.visible and panel.apply_button.disabled, "result action visible but no unmeasured application")
		_check(not panel.allow_paid.button_pressed, "tab changes never consent to paid requests")
		panel._close_panel()
		_check(_main.navigation.navigation_enabled and not _main.manual_controller.is_enabled(), "close restores navigation without resuming movement")
	_main.free()
	await process_frame
	print("workshop_ui_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _visible_parts() -> int:
	var count: int = 0
	for button: Button in _main.part_buttons:
		count += int(button.visible)
	return count


func _inside_root(control: Control) -> bool:
	return Rect2(Vector2.ZERO, root.size).encloses(control.get_global_rect())


func _capture(name: String, viewport: Viewport = null) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://uiux_previews")
	var target: Viewport = root if viewport == null else viewport
	_check(target.get_texture().get_image().save_png("user://uiux_previews/" + name + ".png") == OK, "capture " + name)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
