class_name RobotMotionProgram
extends Node

## High-level movement commands are interpreted by a robot-specific joint program.

signal status_changed(message: String)

var _hardware: RunMode
var _graph: ConnectionGraph
var _enabled: bool = false
var _supported: bool = false
var _status: String = "No robot movement program configured"
var _move_input: Vector2 = Vector2.ZERO


func configure(hardware: RunMode, graph: ConnectionGraph) -> bool:
	set_enabled(false)
	_hardware = hardware
	_graph = graph
	_supported = false
	return false


func set_enabled(enabled: bool) -> void:
	_enabled = enabled and _supported
	if not _enabled:
		_move_input = Vector2.ZERO
	set_physics_process(_enabled)


func set_move_input(command: Vector2) -> void:
	_move_input = command.limit_length(1.0) if command.is_finite() else Vector2.ZERO


func is_supported() -> bool:
	return _supported


func get_status() -> String:
	return _status


func _set_status(message: String) -> void:
	if message == _status:
		return
	_status = message
	status_changed.emit(message)
