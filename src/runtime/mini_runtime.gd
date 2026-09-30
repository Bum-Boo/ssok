class_name MiniRuntime
extends Node

signal line_started(line_no: int)
signal finished()
signal failed(line_no: int, message: String)
signal stopped()
signal settled()

const MAX_SOURCE_BYTES: int = 65536
const MAX_LINES: int = 2048
const MAX_WAIT_SECONDS: float = 60.0
const OPERATIONS_PER_TICK: int = 128

var hardware: RunMode
var _running: bool = false
var _execution_id: int = 0
var _program: LearnerProgram
var _variables: Dictionary = {}
var _servos: Dictionary = {}
var _pc: int = 0
var _stack: Array = []
var _ticks: int = 0
var _wake_tick: int = 0
var _error: String = ""
var current_line: int = 0
var sleep_scale: float = 1.0


func run(source: String) -> void:
	if _running:
		return
	var validation: Dictionary = validate(source)
	if not validation.is_empty():
		failed.emit(validation.line, _translated_error(validation))
		return
	_program = LearnerProgram.new()
	_program.parse(source)
	_execution_id += 1
	_variables.clear()
	_servos.clear()
	_pc = 0
	_stack.clear()
	_ticks = 0
	current_line = 0
	_wake_tick = 0
	_error = ""
	_running = true
	# Preserve immediate finite programs while bounding the work of infinite ones.
	_step()
	if _running:
		await settled


func validate(source: String, check_hardware: bool = true) -> Dictionary:
	var parsed := LearnerProgram.new()
	var validation: Dictionary = parsed.parse(source)
	if not validation.is_empty():
		return validation
	for binding: Dictionary in parsed.bindings:
		if check_hardware and (not is_instance_valid(hardware) or not hardware.is_built()):
			return {"line": binding.line, "error": tr("Run mode is not active")}
		var pins: Array[int] = []
		for argument: Dictionary in binding.args:
			var pin: int = -1
			if argument.get("kind") == "literal" and typeof(argument.value) in [TYPE_INT, TYPE_FLOAT]:
				pin = int(argument.value)
			elif argument.get("kind") == "name" and argument.name.begins_with("pin"):
				pin = int(argument.name.substr(3))
			if pin < 0 or pin > 255:
				return {"line": binding.line, "error": tr("Use a board pin when connecting hardware.")}
			pins.append(pin)
		if check_hardware and not hardware.has_device(binding.kind, pins):
			return {"line": binding.line, "error": tr("Pin %d has nothing connected") % pins[0]}
	for instruction: Dictionary in parsed.bytecode:
		if instruction.op == "invoke" and instruction.name == "sleep" and instruction.args[0].get("kind") == "literal":
			var scale: float = hardware.sleep_scale() if is_instance_valid(hardware) and hardware.is_built() else sleep_scale
			var seconds: Variant = instruction.args[0].value
			if typeof(seconds) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(seconds)) or seconds < 0 or seconds * scale > MAX_WAIT_SECONDS:
				return {"line": instruction.line, "error": tr("Wait must be between 0 and 60 seconds.")}
	return {}


func stop() -> void:
	_execution_id += 1
	var active: bool = _running
	_running = false
	_variables.clear()
	_servos.clear()
	if is_instance_valid(hardware):
		hardware.stop_motors()
	if active:
		stopped.emit()
		settled.emit()


func is_running() -> bool:
	return _running


func _physics_process(_delta: float) -> void:
	if _running:
		_ticks += 1
		_step()


func _step() -> void:
	if _ticks < _wake_tick:
		return
	var execution: int = _execution_id
	for operation: int in OPERATIONS_PER_TICK:
		if not _running or execution != _execution_id:
			return
		if _pc >= _program.bytecode.size():
			_running = false
			finished.emit()
			settled.emit()
			return
		var instruction: Dictionary = _program.bytecode[_pc]
		if current_line != instruction.line:
			current_line = instruction.line
			line_started.emit(current_line)
		if execution != _execution_id:
			return
		_pc += 1
		match instruction.op:
			"literal":
				_stack.append(instruction.value)
			"name":
				if instruction.name.begins_with("pin") and instruction.name.substr(3).is_valid_int():
					_stack.append(int(instruction.name.substr(3)))
				elif _variables.has(instruction.name):
					_stack.append(_variables[instruction.name])
				else:
					_error = tr("NameError: '%s' is not defined") % instruction.name
			"store":
				var value: Variant = _stack.pop_back()
				_variables[instruction.name] = value
				if value is ServoDrive:
					_servos[instruction.name] = value
			"pop":
				_stack.pop_back()
			"invoke":
				var args: Array = []
				for index: int in instruction.argc:
					args.push_front(_stack.pop_back())
				_stack.append(_call(instruction.name, args))
			"unary":
				var value: Variant = _stack.pop_back()
				if instruction.operator == "not":
					_stack.append(not _truth(value))
				elif _numeric(value):
					_stack.append(-float(value) if instruction.operator == "-" else float(value))
			"binary":
				var b: Variant = _stack.pop_back()
				var a: Variant = _stack.pop_back()
				_stack.append(_binary(instruction.operator, a, b))
			"truth":
				_stack.append(_truth(_stack.pop_back()))
			"logical_guard":
				var value: bool = _truth(_stack.pop_back())
				if instruction.operator == "and" and not value or instruction.operator == "or" and value:
					_stack.append(value)
					_pc = instruction.target
			"test":
				if not _truth(_stack.pop_back()):
					_pc = instruction.target
			"jump":
				_pc = instruction.target

		if not _error.is_empty():
			_running = false
			if is_instance_valid(hardware):
				hardware.stop_motors()
			failed.emit(current_line, _error)
			settled.emit()
			return
		if _wake_tick > _ticks:
			return


