class_name TitleScreen
extends MenuScreen

signal stages_requested
signal lab_requested
signal examples_requested
signal projects_requested

var play_button: Button
var language_picker: OptionButton
var settings: SettingsPanel
var logo: TextureRect
var menu: VBoxContainer


func build() -> void:
	logo = TextureRect.new()
	logo.texture = load("res://assets/branding/ssok.png") as Texture2D
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 150)
	content.add_child(logo)
	var tagline: Label = text(content, "Build a robot, code it, and watch it move.", 20)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu = VBoxContainer.new()
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
	settings_button.clip_text = false
	settings_button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	footer.add_child(settings_button)
	settings = SettingsPanel.new()
	settings.theme = theme
	add_child(settings)
	settings_button.pressed.connect(settings.open_panel)
	settings.panel_closed.connect(settings_button.grab_focus)
	play_button.focus_entered.connect(_on_next_frame.bind(_show_logo_with_play))
	_focus_play_on_start.call_deferred()
	content.minimum_size_changed.connect(_on_next_frame.bind(_fit_to_viewport))
	get_viewport().size_changed.connect(_on_next_frame.bind(_fit_to_viewport))
	_on_next_frame(_fit_to_viewport)


## Runs `callback` once on the next frame, after layout has settled. The one-shot connection
## is dropped with this screen, so nothing resumes on a freed Title.
func _on_next_frame(callback: Callable) -> void:
	if is_inside_tree() and not get_tree().process_frame.is_connected(callback):
		get_tree().process_frame.connect(callback, CONNECT_ONE_SHOT)


## Startup focus for Play. A rebuild or immediate Enter can replace this Title before the deferred
## call runs; a removed Title then leaves focus with whichever screen took its place.
func _focus_play_on_start() -> void:
	if is_inside_tree() and play_button.is_visible_in_tree():
		play_button.grab_focus()


## Short windows tighten the spacing, then shrink the logo (88..150) so the logo and footer fit
## without scrolling. Larger windows keep the defaults; enlarged text still scrolls.
func _fit_to_viewport() -> void:
	if not is_inside_tree():
		return
	var content_gaps: int = content.get_child_count() - 1
	var menu_gaps: int = menu.get_child_count() - 1
	# Height without the logo or gaps, so the result does not depend on the previous fit.
	var gaps: float = content_gaps * content.get_theme_constant("separation") + menu_gaps * menu.get_theme_constant("separation")
	var bare: float = content.get_combined_minimum_size().y - logo.custom_minimum_size.y - gaps
	var available: float = get_viewport_rect().size.y - 64.0 - 2.0
	var content_separation: int = 18
	var menu_separation: int = 12
	var logo_height: float = 150.0
	if bare + content_gaps * content_separation + menu_gaps * menu_separation + logo_height > available:
		content_separation = 12
		menu_separation = 8
		logo_height = floorf(clampf(available - bare - content_gaps * content_separation - menu_gaps * menu_separation, 88.0, 150.0))
	if content.get_theme_constant("separation") != content_separation:
		content.add_theme_constant_override("separation", content_separation)
	if menu.get_theme_constant("separation") != menu_separation:
		menu.add_theme_constant_override("separation", menu_separation)
	if logo.custom_minimum_size.y != logo_height:
		logo.custom_minimum_size.y = logo_height


## Focusing Play (startup, Tab or a return from Settings) can leave follow_focus scrolled past the logo;
## return to the top while Play still fits.
func _show_logo_with_play() -> void:
	if not is_inside_tree() or not play_button.has_focus():
		return
	var scroll := content.get_parent().get_parent().get_parent() as ScrollContainer
	if scroll == null:
		return
	var top: float = play_button.global_position.y - scroll.global_position.y + scroll.scroll_vertical
	if top + play_button.size.y <= scroll.size.y:
		scroll.scroll_vertical = 0


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
