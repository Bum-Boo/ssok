class_name SsokTheme
extends RefCounted

## Shared palette, typography and visible focus states for the workshop UI.

static var BG: Color = Color("171c24")
static var BG_RAISED: Color = Color("222a35")
static var BG_SUNKEN: Color = Color("11151c")
static var ACCENT: Color = Color("72d9bb")
static var ACCENT_DOWN: Color = Color("225b51")
static var TEXT: Color = Color("e7edf4")
static var TEXT_DIM: Color = Color("a3afbe")
static var BORDER: Color = Color("303b49")


static var ERROR: Color = Color("ff9292")
static var ui_scale: float = 1.0
static var code_scale: float = 1.0
static var dark: bool = true


static func palette() -> Dictionary:
	return {"BG": BG, "BG_RAISED": BG_RAISED, "BG_SUNKEN": BG_SUNKEN, "ACCENT": ACCENT, "ACCENT_DOWN": ACCENT_DOWN, "TEXT": TEXT, "TEXT_DIM": TEXT_DIM, "BORDER": BORDER, "ERROR": ERROR}


static func configure(use_dark: bool, text_scale: float, source_scale: float) -> void:
	dark = use_dark
	ui_scale = text_scale
	code_scale = source_scale
	BG = Color("171c24" if dark else "f7f9fc")
	BG_RAISED = Color("222a35" if dark else "e7edf4")
	BG_SUNKEN = Color("11151c" if dark else "ffffff")
	ACCENT = Color("72d9bb" if dark else "166e59")
	ACCENT_DOWN = Color("225b51" if dark else "d6efe7")
	TEXT = Color("e7edf4" if dark else "172330")
	TEXT_DIM = Color("a3afbe" if dark else "4c5b6b")
	BORDER = Color("303b49" if dark else "9aabbc")
	ERROR = Color("ff9292" if dark else "a51d36")


static func font_size(base: int) -> int:
	return roundi(base * ui_scale)


static func remember(node: Node) -> void:
	# Overrides retain their semantic role and unscaled size across preference changes.
	if node is Control or node is Window:
		var colors: Dictionary = node.get_meta("ssok_colors", {})
		var sizes: Dictionary = node.get_meta("ssok_sizes", {})
		var styles: Dictionary = node.get_meta("ssok_styles", {})
		for property: Dictionary in node.get_property_list():
			var name: String = property.name
			if name.begins_with("theme_override_colors/") and not colors.has(name):
				var role: String = _color_role(node.get(name))
				if not role.is_empty():
					colors[name] = role
			elif name.begins_with("theme_override_font_sizes/") and not sizes.has(name) and node.has_theme_font_size_override(name.get_slice("/", 1)):
				sizes[name] = float(node.get(name)) / ui_scale
			elif name.begins_with("theme_override_styles/") and not styles.has(name):
				var style: Variant = node.get(name)
				if style is StyleBoxFlat:
					var fields: Dictionary = {}
					for field: String in ["bg_color", "border_color"]:
						var role: String = _color_role(style.get(field))
						if not role.is_empty():
							fields[field] = role
					styles[name] = fields
		node.set_meta("ssok_colors", colors)
		node.set_meta("ssok_sizes", sizes)
		node.set_meta("ssok_styles", styles)
		if node is Control and node.modulate != Color.WHITE and not node.has_meta("ssok_modulate"):
			var role: String = _color_role(node.modulate)
			if not role.is_empty():
				node.set_meta("ssok_modulate", role)
	if node is Label and node.label_settings != null and not node.has_meta("ssok_label_size"):
		node.set_meta("ssok_label_size", float(node.label_settings.font_size) / ui_scale)
		node.set_meta("ssok_label_color", _color_role(node.label_settings.font_color))
	for child: Node in node.get_children():
		remember(child)


static func adapt(node: Node) -> void:
	if node is Control or node is Window:
		var colors: Dictionary = node.get_meta("ssok_colors", {})
		for name: String in colors:
			node.set(name, palette()[colors[name]])
		var sizes: Dictionary = node.get_meta("ssok_sizes", {})
		for name: String in sizes:
			node.set(name, roundi(float(sizes[name]) * ui_scale))
		var styles: Dictionary = node.get_meta("ssok_styles", {})
		for name: String in styles:
			var style: StyleBoxFlat = node.get(name) as StyleBoxFlat
			if style != null:
				for field: String in styles[name]:
					style.set(field, palette()[styles[name][field]])
		if node is Control and node.has_meta("ssok_modulate"):
			node.modulate = palette()[node.get_meta("ssok_modulate")]
	if node is Label and node.label_settings != null and node.has_meta("ssok_label_size"):
		node.label_settings.font_size = roundi(float(node.get_meta("ssok_label_size")) * ui_scale)
		var role: String = node.get_meta("ssok_label_color", "")
		if not role.is_empty():
			node.label_settings.font_color = palette()[role]
	for child: Node in node.get_children():
		adapt(child)


