class_name AgentGoalInbox
extends Node

## One user-requested goal for one foreground operator. Never calls a provider itself.
signal status_changed(connected: bool, busy: bool, status: String)

const OPERATOR_TTL_MS: int = 3000
const QUEUE_TTL_MS: int = 20000
const GOAL_LIMIT_MS: int = 310000
var loop: AgentCameraLoop
var _operator: String = ""
var _heartbeat: int = 0
var _request: Dictionary = {}
var _claimed: bool = false
var _submitted_at: int = 0
var _claimed_at: int = 0
var _last_connected: bool = false
var _status: String = ""


func _ready() -> void:
	loop.state_changed.connect(_on_loop_state)


func connected() -> bool:
	return not _operator.is_empty() and (_claimed or Time.get_ticks_msec() - _heartbeat < OPERATOR_TTL_MS)


func busy() -> bool:
	return not _request.is_empty()


func submit(goal: String) -> Dictionary:
	if not connected() or busy() or OS.has_feature("web"):
		return {"error": "operator_unavailable"}
	goal = goal.strip_edges()
	var token: String = OS.get_environment("SSOK_AGENT_TOKEN")
	if goal.is_empty() or goal.length() > 1000 or (not token.is_empty() and goal.contains(token)):
		return {"error": "invalid_goal"}
	for index: int in goal.length():
		if goal.unicode_at(index) < 32:
			return {"error": "invalid_goal"}
	# Begin/mode transition belongs to the app; submit only binds its resulting episode.
	if not loop.enabled:
		return {"error": "camera_not_enabled"}
	_request = {"request_id": Crypto.new().generate_random_bytes(12).hex_encode(), "goal": goal,
		"episode_id": loop.episode_id, "control_generation": loop.control_generation,
		"revision": loop.controller.current_revision()}
	_submitted_at = Time.get_ticks_msec()
	_claimed = false
	_status = "Goal sent. Waiting for the operator."
	_emit()
	return {"queued": true}


func poll(args: Dictionary) -> Dictionary:
	var identity: Variant = args.get("operator_id", "")
	if not identity is String or identity.length() < 16 or identity.length() > 64:
		return {"error": "invalid_operator"}
	if not _operator.is_empty() and _operator != identity and connected():
		return {"error": "operator_already_connected"}
	_operator = identity
	_heartbeat = Time.get_ticks_msec()
	_last_connected = true
	_emit()
	if _request.is_empty() or _claimed or loop.state != "ready":
		return {"job": {}, "policy": {"max_steps": 8, "max_observations": 9, "seconds": 300}}
	if not _context_valid():
		cancel()
		return {"job": {}}
	_claimed = true
	_claimed_at = Time.get_ticks_msec()
	_status = "Running the goal. Stop is always available."
	_emit()
	return {"job": _request.duplicate(), "policy": {"max_steps": 8, "max_observations": 9, "seconds": 300}}


func leave(args: Dictionary) -> Dictionary:
	if args.get("operator_id") != _operator:
		return {"error": "invalid_operator"}
	_operator = ""
	if busy():
		cancel()
	_emit()
	return {"disconnected": true}


func cancel(status: String = "Goal run stopped.") -> void:
	var had_request: bool = busy()
	_request.clear()
	_claimed = false
	_status = status if had_request else _status
	if had_request and loop.enabled:
		loop.cancel("goal_cancelled")
	_emit()


func _context_valid() -> bool:
	return loop.enabled and _request.get("episode_id") == loop.episode_id and _request.get("control_generation") == loop.control_generation and _request.get("revision") == loop.controller.current_revision()


func _on_loop_state(_snapshot: Dictionary) -> void:
	if busy() and (loop.state in ["stopped", "fault"] or not _context_valid()):
		# An actor Stop is an observed end, not a certified achievement of the goal.
		cancel("Goal run stopped." if loop.state == "stopped" else "Goal run failed. Check the recent events.")


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if busy() and ((not _claimed and (not connected() or now - _submitted_at > QUEUE_TTL_MS)) or (_claimed and now - _claimed_at > GOAL_LIMIT_MS)):
		cancel("Goal run reached its limit and stopped.")
	var present: bool = connected()
	if present != _last_connected:
		_last_connected = present
		_emit()


func _emit() -> void:
	status_changed.emit(connected(), busy(), _status)
