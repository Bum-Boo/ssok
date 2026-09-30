class_name BoardProfile
extends RefCounted

## Declarative hardware API. The block editor is generated from these descriptors.
## No parser or motor execution lives in a board profile (ADR 0004).
const GENERIC_API: Array[Dictionary] = [
	{"id": "servo", "label": "Connect servo",
		"arguments": [{"name": "name", "type": "identifier", "default": "arm"}, {"name": "pin", "type": "integer", "default": 9, "min": 0, "max": 255}]},
	{"id": "write", "label": "Set servo angle",
		"arguments": [{"name": "name", "type": "identifier", "default": "arm"}, {"name": "angle", "type": "number", "default": 90, "min": 0, "max": 180}]},
	{"id": "write_relative", "label": "Set relative angle",
		"arguments": [{"name": "name", "type": "identifier", "default": "arm"}, {"name": "angle", "type": "number", "default": 0, "min": -90, "max": 90}]},
	{"id": "sleep", "label": "Wait",
		"arguments": [{"name": "seconds", "type": "number", "default": 0.5, "min": 0, "max": 60}]},
]


const LEARNING_API: Array[Dictionary] = [
	{"id": "motor", "label": "Connect wheel motor", "arguments": [{"name": "name", "type": "identifier", "default": "left"}, {"name": "pin", "type": "integer", "default": 0, "min": 0, "max": 255}]},
	{"id": "motor_on", "label": "Run wheel motor", "arguments": [{"name": "name", "type": "identifier", "default": "left"}, {"name": "direction", "type": "choice", "default": "forward", "choices": ["forward", "reverse"]}, {"name": "speed", "type": "number", "default": 40, "min": 0, "max": 100}]},
	{"id": "motor_stop", "label": "Stop wheel motor", "arguments": [{"name": "name", "type": "identifier", "default": "left"}, {"name": "mode", "type": "choice", "default": "brake", "choices": ["brake", "coast"]}]},
	{"id": "sonar", "label": "Connect distance sensor", "arguments": [{"name": "name", "type": "identifier", "default": "sonar"}, {"name": "trigger", "type": "integer", "default": 1, "min": 0, "max": 255}, {"name": "echo", "type": "integer", "default": 2, "min": 0, "max": 255}]},
	{"id": "distance", "label": "Read distance", "arguments": [{"name": "variable", "type": "identifier", "default": "distance"}, {"name": "name", "type": "identifier", "default": "sonar"}]},
	{"id": "variable", "label": "Set variable", "arguments": [{"name": "name", "type": "identifier", "default": "count"}, {"name": "expression", "type": "expression", "default": "0"}]},
	{"id": "while", "label": "Repeat while", "arguments": [{"name": "expression", "type": "expression", "default": "True"}]},
	{"id": "if", "label": "If", "arguments": [{"name": "expression", "type": "expression", "default": "True"}]},
	{"id": "elif", "label": "Else if", "arguments": [{"name": "expression", "type": "expression", "default": "True"}]},
	{"id": "else", "label": "Else", "arguments": []},
	{"id": "stop", "label": "Stop all motors", "arguments": []},
]

var sleep_unit_seconds: float = 1.0
var pin_constants: Dictionary = {}

var id: String = "generic-servo"
var display_name: String = "Virtual servo board"
var recommended_language: String = "ssok-python"
var api: Array[Dictionary] = GENERIC_API.duplicate(true)


func _init() -> void:
	api.append_array(LEARNING_API.duplicate(true))


func operation(operation_id: String) -> Dictionary:
	for entry: Dictionary in api:
		if entry.id == operation_id:
			return entry
	return {}


func defaults(operation_id: String) -> Dictionary:
	var descriptor: Dictionary = operation(operation_id)
	if descriptor.is_empty():
		return {}
	var result: Dictionary = {"op": operation_id, "args": {}}
	for parameter: Dictionary in descriptor.arguments:
		result.args[parameter.name] = parameter.default
	return result


static func for_id(profile_id: String) -> BoardProfile:
	var result := BoardProfile.new()
	if profile_id == "microbit":
		result.id = "microbit"
		result.display_name = "micro:bit V2"
		result.sleep_unit_seconds = 0.001
		result.api[0].arguments[1].default = 0
		result.api[3].arguments[0].default = 500
		result.api[3].arguments[0].max = 60000
		for pin: int in [0, 1, 2, 8, 12, 16]:
			result.pin_constants["pin%d" % pin] = pin
	elif profile_id == "uno":
		result.id = "uno"
		result.display_name = "Arduino Uno R3"
	return result
