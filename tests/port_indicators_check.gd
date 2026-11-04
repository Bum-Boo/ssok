extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph := ConnectionGraph.new()
	var plate: PartDef = load("res://assets/construction_kit/parts/kit_plate_120_80.tres")
	var beam: PartDef = load("res://assets/construction_kit/parts/kit_beam_60.tres")
	graph.parts.append({"part_def": plate, "transform": Transform3D.IDENTITY})
	var beam_offset: Vector3 = plate.ports[0].local_position - beam.ports[1].local_position
	graph.parts.append({"part_def": beam, "transform": Transform3D(Basis.IDENTITY, beam_offset)})
	var indicators := PortIndicators.new()
	root.add_child(indicators)
	indicators.refresh(graph)
	_check(indicators.ring_count() == 0, "unselected assembly has no rings")
	indicators.refresh(graph, 0)
	_check(indicators.ring_count() == plate.ports.size(), "selection shows the selected part's free holes")
	indicators.refresh(graph, -1, {"active": true, "target_part": 0, "target_port": plate.ports[0].id})
	_check(indicators.ring_count() == plate.ports.size() + beam.ports.size(), "placement shows every free mechanical port")
	# The dummy headless renderer does not retain MultiMesh GPU buffer values.
	# The rendered invocation verifies these properties against actual GL buffers.
	if DisplayServer.get_name() != "headless":
		var ring_pose: Transform3D = indicators.rings.multimesh.get_instance_transform(0)
		_check(ring_pose.basis.y.normalized().is_equal_approx(plate.ports[0].local_normal), "ring normal follows port face")
		_check(is_equal_approx(ring_pose.basis.x.length(), 1.6), "target ring grows by 1.6")
		_check(ring_pose.origin.is_equal_approx(plate.ports[0].local_position + plate.ports[0].local_normal * 0.0003), "ring lifts 0.3 mm off the face")
	indicators.refresh(graph, -1, {"active": true, "moving_part": 1})
	_check(indicators.ring_count() == plate.ports.size(), "moving part's hidden old position leaves no floating rings")
	graph.links.append({"a_part": 0, "a_port": plate.ports[0].id, "b_part": 1, "b_port": beam.ports[1].id})
	indicators.refresh(graph, -1, {"active": true})
	_check(indicators.ring_count() == plate.ports.size() + beam.ports.size() - 2, "both occupied endpoints lose their ring")
	_check(indicators.bolt_count() == 1, "a mechanical hole link creates exactly one hex bolt")
	var bolt_mesh: CylinderMesh = indicators.bolts.multimesh.mesh
	_check(bolt_mesh.radial_segments == 6 and is_equal_approx(bolt_mesh.height, 0.0025) and is_equal_approx(bolt_mesh.top_radius, 0.0035), "bolt has specified hex dimensions")
	if DisplayServer.get_name() != "headless":
		var bolt_pose: Transform3D = indicators.bolts.multimesh.get_instance_transform(0)
		_check(bolt_pose.origin.z > beam_offset.z + beam.ports[0].local_position.z, "bolt head sits outside the attached beam rather than inside its contact face")
	indicators.refresh(graph, -1, {"active": true}, true)
	_check(not indicators.rings.visible and indicators.bolts.visible, "run hides rings and preserves bolt heads")
	var run := RunMode.new()
	root.add_child(run)
	run.build(graph)
	indicators.set_run_mode(run)
	_check(not indicators.rings.visible, "runtime binding hides rings independently of refresh")
	if DisplayServer.get_name() != "headless":
		var before: Transform3D = indicators.bolts.multimesh.get_instance_transform(0)
		for body: RigidBody3D in run.bodies:
			body.freeze = true
		# Both parts may share a merged body. Move each unique body once.
		var moved: Dictionary = {}
		for body: RigidBody3D in run.bodies:
			if not moved.has(body):
				body.position.x += 0.02
				moved[body] = true
		await process_frame
		await process_frame
		var after: Transform3D = indicators.bolts.multimesh.get_instance_transform(0)
		_check(is_equal_approx(after.origin.x - before.origin.x, 0.02), "runtime bolt follows graph-derived moving body")
	indicators.set_run_mode(null)
	run.teardown()
	run.queue_free()
	SsokTheme.configure(false, 1.0, 1.0)
	indicators.refresh(graph, -1, {"active": true})
	if DisplayServer.get_name() != "headless":
		var light_color: Color = indicators.rings.multimesh.get_instance_color(0)
		_check(absf(light_color.r - SsokTheme.ACCENT.r) < 0.01, "light theme updates existing ring colors")
	else:
		print("MultiMesh GPU buffer checks: run with a display (dummy headless renderer has no buffers)")
	SsokTheme.configure(true, 1.0, 1.0)
	var shaft_graph := ConnectionGraph.new()
	var motor: PartDef = load("res://assets/construction_kit/parts/kit_motor_12.tres")
	shaft_graph.parts.append({"part_def": motor, "transform": Transform3D.IDENTITY})
	indicators.refresh(shaft_graph, 0)
	var mechanical: Array[Port] = []
	for port: Port in motor.ports:
		if port.kind == Port.Kind.MECH:
			mechanical.append(port)
	_check(indicators.ring_count() == mechanical.size(), "motor mechanical holes and shaft get rings, electrical pins stay separate")
	if DisplayServer.get_name() != "headless":
		for index: int in mechanical.size():
			if mechanical[index].rotates:
				var shaft_color: Color = indicators.rings.multimesh.get_instance_color(index)
				_check(absf(shaft_color.r - SsokTheme.SHAFT.r) < 0.01, "rotating shaft uses theme shaft color")
	await _check_picking()
	if "--screenshots" in OS.get_cmdline_user_args():
		await _screenshots(graph)
	indicators.queue_free()
	print("port_indicators_check: %d failure(s)" % _failures)
	quit(1 if _failures else 0)


