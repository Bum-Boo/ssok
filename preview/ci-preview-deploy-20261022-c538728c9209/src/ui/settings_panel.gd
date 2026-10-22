class_name SettingsPanel
extends Window

signal panel_closed
var language_picker: OptionButton
var appearance_picker: OptionButton
var text_picker: OptionButton
var code_picker: OptionButton
var mute_button: CheckBox
var close_button: Button
var volume_slider: HSlider
var volume_label: Label
var feedback: Label
var _syncing: bool = false


func _ready() -> void:
	title = "Settings"
	visible = false
	exclusive = true
	unresizable = true
	close_requested.connect(close_panel)
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var note := Label.new()
	note.text = "Changes apply immediately. Your robot and code stay unchanged."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	language_picker = _picker(content, "Language")
	language_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for language: String in SsokLocale.NAMES:
		language_picker.add_item(language)
	language_picker.item_selected.connect(_select_language)
	appearance_picker = _picker(content, "Theme")
	for appearance: String in ["System", "Light", "Dark"]:
		appearance_picker.add_item(appearance)
	appearance_picker.item_selected.connect(func(index: int) -> void: _change_preference("appearance", ["system", "light", "dark"][index]))
	text_picker = _scale_picker(content, "Interface text size", "text_scale")
	code_picker = _scale_picker(content, "Code text size", "code_scale")
	mute_button = CheckBox.new()
	mute_button.text = "Mute sound effects"
	mute_button.focus_mode = Control.FOCUS_ALL
	mute_button.toggled.connect(func(muted: bool) -> void: _change_preference("muted", muted))
	content.add_child(mute_button)
	var volume_row := HBoxContainer.new()
	content.add_child(volume_row)
	var volume_title := Label.new()
	volume_title.text = "Sound effects volume"
	volume_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_row.add_child(volume_title)
	volume_label = Label.new()
	volume_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	volume_row.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.max_value = 100.0
	volume_slider.step = 5.0
	volume_slider.custom_minimum_size.y = 36
	volume_slider.focus_mode = Control.FOCUS_ALL
	volume_slider.value_changed.connect(func(value: float) -> void: _change_preference("volume", value))
	content.add_child(volume_slider)
	var shortcuts := Label.new()
	shortcuts.text = "Tab moves between controls. Esc closes settings."
	shortcuts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(shortcuts)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(feedback)
	var actions := HBoxContainer.new()
	layout.add_child(actions)
	var reset: Button = SsokTheme.button("Restore defaults")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.tooltip_text = "Reset theme, text sizes and sound. Your language stays selected."
	reset.pressed.connect(func() -> void: _saved(Preferences.reset_preferences()))
	actions.add_child(reset)
	close_button = SsokTheme.button("Close")
	close_button.pressed.connect(close_panel)
	actions.add_child(close_button)
	Preferences.changed.connect(sync_values)
	sync_values()


func _picker(parent: Node, caption: String) -> OptionButton:
	var label := Label.new()
	label.text = caption
	parent.add_child(label)
	var picker := OptionButton.new()
	picker.fit_to_longest_item = false
	picker.custom_minimum_size.y = 36
	picker.focus_mode = Control.FOCUS_ALL
	parent.add_child(picker)
	return picker


func _scale_picker(parent: Node, caption: String, key: String) -> OptionButton:
	var picker: OptionButton = _picker(parent, caption)
	picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for scale: float in InterfacePreferences.SCALES:
		picker.add_item("%d%%" % roundi(scale * 100))
	picker.item_selected.connect(func(index: int) -> void: _change_preference(key, InterfacePreferences.SCALES[index]))
	return picker


func sync_values() -> void:
	if not is_instance_valid(language_picker):
		return
	_syncing = true
	language_picker.select(SsokLocale.LOCALES.find(SsokLocale.normalize(TranslationServer.get_locale())))
	appearance_picker.select(["system", "light", "dark"].find(Preferences.values.appearance))
	text_picker.select(InterfacePreferences.SCALES.find(float(Preferences.values.text_scale)))
	code_picker.select(InterfacePreferences.SCALES.find(float(Preferences.values.code_scale)))
	mute_button.set_pressed_no_signal(Preferences.values.muted)
	volume_slider.set_value_no_signal(Preferences.values.volume)
	volume_label.text = "%d%%" % roundi(Preferences.values.volume)
	_syncing = false


func _change_preference(key: String, value: Variant) -> void:
	if not _syncing:
		_saved(Preferences.set_preference(key, value))


func _select_language(index: int) -> void:
	_saved(SsokLocale.select_locale(SsokLocale.LOCALES[index]))
	language_picker.grab_focus.call_deferred()


func _saved(error: Error) -> void:
	if error == OK:
		SsokLocale.bind(feedback, "Settings saved on this device.")
	else:
		SsokLocale.bind(feedback, "Settings applied, but could not be saved. Check storage permissions.")


func open_panel() -> void:
	feedback.text = ""
	sync_values()
	fit_window()
	language_picker.grab_focus()


func fit_window() -> void:
	var available: Vector2 = get_parent().get_viewport().get_visible_rect().size
	var height: int = mini(640, int(available.y) - 2 * (SsokTheme.font_size(36) + 12))
	popup_centered(Vector2i(mini(560, int(available.x) - 32), maxi(200, height)))


func close_panel() -> void:
	hide()
	panel_closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		set_input_as_handled()
		close_panel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		sync_values.call_deferred()
