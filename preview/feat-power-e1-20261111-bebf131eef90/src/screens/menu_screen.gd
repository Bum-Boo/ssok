class_name MenuScreen
extends Control

## Shared frame for full-screen 2D menus: themed background, centered column and cards.
## Menus only choose what to do next; building and running happen in the workshop scene.

signal back_requested

var content: VBoxContainer
var _preferences: InterfacePreferences


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = SsokTheme.build()
	var background := ColorRect.new()
	background.name = "Background"
	background.color = SsokTheme.BG_SUNKEN
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	scroll.add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	content = VBoxContainer.new()
	content.custom_minimum_size.x = minf(980.0, maxf(320.0, get_viewport_rect().size.x - 64.0))
	content.add_theme_constant_override("separation", 18)
	center.add_child(content)
	_preferences = get_node_or_null("/root/Preferences") as InterfacePreferences
	build()
	get_viewport().size_changed.connect(_resize)


## Subclasses add their widgets to `content` here.
func build() -> void:
	pass


func _resize() -> void:
	if content != null:
		content.custom_minimum_size.x = minf(980.0, maxf(320.0, get_viewport_rect().size.x - 64.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not back_requested.get_connections().is_empty():
		back_requested.emit()
		get_viewport().set_input_as_handled()


func header(title: String, subtitle: String = "", with_back: bool = true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	if with_back:
		var back: Button = SsokTheme.button("Back", "arrow-left")
		back.name = "BackButton"
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		back.clip_text = false
		back.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		back.pressed.connect(func() -> void: back_requested.emit())
		row.add_child(back)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", SsokTheme.font_size(30))
	heading.add_theme_color_override("font_color", SsokTheme.ACCENT)
	titles.add_child(heading)
	if not subtitle.is_empty():
		var detail := Label.new()
		detail.text = subtitle
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.label_settings = SsokTheme.dim_settings()
		titles.add_child(detail)


static func card(minimum_width: float = 280.0) -> Array:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minimum_width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = SsokTheme.BG_RAISED
	style.border_color = SsokTheme.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return [panel, box]


static func text(parent: Control, value: String, size: int = 15, dim: bool = false, color: Color = Color.TRANSPARENT) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", SsokTheme.font_size(size))
	if dim:
		label.add_theme_color_override("font_color", SsokTheme.TEXT_DIM)
	elif color.a > 0.0:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


static func primary(button: Button) -> Button:
	button.theme_type_variation = &"PrimaryButton"
	button.add_theme_color_override("icon_normal_color", SsokTheme.BG_SUNKEN)
	return button
