extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	root.gui_embed_subwindows = true
	var preferences: Node = root.get_node("Preferences")
	preferences.values.text_scale = 2.0
	preferences.values.appearance = "dark"
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	for frame: int in 4:
		await process_frame
	var title: Node = app.current
	var picker: OptionButton = title.language_picker
	var button: Button = title.find_child("SettingsButton", true, false)
	var rows: Array[Dictionary] = []
	var failures: int = 0
	for index: int in 4:
		picker.grab_focus()
		picker.select(index)
		picker.item_selected.emit(index)
		for frame: int in 4:
			await process_frame
		var focused: bool = root.gui_get_focus_owner() == picker
		var footer: Rect2 = button.get_parent().get_global_rect()
		var fits: bool = footer.position.x >= 31.0 and footer.end.x <= 1121.0
		var locale: String = SsokLocale.LOCALES[index]
		var current: bool = SsokLocale.normalize(TranslationServer.get_locale()) == locale
		rows.append({"locale": locale, "translation": button.tr(button.text), "same_title_instance": app.current == title, "picker_focus_preserved": focused, "locale_applied": current, "footer_fits": fits, "button_width": button.size.x})
		if not focused or not fits or not current or app.current != title:
			failures += 1
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows, "failures": failures, "viewport": [1152, 648], "text_scale": 2.0, "title_source_sha256": FileAccess.get_sha256("res://src/screens/title_screen.gd"), "scope": "Actual existing picker callback live translation/focus/minimum-size update; same router/title instance; isolated user data"}, "\t") + "\n")
	file.close()
	app.free()
	print("TITLE live language4/%d failures" % failures)
	quit(1 if failures else 0)
