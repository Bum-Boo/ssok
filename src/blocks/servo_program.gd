class_name ServoProgram
extends RefCounted

## Lossless for untouched lines; edited blocks emit the same bounded learner language.
const MAX_LINES: int = 2048
const IDENTIFIER: String = "^[A-Za-z_][A-Za-z0-9_]*$"
const TEMPLATES: Dictionary = {"servo": "{name} = Servo({pin})", "write": "{name}.write({angle})",
	"write_relative": "{name}.write_relative({angle})", "sleep": "sleep({seconds})", "motor": "{name} = Motor({pin})", "motor_on": "{name}.motor_on(\"{direction}\", {speed})", "motor_stop": "{name}.stop(\"{mode}\")", "sonar": "{name} = Sonar({trigger}, {echo})", "distance": "{variable} = {name}.distance_cm()", "variable": "{name} = {expression}", "while": "while {expression}:", "if": "if {expression}:", "elif": "elif {expression}:", "else": "else:", "stop": "stop()", "for": "for {name} in range({expression}):", "break": "break", "motor_pair": "{name} = Motor({first}, {second})", "forward": "{name}.forward({speed})", "backward": "{name}.backward({speed})", "motor_brake": "{name}.stop()", "sensor_value": "{variable} = {name}.distance()"}


static func parse(source: String, profile: BoardProfile) -> Dictionary:
	var lines: PackedStringArray = source.split("\n")
	if lines.size() > MAX_LINES or source.to_utf8_buffer().size() > ProjectStore.MAX_CODE_BYTES:
		return {"error": "This program is too large for the block editor.", "line": 1}
	var syntax := LearnerProgram.new()
	var syntax_error: Dictionary = syntax.parse(source)
	if not syntax_error.is_empty():
		return {"error": syntax_error.error, "line": syntax_error.line}
	var instructions: Array[Dictionary] = []
	var assign: RegEx = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*Servo\(\s*(?:pin\s*=\s*|pin)?(\d+)\s*\)$")
	var write: RegEx = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\.(write|write_relative)\(\s*(-?\d+(?:\.\d+)?)\s*\)$")
	var wait: RegEx = RegEx.create_from_string(r"^sleep\(\s*(\d+(?:\.\d+)?)\s*\)$")
	var import_line: RegEx = RegEx.create_from_string(r"^from\s+servo\s+import\s+Servo$")
	for index: int in lines.size():
		var line: String = lines[index].strip_edges()
		var item: Dictionary = {"op": "raw", "raw": lines[index]}
		if not line.is_empty() and not line.begins_with("#") and import_line.search(line) == null:
			var match_assign: RegExMatch = assign.search(line)
			var match_write: RegExMatch = write.search(line)
			var match_wait: RegExMatch = wait.search(line)
			if match_assign != null:
				item = {"op": "servo", "args": {"name": match_assign.get_string(1), "pin": int(match_assign.get_string(2))}, "raw": lines[index]}
			elif match_write != null:
				item = {"op": match_write.get_string(2), "args": {"name": match_write.get_string(1), "angle": float(match_write.get_string(3))}, "raw": lines[index]}
			elif match_wait != null:
				item = {"op": "sleep", "args": {"seconds": float(match_wait.get_string(1))}, "raw": lines[index]}
			else:
				item = _learning_instruction(line, profile)
				item["raw"] = lines[index]
			if not valid_instruction(item, profile):
				return {"error": "This command is outside the board API limits. Your code is unchanged.", "line": index + 1}
		item["indent"] = lines[index].length() - lines[index].lstrip(" ").length()
		instructions.append(item)
	return {"instructions": instructions, "ast": syntax.ast.duplicate(true)}


static func valid_instruction(item: Dictionary, profile: BoardProfile) -> bool:
	if item.get("op") == "raw":
		return item.get("raw") is String
	if not item.get("op") is String or not item.get("args") is Dictionary:
		return false
	var descriptor: Dictionary = profile.operation(item.op)
	if descriptor.is_empty() or item.args.size() != descriptor.arguments.size():
		return false
	for parameter: Dictionary in descriptor.arguments:
		var value: Variant = item.args.get(parameter.name)
		if parameter.type == "choice":
			if value not in parameter.choices:
				return false
		elif parameter.type == "expression":
			if not value is String or value.length() > 1024 or value.strip_edges().is_empty():
				return false
		elif parameter.type == "identifier":
			if not value is String or RegEx.create_from_string(IDENTIFIER).search(value) == null:
				return false
		else:
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value < parameter.min or value > parameter.max:
				return false
			if parameter.type == "integer" and value != floorf(float(value)):
				return false
	return true


