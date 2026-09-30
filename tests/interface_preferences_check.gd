extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _main: Node3D
var _prefs: InterfacePreferences
var _path: String = "user://preferences_test_%d.cfg" % OS.get_process_id()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_prefs = root.get_node("Preferences") as InterfacePreferences
	root.size = Vector2i(1600, 1000)
	root.gui_embed_subwindows = true
	_prefs.reset_preferences(_path)
	_check(_prefs.set_preference("text_scale", 9.0, _path) == ERR_INVALID_PARAMETER, "reject unusable text scale")
	_check(_prefs.set_preference("muted", "false", _path) == ERR_INVALID_PARAMETER, "reject non-boolean mute")
	_check(_prefs.set_preference("volume", NAN, _path) == ERR_INVALID_PARAMETER, "reject non-finite volume")
	_check(_prefs.set_preference("appearance", "light", _path) == OK, "save explicit appearance")
	_prefs.set_preference("volume", 35.0, _path)
	var loaded := InterfacePreferences.new()
	loaded.load_preferences(_path)
	_check(loaded.values.appearance == "light" and loaded.values.volume == 35.0, "independent instance restores saved preferences")
	loaded.free()
	var bad := ConfigFile.new()
	bad.set_value("interface", "appearance", "unknown")
	bad.set_value("interface", "text_scale", "big")
	bad.set_value("interface", "volume", -5)
	bad.save(_path)
	_prefs.load_preferences(_path)
	_check(_prefs.values == InterfacePreferences.DEFAULTS, "invalid stored fields fall back independently")
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await _settle()
	_main._on_microbit_arm_pressed()
	_main.code_edit.text += "\n# learner 日本語 中文 초안\n"
	_main.blocks._add_block()
	_main.blocks.instructions.append({"op": "raw", "raw": "learner_name = 42", "indent": 0})
	_main.blocks._rebuild()
	var before: String = _workspace()
	for locale: String in ["ko", "en", "ja", "zh_CN"]:
		_main.language_picker.grab_focus()
		_main.language_picker.item_selected.emit(SsokLocale.LOCALES.find(locale))
		await _settle()
		_check(_workspace() == before, locale + " preserves graph, code, draft, tab and mode")
		_check(root.gui_get_focus_owner() == _main.language_picker, locale + " keeps language focus")
		var title: Label = _main.blocks.rows.get_child(0).get_child(0).get_child(1) as Label
		_check(title.text == _main.blocks.profile.operation("servo").label, locale + " retains untranslated block title key")
		var raw: Label = _main.blocks.rows.get_child(_main.blocks.rows.get_child_count() - 1) as Label
		_check(raw.text == SsokLocale.format_text("Code block\n%s", ["learner_name = 42"]), locale + " translates raw caption while preserving learner source")
		await _capture("workshop-" + locale)
		_main._open_settings()
		_check(_main.settings.language_picker.selected == SsokLocale.LOCALES.find(locale), locale + " settings language mirrors toolbar")
		_check(_main.settings.close_button.size.x >= 80.0, locale + " Close has a visible text target")
		await _capture("settings-" + locale)
		await _key(_main.settings, KEY_ESCAPE)
		_check(not _main.settings.visible and root.gui_get_focus_owner() == _main.settings_button, locale + " Esc closes settings and restores toolbar focus")
	for appearance: String in ["light", "dark"]:
		_prefs.set_preference("appearance", appearance, _path)
		await _settle()
		var theme: Theme = _main._ui_root.theme
		_check(_contrast(theme.get_color("font_color", "Label"), SsokTheme.BG) >= 4.5, appearance + " body contrast")
		_check(_contrast(theme.get_color("font_focus_color", "OptionButton"), SsokTheme.BG_RAISED) >= 4.5, appearance + " focused selector contrast")
		_check(_contrast(theme.get_color("font_pressed_color", "OptionButton"), SsokTheme.ACCENT_DOWN) >= 4.5, appearance + " open selector text contrast")
		_check(_contrast(theme.get_color("font_hover_color", "PopupMenu"), SsokTheme.BG_RAISED) >= 4.5, appearance + " selected menu text contrast")
		_check((theme.get_stylebox("embedded_unfocused_border", "Window") as StyleBoxFlat).bg_color == SsokTheme.BG, appearance + " embedded window retains palette when browser focus changes")
		_check(_contrast(SsokTheme.TEXT_DIM, SsokTheme.BG_RAISED) >= 4.5, appearance + " secondary text contrast")
		_check(_contrast(theme.get_color("font_color", "PrimaryButton"), SsokTheme.ACCENT) >= 4.5, appearance + " primary contrast")
		_check(_main.projects.theme == theme and _main.settings.theme == theme, appearance + " openable windows share live theme")
		_prefs.set_preference("code_scale", 2.0, _path)
		for scale: float in [1.0, 1.5, 2.0, 1.0]:
			_prefs.set_preference("text_scale", scale, _path)
			await _settle()
			_check(_main.code_edit.get_theme_font_size("font_size") == 30, "code size is independent of interface text")
			_check(_main._ui_root.theme.default_font_size == roundi(14 * scale), "interface size applies without accumulating rounding")
			_check(_workspace() == before, "theme and scales preserve edits")
		_main._open_settings()
		await _capture("theme-" + appearance)
		_main.settings.close_panel()
	_prefs.set_preference("text_scale", 2.0, _path)
	root.size = Vector2i(1024, 768)
	await _settle()
	_main.assembly.load_graph(ConnectionGraph.new())
	await _settle()
	_check(not _main._empty_panel.visible, "compact window has one starting instruction")
	var mission: Rect2 = _main.flag_mission.get_global_rect()
	_check(mission.end.x <= _main._side_panel.get_global_rect().position.x and mission.position.x >= 248.0, "enlarged mission stays between side panels")
	_check(mission.end.y < _main.status.get_global_rect().position.y, "enlarged mission remains above footer")
	await _capture("compact-200")
	_main._on_microbit_arm_pressed()
	_main.control_source.select(_main.CONTROL_CODE)
	_main.control_source.item_selected.emit(_main.CONTROL_CODE)
	_main.mode_button.button_pressed = true
	_main.runtime.run("while True:\n    sleep(1000)\n")
	await _settle()
	_check(_main.runtime.is_running(), "code is running before preference dialog")
	_main._open_settings()
	_check(_main.runtime.is_running(), "opening settings keeps the active VM")
	_prefs.set_preference("appearance", "light", _path)
	_check(_main.runtime.is_running(), "theme change keeps the active VM")
	_prefs.set_preference("muted", true, _path)
	_check(_prefs.effects_gain() == 0.0 and not _main.flag_mission._sound.playing, "mute silences and stops effects")
	_prefs.set_preference("muted", false, _path)
	_prefs.set_preference("volume", 25.0, _path)
	_check(is_equal_approx(_main.flag_mission._sound.volume_db, -13.0 + linear_to_db(0.25)), "sound gain follows volume")
	var error: Error = _prefs.set_preference("code_scale", 1.5, "user://uncreated_settings_dir/preferences.cfg")
	_main.settings._saved(error)
	await _settle()
	_check(error != OK and _main.code_edit.get_theme_font_size("font_size") == 23, "failed persistence still applies the selected setting")
	_check(_main.settings.feedback.has_meta("localized_source"), "save failure feedback retains translation source")
	_main.settings.close_panel()
	_main.runtime.stop()
	_main.mode_button.button_pressed = false
	var locale: String = TranslationServer.get_locale()
	_main.settings._saved(_prefs.reset_preferences(_path))
	_check(_prefs.values == InterfacePreferences.DEFAULTS and TranslationServer.get_locale() == locale, "reset preserves selected language")
	_main.free()
	DirAccess.remove_absolute(_path)
	await process_frame
	print("interface_preferences_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _workspace() -> String:
	return var_to_str([_main.code_edit.text, _main.assembly.graph.parts, _main.assembly.graph.links, _main.blocks.instructions, _main.program_tabs.current_tab, _main.mode_button.button_pressed])


func _settle() -> void:
	for frame: int in range(6):
		await process_frame


func _key(window: Window, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	window.push_input(event)
	await process_frame
	event.pressed = false
	window.push_input(event)
	await _settle()


func _luminance(color: Color) -> float:
	var rgb: Array[float] = [color.r, color.g, color.b]
	for i: int in rgb.size():
		rgb[i] = rgb[i] / 12.92 if rgb[i] <= 0.04045 else pow((rgb[i] + 0.055) / 1.055, 2.4)
	return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722


func _contrast(first: Color, second: Color) -> float:
	var a: float = _luminance(first)
	var b: float = _luminance(second)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or "--screenshots" not in OS.get_cmdline_user_args():
		return
	await _settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://settings_previews")
	_check(root.get_texture().get_image().save_png("user://settings_previews/" + name + ".png") == OK, "capture " + name)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
