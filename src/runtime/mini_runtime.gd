class_name MiniRuntime
extends Node

## Minimal MicroPython-flavoured line interpreter for the first slice (ADR 0004 language layer).
## Knows nothing about boards: hardware comes in through `hardware`, which resolves pins.
##
## Supported:
##   from servo import Servo
##   name = Servo(<pin>)
##   name.write(<angle>)
##   name.write_relative(<signed_angle>)
##   sleep(<seconds>)
##   # comments and blank lines

signal line_started(line_no: int)
signal finished()
signal failed(line_no: int, message: String)
signal stopped()

const MAX_SOURCE_BYTES: int = 65536
const MAX_LINES: int = 2048
const MAX_WAIT_SECONDS: float = 60.0

## Object with `servo_on_pin(pin: int) -> ServoDrive`.
var hardware: RunMode
var _servos: Dictionary = {}
var _running := false
var _execution_id: int = 0

var _re_assign := RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*Servo\(\s*(?:pin\s*=\s*)?(\d+)\s*\)$")
var _re_write := RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\.(write|write_relative)\(\s*(-?\d+(?:\.\d+)?)\s*\)$")
var _re_sleep := RegEx.create_from_string(r"^sleep\(\s*(\d+(?:\.\d+)?)\s*\)$")
var _re_import := RegEx.create_from_string(r"^from\s+servo\s+import\s+Servo$")


func run(source: String) -> void:
	if _running:
		return
	_execution_id += 1
	var execution_id: int = _execution_id
	_running = true
	_servos.clear()
	var validation: Dictionary = validate(source)
	if not validation.is_empty():
		_running = false
		failed.emit(validation.line, validation.error)
		return
	var lines := source.split("\n")
	for i in lines.size():
		if execution_id != _execution_id:
			return
		var line := lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		line_started.emit(i + 1)
		if execution_id != _execution_id:
			return
		var error := await _exec(line)
		# A stopped sleep must not resume against a new graph or a newer program.
		if execution_id != _execution_id:
			return
		if not error.is_empty():
			_running = false
			failed.emit(i + 1, error)
			return
	_running = false
	finished.emit()


func validate(source: String, check_hardware: bool = true) -> Dictionary:
	if source.to_utf8_buffer().size() > MAX_SOURCE_BYTES:
		return {"line": 1, "error": tr("This program is too large. Use at most 2048 lines and 64 KiB.")}
	var lines: PackedStringArray = source.split("\n")
	if lines.size() > MAX_LINES:
		return {"line": 1, "error": tr("This program is too large. Use at most 2048 lines and 64 KiB.")}
	var names: Dictionary = {}
	for index: int in lines.size():
		var line: String = lines[index].strip_edges()
		if line.is_empty() or line.begins_with("#") or _re_import.search(line) != null:
			continue
		var error: String = ""
		var binding: RegExMatch = _re_assign.search(line)
		var command: RegExMatch = _re_write.search(line)
		var wait: RegExMatch = _re_sleep.search(line)
		if binding != null:
			if binding.get_string(2).length() > 18:
				error = tr("SyntaxError: %s") % line
			elif check_hardware and (not is_instance_valid(hardware) or not hardware.is_built()):
				error = tr("Run mode is not active")
			elif check_hardware and hardware.servo_on_pin(int(binding.get_string(2))) == null:
				error = tr("Pin %d has nothing connected") % int(binding.get_string(2))
			else:
				names[binding.get_string(1)] = true
		elif command != null:
			if not names.has(command.get_string(1)):
				error = tr("NameError: '%s' is not defined") % command.get_string(1)
			elif not is_finite(float(command.get_string(3))):
				error = tr("Servo angles must be finite numbers.")
		elif wait != null:
			var seconds: float = float(wait.get_string(1))
			if not is_finite(seconds) or seconds > MAX_WAIT_SECONDS:
				error = tr("Wait must be between 0 and 60 seconds.")
		else:
			error = tr("SyntaxError: %s") % line
		if not error.is_empty():
			return {"line": index + 1, "error": error}
	return {}


func stop() -> void:
	_execution_id += 1
	var was_running: bool = _running
	_running = false
	_servos.clear()
	if was_running:
		stopped.emit()


func is_running() -> bool:
	return _running


func _exec(line: String) -> String:
	if _re_import.search(line):
		return ""
	var m := _re_assign.search(line)
	if m:
		var pin := int(m.get_string(2))
		if not is_instance_valid(hardware) or not hardware.is_built():
			return "Run mode is not active"
		var servo := hardware.servo_on_pin(pin)
		if servo == null:
			return tr("Pin %d has nothing connected") % pin
		_servos[m.get_string(1)] = servo
		return ""
	m = _re_write.search(line)
	if m:
		var name := m.get_string(1)
		if not _servos.has(name):
			return tr("NameError: '%s' is not defined") % name
		if not is_instance_valid(_servos[name]):
			return tr("Servo '%s' is no longer available") % name
		if m.get_string(2) == "write_relative":
			(_servos[name] as ServoDrive).write_relative(float(m.get_string(3)))
		else:
			(_servos[name] as ServoDrive).write(float(m.get_string(3)))
		return ""
	m = _re_sleep.search(line)
	if m:
		await get_tree().create_timer(float(m.get_string(1))).timeout
		return ""
	return tr("SyntaxError: %s") % line
