extends SceneTree

## Actual rendered bridge regression: stale cleanup must preserve its replacement.
var app: Node3D
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rendered desktop required")
		quit(1)
		return
	root.size = Vector2i(1600, 1000)
	app = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(app)
	await process_frame
	app._load_preset(RobotCarPreset.build(0.5), RobotCarPreset.BRAKE_CODE, "")
	app.control_source.select(app.CONTROL_CODE)
	app.mode_button.button_pressed = true
	app.agent_loop.begin()
	await _ready_frame()
	var old: Dictionary = _context()
	app._on_stop_pressed()
	app.agent_loop.begin()
	await _ready_frame()
	var replacement: Dictionary = _context()
	_check(old != replacement, "intentional replacement has a new ownership context")
	var stale: Dictionary = await _request("stop", old)
	_check(app.agent_loop.enabled and app.agent_loop.state == "ready" and _context() == replacement, "stale primary Stop preserves the replacement owner")
	_check(stale.get("data", {}).get("owner_revoked") == true and stale.get("data", {}).get("stop_scope") == "context_replaced", "stale cleanup reports revocation without claiming replacement stopped")
	# Keep the first connection incomplete to force the Stop priority lane.
	var held := StreamPeerTCP.new()
	held.connect_to_host("127.0.0.1", 8127)
	await _connected(held)
	held.put_data(_wire("held", "describe", {}).trim_suffix("\n").to_utf8_buffer())
	for frame: int in 5:
		await process_frame
	var priority: Dictionary = await _request("stop", old)
	_check(app.agent_loop.enabled and _context() == replacement, "stale priority Stop preserves the replacement owner")
	_check(priority.get("data", {}).get("stop_scope") == "context_replaced", "priority lane uses the same context check")
	held.put_data("\n".to_utf8_buffer())
	for frame: int in 5:
		await process_frame
	held.disconnect_from_host()
	var invalid: Dictionary = await _request("stop", {"episode_id": replacement.episode_id, "revision": true, "control_generation": replacement.control_generation})
	_check(invalid.get("error") == "invalid_stop_context" and _context() == replacement and app.agent_loop.enabled, "malformed scoped Stop cannot become global Stop")
	var matched: Dictionary = await _request("stop", replacement)
	_check(matched.get("data", {}).get("state") == "stopped" and not app.agent_loop.enabled, "matching scoped Stop brakes its owner")
	_check(matched.get("data", {}).get("stop_scope") == "matched_context", "matched revocation is explicit")
	var generation: int = app.agent_loop.control_generation
	var repeated: Dictionary = await _request("stop", replacement)
	_check(repeated.get("data", {}).get("owner_revoked") == true and app.agent_loop.control_generation == generation, "repeated old cleanup does not advance the new generation")
	app.agent_loop.begin()
	await _ready_frame()
	var global_stop: Dictionary = await _request("stop", {})
	_check(global_stop.get("data", {}).get("state") == "stopped" and not app.agent_loop.enabled, "unscoped local/operator emergency Stop remains global")
	app.free()
	print("bridge_stop_owner_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _context() -> Dictionary:
	var value: Dictionary = app.agent_loop.describe()
	return {"episode_id": value.episode_id, "revision": value.revision, "control_generation": value.control_generation}


func _ready_frame() -> void:
	for tick: int in 600:
		await physics_frame
		if app.agent_loop.state in ["ready", "fault", "stopped"]:
			break
	_check(app.agent_loop.state == "ready", "rendered episode reaches ready")


func _connected(peer: StreamPeerTCP) -> void:
	for frame: int in 180:
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			return
		await process_frame
	assert(false, "connection timeout")


func _wire(identity: String, tool: String, args: Dictionary) -> String:
	return JSON.stringify({"id": identity, "token": OS.get_environment("SSOK_AGENT_TOKEN"), "tool": tool, "args": args}) + "\n"


func _request(tool: String, args: Dictionary) -> Dictionary:
	var peer := StreamPeerTCP.new()
	peer.connect_to_host("127.0.0.1", 8127)
	await _connected(peer)
	peer.put_data(_wire("owner-regression", tool, args).to_utf8_buffer())
	var body := PackedByteArray()
	for frame: int in 600:
		peer.poll()
		var count: int = peer.get_available_bytes()
		if count > 0:
			body.append_array(peer.get_data(count)[1])
		if body.find(10) >= 0:
			peer.disconnect_from_host()
			return JSON.parse_string(body.get_string_from_utf8()) as Dictionary
		await process_frame
	peer.disconnect_from_host()
	assert(false, "response timeout")
	return {}


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
