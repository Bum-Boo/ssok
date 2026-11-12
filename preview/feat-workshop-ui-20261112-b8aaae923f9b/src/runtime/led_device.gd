class_name LEDDevice
extends RefCounted

var brightness: float = 0.0
var material: StandardMaterial3D


func configure(visual: MeshInstance3D) -> void:
	var surface: int = visual.mesh.get_surface_count() - 1
	material = visual.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
	visual.set_surface_override_material(surface, material)
	off()


func on() -> void:
	set_brightness(1.0)


func off() -> void:
	set_brightness(0.0)


func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.0, 1.0)
	material.emission_enabled = brightness > 0.0
	material.emission = Color(1.0, 0.2, 0.01) * brightness
	material.emission_energy_multiplier = 2.0 * brightness
	material.albedo_color = Color(0.12 + 0.88 * brightness, 0.025 + 0.175 * brightness, 0.005, 1.0)
