class_name LearnerProgram
extends RefCounted

const MAX_DEPTH: int = 32
const MAX_EXPRESSION_TOKENS: int = 256
const PRECEDENCE: Dictionary = {"or": 1, "and": 2, "==": 3, "!=": 3, "<": 3, "<=": 3, ">": 3, ">=": 3, "+": 4, "-": 4, "*": 5, "/": 5, "//": 5, "%": 5}
const FUNCTIONS: Dictionary = {"Servo": [1, 1], "Motor": [1, 1], "Sonar": [2, 2], "sleep": [1, 1], "running_time": [0, 0], "motor_on": [3, 3], "stop": [0, 0], "machine.time_pulse_us": [2, 3]}
const METHODS: Dictionary = {"write": [1, 1], "write_relative": [1, 1], "motor_on": [2, 2], "stop": [0, 1], "distance_cm": [0, 0]}
var error: Dictionary = {}
var ast: Array[Dictionary] = []
var bytecode: Array[Dictionary] = []
var bindings: Array[Dictionary] = []
var _lines: Array[Dictionary] = []
var _line_index: int = 0
var _tokens: Array[Dictionary] = []
var _token_index: int = 0
var _expression_line: int = 1
var _depth: int = 0
var _names: Dictionary = {}


func parse(source: String) -> Dictionary:
	error.clear()
	ast.clear()
	bytecode.clear()
	bindings.clear()
	_lines.clear()
	_names = {"True": true, "False": true, "machine": true}
	_line_index = 0
	if source.to_utf8_buffer().size() > 65536 or source.split("\n").size() > 2048:
		return {"line": 1, "column": 1, "error": "This program is too large. Use at most 2048 lines and 64 KiB."}
	var rows: PackedStringArray = source.split("\n")
	for index: int in rows.size():
		var text: String = rows[index]
		var content: String = text.strip_edges()
		if content.is_empty() or content.begins_with("#"):
			continue
		if text.contains("\t"):
			_fail(index + 1, 1, "Use spaces for indentation.")
			break
		_lines.append({"text": content, "indent": text.length() - text.lstrip(" ").length(), "line": index + 1})
	if error.is_empty():
		ast = _block(0, 0)
	if error.is_empty():
		_compile(ast, [])
	return error


func _block(indent: int, depth: int) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	if depth > MAX_DEPTH:
		_fail(_lines[_line_index].line, 1, "This expression or block is too deeply nested.")
		return nodes
	while _line_index < _lines.size() and error.is_empty():
		var row: Dictionary = _lines[_line_index]
		if row.indent < indent:
			break
		if row.indent != indent:
			_fail(row.line, row.indent + 1, "Unexpected indentation.")
			break
		var text: String = row.text
		if text.begins_with("elif ") or text == "else:":
			break
		_line_index += 1
		if text.begins_with("from ") or text == "import machine":
			if text not in ["from servo import Servo", "from microbit import *", "from microbit import sleep", "import machine"]:
				_fail(row.line, 1, "This import is not supported.")
			continue
		if text.begins_with("if ") or text.begins_with("while "):
			var kind: String = "while" if text.begins_with("while ") else "if"
			if not text.ends_with(":"):
				_fail(row.line, text.length(), "Add ':' after the condition.")
				break
			var condition: Dictionary = expression(text.substr(kind.length() + 1).trim_suffix(":"), row.line)
			_check_names(condition, row.line)
			var body: Array[Dictionary] = _child(indent, depth, row.line)
			var node: Dictionary = {"op": kind, "condition": condition, "body": body, "otherwise": [], "line": row.line}
			if kind == "if":
				var tail: Dictionary = node
				while _line_index < _lines.size() and _lines[_line_index].indent == indent:
					var next: Dictionary = _lines[_line_index]
					if next.text == "else:":
						_line_index += 1
						tail.otherwise = _child(indent, depth, next.line)
						break
					if not next.text.begins_with("elif "):
						break
					_line_index += 1
					if not next.text.ends_with(":"):
						_fail(next.line, 1, "Add ':' after the condition.")
						break
					var branch: Dictionary = {"op": "if", "condition": expression(next.text.substr(5).trim_suffix(":"), next.line), "line": next.line, "body": _child(indent, depth, next.line), "otherwise": []}
					_check_names(branch.condition, next.line)
					tail.otherwise = [branch]
					tail = branch
			nodes.append(node)
		elif text in ["pass", "break", "continue"]:
			nodes.append({"op": text, "line": row.line})
		else:
			var assignment: RegExMatch = RegEx.create_from_string(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)\s*(.*)$").search(text)
			var value: Dictionary = expression(assignment.get_string(2) if assignment else text, row.line)
			_check_names(value, row.line)
			if assignment:
				var name: String = assignment.get_string(1)
				if name in ["True", "False", "machine"] or name.begins_with("pin") and name.substr(3).is_valid_int() or FUNCTIONS.has(name):
					_fail(row.line, 1, "Choose another variable name.")
				_names[name] = true
				nodes.append({"op": "assign", "name": name, "value": value, "line": row.line})
				if value.get("kind") == "call" and value.name in ["Servo", "Motor", "Sonar"]:
					bindings.append({"name": name, "kind": value.name, "args": value.args, "line": row.line})
			elif value.get("kind") == "call":
				nodes.append({"op": "call", "value": value, "line": row.line})
			else:
				_fail(row.line, 1, "Use an assignment or a supported command.")
	if indent == 0 and _line_index < _lines.size() and error.is_empty():
		_fail(_lines[_line_index].line, 1, "Unexpected indentation.")
	return nodes


