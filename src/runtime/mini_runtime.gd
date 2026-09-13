class_name MiniRuntime
extends Node

## Minimal MicroPython-flavoured line interpreter for the first slice (ADR 0004 language layer).
## Knows nothing about boards: hardware comes in through `hardware`, which resolves pins.
##
## Supported:
##   from servo import Servo
##   name = Servo(<pin>)
##   name.write(<angle>)
##   sleep(<seconds>)
##   # comments and blank lines

signal line_started(line_no: int)
signal finished()
signal failed(line_no: int, message: String)

## Object with `servo_on_pin(pin: int) -> ServoDrive`.
var hardware: RunMode
var _servos: Dictionary = {}
var _running := false

var _re_assign := RegEx.create_from_string(r"^(\w+)\s*=\s*Servo\(\s*(?:pin\s*=\s*)?(\d+)\s*\)$")
var _re_write := RegEx.create_from_string(r"^(\w+)\.write\(\s*(-?\d+(?:\.\d+)?)\s*\)$")
var _re_sleep := RegEx.create_from_string(r"^sleep\(\s*(\d+(?:\.\d+)?)\s*\)$")
var _re_import := RegEx.create_from_string(r"^from\s+servo\s+import\s+Servo$")


func run(source: String) -> void:
	if _running:
		return
	_running = true
	_servos.clear()
	var lines := source.split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		line_started.emit(i + 1)
		var error := await _exec(line)
		if not error.is_empty():
			_running = false
			failed.emit(i + 1, error)
			return
	_running = false
	finished.emit()


func is_running() -> bool:
	return _running


func _exec(line: String) -> String:
	if _re_import.search(line):
		return ""
	var m := _re_assign.search(line)
	if m:
		var pin := int(m.get_string(2))
		var servo := hardware.servo_on_pin(pin)
		if servo == null:
			return "Pin %d has nothing connected" % pin
		_servos[m.get_string(1)] = servo
		return ""
	m = _re_write.search(line)
	if m:
		var name := m.get_string(1)
		if not _servos.has(name):
			return "NameError: '%s' is not defined" % name
		(_servos[name] as ServoDrive).write(float(m.get_string(2)))
		return ""
	m = _re_sleep.search(line)
	if m:
		await get_tree().create_timer(float(m.get_string(1))).timeout
		return ""
	return "SyntaxError: %s" % line
