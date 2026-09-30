#!/usr/bin/env python3
"""Validate elementary kit geometry, real through holes, and catalog ports."""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_obj import bounds, load_obj

ROOT = Path(__file__).resolve().parents[2]


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def ray_distance(origin, direction, vertices):
    edge_1, edge_2 = sub(vertices[1], vertices[0]), sub(vertices[2], vertices[0])
    p = cross(direction, edge_2)
    determinant = dot(edge_1, p)
    if abs(determinant) < 1e-12:
        return None
    inverse = 1.0 / determinant
    t = sub(origin, vertices[0])
    u = dot(t, p) * inverse
    if u < -1e-7 or u > 1 + 1e-7:
        return None
    q = cross(t, edge_1)
    v = dot(direction, q) * inverse
    if v < -1e-7 or u + v > 1 + 1e-7:
        return None
    return dot(edge_2, q) * inverse


def components(mesh):
    # OBJ normals may split vertices; connected manufactured metal is checked by
    # physical vertex coordinates rather than by exporter-specific vertex IDs.
    representatives = {}
    parents = []
    vertex_ids = []
    for vertex in mesh.vertices:
        key = tuple(round(value, 7) for value in vertex)
        if key not in representatives:
            representatives[key] = len(parents)
            parents.append(len(parents))
        vertex_ids.append(representatives[key])

    def root(index):
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index

    for indices, _ in mesh.faces:
        for index in indices[1:]:
            parents[root(vertex_ids[index])] = root(vertex_ids[indices[0]])
    return len({root(index) for index in range(len(parents))})


def check_blender_scenes(catalog):
    try:
        import bpy
        from mathutils import Matrix, Vector
    except ImportError:
        return
    manifest = json.loads((ROOT / "assets/construction_kit/assemblies.json").read_text())
    library = {part["id"] for part in catalog["parts"]}
    conversion = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    assert bpy.context.scene.name == "01 - MODULARITY OVERVIEW", "Opening the file must reveal separable assembly parts"
    assert "04 - PARTS TRAY" in bpy.data.scenes
    source = bpy.data.scenes["00 - SOURCE CATALOG"]
    source_objects = {obj.get("ssok_catalog_id"): obj for obj in source.objects if obj.get("ssok_catalog_id")}
    assert set(source_objects) == library
    assert all(obj.library is None and obj.data.library is None for obj in source_objects.values()), "Verified output must own its appended source meshes"
    scene_ids = ["02 - ASSEMBLED GRAPH", *[f"05 - ALTERNATE {index + 1}" for index in range(len(manifest["assemblies"]) - 1)]]
    for spec, scene_id in zip(manifest["assemblies"], scene_ids):
        scene = bpy.data.scenes[scene_id]
        # Blender does not evaluate matrix_world caches in inactive scenes.
        bpy.context.window.scene = scene
        bpy.context.view_layer.update()
        records = {str(part["instance_id"]): part for part in spec["parts"] if part["catalog_id"] in library}
        objects = {obj["ssok_instance_id"]: obj for obj in scene.objects if obj.get("ssok_assembly_id") == spec["id"]}
        assert set(objects) == set(records), (spec["id"], "one independent object per graph instance")
        for instance, record in records.items():
            obj = objects[instance]
            assert obj["ssok_catalog_id"] == record["catalog_id"]
            assert obj.data == source_objects[record["catalog_id"]].data, (instance, "assembly must reuse library part mesh")
            assert not obj["ssok_exploded_display_only"]
            transform = Matrix.Identity(4)
            for column in range(3):
                for row in range(3):
                    transform[row][column] = record["basis"][column][row]
            transform.translation = Vector(record["position"])
            expected = conversion @ transform @ conversion.inverted()
            assert all(abs(obj.matrix_world[row][column] - expected[row][column]) < 1e-6
                       for row in range(4) for column in range(4)), (instance, "Blender transform differs from ConnectionGraph", [list(row) for row in obj.matrix_world], [list(row) for row in expected])
        print(f"Blender {spec['id']}: {len(objects)} separate graph-derived objects; exact catalog mesh reuse and transforms")
    exploded = [obj for obj in bpy.data.scenes["03 - EXPLODED GRAPH"].objects if obj.get("ssok_assembly_id")]
    assert all(obj["ssok_exploded_display_only"] for obj in exploded)
    assert len(exploded) == sum(part["catalog_id"] in library for part in manifest["assemblies"][0]["parts"])
    print("Blender source, assembled, exploded, parts-tray and alternate-structure scenes passed")