func _binary(operator: String, a: Variant, b: Variant) -> Variant:
	if operator == "==":
		return a == b
	if operator == "!=":
		return a != b
	if not _numeric(a) or not _numeric(b):
		return null
	match operator:
		"+": return _finite(float(a) + float(b))
		"-": return _finite(float(a) - float(b))
		"*": return _finite(float(a) * float(b))
		"/", "//", "%":
			if float(b) == 0.0:
				_error = tr("Cannot divide by zero.")
				return null
			if operator == "%":
				return fposmod(float(a), absf(float(b))) if b > 0 else -fposmod(-float(a), absf(float(b)))
			return floorf(float(a) / float(b)) if operator == "//" else _finite(float(a) / float(b))
		"<": return a < b
		"<=": return a <= b
		">": return a > b
		">=": return a >= b
	return null


func _call(name: String, args: Array) -> Variant:
	if name == "running_time":
		return _ticks * 1000.0 / Engine.physics_ticks_per_second
	if name == "sleep":
		var scale: float = hardware.sleep_scale() if is_instance_valid(hardware) and hardware.is_built() else sleep_scale
		if not _numeric(args[0]) or args[0] < 0 or args[0] * scale > MAX_WAIT_SECONDS:
			_error = tr("Wait must be between 0 and 60 seconds.")
			return null
		_wake_tick = _ticks + maxi(1, int(ceil(float(args[0]) * scale * Engine.physics_ticks_per_second)))
		return null
	if not is_instance_valid(hardware) or not hardware.is_built():
		_error = tr("Run mode is not active")
		return null
	if name in ["Servo", "Motor", "Sonar"]:
		return hardware.device(name, args)
	if name == "stop":
		hardware.stop_motors()
		return null
	if name == "motor_on":
		return _device_call(args[0], "motor_on", [args[1], args[2]])
	if name == "machine.time_pulse_us":
		var result: Dictionary = hardware.pulse_us(args)
		_error = result.get("error", "")
		return result.get("value")
	var target: String = name.get_slice(".", 0)
	if not _variables.has(target):
		_error = tr("NameError: '%s' is not defined") % target
		return null
	return _device_call(_variables[target], name.get_slice(".", 1), args)


func _device_call(device_value: Variant, method: String, args: Array) -> Variant:
	if not device_value is Object or not is_instance_valid(device_value):
		_error = tr("This variable is not a connected device.")
		return null
	if not device_value.has_method(method):
		_error = tr("This device does not support that command.")
		return null
	if method in ["write", "write_relative"] and not _numeric(args[0]):
		return null
	if method == "motor_on":
		if not _numeric(args[1]) or args[1] < 0 or args[1] > 100 or args[0] not in ["forward", "reverse", 1, -1]:
			_error = tr("Choose forward or reverse and a speed from 0 to 100.")
			return null
	if method == "stop" and not args.is_empty() and args[0] not in ["brake", "coast"]:
		_error = tr("Choose brake or coast.")
		return null
	return device_value.callv(method, args)


func _numeric(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		_error = tr("Use a finite number here.")
		return false
	return true


func _finite(value: float) -> Variant:
	return value if _numeric(value) else null


func _truth(value: Variant) -> bool:
	if value is bool:
		return value
	if typeof(value) in [TYPE_FLOAT, TYPE_INT]:
		return value != 0
	return value != null


func _translated_error(validation: Dictionary) -> String:
	if validation.has("message"):
		var message: String = tr(validation.message)
		if not validation.arguments.is_empty():
			message = message % validation.arguments
		return tr("Column %d: %s") % [validation.column, message]
	return validation.error
