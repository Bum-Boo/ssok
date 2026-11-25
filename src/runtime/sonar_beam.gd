class_name SonarBeam
extends MeshInstance3D

## Run-mode view of an ultrasonic sensor while the learner's program reads it (ADR 0043): the
## sensing cone up to the measured echo, or a fading cone when nothing answered. Derived from the
## sensor's last reading only; it never feeds back into physics or the graph.

## Visual layer for overlays that a camera on the robot must not see.
const LAYER: int = 1 << 19
const SHADER: Shader = preload("res://assets/shaders/sonar_beam.gdshader")
## Same 7.5-degree half angle the sensor samples (SonarSensor.distance_cm).
const HALF_ANGLE: float = 0.1308997
const IDLE_LENGTH: float = 0.45
const MAX_LENGTH: float = 1.2
const HOLD_SECONDS: float = 0.35
const FADE_SECONDS: float = 0.35

var run_mode: RunMode
var part_index: int = -1
var _since_ping: float = INF
var _length: float = IDLE_LENGTH
var _material: ShaderMaterial


func _init() -> void:
	name = "SonarBeam"
	layers = LAYER
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = make_cone()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material_override = _material
	visible = false


## Called after each program reading. Distances are in centimetres, as the sensor reports them.
func ping(valid: bool, distance_cm: float) -> void:
	_since_ping = 0.0
	_length = clampf(distance_cm / 100.0, 0.02, MAX_LENGTH) if valid else IDLE_LENGTH
	_material.set_shader_parameter("echo", 1.0 if valid else 0.0)
	_material.set_shader_parameter("length_m", _length)
	_follow()
	visible = true


func opacity() -> float:
	if _since_ping <= HOLD_SECONDS:
		return 1.0
	return clampf(1.0 - (_since_ping - HOLD_SECONDS) / FADE_SECONDS, 0.0, 1.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_since_ping += delta
	var amount: float = opacity()
	if amount <= 0.0 or not is_instance_valid(run_mode) or not run_mode.is_built():
		visible = false
		return
	_material.set_shader_parameter("opacity", amount)
	_follow()


func _follow() -> void:
	if not is_instance_valid(run_mode) or not run_mode.is_built() or part_index < 0 or part_index >= run_mode.bodies.size():
		return
	# Same origin and axis as the sensor's rays; the unit cone is scaled to the reading.
	var pose: Transform3D = run_mode.part_global_transform(part_index)
	var origin: Vector3 = pose * Vector3(0, 0, 0.012)
	var basis: Basis = pose.basis.orthonormalized()
	global_transform = Transform3D(basis.scaled(Vector3(_length, _length, _length)), origin)


## Open cone of unit length along +Z. UV.y runs from the apex (0) to the rim (1).
static func make_cone(segments: int = 32) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var radius: float = tan(HALF_ANGLE)
	var rings: int = 8
	for ring: int in rings + 1:
		var along: float = float(ring) / float(rings)
		for segment: int in segments + 1:
			var angle: float = TAU * float(segment) / float(segments)
			var direction := Vector3(cos(angle), sin(angle), 0.0)
			vertices.append(Vector3(direction.x * radius * along, direction.y * radius * along, along))
			normals.append(Vector3(direction.x, direction.y, -radius).normalized())
			uvs.append(Vector2(float(segment) / float(segments), along))
	for ring: int in rings:
		for segment: int in segments:
			var current: int = ring * (segments + 1) + segment
			var next: int = current + segments + 1
			indices.append_array(PackedInt32Array([current, next, current + 1, current + 1, next, next + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var cone := ArrayMesh.new()
	cone.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return cone
