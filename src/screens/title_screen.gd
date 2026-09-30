class_name TitleScreen
extends MenuScreen

signal stages_requested
signal lab_requested
signal examples_requested
signal projects_requested

var play_button: Button
var language_picker: OptionButton
var settings: SettingsPanel


func build() -> void:
	var logo := TextureRect.new()
	logo.texture = load("res://assets/branding/ssok.png") as Texture2D
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 150)
	content.add_child(logo)
	var tagline: Label = text(content, "Build a robot, code it, and watch it move.", 20)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	menu.custom_minimum_size.x = 380
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(menu)
	play_button = _menu_button(menu, "Play stages", "flag", "Clear challenges one by one.", stages_requested)
	primary(play_button)
	_menu_button(menu, "Free building", "hammer", "Build anything with every part. You can turn it into a challenge.", lab_requested)
	_menu_button(menu, "Explore examples", "sparkles", "Try finished robots: arms, walkers and humanoids.", examples_requested)
	_menu_button(menu, "Open my project", "folder-open", "Continue a saved build.", projects_requested)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 10)
	content.add_child(footer)
	language_picker = OptionButton.new()
	language_picker.name = "LanguagePicker"
	language_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for language_name: String in SsokLocale.NAMES:
		language_picker.add_item(language_name)
	language_picker.select(SsokLocale.LOCALES.find(SsokLocale.normalize(TranslationServer.get_locale())))
	language_picker.item_selected.connect(func(index: int) -> void:
		SsokLocale.select_locale(SsokLocale.LOCALES[index])
		language_picker.grab_focus.call_deferred())
	footer.add_child(language_picker)
	var settings_button: Button = SsokTheme.button("Settings", "cog")
	settings_button.name = "SettingsButton"
	footer.add_child(settings_button)
	settings = SettingsPanel.new()
	settings.theme = theme
	add_child(settings)
	settings_button.pressed.connect(settings.open_panel)
	settings.panel_closed.connect(settings_button.grab_focus)
	play_button.grab_focus.call_deferred()


func _menu_button(parent: Control, label: String, icon_name: String, detail: String, action: Signal) -> Button:
	var button: Button = SsokTheme.button(label, icon_name)
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size", SsokTheme.font_size(18))
	button.tooltip_text = detail
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void: action.emit())
	parent.add_child(button)
	var caption: Label = text(parent, detail, 13, true)
	caption.custom_minimum_size.y = 0
	return button


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and language_picker != null:
		language_picker.select(SsokLocale.LOCALES.find(SsokLocale.normalize(TranslationServer.get_locale())))
