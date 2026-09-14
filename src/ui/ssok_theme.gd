class_name SsokTheme
extends RefCounted

## Code-built Theme for the prototype shell so every panel, button and code
## box shares one palette until a human composes the real UI in the editor.

const BG := Color(0.11, 0.12, 0.15, 0.94)
const BG_RAISED := Color(0.16, 0.18, 0.22)
const BG_SUNKEN := Color(0.07, 0.08, 0.10)
const ACCENT := Color(0.30, 0.62, 1.0)
const ACCENT_DOWN := Color(0.22, 0.48, 0.82)
const TEXT := Color(0.92, 0.93, 0.95)
const TEXT_DIM := Color(0.62, 0.66, 0.72)
const BORDER := Color(1, 1, 1, 0.06)


static func build() -> Theme:
	var theme := Theme.new()
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
	return theme


static func title_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = 17
	settings.font_color = Color.WHITE
	return settings


static func dim_settings() -> LabelSettings:
	var settings := LabelSettings.new()
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