static func _color_role(value: Variant) -> String:
	if value is Color:
		for role: String in palette():
			if value == palette()[role]:
				return role
	return ""


static func code_highlighter() -> CodeHighlighter:
	var syntax := CodeHighlighter.new()
	syntax.number_color = Color("e6bb84" if dark else "895214")
	syntax.function_color = Color("86b9ef" if dark else "1a558c")
	syntax.symbol_color = TEXT_DIM
	syntax.add_keyword_color("from", Color("c9a1ee" if dark else "70449b"))
	syntax.add_keyword_color("import", Color("c9a1ee" if dark else "70449b"))
	syntax.add_keyword_color("Servo", ACCENT)
	syntax.add_color_region("#", "", Color("8193a7" if dark else "526273"), true)
	return syntax


static func build() -> Theme:
	var theme := Theme.new()
	populate(theme)
	return theme


static func populate(theme: Theme) -> void:
	if SsokLocale.ui_font == null:
		SsokLocale.update_fonts()
	theme.default_font = SsokLocale.ui_font
	theme.set_font(&"font", &"CodeEdit", SsokLocale.code_font)
	theme.default_font_size = font_size(14)

	theme.set_stylebox(&"panel", &"PanelContainer", _flat(BG, 12, BORDER, 10))
	theme.set_stylebox(&"panel", &"Panel", _flat(BG, 12, BORDER, 10))
	var window_border: StyleBoxFlat = _flat(BG, 0, BORDER, 8)
	window_border.expand_margin_top = font_size(36)
	theme.set_stylebox(&"embedded_border", &"Window", window_border)
	theme.set_stylebox(&"embedded_unfocused_border", &"Window", window_border)
	theme.set_color(&"title_color", &"Window", TEXT)
	theme.set_color(&"title_unfocused_color", &"Window", TEXT_DIM)
	var close_image := Image.new()
	close_image.load_svg_from_string("<svg xmlns='http://www.w3.org/2000/svg' width='20' height='20'><path d='M4 4L16 16M16 4L4 16' stroke='#%s' stroke-width='2'/></svg>" % TEXT.to_html(false))
	var close_texture: ImageTexture = ImageTexture.create_from_image(close_image)
	theme.set_icon(&"close", &"Window", close_texture)
	theme.set_icon(&"close_pressed", &"Window", close_texture)
	theme.set_font_size(&"title_font_size", &"Window", font_size(16))
	theme.set_constant(&"title_height", &"Window", font_size(36))

	theme.set_stylebox(&"normal", &"Button", _flat(BG_RAISED, 8, Color.TRANSPARENT, 7))
	theme.set_stylebox(&"hover", &"Button", _flat(BG_RAISED.lightened(0.12) if dark else BG_RAISED.darkened(0.06), 8, ACCENT, 7))
	theme.set_stylebox(&"pressed", &"Button", _flat(ACCENT_DOWN, 8, Color.TRANSPARENT, 7))
	theme.set_stylebox(&"focus", &"Button", _flat(Color.TRANSPARENT, 8, ACCENT, 7))
	theme.set_stylebox(&"disabled", &"Button", _flat(BG_RAISED.darkened(0.2), 8, Color.TRANSPARENT, 7))
	theme.set_color(&"font_color", &"Button", TEXT)
	theme.set_color(&"font_focus_color", &"Button", TEXT)
	theme.set_color(&"font_hover_color", &"Button", TEXT)
	theme.set_color(&"font_pressed_color", &"Button", TEXT)
	theme.set_color(&"font_disabled_color", &"Button", TEXT_DIM)
	for state: StringName in [&"normal", &"hover", &"pressed"]:
		theme.set_stylebox(state, &"CheckBox", _flat(Color.TRANSPARENT, 6, Color.TRANSPARENT, 4))
	theme.set_stylebox(&"focus", &"CheckBox", _flat(Color.TRANSPARENT, 6, ACCENT, 4))
	for state: StringName in [&"unchecked", &"checked"]:
		var checkbox_image := Image.new()
		var mark: String = "<path d='M5 10L8 13L15 6' fill='none' stroke='#%s' stroke-width='2'/>" % BG_SUNKEN.to_html(false) if state == &"checked" else ""
		checkbox_image.load_svg_from_string("<svg xmlns='http://www.w3.org/2000/svg' width='20' height='20'><rect x='2' y='2' width='16' height='16' rx='3' fill='%s' stroke='#%s' stroke-width='2'/>%s</svg>" % ["#" + ACCENT.to_html(false) if state == &"checked" else "none", TEXT_DIM.to_html(false), mark])
		theme.set_icon(state, &"CheckBox", ImageTexture.create_from_image(checkbox_image))
	theme.set_color(&"font_focus_color", &"OptionButton", TEXT)
	theme.set_constant(&"modulate_arrow", &"OptionButton", 1)

	theme.set_stylebox(&"normal", &"CheckButton", _flat(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0))
	theme.set_stylebox(&"hover", &"CheckButton", _flat(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0))
	theme.set_stylebox(&"pressed", &"CheckButton", _flat(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0))
	theme.set_stylebox(&"focus", &"CheckButton", _flat(Color.TRANSPARENT, 4, ACCENT, 0))
	theme.set_color(&"font_color", &"CheckButton", TEXT)
	theme.set_color(&"font_pressed_color", &"CheckButton", ACCENT)

	theme.set_color(&"font_color", &"Label", TEXT)

	theme.set_stylebox(&"normal", &"CodeEdit", _flat(BG_SUNKEN, 10, BORDER, 8))
	theme.set_stylebox(&"focus", &"CodeEdit", _flat(BG_SUNKEN, 10, ACCENT, 8))
	theme.set_color(&"font_color", &"CodeEdit", TEXT)
	theme.set_color(&"background_color", &"CodeEdit", BG_SUNKEN)
	theme.set_color(&"current_line_color", &"CodeEdit", Color(1, 1, 1, 0.04) if dark else Color(0, 0, 0, 0.04))
	theme.set_color(&"line_number_color", &"CodeEdit", TEXT_DIM)
	theme.set_font_size(&"font_size", &"CodeEdit", roundi(15 * code_scale))

	theme.set_stylebox(&"separator", &"HSeparator", _flat(BORDER, 0, Color.TRANSPARENT, 0))
	theme.set_constant(&"separation", &"HSeparator", 10)
	theme.set_constant(&"separation", &"VBoxContainer", 8)
	theme.set_constant(&"separation", &"HBoxContainer", 8)
	theme.set_constant(&"h_separation", &"Button", 10)
	theme.set_constant(&"icon_max_width", &"Button", 18)
	theme.set_constant(&"icon_max_width", &"CheckButton", 24)
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
	theme.set_color(&"font_hover_color", &"PopupMenu", TEXT)
	theme.set_color(&"font_disabled_color", &"PopupMenu", TEXT_DIM)
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
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		theme.set_color(state, &"PrimaryButton", BG_SUNKEN)
	for state: StringName in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_focus_color"]:
		theme.set_color(state, &"Button", TEXT)
		theme.set_color(state, &"PrimaryButton", BG_SUNKEN)
	theme.set_type_variation(&"QuietButton", &"Button")
	theme.set_stylebox(&"normal", &"QuietButton", _flat(Color.TRANSPARENT, 8, Color.TRANSPARENT, 6))
	theme.set_type_variation(&"SectionLabel", &"Label")
	theme.set_color(&"font_color", &"SectionLabel", TEXT_DIM)
	theme.set_font_size(&"font_size", &"SectionLabel", font_size(12))


static func icon(name: String) -> Texture2D:
	return load("res://assets/icons/lucide/" + name + ".svg") as Texture2D


static func button(text: String, icon_name: String = "") -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size.y = 36
	control.custom_minimum_size.x = 36 if text.length() <= 2 else 80
	control.focus_mode = Control.FOCUS_ALL
	control.clip_text = true
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	control.tooltip_text = text
	if not icon_name.is_empty():
		control.icon = icon(icon_name)
	return control


static func title_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = SsokLocale.ui_font
	settings.font_size = font_size(17)
	settings.font_color = TEXT
	return settings


static func dim_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = SsokLocale.ui_font
	settings.font_size = font_size(13)
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
