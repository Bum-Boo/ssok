class_name SsokTheme
extends RefCounted

## Shared palette, typography and visible focus states for the workshop UI.

const BG := Color("171c24")
const BG_RAISED := Color("222a35")
const BG_SUNKEN := Color("11151c")
const ACCENT := Color("72d9bb")
const ACCENT_DOWN := Color("225b51")
const TEXT := Color("e7edf4")
const TEXT_DIM := Color("a3afbe")
const BORDER := Color("303b49")


static func build() -> Theme:
	var theme := Theme.new()
	SsokLocale.update_fonts()
	theme.default_font = SsokLocale.ui_font
	theme.set_font(&"font", &"CodeEdit", SsokLocale.code_font)
	theme.default_font_size = 14

	theme.set_stylebox(&"panel", &"PanelContainer", _flat(BG, 12, BORDER, 10))
	theme.set_stylebox(&"panel", &"Panel", _flat(BG, 12, BORDER, 10))

	theme.set_stylebox(&"normal", &"Button", _flat(BG_RAISED, 8, Color.TRANSPARENT, 7))
	theme.set_stylebox(&"hover", &"Button", _flat(BG_RAISED.lightened(0.12), 8, ACCENT, 7))
	theme.set_stylebox(&"pressed", &"Button", _flat(ACCENT_DOWN, 8, Color.TRANSPARENT, 7))
	theme.set_stylebox(&"focus", &"Button", _flat(Color.TRANSPARENT, 8, ACCENT, 7))
	theme.set_stylebox(&"disabled", &"Button", _flat(BG_RAISED.darkened(0.2), 8, Color.TRANSPARENT, 7))
	theme.set_color(&"font_color", &"Button", TEXT)
	theme.set_color(&"font_hover_color", &"Button", Color.WHITE)
	theme.set_color(&"font_pressed_color", &"Button", Color.WHITE)
	theme.set_color(&"font_disabled_color", &"Button", TEXT_DIM)

	theme.set_stylebox(&"normal", &"CheckButton", _flat(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0))
	theme.set_stylebox(&"hover", &"CheckButton", _flat(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0))
	theme.set_stylebox(&"pressed", &"CheckButton", _flat(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0))
	theme.set_stylebox(&"focus", &"CheckButton", _flat(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0))
	theme.set_color(&"font_color", &"CheckButton", TEXT)
	theme.set_color(&"font_pressed_color", &"CheckButton", ACCENT)

	theme.set_color(&"font_color", &"Label", TEXT)

	theme.set_stylebox(&"normal", &"CodeEdit", _flat(BG_SUNKEN, 10, BORDER, 8))
	theme.set_stylebox(&"focus", &"CodeEdit", _flat(BG_SUNKEN, 10, ACCENT, 8))
	theme.set_color(&"font_color", &"CodeEdit", TEXT)
	theme.set_color(&"background_color", &"CodeEdit", BG_SUNKEN)
	theme.set_color(&"current_line_color", &"CodeEdit", Color(1, 1, 1, 0.04))
	theme.set_color(&"line_number_color", &"CodeEdit", TEXT_DIM)
	theme.set_font_size(&"font_size", &"CodeEdit", 15)

	theme.set_stylebox(&"separator", &"HSeparator", _flat(BORDER, 0, Color.TRANSPARENT, 0))
	theme.set_constant(&"separation", &"HSeparator", 10)
	theme.set_constant(&"separation", &"VBoxContainer", 8)
	theme.set_constant(&"separation", &"HBoxContainer", 8)
	theme.set_constant(&"h_separation", &"Button", 10)
	theme.set_constant(&"icon_max_width", &"Button", 18)
	theme.set_constant(&"icon_max_width", &"CheckButton", 0)
	for type: StringName in [&"LineEdit", &"TextEdit"]:
		theme.set_stylebox(&"normal", type, _flat(BG_SUNKEN, 10, BORDER, 6))
		theme.set_stylebox(&"focus", type, _flat(BG_SUNKEN, 10, ACCENT, 6))
		theme.set_color(&"font_color", type, TEXT)
		theme.set_color(&"font_placeholder_color", type, TEXT_DIM)
		theme.set_color(&"caret_color", type, ACCENT)
		theme.set_color(&"selection_color", type, ACCENT_DOWN)
	theme.set_stylebox(&"panel", &"PopupMenu", _flat(BG, 8, BORDER, 8))
	theme.set_stylebox(&"hover", &"PopupMenu", _flat(BG_RAISED, 8, Color.TRANSPARENT, 4))
	theme.set_color(&"font_color", &"PopupMenu", TEXT)
	theme.set_constant(&"v_separation", &"PopupMenu", 12)
	theme.set_stylebox(&"panel", &"TabContainer", _flat(BG, 12, Color.TRANSPARENT, 0))
	for type: StringName in [&"TabContainer", &"TabBar"]:
		theme.set_stylebox(&"tab_selected", type, _flat(BG_RAISED, 10, BORDER, 6))
		theme.set_stylebox(&"tab_unselected", type, _flat(BG, 10, Color.TRANSPARENT, 6))
		theme.set_stylebox(&"tab_hovered", type, _flat(BG_RAISED, 10, Color.TRANSPARENT, 6))
		theme.set_color(&"font_selected_color", type, ACCENT)
		theme.set_color(&"font_unselected_color", type, TEXT_DIM)
	theme.set_type_variation(&"PrimaryButton", &"Button")
	theme.set_stylebox(&"normal", &"PrimaryButton", _flat(ACCENT, 10, Color.TRANSPARENT, 6))
	theme.set_stylebox(&"hover", &"PrimaryButton", _flat(ACCENT.lightened(0.12), 10, Color.TRANSPARENT, 6))
	theme.set_stylebox(&"pressed", &"PrimaryButton", _flat(ACCENT.darkened(0.15), 10, Color.TRANSPARENT, 6))
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		theme.set_color(state, &"PrimaryButton", BG_SUNKEN)
	theme.set_type_variation(&"QuietButton", &"Button")
	theme.set_stylebox(&"normal", &"QuietButton", _flat(Color.TRANSPARENT, 8, Color.TRANSPARENT, 6))
	theme.set_type_variation(&"SectionLabel", &"Label")
	theme.set_color(&"font_color", &"SectionLabel", TEXT_DIM)
	theme.set_font_size(&"font_size", &"SectionLabel", 12)
	return theme


static func icon(name: String) -> Texture2D:
	return load("res://assets/icons/lucide/" + name + ".svg") as Texture2D


static func button(text: String, icon_name: String = "") -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size.y = 36
	control.focus_mode = Control.FOCUS_ALL
	if not icon_name.is_empty():
		control.icon = icon(icon_name)
	return control


static func title_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = SsokLocale.ui_font
	settings.font_size = 17
	settings.font_color = Color.WHITE
	return settings


static func dim_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = SsokLocale.ui_font
	settings.font_size = 13
	settings.font_color = TEXT_DIM
	return settings


static func _flat(fill: Color, margin: int, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.anti_aliasing = true
	return style
