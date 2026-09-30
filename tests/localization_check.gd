extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _main: Node3D
var _test_settings: String = "user://localization_test_%d.cfg" % OS.get_process_id()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1400, 950)
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	_main.biped_button.pressed.emit()
	var fingerprint: String = MotionSnapshot.fingerprint(_main._motion_snapshot())
	var source: String = "# 한국어 中文 日本語\narm = Servo(9)"
	var goal: String = "한국어 中文 日本語: Walk forward"
	_main.code_edit.text = source
	var panel: MotionLabPanel = _main.motion_lab
	panel.goal_edit.text = goal
	panel.token_edit.text = "localization-test-not-a-real-token"
	panel.allow_paid.button_pressed = true
	var metric: Dictionary = {"forward_m": 0.01, "lateral_m": 0.002, "yaw_rad": 0.01,
		"min_upright": 0.98, "min_height_m": 0.10, "score": 0.25, "finite": true, "fallen": false}
	panel.best = {"policy": MotionPolicy.defaults(), "metrics": metric}
	panel.best_fingerprint = fingerprint
	panel._job = {"state": "completed", "history": [{"metrics": metric}]}
	panel._show_best()
	panel._status("%s | evaluations: %d | API calls: %s | tokens: %s%s", ["COMPLETED", 1, "0", "0", ""], [0])
	var translated_arguments: Array[int] = [0]
	_main._set_status("Added %s - G to move, R to rotate, Enter to confirm", false, ["Foot"], translated_arguments)
	var original_policy: Dictionary = panel.best.policy.duplicate()
	var keys: PackedStringArray = (load("res://assets/locales/ko.po") as Translation).get_message_list()
	var pickup_messages: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/localization/pickup_messages.json"))
	pickup_messages.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://tools/localization/construction_messages.json")))
	pickup_messages.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://tools/localization/project_messages.json")))
	pickup_messages.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://tools/localization/block_messages.json")))
	pickup_messages.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://tools/localization/core_messages.json")))
	pickup_messages.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://tools/localization/flag_mission_messages.json")))
	pickup_messages.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://tools/localization/learning_messages.json")))
	_check(keys.size() >= 189, "complete translation inventory")
	for locale: String in SsokLocale.LOCALES:
		_check(SsokLocale.select_locale(locale, false) == OK, "switch " + locale)
		await process_frame
		await process_frame
		var translation: Translation = null if locale == "en" else load("res://assets/locales/" + locale + ".po") as Translation
		if translation != null:
			_check(translation.get_message_list().size() == keys.size(), locale + " catalog parity")
			for message: Dictionary in pickup_messages:
				_check(not translation.get_message(message.en).is_empty(), locale + " modular pickup source explicitly covered: " + message.en)
			for key: String in keys:
				var value: String = translation.get_message(key)
				_check(not value.is_empty(), locale + " translation: " + key)
				_check(_placeholders(key) == _placeholders(value), locale + " placeholders: " + key)
				_check(String(TranslationServer.translate(key)) == value, locale + " native lookup: " + key)
				for character: String in value:
					if character.unicode_at(0) > 32:
						_check(SsokLocale.ui_font.has_char(character.unicode_at(0)), locale + " glyph: " + character)
		_check(_main.language_picker.selected == SsokLocale.LOCALES.find(locale), "selector stays in sync")
		_check(_main.run_button.tr(_main.run_button.text) == TranslationServer.translate("Run code"), "native button translation")
		_check(_main.flag_mission._message.text == TranslationServer.translate("Build a small robot, wire its motor, and raise the flag."), "flag mission translates when language changes")
		_check(_main.status.text.contains(TranslationServer.translate("Foot")), "live formatted part name")
		_check(panel.status_label.text.contains(TranslationServer.translate("COMPLETED")), "live job state")
		_check(panel.result_label.text.contains("0.2500"), "measured numeric precision retained")
		_check(panel.history_label.text.begins_with(TranslationServer.translate("Baseline")), "history switches language")
		_check(_main.code_edit.text == source and panel.goal_edit.text == goal, "user text preserved")
		_check(panel.token_edit.text == "localization-test-not-a-real-token" and panel.allow_paid.button_pressed, "connection and consent unchanged")
		_check(MotionSnapshot.fingerprint(_main._motion_snapshot()) == fingerprint, "assembly unchanged")
		_check(panel.best.policy == original_policy, "policy keys and values unchanged")
		_check(_main.code_edit.get_theme_font("font") == SsokLocale.code_font, "code uses CJK monospace")
		_check(panel.token_edit.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "token never translated")
		if "--screenshots" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await _capture(locale + "_workshop")
			panel.open_panel()
			await _capture(locale + "_lab")
			panel.hide()
	_check(SsokLocale.normalize("ko-KR") == "ko", "Korean OS locale")
	_check(SsokLocale.normalize("zh_Hans_CN") == "zh_CN", "Chinese OS locale")
	_check(SsokLocale.normalize("ja_JP") == "ja", "Japanese OS locale")
	_check(SsokLocale.normalize("fr_FR") == "en", "unsupported OS locale fallback")
	_check(SsokLocale.select_locale("invalid", false) == ERR_INVALID_PARAMETER, "invalid locale rejected")
	var previous: PackedByteArray = FileAccess.get_file_as_bytes(_test_settings) if FileAccess.file_exists(_test_settings) else PackedByteArray()
	for locale: String in SsokLocale.LOCALES:
		_check(SsokLocale.select_locale(locale, true, _test_settings) == OK, "save locale")
		_check(SsokLocale.saved_locale(_test_settings) == locale, "restore locale on next launch")
	var settings: ConfigFile = ConfigFile.new()
	settings.set_value("interface", "language", {"bad": true})
	settings.save(_test_settings)
	_check(SsokLocale.saved_locale(_test_settings) == SsokLocale.normalize(OS.get_locale()), "malformed preference fallback")
	if previous.is_empty():
		DirAccess.remove_absolute(_test_settings)
	else:
		var file: FileAccess = FileAccess.open(_test_settings, FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	SsokLocale.select_locale("en", false)
	await process_frame
	_main.mode_button.button_pressed = true
	var bodies: Array[RigidBody3D] = _main.run_mode.bodies.duplicate()
	SsokLocale.select_locale("ko", false)
	await process_frame
	_check(_main.mode_button.button_pressed and _main.manual_controller.is_enabled(), "switching during play preserves control ownership")
	_check(_main.run_mode.bodies == bodies, "language change does not rebuild physics")
	_main.mode_button.button_pressed = false
	_main.free()
	await process_frame
	print("localization_check: %d checks, %d failure(s)" % [_checks, _failures])
	quit(1 if _failures else 0)


func _placeholders(value: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var pattern: RegEx = RegEx.create_from_string("%[+0-9.]*[sdf]")
	for found: RegExMatch in pattern.search_all(value):
		result.append(found.get_string())
	return result


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://localization_previews")
	var viewport: Viewport = _main.motion_lab if name.ends_with("_lab") else root
	var path: String = "user://localization_previews/" + name + ".png"
	_check(viewport.get_texture().get_image().save_png(path) == OK, "screenshot " + name)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
