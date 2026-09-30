class_name InterfacePreferences
extends Node

signal changed

const PATH: String = "user://interface.cfg"
const DEFAULTS: Dictionary = {"appearance": "system", "text_scale": 1.0, "code_scale": 1.0, "muted": false, "volume": 60.0}
const SCALES: Array[float] = [1.0, 1.15, 1.3, 1.5, 2.0]
var values: Dictionary = DEFAULTS.duplicate()
var _poll_seconds: float = 0.0
var _last_system_dark: bool = true


func _ready() -> void:
	load_preferences()
	_last_system_dark = dark_appearance()
	if DisplayServer.is_dark_mode_supported():
		DisplayServer.set_system_theme_change_callback(_system_theme_changed)


func _process(delta: float) -> void:
	if not OS.has_feature("web") or values.appearance != "system":
		return
	_poll_seconds += delta
	if _poll_seconds < 1.0:
		return
	_poll_seconds = 0.0
	var current: bool = dark_appearance()
	if current != _last_system_dark:
		_last_system_dark = current
		changed.emit()


func load_preferences(path: String = PATH) -> void:
	values = DEFAULTS.duplicate()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for key: String in DEFAULTS:
		var value: Variant = config.get_value("interface", key, DEFAULTS[key])
		if valid(key, value):
			values[key] = value


func valid(key: String, value: Variant) -> bool:
	match key:
		"appearance":
			return value is String and value in ["system", "light", "dark"]
		"text_scale", "code_scale":
			return (value is float or value is int) and float(value) in SCALES
		"muted":
			return value is bool
		"volume":
			return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 100.0
	return false


func set_preference(key: String, value: Variant, path: String = PATH) -> Error:
	if not valid(key, value):
		return ERR_INVALID_PARAMETER
	values[key] = value
	changed.emit()
	return save_preferences(path)


func save_preferences(path: String = PATH) -> Error:
	var config := ConfigFile.new()
	for key: String in DEFAULTS:
		config.set_value("interface", key, values[key])
	return config.save(path)


func reset_preferences(path: String = PATH) -> Error:
	values = DEFAULTS.duplicate()
	changed.emit()
	return save_preferences(path)


func dark_appearance() -> bool:
	if values.appearance != "system":
		return values.appearance == "dark"
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("window.matchMedia('(prefers-color-scheme: dark)').matches"))
	return DisplayServer.is_dark_mode() if DisplayServer.is_dark_mode_supported() else true


func effects_gain() -> float:
	return 0.0 if values.muted else float(values.volume) / 100.0


func _system_theme_changed() -> void:
	if values.appearance == "system":
		changed.emit()
