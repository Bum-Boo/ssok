extends SceneTree

## Builds the mesh of the 4xAA battery holder from primitives and saves it under
## assets/power, apart from the Blender-sourced parts. Run headless from the repository root:
##   godot --headless --path . -s tools/godot/make_power_parts.gd

const OUTPUT: String = "res://assets/power/meshes/battery_holder_4aa.res"
## Outer size of the holder in metres (x, y, z); four AA cells lie along z.
const BODY: Vector3 = Vector3(0.062, 0.016, 0.058)
const CELL_RADIUS: float = 0.00725
const CELL_LENGTH: float = 0.0505
const CELL_PITCH: float = 0.0148


func _initialize() -> void:
	var black: Material = load("res://assets/materials/black.tres")
	var steel: Material = load("res://assets/materials/detail_steel.tres")
	var gold: Material = load("res://assets/materials/gold.tres")
	var red: Material = load("res://assets/materials/red.tres")
	var mesh := ArrayMesh.new()

	# Tray: floor plus two end walls, so the cells stay visible from above.
	var tray := SurfaceTool.new()
	tray.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tray, Vector3(BODY.x, 0.003, BODY.z), Vector3(0, -BODY.y * 0.5 + 0.0015, 0))
	for z: float in [-1.0, 1.0]:
		_box(tray, Vector3(BODY.x, BODY.y, 0.003), Vector3(0, 0, z * (BODY.z * 0.5 - 0.0015)))
	for x: float in [-1.0, 1.0]:
		_box(tray, Vector3(0.002, BODY.y * 0.6, BODY.z), Vector3(x * (BODY.x * 0.5 - 0.001), -BODY.y * 0.2, 0))
	_commit(tray, mesh, black)

	var cells := SurfaceTool.new()
	cells.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in 4:
		_cylinder(cells, CELL_RADIUS, CELL_LENGTH, Vector3((index - 1.5) * CELL_PITCH, -BODY.y * 0.5 + 0.003 + CELL_RADIUS, 0))
	_commit(cells, mesh, steel)

	# Positive caps alternate ends, as cells do in a series holder.
	var caps := SurfaceTool.new()
	caps.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in 4:
		var end: float = 1.0 if index % 2 == 0 else -1.0
		_cylinder(caps, 0.0028, 0.002, Vector3((index - 1.5) * CELL_PITCH, -BODY.y * 0.5 + 0.003 + CELL_RADIUS, end * (CELL_LENGTH * 0.5 + 0.001)))
	_commit(caps, mesh, gold)

	# Slide switch on the side wall.
	var switch := SurfaceTool.new()
	switch.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(switch, Vector3(0.004, 0.005, 0.009), Vector3(BODY.x * 0.5 + 0.002, -0.001, 0.012))
	_commit(switch, mesh, red)

	var error: Error = ResourceSaver.save(mesh, OUTPUT)
	print("make_power_parts: ", OUTPUT, " surfaces=", mesh.get_surface_count(), " error=", error)
	quit(0 if error == OK else 1)


func _box(tool: SurfaceTool, size: Vector3, center: Vector3) -> void:
	var shape := BoxMesh.new()
	shape.size = size
	tool.append_from(shape, 0, Transform3D(Basis.IDENTITY, center))


func _cylinder(tool: SurfaceTool, radius: float, length: float, center: Vector3) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = length
	shape.radial_segments = 24
	shape.rings = 1
	# CylinderMesh stands along y; cells lie along z.
	tool.append_from(shape, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), center))


func _commit(tool: SurfaceTool, mesh: ArrayMesh, material: Material) -> void:
	tool.set_material(material)
	tool.commit(mesh)
