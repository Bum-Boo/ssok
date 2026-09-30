class_name SsokLocale
extends Node

## Native translations own static UI; bindings retain templates for live dynamic text.
const LOCALES: Array[String] = ["ko", "zh_CN", "ja", "en"]
const NAMES: Array[String] = ["한국어", "简体中文", "日本語", "English"]
const SETTINGS_PATH: String = "user://language.cfg"
static var bundled_font: FontFile
static var ui_font: FontVariation
static var code_font: FontVariation


static func normalize(locale: String) -> String:
	var language: String = locale.replace("-", "_").get_slice("_", 0).to_lower()
	return "zh_CN" if language == "zh" else (language if language in LOCALES else "en")


static func saved_locale(path: String = SETTINGS_PATH) -> String:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(path) == OK:
		var value: Variant = settings.get_value("interface", "language", "")
		if value is String and value in LOCALES:
			return value
	return normalize(OS.get_locale())


static func select_locale(locale: String, persist: bool = true, path: String = SETTINGS_PATH) -> Error:
	if locale not in LOCALES:
		return ERR_INVALID_PARAMETER
	TranslationServer.set_locale(locale)
	update_fonts()
	if not persist:
		return OK
	var settings: ConfigFile = ConfigFile.new()
	settings.set_value("interface", "language", locale)
	return settings.save(path)


static func update_fonts() -> void:
	if ui_font == null:
		bundled_font = load("res://assets/fonts/NotoSansCJK-Regular.ttc") as FontFile
		ui_font = FontVariation.new()
		ui_font.base_font = bundled_font
		code_font = FontVariation.new()
		code_font.base_font = bundled_font
	var locale: String = normalize(TranslationServer.get_locale())
	var face: int = 1 if locale == "ko" else (2 if locale == "zh_CN" else 0)
	ui_font.variation_face_index = face
	code_font.variation_face_index = face + 5


static func bind(label: Label, source: String, arguments: Array = [], translated_arguments: Array[int] = []) -> void:
	label.set_meta("localized_source", source)
	label.set_meta("localized_arguments", arguments.duplicate())
	label.set_meta("localized_translated_arguments", translated_arguments.duplicate())
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = format_text(source, arguments, translated_arguments)


static func format_text(source: String, arguments: Array = [], translated_arguments: Array[int] = []) -> String:
	var translated: String = TranslationServer.translate(source)
	var values: Array = arguments.duplicate()
	for index: int in translated_arguments:
		values[index] = TranslationServer.translate(str(values[index]))
	return translated if values.is_empty() else translated % values


func _ready() -> void:
	var locale: String = saved_locale()
	var args: PackedStringArray = OS.get_cmdline_args()
	var index: int = args.find("--language")
	if index >= 0 and index + 1 < args.size():
		locale = normalize(args[index + 1])
	select_locale(locale, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		update_fonts()
		_refresh.call_deferred(get_tree().root)


func _refresh(node: Node) -> void:
	if node is Label and node.has_meta("localized_source"):
		bind(node as Label, node.get_meta("localized_source"), node.get_meta("localized_arguments"), node.get_meta("localized_translated_arguments"))
	for child: Node in node.get_children():
		_refresh(child)
