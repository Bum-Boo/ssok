#!/usr/bin/env python3
"""Check Blender-generated ssok OBJ bounds and port-adjacent surfaces."""

from __future__ import annotations

import argparse
import math
from dataclasses import dataclass
from pathlib import Path


Vec3 = tuple[float, float, float]


@dataclass
class ObjMesh:
	vertices: list[Vec3]
	faces: list[tuple[tuple[int, ...], str | None]]


PARTS = {
	"base": {
		"body_material": "BaseBody",
		"body_bounds": ((-0.04, -0.01, -0.04), (0.04, 0.01, 0.04)),
		"ports": {"mount_top": (0.0, 0.01, 0.0)},
	},
	"servo": {
		"body_material": "ServoBody",
		"body_bounds": ((-0.0115, -0.015, -0.006), (0.0115, 0.015, 0.006)),
		"ports": {
			"mount_bottom": (0.0, -0.015, 0.0),
			"output_shaft": (0.0115, 0.005, 0.0),
			"signal_pin": (-0.0115, 0.0, 0.0),
		},
	},
	"arm_link": {
		"body_material": "ArmBody",
		"body_bounds": ((-0.005, -0.04, -0.005), (0.005, 0.04, 0.005)),
		"ports": {"mount_base": (0.0, -0.035, -0.005)},
	},
	"board": {
		"body_material": "BoardBody",
		"body_bounds": ((-0.035, -0.0025, -0.025), (0.035, 0.0025, 0.025)),
		"ports": {
			"pin_9": (-0.03, 0.0025, -0.02),
			"pin_10": (-0.03, 0.0025, -0.01),
		},
	},
}


def load_obj(path: Path) -> ObjMesh:
	vertices: list[Vec3] = []
	faces: list[tuple[tuple[int, ...], str | None]] = []
	material: str | None = None
	with path.open(encoding="utf-8") as source:
		for raw_line in source:
			words = raw_line.split()
			if not words:
				continue
			if words[0] == "v" and len(words) >= 4:
				vertices.append((float(words[1]), float(words[2]), float(words[3])))
			elif words[0] == "usemtl" and len(words) == 2:
				material = words[1]
			elif words[0] == "f" and len(words) >= 4:
				indices = tuple(int(word.split("/", 1)[0]) - 1 for word in words[1:])
				faces.append((indices, material))
	assert vertices, f"{path}: no vertices"
	assert faces, f"{path}: no faces"
	return ObjMesh(vertices, faces)


def bounds(vertices: list[Vec3]) -> tuple[Vec3, Vec3]:
	return (
		tuple(min(vertex[axis] for vertex in vertices) for axis in range(3)),
		tuple(max(vertex[axis] for vertex in vertices) for axis in range(3)),
	)


def subtract(a: Vec3, b: Vec3) -> Vec3:
	return tuple(a[i] - b[i] for i in range(3))


def add(a: Vec3, b: Vec3) -> Vec3:
	return tuple(a[i] + b[i] for i in range(3))


def scale(value: Vec3, factor: float) -> Vec3:
	return tuple(component * factor for component in value)


def dot(a: Vec3, b: Vec3) -> float:
	return sum(a[i] * b[i] for i in range(3))


def point_triangle_distance(point: Vec3, a: Vec3, b: Vec3, c: Vec3) -> float:
	# Closest-point regions from Real-Time Collision Detection, Christer Ericson.
	ab = subtract(b, a)
	ac = subtract(c, a)
	ap = subtract(point, a)
	d1, d2 = dot(ab, ap), dot(ac, ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return math.dist(point, a)
	bp = subtract(point, b)
	d3, d4 = dot(ab, bp), dot(ac, bp)
	if d3 >= 0.0 and d4 <= d3:
		return math.dist(point, b)
	vc = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return math.dist(point, add(a, scale(ab, d1 / (d1 - d3))))
	cp = subtract(point, c)
	d5, d6 = dot(ab, cp), dot(ac, cp)
	if d6 >= 0.0 and d5 <= d6:
		return math.dist(point, c)
	vb = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return math.dist(point, add(a, scale(ac, d2 / (d2 - d6))))
	va = d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		bc = subtract(c, b)
		return math.dist(point, add(b, scale(bc, (d4 - d3) / ((d4 - d3) + (d5 - d6)))))
	denominator = 1.0 / (va + vb + vc)
	closest = add(a, add(scale(ab, vb * denominator), scale(ac, vc * denominator)))
	return math.dist(point, closest)


def surface_distance(mesh: ObjMesh, point: Vec3) -> float:
	distance = math.inf
	for indices, _material in mesh.faces:
		for offset in range(1, len(indices) - 1):
			a, b, c = (mesh.vertices[index] for index in (indices[0], indices[offset], indices[offset + 1]))
			distance = min(distance, point_triangle_distance(point, a, b, c))
	return distance


def material_vertices(mesh: ObjMesh, material: str) -> list[Vec3]:
	indices = {index for face, face_material in mesh.faces if face_material == material for index in face}
	assert indices, f"material {material!r} has no faces"
	return [mesh.vertices[index] for index in sorted(indices)]


def check_part(directory: Path, name: str, spec: dict[str, object]) -> None:
	path = directory / f"{name}.obj"
	mesh = load_obj(path)
	actual_min, actual_max = bounds(mesh.vertices)
	print(f"{name:8s} min={actual_min!r} max={actual_max!r} vertices={len(mesh.vertices)} faces={len(mesh.faces)}")
	assert len(mesh.faces) < 5000, f"{name}: {len(mesh.faces)} triangles exceeds the polygon budget"
	body_min, body_max = bounds(material_vertices(mesh, str(spec["body_material"])))
	expected_min, expected_max = spec["body_bounds"]
	for label, actual, expected in (("min", body_min, expected_min), ("max", body_max, expected_max)):
		for axis, (actual_value, expected_value) in enumerate(zip(actual, expected, strict=True)):
			assert abs(actual_value - expected_value) <= 0.0001, (
				f"{name}: body {label} axis {axis} is {actual_value:.6f}, expected {expected_value:.6f}"
			)
	for axis in range(3):
		assert actual_min[axis] >= expected_min[axis] - 0.0061, f"{name}: protrusion exceeds 6 mm on axis {axis}"
		assert actual_max[axis] <= expected_max[axis] + 0.0061, f"{name}: protrusion exceeds 6 mm on axis {axis}"
	for port_name, position in spec["ports"].items():
		distance = surface_distance(mesh, position)
		assert distance <= 0.002, f"{name}.{port_name}: nearest geometry is {distance * 1000:.3f} mm away"
		print(f"  {port_name}: nearest surface {distance * 1000:.3f} mm")


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("directory", nargs="?", type=Path, default=Path("assets/parts"))
	args = parser.parse_args()
	for name, spec in PARTS.items():
		check_part(args.directory, name, spec)


if __name__ == "__main__":
	main()
