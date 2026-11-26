class_name PartCard
extends PanelContainer

## What a tray part is: its picture, its name, the real product behind it and that product's
## ratings (assets/part_specs.json). Shown in the parts tray for the part under the pointer.

const SPECS: String = "res://assets/part_specs.json"
const THUMBNAILS: String = "res://assets/part_thumbnails/%s.png"

static var _specs: Dictionary = {}

var definition: PartDef
var _picture: TextureRect
var _name: Label
var _product: Label
var _rows: GridContainer
var _source: Label


static func specs() -> Dictionary:
	if _specs.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPECS))
		if parsed is Dictionary:
			_specs = parsed.get("parts", {})
	return _specs


static func thumbnail(id: StringName) -> Texture2D:
	var path: String = THUMBNAILS % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _ready() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = SsokTheme.BG_SUNKEN
	frame.border_color = SsokTheme.BORDER
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(4)
	frame.set_content_margin_all(10)
	add_theme_stylebox_override("panel", frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	_picture = TextureRect.new()
	_picture.custom_minimum_size = Vector2(64, 64)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(_picture)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(titles)
	_name = Label.new()
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.label_settings = SsokTheme.title_settings()
	titles.add_child(_name)
	_product = Label.new()
	_product.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_product.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_product.label_settings = SsokTheme.dim_settings()
	titles.add_child(_product)
	_rows = GridContainer.new()
	_rows.columns = 2
	_rows.add_theme_constant_override("h_separation", 10)
	_rows.add_theme_constant_override("v_separation", 2)
	box.add_child(_rows)
	_source = Label.new()
	_source.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_source.label_settings = SsokTheme.dim_settings()
	box.add_child(_source)
	visible = definition != null
	if definition != null:
		show_part(definition)


func show_part(part: PartDef) -> void:
	definition = part
	if not is_node_ready():
		return
	visible = true
	_picture.texture = thumbnail(part.id)
	_name.text = part.display_name
	var spec: Dictionary = specs().get(String(part.id), {})
	_product.visible = spec.has("product")
	if _product.visible:
		_product.text = tr("Real part: %s") % spec.product
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for row: Array in spec.get("rows", []):
		var key := Label.new()
		key.text = row[0]
		key.label_settings = SsokTheme.dim_settings()
		_rows.add_child(key)
		var value := Label.new()
		value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		value.text = row[1]
		_rows.add_child(value)
	_rows.visible = _rows.get_child_count() > 0
	var source: String = spec.get("source", "")
	_source.visible = not source.is_empty()
	if _source.visible:
		_source.text = tr("Source: %s") % source


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and definition != null:
		show_part(definition)
