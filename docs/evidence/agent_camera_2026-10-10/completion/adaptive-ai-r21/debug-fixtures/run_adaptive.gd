extends "res://tools/app_control/run_desktop.gd"

## DEBUG-r21: own rendered fixture only, normal exit after actual Stop evaluation readback.
var _seen_active: bool = false
var _closing: bool = false

func _process(_delta: float) -> bool:
	if app == null or _closing:
		return false
	if app.agent_loop.enabled:
		_seen_active = true
	elif _seen_active:
		_closing = true
		_finish.call_deferred()
	return false

func _finish() -> void:
	for tick: int in 132:
		await physics_frame
	for tick: int in 900:
		if FileAccess.file_exists("user://r21-runner-finished.json"):
			break
		await physics_frame
	app.free()
	quit(0)
