extends SceneTree

const EXPECTED_PORT_PAIRS: Array[Array] = [
	[&"mount_top", &"mount_bottom"],
	[&"output_shaft", &"mount_base"],
	[&"signal_pin", &"pin_9"],
]

var _failed := false


func _initialize() -> void:
	call_deferred(&"_run_check")


func _run_check() -> void:
	var assembly := AssemblyMode.new()
	root.add_child(assembly)
	var base: PartNode = assembly.spawn_part(load("res://assets/parts/base.tres"), Transform3D.IDENTITY)
	var servo: PartNode = assembly.spawn_part(
		load("res://assets/parts/servo.tres"),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.026, 0.0))
	)
	_assert(assembly.try_snap(servo), "servo did not snap to base")

	var arm: PartNode = assembly.spawn_part(
		load("res://assets/parts/arm_link.tres"),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.081, 0.0))
	)
	_assert(assembly.try_snap(arm), "arm did not snap to servo")

	var signal_position := servo.get_port_global_position(&"signal_pin")
	var board: PartNode = assembly.spawn_part(
		load("res://assets/parts/board.tres"),
		Transform3D(Basis.IDENTITY, signal_position + Vector3(0.031, -0.0025, 0.02))
	)
	_assert(assembly.try_snap(board), "board pin did not snap to servo signal")

	print("parts: ", assembly.graph.parts.size())
	print("links: ", assembly.graph.links)
	_assert(assembly.graph.parts.size() == 4, "expected exactly 4 parts")
	_assert(assembly.graph.links.size() == 3, "expected exactly 3 links")
	for expected_pair: Array in EXPECTED_PORT_PAIRS:
		_assert(_has_port_pair(assembly.graph.links, expected_pair[0], expected_pair[1]),
			"missing expected port pair %s" % [expected_pair])
	_assert(_has_port_pair(assembly.graph.links, &"signal_pin", &"pin_9"),
		"nearest board port pin_9 was not selected")
	if _failed:
		quit(1)
	else:
		print("assembly_snap_check: PASS")
		quit(0)


func _has_port_pair(links: Array[Dictionary], first: StringName, second: StringName) -> bool:
	for link: Dictionary in links:
		if link["a_port"] == first and link["b_port"] == second:
			return true
		if link["a_port"] == second and link["b_port"] == first:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
