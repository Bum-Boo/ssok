extends SceneTree
## DEBUG-r23: geometry replay only; no simulation, actor, image generation or production edit.
func vector(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func run_projection() -> void:
	var location: String = "res://build/ai-loop-evidence/completion/projection-r23/"
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(location + "input.json"))
	var graph: ConnectionGraph = RobotCarPreset.build(input.wall_x)
	var mode: RunMode = RunMode.new()
	root.add_child(mode)
	mode.build(graph)
	var offset: Transform3D = mode._body_offsets[0]
	assert(offset.is_equal_approx(Transform3D.IDENTITY), "Replay requires graph chassis/body identity")
	var wall: PartDef = graph.parts[-1].part_def
	var bounds: AABB = wall.mesh.get_aabb()
	var wall_front: float = input.wall_x + bounds.position.x
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	var floor_mesh: MeshInstance3D = main.get_node("Floor/MeshInstance3D")
	var floor_bounds: AABB = floor_mesh.mesh.get_aabb()
	var floor_y: float = floor_mesh.transform.origin.y + floor_bounds.end.y
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(640, 480)
	root.add_child(viewport)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 60.0
	camera.near = 0.005
	camera.far = 20.0
	viewport.add_child(camera)
	camera.current = true
	var loop: AgentCameraLoop = AgentCameraLoop.new()
	var mount: Transform3D = loop._mount
	var rows: Array[Dictionary] = []
	for row: Dictionary in input.rows:
		var body_pose: Transform3D = Transform3D(Basis.from_euler(vector(row.rotation)), vector(row.position))
		camera.global_transform = body_pose * offset * mount
		var position: Vector3 = camera.global_position
		var center: Vector3 = camera.project_ray_normal(Vector2(320, 240))
		var z_wall: float = position.z + (wall_front - position.x) * center.z / center.x
		var boundary: Vector2 = camera.unproject_position(Vector3(wall_front, floor_y, z_wall))
		var targets: Dictionary = {}
		var projected_gaps: Dictionary = {}
		var camera_to_front: float = wall_front - row.gap_m - position.x
		for pixel: int in [12, 20, 24, 31, 38]:
			var ray: Vector3 = camera.project_ray_normal(Vector2(320, 480 - pixel))
			var distance_x: float = ray.x * (floor_y - position.y) / ray.y
			targets[str(pixel)] = distance_x - camera_to_front
		for gap: float in [0.04, 0.14]:
			var virtual_wall_x: float = position.x + camera_to_front + gap
			var virtual_z: float = position.z + (virtual_wall_x - position.x) * center.z / center.x
			projected_gaps[str(gap)] = 480 - camera.unproject_position(Vector3(virtual_wall_x, floor_y, virtual_z)).y
		var leveling: Transform3D = Transform3D(Basis.IDENTITY, body_pose.origin) * mount
		var actual: Transform3D = camera.global_transform
		camera.global_transform = leveling
		var leveled_z: float = camera.global_position.z
		var leveled_floor: float = 480 - camera.unproject_position(Vector3(wall_front, floor_y, leveled_z)).y
		camera.global_transform = actual
		rows.append({"case":row.case,"label":row.label,"sha256":row.png_sha256,
			"predicted_floor_pixels":480 - boundary.y,"classified_floor_pixels":row.pixels.floor_pixels,
			"prediction_error_pixels":480 - boundary.y - row.pixels.floor_pixels,
			"target_gap_m":targets,"fixed_gap_floor_pixels":projected_gaps,
			"level_body_at_same_origin_floor_pixels":leveled_floor,
			"camera_position":[position.x,position.y,position.z],
			"camera_basis":[[actual.basis.x.x,actual.basis.x.y,actual.basis.x.z],[actual.basis.y.x,actual.basis.y.y,actual.basis.y.z],[actual.basis.z.x,actual.basis.z.y,actual.basis.z.z]],
			"camera_to_robot_front_x_m":camera_to_front,"observed_gap_m":row.gap_m,
			"pose_provenance":row.pose_provenance})
	var file: FileAccess = FileAccess.open(location + "projection.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows,"wall_front_x_m":wall_front,"floor_y_m":floor_y,
		"graph_chassis_offset_identity":true,"camera_fov":camera.fov,"keep_aspect":camera.keep_aspect,
		"viewport":[640,480],"scope":"Headless numerical replay of archived poses; no new images, physical trajectories or AI trials."}, "\t") + "\n")
	file.close()
	main.free()
	loop.free()
	mode.free()
	viewport.free()
	print("DEBUG-r23 projected ", rows.size(), " archived poses")
	quit(0)

func _initialize() -> void:
	run_projection.call_deferred()
