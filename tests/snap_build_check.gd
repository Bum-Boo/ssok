extends SceneTree

var checks := 0
var failures := 0
var assembly: AssemblyMode
const PARTS := "res://assets/construction_kit/parts/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assembly = AssemblyMode.new()
	root.add_child(assembly)
	var plate_def: PartDef = load(PARTS + "kit_plate_120_80.tres")
	var beam_def: PartDef = load(PARTS + "kit_beam_60.tres")
	# Rotate the stock XY plate onto the workbench, front face up.
	var plate := assembly.spawn_part(plate_def, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.1, 0)))
	var target := plate.get_port_global_position(&"h2_front")
	_check(assembly.begin_place(beam_def), "begin new beam")
	assembly.update_place_ray(target + Vector3.UP, Vector3.DOWN)
	var state := assembly.placement_state()
	_check(state.target_part == 0 and state.target_port == &"h2_front", "cursor picks visible plate hole")
	var anchor := _port(beam_def, state.anchor_port)
	var expected := AssemblyMode.align_port_transform(Transform3D.IDENTITY, anchor, target, Vector3.UP)
	_check(state.transform.is_equal_approx(expected), "ghost equals shared pure alignment")
	assembly.rotate_place(1)
	state = assembly.placement_state()
	_check(state.transform.basis.is_equal_approx(Basis(Vector3.UP, PI * 0.5) * expected.basis), "twist is 90 degrees about target normal")
	var old_anchor: StringName = state.anchor_port
	assembly.cycle_anchor()
	_check(assembly.placement_state().anchor_port != old_anchor, "Tab changes compatible anchor")
	assembly.cancel_place()
	assembly.begin_place(beam_def)
	assembly.update_place_ray(target + Vector3.UP, Vector3.DOWN)
	var count := assembly.commit_place()
	_check(count >= 2, "coincident beam row creates multiple links")
	_check(assembly.graph.parts.size() == 2 and assembly.graph.links.size() == count, "part and all links committed")
	var indicators := PortIndicators.new()
	root.add_child(indicators)
	indicators.refresh(assembly.graph, -1, {"active": true})
	_check(indicators.ring_count() == plate_def.ports.size() + beam_def.ports.size() - count * 2, "rings count all and only unoccupied mechanical ports")
	_check(indicators.bolt_count() == count, "one bolt per linked kit hole")
	_check(assembly.undo(), "one undo accepted")
	_check(assembly.graph.parts.size() == 1 and assembly.graph.links.is_empty(), "one undo removes part and every new link")
	_check(assembly.redo(), "redo restores placement")
	plate = assembly._part_nodes[0]
	var beam: PartNode = assembly._part_nodes[1]
	var before: Transform3D = beam.global_transform
	var old_links := assembly.graph.links.duplicate(true)
	_check(assembly.begin_move(beam), "begin_move accepts placed beam")
	_check(assembly.graph.links.is_empty(), "move detaches mechanical links")
	var second_target := plate.get_port_global_position(&"h8_front")
	assembly.update_place_ray(second_target + Vector3.UP, Vector3.DOWN)
	_check(not assembly.placement_state().transform.is_equal_approx(before), "move previews another hole")
	assembly.cancel_place()
	_check(beam.global_transform.is_equal_approx(before) and assembly.graph.links == old_links, "cancel restores exact transform and links")
	assembly.begin_move(beam)
	assembly.update_place_ray(second_target + Vector3.UP, Vector3.DOWN)
	_check(assembly.commit_place() >= 1, "move commits at another hole")
	assembly.undo()
	_check(beam.global_transform.is_equal_approx(before) and assembly.graph.links == old_links, "one move undo restores original assembly")
	assembly.begin_place(beam_def)
	assembly.update_place_ray(target + Vector3.UP, Vector3.DOWN)
	state = assembly.placement_state()
	_check(state.target_part != 0 or not assembly._is_port_linked(0, state.target_port), "occupied hole is never a target")
	assembly.cancel_place()
	# An independent obstacle lies above an unoccupied target hole.
	var obstacle_def := PartDef.new()
	obstacle_def.id = &"test_obstacle"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, 0.012)
	obstacle_def.mesh = mesh
	obstacle_def.collision_boxes = [AABB(-mesh.size * 0.5, mesh.size)]
	var free_target := plate.get_port_global_position(&"h16_front")
	assembly.spawn_part(obstacle_def, Transform3D(Basis.IDENTITY, free_target + Vector3(0, 0.006, 0.02)))
	assembly.begin_place(beam_def)
	assembly.update_place_ray(free_target + Vector3.UP, Vector3.DOWN)
	var unchanged := assembly._snapshot()
	_check(assembly.placement_state().blocked, "obstacle or incompatible surface blocks preview")
	_check(assembly.placement_state().reason == "This spot is blocked. Try another hole.", "penetrating ghost reports collision rather than incompatible surface")
	_check(assembly.commit_place() == -1 and assembly._snapshot() == unchanged, "blocked commit leaves graph unchanged")
	assembly.update_place_ray(free_target + Vector3(0, 1, 0.02), Vector3.DOWN)
	_check(assembly.placement_state().blocked and assembly.placement_state().reason == "This part has no matching hole here. Try the floor or another part.", "incompatible surface directs learner to floor or another part")
	assembly.cancel_place()
	assembly.begin_place(beam_def)
	assembly.update_place_ray(Vector3(0.503, 1, 0.507), Vector3.DOWN)
	state = assembly.placement_state()
	_check(state.target_part == -1 and not state.blocked, "empty space chooses floor")
	var floor_bounds: AABB = state.transform * beam_def.mesh.get_aabb()
	_check(is_equal_approx(floor_bounds.position.y, ServoArmPreset.FLOOR_TOP), "floor placement rests mesh on workbench")
	_check(is_equal_approx(state.transform.origin.x, 0.5) and is_equal_approx(state.transform.origin.z, 0.51), "floor placement uses 10 mm grid")
	var links_before := assembly.graph.links.size()
	_check(assembly.commit_place() == 0 and assembly.graph.links.size() == links_before, "floor commit adds no links")
	# Direct SAT coverage distinguishes penetration from touching, including rotated stock.
	var unit := AABB(Vector3(-0.01, -0.01, -0.01), Vector3.ONE * 0.02)
	_check(AssemblyMode._boxes_overlap(Transform3D.IDENTITY, unit, Transform3D(Basis.IDENTITY, Vector3(0.01, 0, 0)), unit), "overlapping collision boxes obstruct")
	_check(not AssemblyMode._boxes_overlap(Transform3D.IDENTITY, unit, Transform3D(Basis.IDENTITY, Vector3(0.02, 0, 0)), unit), "face contact is allowed")
	_check_wire_preservation()
	indicators.free()
	assembly.free()
	await process_frame
	print("snap_build_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_wire_preservation() -> void:
	var edit := AssemblyMode.new()
	root.add_child(edit)
	var base := edit.spawn_part(load("res://assets/parts/base.tres"), Transform3D.IDENTITY)
	var servo := edit.spawn_part(load("res://assets/parts/servo.tres"), Transform3D.IDENTITY)
	var board := edit.spawn_part(load("res://assets/parts/board.tres"), Transform3D(Basis.IDENTITY, Vector3(0.3, 0.1, 0)))
	_check(edit.snap(servo, &"mount_bottom", base, &"mount_top"), "wire fixture has mechanical mounting")
	_check(edit.connect_wire(servo.graph_index, &"signal_pin", board.graph_index, &"pin_9"), "wire fixture uses graph-selected pin")
	var original := edit._snapshot()
	edit.begin_move(servo)
	_check(edit.graph.links.size() == 1 and edit._is_port_linked(servo.graph_index, &"signal_pin"), "begin_move detaches only mechanics and retains electrical wire")
	edit.cancel_place()
	_check(edit._snapshot() == original, "move cancellation restores mechanical and electrical snapshot")
	edit.begin_move(servo)
	edit.update_place_ray(Vector3(0.7, 1, 0.7), Vector3.DOWN)
	_check(edit.commit_place() == 0 and edit.graph.links.size() == 1, "floor re-placement keeps electrical connection")
	edit.undo()
	_check(edit._snapshot() == original, "move Undo restores original transform and both link kinds")
	edit.free()


func _port(definition: PartDef, id: StringName) -> Port:
	for port: Port in definition.ports:
		if port.id == id:
			return port
	return null


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