def main():
    catalog = json.loads((ROOT / "assets/construction_kit/catalog.json").read_text())
    if "--scenes-only" in sys.argv:
        check_blender_scenes(catalog)
        return
    materials = json.loads((ROOT / "assets/materials/catalog.json").read_text())["materials"]
    assert catalog["standard"]["pitch_m"] == .02
    assert catalog["standard"]["hole_diameter_m"] == .004
    assert catalog["standard"]["commercial_compatibility"] is False
    total_triangles, total_holes = 0, 0
    for part in catalog["parts"]:
        path = ROOT / "assets/construction_kit/obj" / (part["id"] + ".obj")
        mesh = load_obj(path)
        assert 8 <= len(mesh.faces) < 5000, (part["id"], "triangle budget", len(mesh.faces))
        assert all(math.isfinite(value) for vertex in mesh.vertices for value in vertex)
        for indices, material in mesh.faces:
            assert len(indices) == 3 and len(set(indices)) == 3
            assert material in materials and material != "Temporary_cutter", (part["id"], material)
        minimum, maximum = bounds(mesh.vertices)
        for axis in range(3):
            expected_min = part["center"][axis] - part["size"][axis] / 2
            expected_max = part["center"][axis] + part["size"][axis] / 2
            assert abs(minimum[axis] - expected_min) < .0006, (part["id"], "AABB min", axis, minimum, part["center"], part["size"])
            assert abs(maximum[axis] - expected_max) < .0006, (part["id"], "AABB max", axis, maximum, part["center"], part["size"])
        if part["kind"] in ("beam", "plate", "bracket", "spacer", "coupler", "fastener", "pad"):
            assert components(mesh) == 1, (part["id"], "must be one connected manufactured solid", components(mesh))
        for hole in part["holes"]:
            center, normal = hole["position"], hole["normal"]
            ports = [port for port in part["ports"] if port.get("hole_id") == hole["id"]]
            assert len(ports) == 2, (part["id"], hole["id"], "two real surface ports")
            for sign in (-1, 1):
                expected = [center[i] + sign * normal[i] * hole["thickness_m"] / 2 for i in range(3)]
                assert any(all(abs(expected[i] - port["position"][i]) < 1e-7 for i in range(3)) and
                           all(sign * normal[i] == port["normal"][i] for i in range(3)) for port in ports)
            # Test actual aperture at the centre and 60% of its radius. The latter
            # prevents a tiny decorative puncture satisfying a full 4 mm port.
            tangent_axis = min(range(3), key=lambda i: abs(normal[i]))
            for side in (0, -.6, .6):
                origin = list(center)
                origin[tangent_axis] += side * hole["diameter_m"] / 2
                for indices, _ in mesh.faces:
                    distance = ray_distance(origin, normal, [mesh.vertices[index] for index in indices])
                    assert distance is None or abs(distance) > hole["thickness_m"] / 2 + 1e-6, (
                        part["id"], hole["id"], "declared aperture is obstructed", side, distance)
            total_holes += 1
        total_triangles += len(mesh.faces)
        print(f"{part['id']}: {len(mesh.faces)} triangles; {len(part['holes'])} open physical holes; correct surface ports")
    print(f"check_construction_kit: {len(catalog['parts'])} reusable parts, {total_holes} holes, {total_triangles} triangles; all checks passed")
    check_blender_scenes(catalog)


if __name__ == "__main__":
    main()
