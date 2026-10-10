extends SceneTree

var rows: Array[Dictionary] = []
var failures: Array[String] = []
var folder: String


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int = 4) -> void:
	for index: int in count:
		await process_frame


func _key(window: Window, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	window.push_input(event)
	event.pressed = false
	window.push_input(event)
	await _frames(2)


func _run() -> void:
	folder = OS.get_cmdline_user_args()[0]
	root.gui_embed_subwindows = true
	for locale: String in ["en", "ko", "zh_CN", "ja"]:
		for dark: bool in [true, false]:
			for scale: float in [1.0, 1.15, 1.3, 1.5, 2.0]:
				for viewport: Vector2i in [Vector2i(1400, 950), Vector2i(1152, 648)]:
					root.size = viewport
					SsokLocale.select_locale(locale, false)
					SsokTheme.configure(dark, scale, 1.0)
					var title: TitleScreen = load("res://scenes/screens/title.tscn").instantiate()
					root.add_child(title)
					await _frames()
					var button: Button = title.find_child("SettingsButton", true, false) as Button
					var footer: HBoxContainer = button.get_parent() as HBoxContainer
					var capture: bool = (scale == 1.0 and viewport.x == 1400) or (scale == 2.0 and viewport.x == 1152)
					var label: String = "%s-%s-%d-%d" % [locale, "dark" if dark else "light", roundi(scale * 100), viewport.x]
					var fits: bool = footer.get_global_rect().position.x >= 31.0 and footer.get_global_rect().end.x <= viewport.x - 31.0
					var keyboard: Dictionary = {}
					if capture:
						keyboard.initial_play_focus = root.gui_get_focus_owner() == title.play_button
						for tab: int in 4:
							await _key(root, KEY_TAB)
						keyboard.language_focus = root.gui_get_focus_owner() == title.language_picker
						await _key(root, KEY_TAB)
						keyboard.settings_focus = root.gui_get_focus_owner() == button
						await _key(root, KEY_ENTER)
						keyboard.enter_opens_settings = title.settings.visible
						await _key(title.settings, KEY_ESCAPE)
						keyboard.escape_restores_settings_focus = not title.settings.visible and root.gui_get_focus_owner() == button
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(folder.path_join(label + ".png"))
						for key: String in keyboard:
							if not keyboard[key]:
								failures.append(label + ": " + key)
					if not fits:
						failures.append(label + ": footer outside 32px margin")
					rows.append({"id": label, "locale": locale, "dark": dark, "scale": scale, "viewport": [root.size.x, root.size.y], "text": button.tr(button.text), "button_width": button.size.x, "button_min_width": button.get_minimum_size().x, "footer_left": footer.get_global_rect().position.x, "footer_right": footer.get_global_rect().end.x, "footer_fits_32px_margin": fits, "keyboard": keyboard, "png": label + ".png" if capture else null})
					root.remove_child(title)
					title.free()
					await _frames(1)
	var file := FileAccess.open(folder.path_join("geometry.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"cases": rows.size(), "rows": rows, "failures": failures, "native_renderer": RenderingServer.get_current_rendering_method(), "settings_only_source_sha256": FileAccess.get_sha256("res://src/screens/title_screen.gd"), "scope": "existing title settings label; supported desktop/compact sizes; actual GUI keyboard events"}, "\t") + "\n")
	file.close()
	print("TITLE %d cases; %d failures" % [rows.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)
