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

var id: String = "generic-servo"
var display_name: String = "Virtual servo board"
var recommended_language: String = "ssok-python"
var api: Array[Dictionary] = GENERIC_API.duplicate(true)


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
