extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	var source: String = "# keep my comment\nleft = Motor(pin0, pin8)\nsonar = Sonar(pin1, pin2)\nfor i in range(0, 4, 1):\n    distance = sonar.distance()\n    if distance > 10:\n        left.forward(30)\n    elif distance < 5:\n        left.backward(20)\n    else:\n        left.stop()\n        break\n"
	for profile_id: String in ["generic-servo", "uno", "microbit"]:
		var profile: BoardProfile = BoardProfile.for_id(profile_id)
		var parsed: Dictionary = ServoProgram.parse(source, profile)
		_check(not parsed.has("error"), profile_id + " parses new cards")
		if parsed.has("error"):
			continue
		_check(ServoProgram.generate(parsed.instructions, profile).get("source") == source, "lossless source including comments, indent and final newline")
		var expected: Array[String] = ["motor_pair", "sonar", "for", "sensor_value", "if", "forward", "elif", "backward", "else", "motor_brake", "break"]
		for operation: String in expected:
			var found: bool = false
			for item: Dictionary in parsed.instructions:
				if item.op == operation:
					found = true
			_check(found, "editable card " + operation)
		var edited: Array = parsed.instructions.duplicate(true)
		for item: Dictionary in edited:
			if item.op != "raw":
				item.erase("raw")
		var regenerated: Dictionary = ServoProgram.generate(edited, profile)
		_check(not regenerated.has("error"), "edited cards generate valid code")
		if not regenerated.has("error"):
			_check(LearnerProgram.new().parse(regenerated.source).is_empty(), "generated code passes runtime parser")
		var range_card: Dictionary = ServoProgram.generate([profile.defaults("for")], profile)
		_check(not range_card.has("error") and range_card.source.ends_with("    pass"), "new range card has valid empty body")
		var restricted := BoardProfile.new()
		restricted.api = BoardProfile.GENERIC_API.duplicate(true)
		_check(ServoProgram.parse(source, restricted).has("error"), "restricted profile rejects new operations")
	print("parts_freedom_blocks_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
