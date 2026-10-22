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
	for frame: int in 8:
		await process_frame


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.session = {"mode": "stage", "level": StageLevels.all()[0]}
	root.add_child(main)
	await _settle()
	for locale: String in SsokLocale.LOCALES:
		SsokLocale.select_locale(locale, false)
		await _settle()
		var expected: String = tr("Run")
		_check(tr(main.stage_hud.run_action.text) == expected, locale + " primary uses existing Run")
		_check(tr(main.run_button.text) == expected, locale + " legacy action uses same label")
		_check(main.program_tabs.get_tab_title(0) == tr("Code") and tr("Code") != expected, locale + " Code tab remains distinct")
		_check(main.stage_hud.hint_label.text.contains(expected), locale + " current instruction quotes actual action")
		for file: String in ["workshop_guide_messages", "game_flow_messages", "project_messages", "block_messages", "flag_mission_messages"]:
			var messages: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/localization/" + file + ".json"))
			for message: Dictionary in messages:
				if not message.en.contains("“Run”"):
					continue
				_check(tr(message.en).contains(("「" + expected + "」") if locale == "ja" else ("“" + expected + "”")), locale + " guide exactly quotes label: " + message.en)
		main._toggle_overlay(main._side_panel)
		main.program_tabs.current_tab = 2
		main.blocks.scroll.ensure_control_visible(main.blocks.feedback)
		await _settle()
		_check(main.blocks.feedback.text.contains(expected), locale + " block feedback quotes actual action")
		main.stage_hud.run_action.grab_focus()
		_check(root.gui_get_focus_owner() == main.stage_hud.run_action, locale + " primary remains keyboard focusable")
		main._side_panel.hide()
	# Exercise the real signal; observation/reset contracts stay unchanged.
	main.stage_hud.run_action.pressed.emit()
	await _settle()
	_check(main.mode_button.button_pressed and tr(main.stage_hud.run_action.text) == tr("Reset robot"), "running action becomes Reset robot")
	main.stage_hud.run_action.pressed.emit()
	await _settle()
	_check(not main.mode_button.button_pressed and tr(main.stage_hud.run_action.text) == tr("Run"), "reset restores Run label")
	main.free()
	print("workshop_run_label_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
