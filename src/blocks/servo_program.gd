class_name ServoProgram
extends RefCounted

## Lossless for untouched lines; edited blocks emit the same bounded learner language.
const MAX_LINES: int = 2048
const IDENTIFIER: String = "^[A-Za-z_][A-Za-z0-9_]*$"
const TEMPLATES: Dictionary = {"servo": "{name} = Servo({pin})", "write": "{name}.write({angle})",
	"write_relative": "{name}.write_relative({angle})", "sleep": "sleep({seconds})"}


static func parse(source: String, profile: BoardProfile) -> Dictionary:
	var lines: PackedStringArray = source.split("\n")
	if lines.size() > MAX_LINES or source.to_utf8_buffer().size() > ProjectStore.MAX_CODE_BYTES:
		return {"error": "This program is too large for the block editor.", "line": 1}
	var instructions: Array[Dictionary] = []
	var assign: RegEx = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*Servo\(\s*(?:pin\s*=\s*)?(\d+)\s*\)$")
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
				return {"error": "This line cannot be represented as a block. Your code is unchanged.", "line": index + 1}
			if not valid_instruction(item, profile):
				return {"error": "This command is outside the board API limits. Your code is unchanged.", "line": index + 1}
		instructions.append(item)
	return {"instructions": instructions}


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
		if parameter.type == "identifier":
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
	for item: Dictionary in instructions:
		if not valid_instruction(item, profile):
			return {"error": "A block contains an invalid value. Your code is unchanged."}
		if item.has("raw"):
			lines.append(item.raw)
		else:
			var descriptor: Dictionary = profile.operation(item.op)
			var line: String = TEMPLATES[item.op]
			for parameter: Dictionary in descriptor.arguments:
				line = line.replace("{" + parameter.name + "}", str(item.args[parameter.name]))
			lines.append(line)
	var source: String = "\n".join(lines)
	var verified: Dictionary = parse(source, profile)
	return {"source": source} if not verified.has("error") else verified