func _child(indent: int, depth: int, line: int) -> Array[Dictionary]:
	if _line_index >= _lines.size() or _lines[_line_index].indent <= indent:
		_fail(line, 1, "Indent the body of this block.")
		return []
	return _block(_lines[_line_index].indent, depth + 1)


func expression(text: String, line: int = 1) -> Dictionary:
	_tokens.clear()
	_token_index = 0
	_expression_line = line
	_depth = 0
	var lexer: RegEx = RegEx.create_from_string("^[ ]*(?:(\\d+(?:\\.\\d+)?)|([A-Za-z_][A-Za-z0-9_]*)|('(?:[^'\\\\]|\\\\.)*'|\"(?:[^\"\\\\]|\\\\.)*\")|(==|!=|<=|>=|//|[+*/%<>()=,.-]))")
	var position: int = 0
	while position < text.length():
		if text.substr(position).strip_edges().is_empty() or text.substr(position).strip_edges().begins_with("#"):
			break
		var match_token: RegExMatch = lexer.search(text.substr(position))
		if match_token == null:
			_fail(line, position + 1, "Check this symbol.")
			return {}
		var value: String = match_token.get_string().strip_edges()
		_tokens.append({"value": value, "column": position + 1})
		position += match_token.get_string().length()
		if _tokens.size() > MAX_EXPRESSION_TOKENS:
			_fail(line, position, "This expression or block is too deeply nested.")
			return {}
	_tokens.append({"value": "", "column": position + 1})
	var result: Dictionary = _expr(0)
	if _peek() != "":
		_fail(line, _tokens[_token_index].column, "Use '==' to compare values." if _peek() == "=" else "Check this expression.")
	return result


func _expr(minimum: int) -> Dictionary:
	_depth += 1
	if _depth > MAX_DEPTH or not error.is_empty():
		_fail(_expression_line, 1, "This expression or block is too deeply nested.")
		return {}
	var token: String = _take()
	var left: Dictionary = {}
	if token in ["-", "+", "not"]:
		left = {"kind": "unary", "operator": token, "value": _expr(3 if token == "not" else 6)}
	elif token == "(":
		left = _expr(0)
		_expect(")")
	elif token.is_valid_float():
		left = {"kind": "literal", "value": float(token)}
	elif token.begins_with("'") or token.begins_with('"'):
		left = {"kind": "literal", "value": token.substr(1, token.length() - 2)}
	elif token in ["True", "False"]:
		left = {"kind": "literal", "value": token == "True"}
	elif RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$").search(token):
		var name: String = token
		if _peek() == ".":
			_take()
			name += "." + _take()
		if _peek() == "(":
			_take()
			var arguments: Array[Dictionary] = []
			if _peek() != ")":
				if _peek() == "pin" and _tokens[_token_index + 1].value == "=":
					_take()
					_take()
				arguments.append(_expr(0))
				while _peek() == "," and error.is_empty():
					_take()
					arguments.append(_expr(0))
			_expect(")")
			left = {"kind": "call", "name": name, "args": arguments}
			var limits: Array = FUNCTIONS.get(name, METHODS.get(name.get_slice(".", 1), []))
			if limits.is_empty() or arguments.size() < limits[0] or arguments.size() > limits[1]:
				_fail(_expression_line, 1, "Check the command name and its arguments.")
		else:
			left = {"kind": "name", "name": name}
	else:
		_fail(_expression_line, 1, "Check this expression.")
	while error.is_empty() and PRECEDENCE.has(_peek()) and PRECEDENCE[_peek()] >= minimum:
		var operator: String = _take()
		left = {"kind": "binary", "operator": operator, "left": left, "right": _expr(PRECEDENCE[operator] + 1)}
	_depth -= 1
	return left


