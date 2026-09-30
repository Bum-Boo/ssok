#!/usr/bin/env python3
"""Build a reusable elementary kit, never robot-specific merged limb meshes.

The shared catalog owns all manufactured geometry and real hole locations. Robot
and alternate assemblies are imported from the Godot ConnectionGraph manifest;
this file contains no independently authored robot layout.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_parts import add_box, add_cylinder, export_part, godot_to_blender, join_parts, reset_scene
from part_materials import configure_material, load_catalog

ROOT = Path(__file__).resolve().parents[2]
MATERIALS = {}
CONVERSION = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def box(name, position, size, material, bevel=0):
    return add_box(name, position, size, MATERIALS[material], bevel)


def cylinder(name, position, radius, depth, axis, material, vertices=24):
    return add_cylinder(name, position, radius, depth, axis, MATERIALS[material], vertices)


def boolean(target, other, operation):
    bpy.context.view_layer.objects.active = target
    modifier = target.modifiers.new(name="Manufactured solid" if operation == "UNION" else "Through hole", type="BOOLEAN")
    modifier.operation = operation
    modifier.solver = "EXACT"
    modifier.object = other
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(other, do_unlink=True)


def manufactured_bracket(part):
    # Adjacent sheet faces form one connected bent manufactured part, not a frame.
    objects = [box(part["id"], block["position"], block["size"], part["material"])
               for block in part["geometry"]["blocks"]]
    result = objects[0]
    for other in objects[1:]:
        boolean(result, other, "UNION")
    return result


def motor(part):
    spec = part["geometry"]
    result = cylinder(part["id"], (0, 0, 0), spec["radius"], spec["width"], "X", "DetailGraphite", 32)
    result.data.materials.append(MATERIALS["DetailTeal"])
    for face in result.data.polygons:
        if abs(face.normal.x) > 0.9:
            face.material_index = 1
    shaft = cylinder("Purchased actuator output spline", (spec["width"] / 2 + .003, 0, 0),
                     .004, .008, "X", "DetailSteel", 20)
    boolean(result, shaft, "UNION")
    return result


def controller(part):
    objects = [box(part["id"], (0, 0, 0), (.12, .08, .008), "BoardBody"),
               box("Soldered microcontroller", (0, 0, -.009), (.022, .022, .010), "Black", .001)]
    for port in part["ports"]:
        if port.get("kind") == "ELEC":
            objects.append(box("Soldered PWM connector", port["position"], (.010, .008, .008), "Black", .0005))
            position = list(port["position"])
            position[2] -= .0041
            objects.append(box("Electrical contact", position, (.006, .002, .0002), "Gold"))
    return join_parts(part["id"], objects)


def sensor(part):
    objects = [box(part["id"], (0, 0, -.010), (.06, .04, .004), "BoardBody"),
               box("Purchased optical sensor housing", (0, 0, 0), (.032, .028, .022), "DetailGraphite", .002),
               cylinder("Optical lens surround", (0, 0, .012), .009, .008, "Z", "DetailTeal"),
               cylinder("Solid optical lens", (0, 0, .0165), .0065, .001, "Z", "Black")]
    return join_parts(part["id"], objects)


def build_part(part):
    spec = part["geometry"]
    kind = spec["type"]
    if kind == "plate":
        obj = box(part["id"], (0, 0, 0), part["size"], part["material"])
    elif kind == "bent_bracket":
        obj = manufactured_bracket(part)
    elif kind == "cylinder":
        obj = cylinder(part["id"], (0, 0, 0), spec["radius"], spec["depth"], spec["axis"],
                       part["material"], spec.get("vertices", 24))
    elif kind == "bolt":
        obj = cylinder(part["id"], (0, 0, 0), .002, .012, "Z", part["material"], 16)
        head = cylinder("Integral hex bolt head", (0, 0, -.008), .0035, .004, "Z", part["material"], 6)
        boolean(obj, head, "UNION")
    elif kind == "motor":
        obj = motor(part)
    elif kind == "controller":
        obj = controller(part)
    elif kind == "sensor":
        obj = sensor(part)
    else:
        raise ValueError(f"Unknown geometry: {kind}")
    for hole in part["holes"]:
        axis = "XYZ"[max(range(3), key=lambda i: abs(hole["normal"][i]))]
        cutter = cylinder("Temporary drill", hole["position"], hole["diameter_m"] / 2,
                          hole["thickness_m"] + .002, axis, part["material"], 16)
        boolean(obj, cutter, "DIFFERENCE")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    obj.name = part["id"]
    obj["ssok_part_id"] = part["id"]
    obj["ssok_catalog_id"] = part["id"]
    obj["ssok_unit_kind"] = part["kind"]
    obj["ssok_hole_count"] = len(part["holes"])
    obj["ssok_holes_json"] = json.dumps(part["holes"], separators=(",", ":"))
    obj["ssok_source_catalog"] = "assets/construction_kit/catalog.json"
    obj.asset_mark()
    obj.asset_data.description = part["name"] + "; reusable ssok virtual 20 mm pitch kit; one manufactured unit"
    return obj


def collection(scene, name):
    result = bpy.data.collections.new(name)
    scene.collection.children.link(result)
    return result


def copy_part(source, target, name, matrix):
    obj = source.copy()
    obj.data = source.data
    target.objects.link(obj)
    obj.name = name
    obj.matrix_world = matrix
    return obj


def graph_matrix(record):
    position = record.get("position", record.get("origin", [0, 0, 0]))
    basis = record.get("basis", [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
    if isinstance(record.get("transform"), dict):
        position = record["transform"].get("origin", record["transform"].get("position", position))
        basis = record["transform"].get("basis", basis)
    if len(basis) == 9:
        basis = [basis[0:3], basis[3:6], basis[6:9]]
    result = Matrix.Identity(4)
    for column in range(3):
        for row in range(3):
            result[row][column] = basis[column][row]
    result.translation = Vector(position)
    return CONVERSION @ result @ CONVERSION.inverted()


def assembly(scene, spec, library, offset=(0, 0, 0), exploded=False):
    target = collection(scene, ("EXPLODED | " if exploded else "ASSEMBLED | ") + spec.get("name", spec["id"]))
    records = spec.get("parts", spec.get("graph", {}).get("parts", []))
    points = [graph_matrix(record).translation for record in records]
    centroid = sum(points, Vector()) / max(1, len(points))
    used = 0
    for index, record in enumerate(records):
        part_id = record.get("catalog_id", record.get("part_id", record.get("id")))
        if part_id not in library:
            # Practice props are not construction-kit parts and are not counterfeited here.
            continue
        source = library[part_id]
        matrix = graph_matrix(record)
        original = matrix.copy()
        if exploded:
            delta = matrix.translation - centroid
            matrix.translation = centroid + delta * 1.85
            depth = {"beam": .035, "plate": .065, "bracket": .11, "fastener": .16,
                     "pad": .14, "motor": .02, "controller": .10, "sensor": .10,
                     "spacer": .08, "coupler": .07}.get(source["ssok_unit_kind"], .03)
            matrix.translation += matrix.to_3x3() @ Vector((0, -depth, 0))
            # Identical attached fasteners remain separately visible in the exploded view.
            if source["ssok_unit_kind"] == "fastener":
                matrix.translation.y -= (index % 3) * .010
        matrix.translation += Vector(offset)
        instance = str(record.get("instance_id", record.get("instance", index)))
        obj = copy_part(source, target, f"{instance} | {part_id}", matrix)
        obj["ssok_instance_id"] = instance
        obj["ssok_graph_index"] = index
        obj["ssok_assembly_id"] = spec["id"]
        obj["ssok_graph_transform"] = json.dumps([list(row) for row in original])
        obj["ssok_exploded_display_only"] = exploded
        used += 1
    target["ssok_graph_part_count"] = len(records)
    target["ssok_kit_instance_count"] = used
    target["ssok_source_manifest"] = "assets/construction_kit/assemblies.json"
    return target


def label(target, text, location, size=.035):
    curve = bpy.data.curves.new(text, "FONT")
    curve.body, curve.size, curve.align_x = text, size, "CENTER"
    curve.extrude = .0002
    obj = bpy.data.objects.new(text, curve)
    target.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (math.pi / 2, 0, 0)
    material = bpy.data.materials.get("STUDIO | readable labels")
    if material is None:
        material = bpy.data.materials.new("STUDIO | readable labels")
        material.diffuse_color = (.94, .97, 1, 1)
        material.use_nodes = True
        nodes = material.node_tree.nodes
        nodes.clear()
        emission = nodes.new("ShaderNodeEmission")
        emission.inputs["Color"].default_value = (.94, .97, 1, 1)
        emission.inputs["Strength"].default_value = 1
        output = nodes.new("ShaderNodeOutputMaterial")
        material.node_tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
    curve.materials.append(material)
    return obj


def presentation_scene(name, target, scale, resolution=(1500, 1200)):
    scene = bpy.data.scenes.new(name)
    scene.unit_settings.system = "METRIC"
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.world = bpy.data.worlds.new(name + " World")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.045, .06, .085, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .65
    staging = collection(scene, "STUDIO | not kit parts")
    for position, power, size in [((2, -3, 4), 550, 3), ((-3, -1, 2), 350, 3), ((0, 3, 3), 400, 2)]:
        data = bpy.data.lights.new("Softbox", type="AREA")
        data.energy, data.shape, data.size = power, "DISK", size
        obj = bpy.data.objects.new("Softbox", data)
        staging.objects.link(obj)
        obj.location = position
        obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    camera_data = bpy.data.cameras.new(name + " Camera")
    camera = bpy.data.objects.new(name + " Camera", camera_data)
    staging.objects.link(camera)
    camera.location = Vector(target) + Vector((1.2, -3.5, 1.0))
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type, camera.data.ortho_scale = "ORTHO", scale
    scene.camera = camera
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    return scene, staging


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=ROOT / "assets/construction_kit/catalog.json")
    parser.add_argument("--manifest", type=Path, default=ROOT / "assets/construction_kit/assemblies.json")
    parser.add_argument("--out", type=Path, default=ROOT / "assets/construction_kit/obj")
    parser.add_argument("--blend", type=Path, default=ROOT / "assets/blender/ssok_construction_kit.blend")
    parser.add_argument("--render", type=Path)
    parser.add_argument("--reuse-source", action="store_true", help="Recompose scenes from already validated Blender source meshes without rebuilding geometry")
    parser.add_argument("--source-blend", type=Path, help="Read validated source meshes from this Blender file, independently of the new --blend output")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    if args.source_blend and not args.reuse_source:
        parser.error("--source-blend requires --reuse-source")
    catalog = json.loads(args.catalog.read_text())
    args.out.mkdir(parents=True, exist_ok=True)
    args.blend.parent.mkdir(parents=True, exist_ok=True)
    reset_scene()
    MATERIALS.update({name: configure_material(name) for name in load_catalog()["materials"] if name != "Temporary_cutter"})
    original_scene = bpy.context.scene
    original_scene.name = "00 - SOURCE CATALOG"
    library = {}
    reused = {}
    if args.reuse_source:
        source_blend = args.source_blend or args.blend
        if not source_blend.is_file():
            raise ValueError("--reuse-source requires an existing generated Blender source")
        with bpy.data.libraries.load(str(source_blend.resolve()), link=False) as (available, requested):
            requested.objects = [part["id"] for part in catalog["parts"]]
            assert all(name in available.objects for name in requested.objects)
        reused = {obj["ssok_part_id"]: obj for obj in requested.objects}
        for source_library in list(bpy.data.libraries):
            if Path(source_library.filepath).resolve() == source_blend.resolve():
                bpy.data.libraries.remove(source_library)
    for part in catalog["parts"]:
        if reused:
            obj = reused[part["id"]]
            original_scene.collection.objects.link(obj)
            for index, material in enumerate(obj.data.materials):
                obj.data.materials[index] = MATERIALS[material.name.split(".")[0]]
        else:
            obj = build_part(part)
            export_part(obj, args.out / (part["id"] + ".obj"))
        library[part["id"]] = obj
        print(f"Authored {part['id']}: {len(part['holes'])} real holes", flush=True)
    tray, tray_stage = presentation_scene("04 - PARTS TRAY", (0, 0, .55), 2.2, (1600, 1400))
    tray_collection = collection(tray, "24 REUSABLE MANUFACTURED UNITS | no robot-specific frames")
    for index, part in enumerate(catalog["parts"]):
        matrix = Matrix.Identity(4)
        matrix.translation = Vector(((index % 6 - 2.5) * .30, 0, 1.08 - (index // 6) * .30))
        obj = copy_part(library[part["id"]], tray_collection, part["id"], matrix)
        obj["ssok_instance_id"] = "catalog:" + part["id"]
        label(tray_stage, part["name"], (matrix.translation.x, -.07, matrix.translation.z - .15), .015)
    label(tray_stage, "SSOK / 20 mm PITCH / 4 mm MOUNT HOLES", (0, -.04, 1.32), .045)
    label(tray_stage, "One manufactured unit per object. The same parts build different machines.", (0, -.04, -.12), .027)
    default_scene = tray
    assemblies = []
    if args.manifest.is_file():
        manifest = json.loads(args.manifest.read_text())
        assemblies = manifest.get("assemblies", [])
        if isinstance(assemblies, dict):
            assemblies = [dict(value, id=key) for key, value in assemblies.items()]
    if assemblies:
        first = assemblies[0]
        assembled, _ = presentation_scene("02 - ASSEMBLED GRAPH", (0, 0, .61), 1.65)
        assembly(assembled, first, library)
        exploded, _ = presentation_scene("03 - EXPLODED GRAPH", (0, 0, .63), 2.5)
        assembly(exploded, first, library, exploded=True)
        overview, stage = presentation_scene("01 - MODULARITY OVERVIEW", (0, 0, .70), 3.1, (1800, 1600))
        assembly(overview, first, library, offset=(-.65, 0, 0))
        assembly(overview, first, library, offset=(.65, 0, 0), exploded=True)
        label(stage, "ASSEMBLED", (-.65, -.15, 1.64), .055)
        label(stage, "EXPLODED / SEPARATE PARTS", (.65, -.15, 1.64), .043)
        label(stage, "Same ConnectionGraph. Individual beams, plates, brackets, motors and fasteners.", (0, -.15, -.39), .034)
        for index, spec in enumerate(assemblies[1:]):
            alternate, _ = presentation_scene(f"05 - ALTERNATE {index + 1}", (0, 0, .40), 1.45)
            assembly(alternate, spec, library)
        default_scene = overview
    # Raw source geometry remains editable and selectable, but its stacked origin
    # view is never the scene users first see when opening the file.
    bpy.context.window.scene = default_scene
    bpy.context.scene["ssok_catalog_path"] = "assets/construction_kit/catalog.json"
    bpy.context.scene["ssok_manifest_path"] = "assets/construction_kit/assemblies.json"
    bpy.context.scene["ssok_assembly_count"] = len(assemblies)
    bpy.context.scene["ssok_kit_definition_count"] = len(library)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.shading.type = "MATERIAL"
                area.spaces.active.region_3d.view_perspective = "CAMERA"
                area.spaces.active.region_3d.view_camera_zoom = 0
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.wm.save_as_mainfile(filepath=str(args.blend.resolve()), check_existing=False, compress=True)
    if args.render:
        default_scene.render.filepath = str(args.render.resolve())
        bpy.ops.render.render(write_still=True)
    print(f"construction kit: {len(library)} reusable definitions; {len(assemblies)} graph-derived assemblies; {args.blend}")


if __name__ == "__main__":
    main()
