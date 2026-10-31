extends SceneTree

const PARTS: String = "res://assets/construction_kit/parts/"
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _part(id: StringName, role: String, kind: Port.Kind = Port.Kind.MECH, merge: bool = true) -> PartDef:
	var definition := PartDef.new()
	definition.id = id
	definition.environment_role = role
	definition.merge_fixed_connections = merge
	definition.mass_kg = 0.05
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.02
	definition.mesh = mesh
	var port := Port.new()
	port.id = &"mount"
	port.kind = kind
	definition.ports = [port]
	return definition


func _cup_graph() -> ConnectionGraph:
	var graph := ConnectionGraph.new()
	graph.parts.append({"part_def": load(PARTS + "kit_env_cup.tres"), "transform": Transform3D.IDENTITY})
	return graph


func _count(graph: ConnectionGraph) -> int:
	var reader := RunMode.new()
	root.add_child(reader)
	reader.build(graph)
	var value: int = reader.cup_object_count()
	reader.free()
	return value


func _run() -> void:
	var inside: Vector3 = Vector3(0, 0.03, 0)
	# Transitive chain: object - object - robot structure.
	var graph := _cup_graph()
	graph.parts.append({"part_def": _part(&"o1", "object", Port.Kind.MECH, false), "transform": Transform3D(Basis.IDENTITY, inside)})
	graph.parts.append({"part_def": _part(&"o2", "object", Port.Kind.MECH, false), "transform": Transform3D(Basis.IDENTITY, inside + Vector3(0.03, 0, 0))})
	graph.parts.append({"part_def": _part(&"s", "", Port.Kind.MECH, false), "transform": Transform3D(Basis.IDENTITY, Vector3(0.5, 0.03, 0))})
	graph.links.append({"a_part": 1, "a_port": &"mount", "b_part": 2, "b_port": &"mount"})
	graph.links.append({"a_part": 3, "a_port": &"mount", "b_part": 2, "b_port": &"mount"})
	_check("transitive object chain to structure excluded", _count(graph), 0)
	# Jointed (not merged) free object pair: one RID each.
	graph.links.remove_at(1)
	_check("jointed free object pair counts per solver body", _count(graph), 2)
	# Electrical-only link from object to a structure part does not exclude.
	graph = _cup_graph()
	graph.parts.append({"part_def": _part(&"oe", "object", Port.Kind.ELEC), "transform": Transform3D(Basis.IDENTITY, inside)})
	graph.parts.append({"part_def": _part(&"be", "", Port.Kind.ELEC), "transform": Transform3D(Basis.IDENTITY, Vector3(0.5, 0.03, 0))})
	graph.links.append({"a_part": 1, "a_port": &"mount", "b_part": 2, "b_port": &"mount"})
	_check("electrical-only wire keeps object free", _count(graph), 1)
	# Mixed-kind link (invalid in the editor): a=ELEC object, b=MECH structure.
	graph = _cup_graph()
	graph.parts.append({"part_def": _part(&"om", "object", Port.Kind.MECH), "transform": Transform3D(Basis.IDENTITY, inside)})
	graph.parts.append({"part_def": _part(&"se", "", Port.Kind.ELEC), "transform": Transform3D(Basis.IDENTITY, Vector3(0.5, 0.03, 0))})
	graph.links.append({"a_part": 1, "a_port": &"mount", "b_part": 2, "b_port": &"mount"})
	print("MIXED a=MECH b=ELEC count=%d" % _count(graph))
	graph.links[0] = {"a_part": 2, "a_port": &"mount", "b_part": 1, "b_port": &"mount"}
	print("MIXED a=ELEC b=MECH count=%d" % _count(graph))
	# Rotated (45 deg) box object near a wall: OBB corners decide.
	graph = _cup_graph()
	graph.parts.append({"part_def": _part(&"rb", "object"), "transform": Transform3D(Basis(Vector3.UP, PI / 4), Vector3(0.0675, 0.03, 0))})
	_check("rotated box corner past wall is outside", _count(graph), 0)
	graph.parts[1].transform.origin.x = 0.065
	_check("rotated box corner within tolerance inside", _count(graph), 1)
	# Sideways cup, ball inside.
	graph = ConnectionGraph.new()
	graph.parts.append({"part_def": load(PARTS + "kit_env_cup.tres"), "transform": Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0, 0.08, 0))})
	graph.parts.append({"part_def": load(PARTS + "kit_env_ball.tres"), "transform": Transform3D(Basis(Vector3.FORWARD, 1.0), Vector3(-0.08, 0.02, 0))})
	_check("sideways cup contains ball", _count(graph), 1)
	graph.parts[1].transform.origin.x = -0.15
	_check("ball at sideways mouth edge is outside", _count(graph), 0)
	# Observed in a physical trial (speed 80, lateral 15 mm): ball pressed 1.003 mm into the floor.
	graph.parts[1].transform.origin = Vector3(-0.08, 0.018997, 0.06)
	print("SQUEEZED ball bottom=%.6f count=%d" % [0.018997 - 0.02, _count(graph)])
	# Frozen object is not counted.
	graph.parts[1].transform.origin.x = -0.08
	var reader := RunMode.new()
	root.add_child(reader)
	reader.build(graph)
	reader.bodies[1].freeze = true
	_check("frozen object not counted", reader.cup_object_count(), 0)
	reader.free()
	# Cost per call: N structure parts in a mechanical chain, one cup, one free ball.
	for size: int in [16, 64, 128, 256]:
		graph = _cup_graph()
		graph.parts.append({"part_def": load(PARTS + "kit_env_ball.tres"), "transform": Transform3D(Basis.IDENTITY, inside)})
		var structure: PartDef = _part(&"chain", "")
		for index: int in size - 2:
			graph.parts.append({"part_def": structure, "transform": Transform3D(Basis.IDENTITY, Vector3(0.5 + index * 0.03, 0.03, 0))})
			if index > 0:
				graph.links.append({"a_part": graph.parts.size() - 2, "a_port": &"mount", "b_part": graph.parts.size() - 1, "b_port": &"mount"})
		reader = RunMode.new()
		root.add_child(reader)
		reader.build(graph)
		var started: int = Time.get_ticks_usec()
		var value: int = reader.cup_object_count()
		var spent: float = (Time.get_ticks_usec() - started) / 1000.0
		print("COST parts=%d links=%d count=%d ms_per_call=%.1f (frame budget 16.7)" % [graph.parts.size(), graph.links.size(), value, spent])
		reader.free()
		await process_frame
	print("cup_observer_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(label: String, actual: int, expected: int) -> void:
	checks += 1
	if actual != expected:
		failures += 1
		print("FAIL %s actual=%d expected=%d" % [label, actual, expected])
	else:
		print("ok %s = %d" % [label, actual])
