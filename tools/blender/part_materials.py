"""Shared PBR catalog for editable Blender materials and OBJ material sidecars."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

import bpy


CATALOG_PATH = Path(__file__).resolve().parents[2] / "assets" / "materials" / "catalog.json"
@lru_cache(maxsize=1)
def load_catalog() -> dict:
	catalog = json.loads(CATALOG_PATH.read_text())
	if catalog.get("version") != 1 or catalog.get("color_space") != "linear":
		raise ValueError(f"Expected version 1 linear-color PBR catalog: {CATALOG_PATH}")
	if not isinstance(catalog.get("materials"), dict) or not catalog["materials"]:
		raise ValueError(f"Expected a nonempty materials dictionary in {CATALOG_PATH}")
	return catalog


def material_spec(name: str) -> dict:
	if name.replace(" ", "_") == "Temporary_cutter":
		name = "Temporary_cutter"
	try:
		return load_catalog()["materials"][name]
	except KeyError as error:
		raise ValueError(f"Material {name!r} is missing from {CATALOG_PATH}") from error


def _microtexture(material: bpy.types.Material, principled: bpy.types.ShaderNodeBsdfPrincipled, spec: dict) -> None:
	family = load_catalog().get("families", {}).get(spec["family"], {})
	if not family or family.get("noise_scale", 0.0) <= 0.0:
		return
	nodes, links = material.node_tree.nodes, material.node_tree.links
	coordinates = nodes.new("ShaderNodeTexCoord")
	coordinates.name = "ssok physical coordinates"
	coordinates.label = "Object coordinates in metres"
	coordinates.location = (-760, -60)
	stretch = nodes.new("ShaderNodeVectorMath")
	stretch.operation = "MULTIPLY"
	stretch.name = "ssok grain direction"
	stretch.inputs[1].default_value = family.get("stretch", [1.0, 1.0, 1.0])
	stretch.location = (-560, -60)
	links.new(coordinates.outputs["Object"], stretch.inputs[0])
	noise = nodes.new("ShaderNodeTexNoise")
	noise.name = "ssok microtexture"
	noise.label = spec["family"].replace("_", " ").title() + " microtexture"
	noise.inputs["Scale"].default_value = family["noise_scale"]
	noise.inputs["Detail"].default_value = 2.0
	noise.inputs["Roughness"].default_value = 0.65
	noise.location = (-340, -60)
	links.new(stretch.outputs["Vector"], noise.inputs["Vector"])
	variation = family.get("roughness_variation", 0.0)
	if variation > 0.0:
		roughness = nodes.new("ShaderNodeMapRange")
		roughness.name = "ssok roughness grain"
		roughness.clamp = True
		roughness.inputs["From Min"].default_value = 0.0
		roughness.inputs["From Max"].default_value = 1.0
		roughness.inputs["To Min"].default_value = max(0.0, spec["roughness"] - variation)
		roughness.inputs["To Max"].default_value = min(1.0, spec["roughness"] + variation)
		roughness.location = (-90, -50)
		links.new(noise.outputs["Fac"], roughness.inputs["Value"])
		links.new(roughness.outputs["Result"], principled.inputs["Roughness"])
	if family.get("bump_distance", 0.0) > 0.0:
		bump = nodes.new("ShaderNodeBump")
		bump.name = "ssok surface grain"
		bump.inputs["Strength"].default_value = family.get("bump_strength", 0.1)
		bump.inputs["Distance"].default_value = family["bump_distance"]
		bump.location = (-90, -290)
		links.new(noise.outputs["Fac"], bump.inputs["Height"])
		links.new(bump.outputs["Normal"], principled.inputs["Normal"])


def configure_material(name: str, color: tuple[float, float, float] | None = None) -> bpy.types.Material:
	"""Configure a palette material; catalog color is authoritative over legacy builder colors."""
	spec = material_spec(name)
	material = bpy.data.materials.get(name)
	if material is None:
		material = bpy.data.materials.new(name=name)
	rgba = (*spec["base_color"], 1.0)
	material.diffuse_color = rgba
	material.metallic = spec["metallic"]
	material.roughness = spec["roughness"]
	material.use_nodes = True
	nodes = material.node_tree.nodes
	nodes.clear()
	principled = nodes.new("ShaderNodeBsdfPrincipled")
	principled.name = "Principled BSDF"
	principled.label = spec.get("label", name)
	principled.location = (180, 180)
	for socket, value in {
		"Base Color": rgba,
		"Metallic": spec["metallic"],
		"Roughness": spec["roughness"],
		"IOR": spec.get("ior", 1.45),
		"Specular IOR Level": spec.get("specular", 0.5),
		"Emission Color": rgba,
		"Emission Strength": spec.get("emission_energy", 0.0),
	}.items():
		principled.inputs[socket].default_value = value
	output = nodes.new("ShaderNodeOutputMaterial")
	output.location = (540, 180)
	material.node_tree.links.new(principled.outputs["BSDF"], output.inputs["Surface"])
	if not spec.get("hidden", False):
		_microtexture(material, principled, spec)
		material.asset_mark()
		material.asset_data.description = spec.get("label", name) + "; ssok PBR finish, procedural grain at metre scale"
		for tag in ("ssok", "PBR", spec["family"]):
			if tag not in material.asset_data.tags:
				material.asset_data.tags.new(tag)
		material["ssok_material_id"] = name
		material["ssok_material_family"] = spec["family"]
	return material


def mtl_block(name: str) -> str:
	"""Write diffuse/Phong fallback plus common Pr/Pm PBR extensions; no texture images."""
	spec = material_spec(name)
	color = spec["base_color"]
	roughness = spec["roughness"]
	specular = spec.get("specular", 0.5)
	emission = spec.get("emission_energy", 0.0)
	lines = [
		f"newmtl {name}",
		f"Ns {((1.0 - roughness) ** 2) * 1000.0:.6f}",
		"Ka 1.000000 1.000000 1.000000",
		"Kd " + " ".join(f"{value:.6f}" for value in color),
		"Ks " + " ".join(f"{specular:.6f}" for _ in range(3)),
		"Ke " + " ".join(f"{value * emission:.6f}" for value in color),
		f"Ni {spec.get('ior', 1.45):.6f}",
		"d 1.000000",
		"illum 2",
		f"Pr {roughness:.6f}",
		f"Pm {spec['metallic']:.6f}",
	]
	return "\n".join(lines)