func _check_picking() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var frame := PartDef.new()
	frame.id = &"picking_frame"
	frame.mesh = BoxMesh.new()
	frame.mesh.size = Vector3(0.1, 0.1, 0.01)
	frame.collision_boxes = [AABB(Vector3(-0.05, -0.05, -0.005), Vector3(0.01, 0.1, 0.01)), AABB(Vector3(0.04, -0.05, -0.005), Vector3(0.01, 0.1, 0.01)), AABB(Vector3(-0.04, -0.05, -0.005), Vector3(0.08, 0.01, 0.01)), AABB(Vector3(-0.04, 0.04, -0.005), Vector3(0.08, 0.01, 0.01))]
	var front := PartNode.new()
	front.setup(frame, 0)
	world.add_child(front)
	var behind := PartNode.new()
	var solid: PartDef = frame.duplicate()
	solid.id = &"picking_behind"
	solid.collision_boxes = []
	behind.setup(solid, 1)
	world.add_child(behind)
	behind.position.z = -0.05
	var gizmo := TransformGizmo.new()
	world.add_child(gizmo)
	gizmo.set_enabled(true)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 0, 0.2), Vector3(0, 0, -0.2), 1)
	var hit: Dictionary = space.intersect_ray(query)
	_check(not hit.is_empty() and hit.collider.get_meta(&"part_node", null) == behind, "ray passes through hollow frame to fallback AABB part")
	query.from.x = -0.045
	query.to.x = -0.045
	hit = space.intersect_ray(query)
	_check(not hit.is_empty() and hit.collider.get_meta(&"part_node", null) == front, "ray hits actual frame side")
	for handle: Node in gizmo.get_children():
		_check(handle.collision_layer == 2, "gizmo uses its own picking layer")
	front.set_placement_preview(true)
	_check(front.get_child(-1).collision_layer == 0, "ghost cannot occlude target picking")
	front.clear_placement_preview()
	_check(front.get_child(-1).collision_layer == 1, "confirmed part restores picking")
	world.queue_free()
	await process_frame


func _screenshots(graph: ConnectionGraph) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 700)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var fixture := Node3D.new()
	viewport.add_child(fixture)
	for entry: Dictionary in graph.parts:
		var part := PartNode.new()
		part.setup(entry.part_def, -1)
		fixture.add_child(part)
		part.transform = entry.transform
	var preview := PartNode.new()
	preview.setup(graph.parts[1].part_def, -1)
	fixture.add_child(preview)
	preview.position = Vector3(0.09, 0, 0.025)
	var blocked := PartNode.new()
	blocked.setup(graph.parts[1].part_def, -1)
	fixture.add_child(blocked)
	blocked.position = Vector3(-0.09, 0, 0.025)
	var camera := Camera3D.new()
	fixture.add_child(camera)
	camera.position = Vector3(0.13, 0.1, 0.25)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.25
	camera.near = 0.001
	camera.current = true
	var light := DirectionalLight3D.new()
	fixture.add_child(light)
	light.rotation_degrees = Vector3(-35, -30, 0)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.7
	fixture.add_child(environment)
	var indicators := PortIndicators.new()
	fixture.add_child(indicators)
	DirAccess.make_dir_recursive_absolute("user://port_indicators_previews")
	for dark: bool in [true, false]:
		SsokTheme.configure(dark, 1.0, 1.0)
		environment.environment.background_color = SsokTheme.BG
		preview.set_placement_preview(false)
		blocked.set_placement_preview(true)
		indicators.refresh(graph, -1, {"active": true, "target_part": 0, "target_port": graph.parts[0].part_def.ports[-2].id})
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "user://port_indicators_previews/%s.png" % ("dark" if dark else "light")
		_check(viewport.get_texture().get_image().save_png(path) == OK, "rendered indicator evidence saved")
	viewport.queue_free()
	SsokTheme.configure(true, 1.0, 1.0)


func _check(passed: bool, message: String) -> void:
	if not passed:
		_failures += 1
		push_error(message)
