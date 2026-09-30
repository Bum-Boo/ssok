class_name AppController
extends RefCounted

const TOOLS: Array[String] = ["get_scene", "list_parts", "place_part", "remove_part", "connect_parts", "connect_wire", "set_program", "run", "stop", "get_result"]
const MUTATIONS: Array[String] = ["place_part", "remove_part", "connect_parts", "connect_wire", "set_program", "run"]
var app: Node3D
var allow_edits: bool = false
var origin: String = "agent"
var record_events: bool = false
var events: Array[Dictionary] = []
var revision: int = 0
var _last_fingerprint: String = ""


func invoke(tool: String, args: Dictionary = {}, expected_revision: int = -1) -> Dictionary:
	_refresh_revision()
	if tool not in TOOLS:
		return {"error": "unknown_tool", "revision": revision}
	if tool in MUTATIONS:
		if not allow_edits:
			return {"error": "edits_disabled", "revision": revision}
		if expected_revision != revision:
			return {"error": "stale_revision", "revision": revision}
		if app.mode_button.button_pressed and tool != "run":
			return {"error": "return_to_edit_mode", "revision": revision}
	var data: Variant = {}
	match tool:
		"get_scene":
			data = {"graph": MotionSnapshot.encode(app.assembly.graph), "source": app.code_edit.text, "run_mode": app.run_mode.is_built(), "board": app.blocks.profile.id}
		"list_parts":
			var definitions: Array[Dictionary] = []
			for definition: PartDef in MotionSnapshot._catalog().values():
				var ports: Array[Dictionary] = []
				for port: Port in definition.ports:
					ports.append({"id": String(port.id), "kind": int(port.kind), "tag": String(port.tag), "accepts": Array(port.accepts)})
				definitions.append({"id": String(definition.id), "label": definition.display_name, "ports": ports})
			data = definitions
		"place_part":
			var id: Variant = args.get("id")
			var pose: Variant = args.get("transform")
			if not id is String or not pose is Array:
				return {"error": "invalid_part"}
			var graph: ConnectionGraph = MotionSnapshot.decode({"version": 1, "parts": [{"id": id, "transform": pose}], "links": []})
			if graph == null:
				return {"error": "invalid_part"}
			var part: PartNode = app.assembly.spawn_part(graph.parts[0].part_def, graph.parts[0].transform)
			if part == null:
				return {"error": "part_limit"}
			data = {"part": app.assembly.graph.parts.size() - 1}
		"remove_part":
			if not _part_number(args.get("part")):
				return {"error": "invalid_part"}
			app.assembly.remove_part(app.assembly._part_nodes[int(args.part)])
		"connect_wire", "connect_parts":
			if not _part_number(args.get("a_part")) or not _part_number(args.get("b_part")) or not args.get("a_port") is String or not args.get("b_port") is String:
				return {"error": "invalid_wire"}
			var connected: bool = app.assembly.connect_wire(int(args.a_part), StringName(args.a_port), int(args.b_part), StringName(args.b_port)) if tool == "connect_wire" else app.assembly.connect_parts(int(args.a_part), StringName(args.a_port), int(args.b_part), StringName(args.b_port))
			if not connected:
				return {"error": "incompatible_or_occupied_port"}
		"set_program":
			if not args.get("source") is String or args.source.to_utf8_buffer().size() > ProjectStore.MAX_CODE_BYTES:
				return {"error": "invalid_program"}
			if app.blocks.has_draft():
				return {"error": "pending_block_draft"}
			app.code_edit.text = args.source
			app.blocks.reset_source(args.source)
		"run":
			if app.runtime.is_running():
				return {"error": "already_running"}
			var validation: Dictionary = app.runtime.validate(app.code_edit.text, false)
			if not validation.is_empty():
				return {"error": "invalid_program", "details": validation}
			app._on_run_pressed()
			data = {"running": app.runtime.is_running(), "physics_built": app.run_mode.is_built()}
		"stop":
			app._on_stop_pressed()
			data = {"running": false}
		"get_result":
			var motors: Array[Dictionary] = []
			for part: int in app.run_mode.motors:
				var motor: DriveMotor = app.run_mode.motors[part]
				motors.append({"part": part, "measured_rad_s": motor.measured_rad_s, "applied_torque_nm": motor.applied_torque_nm})
			var servos: Array[Dictionary] = []
			for part: int in app.run_mode.servos:
				var drive: ServoDrive = app.run_mode.servos[part]
				servos.append({"part": part, "angle_deg": drive.observe_angle(), "target_deg": drive.target_deg})
			data = {"running": app.runtime.is_running(), "line": app.runtime.current_line, "state": app.runtime.state, "failure": app.runtime.last_failure, "servos": servos, "motors": motors, "stage_id": app.stages.current.get("id", ""), "stage": app.stages.evaluator.result()}
	_refresh_revision()
	if record_events and events.size() < 1000:
		events.append({"tool": tool, "origin": origin, "physics_frame": Engine.get_physics_frames(), "revision": revision})
	return {"data": data, "revision": revision}


func _part_number(value: Variant) -> bool:
	return MotionSnapshot._is_integer(value) and value >= 0 and value < app.assembly.graph.parts.size()


func _refresh_revision() -> void:
	var fingerprint: String = JSON.stringify([MotionSnapshot.encode(app.assembly.graph), app.code_edit.text, app.mode_button.button_pressed], "", true, true).sha256_text()
	if fingerprint != _last_fingerprint:
		revision += 1
		_last_fingerprint = fingerprint
