extends SceneTree

const IDS: Array[String] = ["kit_gear_2", "kit_gear_3", "kit_axle_40", "kit_line_sensor", "kit_contact_button", "kit_led", "kit_env_line_straight", "kit_env_line_corner", "kit_env_ramp_10", "kit_env_ramp_20", "kit_env_ball", "kit_env_cup"]
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var inventory: Dictionary = {}
	for button: Button in main.part_buttons:
		inventory[String((button.get_meta("part_definition") as PartDef).id)] = button
	for id: String in IDS:
		_check(inventory.has(id), "actual tray exposes " + id)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/construction_kit/catalog.json"))
	for locale: String in ["en", "ko", "ja", "zh_CN"]:
		SsokLocale.select_locale(locale, false)
		await process_frame
		main.part_category.select(4)
		main._filter_parts()
		var visible: int = 0
		for button: Button in main.part_buttons:
			visible += int(button.visible)
		_check(visible == catalog.parts.size(), "all declared kit stock reaches existing filter in " + locale)
		for id: String in IDS:
			if not inventory.has(id):
				continue
			var button: Button = inventory[id]
			var definition: PartDef = button.get_meta("part_definition")
			_check(button.visible and button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED and button.text == definition.display_name and button.tr(button.text) == String(TranslationServer.translate(definition.display_name)), "translated tray label " + locale + ": " + id)
			main.part_search.text = TranslationServer.translate(definition.display_name)
			main._filter_parts()
			_check(button.visible, "localized search reaches " + locale + ": " + id)
			main.part_search.text = ""
			main._filter_parts()
		_check(main.part_category.get_item_text(5) == "Environment", "environment selector keeps translation source in " + locale)
		if locale != "en":
			var pack: Translation = load("res://assets/locales/" + locale + ".po")
			_check(not pack.get_message("Environment").is_empty(), "environment category translated in " + locale)
		for category: int in [1, 3, 5]:
			main.part_category.select(category)
			main._filter_parts()
			for id: String in IDS:
				var expected: int = 5 if id.begins_with("kit_env_") else (3 if id in ["kit_line_sensor", "kit_contact_button", "kit_led"] else 1)
				_check(inventory[id].visible == (category == expected), "category membership " + locale + ": " + id)
	main.part_category.select(0)
	main._filter_parts()
	for id: String in IDS:
		if inventory.has(id):
			inventory[id].pressed.emit()
	_check(main.assembly.graph.parts.size() == IDS.size(), "every new tray button adds its graph part")
	var document: Dictionary = ProjectStore.document("Parts pack", main.assembly.graph, "stop()")
	_check(not document.is_empty() and ProjectStore.graph_from(document) != null, "all new stock shares normal project serialization")
	main.free()
	await process_frame
	print("parts_pack_inventory_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