func _check_names(value: Dictionary, line: int) -> void:
	if value.is_empty() or not error.is_empty():
		return
	match value.kind:
		"name":
			var name: String = value.name
			if not _names.has(name) and not (name.begins_with("pin") and name.substr(3).is_valid_int()):
				var closest: String = ""
				var best: int = 3
				for candidate: String in _names:
					var distance: int = _name_distance(name, candidate)
					if distance < best:
						best = distance
						closest = candidate
				if closest.is_empty():
					_fail(line, 1, "NameError: '%s' is not defined", [name])
				else:
					_fail(line, 1, "Name '%s' is not defined. Did you mean '%s'?", [name, closest])
		"call":
			if value.name.contains(".") and not value.name.begins_with("machine."):
				_check_names({"kind": "name", "name": value.name.get_slice(".", 0)}, line)
			for argument: Dictionary in value.args:
				_check_names(argument, line)
		"binary":
			_check_names(value.left, line)
			_check_names(value.right, line)
		"unary":
			_check_names(value.value, line)


func _compile(nodes: Array, loops: Array) -> void:
	for node: Dictionary in nodes:
		if node.op in ["if", "while"]:
			var start: int = bytecode.size()
			_emit_expression(node.condition, node.line)
			var test: int = bytecode.size()
			bytecode.append({"op": "test", "target": 0, "line": node.line})
			var scope: Dictionary = {"start": start, "breaks": []}
			_compile(node.body, loops + [scope] if node.op == "while" else loops)
			if node.op == "while":
				bytecode.append({"op": "jump", "target": start, "line": node.line})
				bytecode[test].target = bytecode.size()
				for offset: int in scope.breaks:
					bytecode[offset].target = bytecode.size()
			else:
				var skip: int = bytecode.size()
				bytecode.append({"op": "jump", "target": 0, "line": node.line})
				bytecode[test].target = bytecode.size()
				_compile(node.otherwise, loops)
				bytecode[skip].target = bytecode.size()
		elif node.op in ["break", "continue"]:
			if loops.is_empty():
				_fail(node.line, 1, "Use this command inside a loop.")
				return
			if node.op == "break":
				loops[-1].breaks.append(bytecode.size())
			bytecode.append({"op": "jump", "target": loops[-1].start if node.op == "continue" else 0, "line": node.line})
		elif node.op == "pass":
			bytecode.append(node)
		else:
			_emit_expression(node.value, node.line)
			bytecode.append({"op": "store" if node.op == "assign" else "pop", "name": node.get("name", ""), "line": node.line})


func _emit_expression(value: Dictionary, line: int) -> void:
	match value.kind:
		"literal", "name":
			bytecode.append({"op": value.kind, "value": value.get("value"), "name": value.get("name", ""), "line": line})
		"unary":
			_emit_expression(value.value, line)
			bytecode.append({"op": "unary", "operator": value.operator, "line": line})
		"binary":
			_emit_expression(value.left, line)
			if value.operator in ["and", "or"]:
				var guard: int = bytecode.size()
				bytecode.append({"op": "logical_guard", "operator": value.operator, "target": 0, "line": line})
				_emit_expression(value.right, line)
				bytecode.append({"op": "truth", "line": line})
				bytecode[guard].target = bytecode.size()
			else:
				_emit_expression(value.right, line)
				bytecode.append({"op": "binary", "operator": value.operator, "line": line})
		"call":
			for argument: Dictionary in value.args:
				_emit_expression(argument, line)
			bytecode.append({"op": "invoke", "name": value.name, "argc": value.args.size(), "args": value.args, "line": line})


func _peek() -> String:
	return _tokens[mini(_token_index, _tokens.size() - 1)].value


func _take() -> String:
	var value: String = _peek()
	_token_index = mini(_token_index + 1, _tokens.size() - 1)
	return value


func _expect(value: String) -> void:
	if _take() != value:
		_fail(_expression_line, _tokens[_token_index].column, "Check this expression.")


func _fail(line: int, column: int, message: String, arguments: Array = []) -> void:
	if error.is_empty():
		error = {"line": line, "column": column, "message": message, "arguments": arguments, "error": message % arguments if not arguments.is_empty() else message}


func _name_distance(a: String, b: String) -> int:
	if abs(a.length() - b.length()) > 2:
		return 3
	var previous: Array[int] = []
	for index: int in b.length() + 1:
		previous.append(index)
	for row: int in a.length():
		var next: Array[int] = [row + 1]
		for column: int in b.length():
			next.append(mini(mini(next[column] + 1, previous[column + 1] + 1), previous[column] + (0 if a[row] == b[column] else 1)))
		previous = next
	return previous[-1]
