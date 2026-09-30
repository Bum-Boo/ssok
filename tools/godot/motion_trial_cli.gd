extends SceneTree

## Trusted bridge entrypoint. The sole user argument is base64 JSON, never a path or code.

const MAX_ARGUMENT_BYTES: int = 131072


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1 or arguments[0].length() > MAX_ARGUMENT_BYTES:
		_finish({"error": "Expected one bounded base64 JSON argument"})
		return
	var encoded: String = arguments[0]
	var allowed: RegEx = RegEx.new()
	allowed.compile("^[A-Za-z0-9+/]*={0,2}$")
	if encoded.is_empty() or encoded.length() % 4 != 0 or allowed.search(encoded) == null:
		_finish({"error": "Invalid base64 argument"})
		return
	var raw: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if Marshalls.raw_to_base64(raw) != encoded:
		_finish({"error": "Non-canonical base64 argument"})
		return
	var parser: JSON = JSON.new()
	if parser.parse(raw.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		_finish({"error": "Invalid JSON request"})
		return
	var request: Dictionary = parser.data
	for key: Variant in request:
		if key not in ["graph", "policy", "command"]:
			_finish({"error": "Unknown request field"})
			return
	if not request.get("policy") is Dictionary:
		_finish({"error": "A bounded motion policy is required"})
		return
	var graph: ConnectionGraph = BipedPreset.build() if not request.has("graph") else MotionSnapshot.decode(request.graph)
	if graph == null:
		_finish({"error": "Invalid catalog graph snapshot"})
		return
	var command_data: Variant = request.get("command", [0, 1])
	if not command_data is Array or command_data.size() != 2:
		_finish({"error": "Command must contain two finite numbers"})
		return
	for number: Variant in command_data:
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)):
			_finish({"error": "Command must contain two finite numbers"})
			return
	var trial: MotionTrial = MotionTrial.new()
	root.add_child(trial)
	var result: Dictionary = await trial.run_trial(graph, request.policy, Vector2(command_data[0], command_data[1]))
	trial.queue_free()
	_finish(result)


func _finish(result: Dictionary) -> void:
	print("SSOK_MOTION_RESULT=" + JSON.stringify(result))
	quit(1 if result.has("error") else 0)