static func generate(instructions: Array, profile: BoardProfile) -> Dictionary:
	var lines: PackedStringArray = []
	for index: int in instructions.size():
		var item: Dictionary = instructions[index]
		if not valid_instruction(item, profile):
			return {"error": "A block contains an invalid value. Your code is unchanged."}
		if item.has("raw"):
			lines.append(item.raw)
		else:
			var descriptor: Dictionary = profile.operation(item.op)
			var line: String = TEMPLATES[item.op]
			for parameter: Dictionary in descriptor.arguments:
				var value: String = profile.format_pin(int(item.args[parameter.name])) if parameter.name in ["pin", "trigger", "echo", "first", "second"] else str(item.args[parameter.name])
				line = line.replace("{" + parameter.name + "}", value)
			var indent: int = int(item.get("indent", 0))
			lines.append(" ".repeat(indent) + line)
			# The existing panel creates bodies for while/if; range uses the same safe empty body.
			if item.op == "for" and (index + 1 == instructions.size() or int(instructions[index + 1].get("indent", 0)) <= indent):
				lines.append(" ".repeat(indent + 4) + "pass")
	var source: String = "\n".join(lines)
	var verified: Dictionary = parse(source, profile)
	return {"source": source} if not verified.has("error") else verified


static func _learning_instruction(line: String, profile: BoardProfile) -> Dictionary:
	var loop: RegExMatch = RegEx.create_from_string(r"^for ([A-Za-z_][A-Za-z0-9_]*) in range\((.*)\):$").search(line)
	if loop:
		return {"op": "for", "args": {"name": loop.get_string(1), "expression": loop.get_string(2)}}
	if line == "break":
		return {"op": "break", "args": {}}
	var pair: RegExMatch = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*Motor\(\s*(?:pin)?(\d+)\s*,\s*(?:pin)?(\d+)\s*\)$").search(line)
	if pair:
		return {"op": "motor_pair", "args": {"name": pair.get_string(1), "first": int(pair.get_string(2)), "second": int(pair.get_string(3))}}
	var direction: RegExMatch = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\.(forward|backward)\(\s*(\d+(?:\.\d+)?)\s*\)$").search(line)
	if direction:
		return {"op": direction.get_string(2), "args": {"name": direction.get_string(1), "speed": float(direction.get_string(3))}}
	var brake: RegExMatch = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\.stop\(\)$").search(line)
	if brake:
		return {"op": "motor_brake", "args": {"name": brake.get_string(1)}}
	var reading: RegExMatch = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([A-Za-z_][A-Za-z0-9_]*)\.distance\(\)$").search(line)
	if reading:
		return {"op": "sensor_value", "args": {"variable": reading.get_string(1), "name": reading.get_string(2)}}

	for operation_id: String in ["while", "if", "elif"]:
		if line.begins_with(operation_id + " ") and line.ends_with(":"):
			return {"op": operation_id, "args": {"expression": line.substr(operation_id.length() + 1).trim_suffix(":")}}
	if line == "else:":
		return {"op": "else", "args": {}}
	if line == "stop()":
		return {"op": "stop", "args": {}}
	var binding: RegExMatch = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*Motor\(\s*(?:pin)?(\d+)\s*\)$").search(line)
	if binding:
		return {"op": "motor", "args": {"name": binding.get_string(1), "pin": int(binding.get_string(2))}}
	var sonar: RegExMatch = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*Sonar\(\s*(?:pin)?(\d+)\s*,\s*(?:pin)?(\d+)\s*\)$").search(line)
	if sonar:
		return {"op": "sonar", "args": {"name": sonar.get_string(1), "trigger": int(sonar.get_string(2)), "echo": int(sonar.get_string(3))}}
	var on: RegExMatch = RegEx.create_from_string("^([A-Za-z_][A-Za-z0-9_]*)\\.motor_on\\([\"'](forward|reverse)[\"'],\\s*(\\d+(?:\\.\\d+)?)\\)$").search(line)
	if on:
		return {"op": "motor_on", "args": {"name": on.get_string(1), "direction": on.get_string(2), "speed": float(on.get_string(3))}}
	var stop: RegExMatch = RegEx.create_from_string("^([A-Za-z_][A-Za-z0-9_]*)\\.stop\\([\"'](brake|coast)[\"']\\)$").search(line)
	if stop:
		return {"op": "motor_stop", "args": {"name": stop.get_string(1), "mode": stop.get_string(2)}}
	var distance: RegExMatch = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([A-Za-z_][A-Za-z0-9_]*)\.distance_cm\(\)$").search(line)
	if distance:
		return {"op": "distance", "args": {"variable": distance.get_string(1), "name": distance.get_string(2)}}
	var variable: RegExMatch = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)\s*(.*)$").search(line)
	if variable:
		return {"op": "variable", "args": {"name": variable.get_string(1), "expression": variable.get_string(2)}}
	return {"op": "raw", "raw": line}
