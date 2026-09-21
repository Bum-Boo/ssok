#!/usr/bin/env python3
"""Author ssok's original modular humanoid kit and editable assembled Blender scene.

Offline build tool, not exported Godot runtime code. Geometry uses metre-scale
Godot coordinates through the existing Blender helpers and shared PBR catalog.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_parts import (add_box, add_cylinder, apply_bevel, export_part,
                        godot_to_blender, join_parts, reset_scene, subtract_cylinder)
from part_materials import configure_material, load_catalog


M = {}


def box(name, position, size, material, bevel=0.002):
    return add_box(name, position, size, M[material], bevel)


def cyl(name, position, radius, depth, axis, material, vertices=24):
    return add_cylinder(name, position, radius, depth, axis, M[material], vertices, 0.0008)


def bolts(x_values, y_values, z, radius=0.003):
    return [cyl("Hex fastener", (x, y, z), radius, 0.003, "Z", "DetailSteel", 6)
            for x in x_values for y in y_values]


def taper(name, widths, height, depth, center, material):
    bottom, top = widths
    outline = [(-bottom / 2, -height / 2), (bottom / 2, -height / 2),
               (top / 2, height / 2), (-top / 2, height / 2)]
    vertices = [godot_to_blender((x + center[0], y + center[1], z + center[2]))
                for z in (-depth / 2, depth / 2) for x, y in outline]
    faces = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5),
             (2, 3, 7, 6), (3, 0, 4, 7)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(M[material])
    apply_bevel(obj, 0.008, 3)
    return obj


def torso():
    parts = [box("Load bearing spine", (0, 0, -0.035), (0.09, 0.30, 0.07), "ChassisMetal"),
             box("Shoulder crossmember", (0, 0.13, 0), (0.39, 0.045, 0.065), "ChassisMetal"),
             box("Pelvis crossmember", (0, -0.14, 0), (0.27, 0.04, 0.08), "ChassisMetal")]
    for x in (-0.115, 0.115):
        parts.append(box("Torso rail", (x, 0, -0.025), (0.018, 0.25, 0.05), "BracketMetal"))
    return join_parts("modular_torso_frame", parts)


def chest():
    parts = [taper("Chest armor", (0.18, 0.29), 0.24, 0.055, (0, 0.025, 0.055), "Shell"),
             taper("Chest inset", (0.08, 0.14), 0.085, 0.012, (0, 0.062, 0.086), "DetailGraphite"),
             box("Status light", (0, 0.072, 0.094), (0.071, 0.007, 0.003), "DetailTeal", 0.001)]
    for y in (-0.025, -0.041, -0.057):
        parts.append(box("Cooling channel", (0, y, 0.085), (0.105, 0.006, 0.005), "DetailGraphite", 0.001))
    parts += bolts((-0.112, 0.112), (0.092,), 0.085)
    return join_parts("modular_chest_shell", parts)


def pelvis():
    return join_parts("modular_pelvis_shell", [
        taper("Pelvis shell", (0.18, 0.26), 0.082, 0.12, (0, 0, 0), "DetailGraphite"),
        box("Pelvis front trim", (0, 0.003, 0.062), (0.12, 0.026, 0.006), "DetailTeal"),
        *bolts((-0.084, 0.084), (0.012,), 0.063)])


def head():
    parts = [box("Rounded head shell", (0, 0.008, 0), (0.16, 0.146, 0.138), "Shell", 0.027),
             box("Optical visor", (0, 0.022, 0.063), (0.134, 0.054, 0.023), "DetailGraphite", 0.012),
             cyl("Neck coupler", (0, -0.067, 0), 0.034, 0.036, "Y", "BracketMetal")]
    for x in (-0.036, 0.036):
        parts.append(cyl("Optical lens ring", (x, 0.021, 0.078), 0.012, 0.008, "Z", "DetailTeal", 32))
        parts.append(cyl("Optical lens", (x, 0.021, 0.083), 0.007, 0.003, "Z", "Black", 24))
    for x in (-0.079, 0.079):
        parts.append(cyl("Head side insert", (x, 0.012, -0.012), 0.023, 0.006, "X", "DetailTeal"))
    parts.append(box("Mouth grille", (0, -0.025, 0.07), (0.056, 0.009, 0.006), "DetailGraphite"))
    return join_parts("modular_head_shell", parts)


def controller():
    parts = [box("Controller PCB", (0, 0, 0), (0.12, 0.10, 0.008), "BoardBody"),
             box("Microcontroller", (0, 0, -0.008), (0.028, 0.026, 0.008), "Black"),
             box("USB-C shell", (0, -0.045, -0.01), (0.014, 0.012, 0.01), "Silver")]
    for x in (-0.046, 0.046):
        for y in (-0.032, -0.016, 0, 0.016, 0.032):
            parts.append(box("PWM socket", (x, y, -0.008), (0.012, 0.009, 0.009), "Black", 0.001))
            parts.append(box("PWM contact", (x, y, -0.014), (0.007, 0.002, 0.002), "Gold", 0))
    return join_parts("modular_controller", parts)


def motor(arm=False):
    radius, width = (0.026, 0.045) if arm else (0.035, 0.068)
    parts = [cyl("Actuator gearbox", (0, 0, 0), radius, width, "X", "DetailGraphite", 32),
             box("Actuator electronics", (0, 0.009, -radius * 0.75),
                 (width * 0.85, radius * 0.9, radius * 0.7), "DetailGraphite", 0.004)]
    for x in (-width / 2, width / 2):
        parts.append(cyl("Bearing cover", (x, 0, 0), radius * 0.86, 0.005, "X", "DetailTeal", 32))
        parts.append(cyl("Output spline", (x * 1.10, 0, 0), radius * 0.42, 0.005, "X", "DetailSteel", 20))
        for a in range(0, 360, 90):
            r = radius * 0.68
            parts.append(cyl("Housing screw", (x * 1.09, math.sin(math.radians(a)) * r,
                           math.cos(math.radians(a)) * r), 0.0022, 0.002, "X", "Silver", 6))
    return join_parts("modular_arm_motor" if arm else "modular_leg_motor", parts)


def bracket(arm=False):
    x = 0.029 if arm else 0.043
    height = 0.032 if arm else 0.04
    parts = [box("U bracket lower bridge", (0, -height, 0), (2*x, 0.008, 0.04), "BracketMetal")]
    for side in (-x, x):
        plate = box("U bracket cheek", (side, -height/2, 0), (0.007, height+0.03, 0.044), "BracketMetal")
        subtract_cylinder(plate, (side, 0, 0), 0.010 if arm else 0.014, 0.015, "X")
        parts.append(plate)
    return join_parts("modular_arm_bracket" if arm else "modular_leg_bracket", parts)


def frame(name, width, length, depth):
    parts = []
    for x in (-width * 0.32, width * 0.32):
        rail = box("Perforated structural rail", (x, 0, 0), (width * 0.23, length, depth * 0.40), "ChassisMetal")
        for y in (-length * 0.26, 0, length * 0.26):
            subtract_cylinder(rail, (x, y, 0), 0.003, depth, "Z")
        parts.append(rail)
    parts += [taper("Link front guard", (width*0.55, width*0.87), length*0.65, 0.013,
                    (0, 0, depth * 0.38), "Shell"),
              box("Link colored spine", (0, 0, depth * 0.5), (width * 0.15, length * 0.46, 0.006), "DetailTeal", 0.001),
              box("Link rear cable cover", (0, 0, -depth * 0.25), (width*0.4, length*0.7, 0.014), "DetailGraphite")]
    for y in (-length/2+0.006, length/2-0.006):
        parts.append(box("Link end plate", (0, y, 0), (width, 0.012, depth*0.60), "BracketMetal"))
    return join_parts(name, parts)


def hand():
    parts = [box("Palm chassis", (0, 0.012, 0), (0.068, 0.04, 0.058), "DetailGraphite", 0.006),
             box("Palm tactile pad", (0, 0.01, 0.031), (0.044, 0.033, 0.009), "Rubber", 0.003)]
    for x in (-0.027, -0.009, 0.009, 0.027):
        parts.append(box("Passive finger", (x, -0.021, 0.008), (0.010, 0.038, 0.03), "Shell", 0.004))
        parts.append(box("Finger contact pad", (x, -0.023, 0.026), (0.009, 0.025, 0.007), "Rubber", 0.002))
    return join_parts("modular_gripper_hand", parts)


def foot():
    parts = [box("Sole rubber", (0, -0.021, 0), (0.22, 0.018, 0.22), "Rubber", 0.013),
             box("Foot support plate", (0, -0.007, -0.003), (0.20, 0.015, 0.21), "BracketMetal", 0.013),
             taper("Foot top shell", (0.175, 0.12), 0.023, 0.17, (0, 0.012, 0), "Shell"),
             box("Toe bumper", (0, -0.003, 0.095), (0.16, 0.02, 0.015), "DetailTeal", 0.006)]
    for x in (-0.070, 0.070):
        parts.append(cyl("Foot bolt", (x, 0.003, -0.06), 0.003, 0.003, "Y", "DetailSteel", 6))
    return join_parts("modular_foot", parts)


def assembled_instances(parts):
    floor, hip = 0.05, 0.54
    layout = [("modular_torso_frame", (0, .75, 0)), ("modular_chest_shell", (0, .75, 0)),
              ("modular_pelvis_shell", (0, .63, 0)), ("modular_head_shell", (0, .995, 0)),
              ("modular_controller", (0, .75, -.075))]
    for sign in (-1, 1):
        for frame_id, motor_id, bracket_id, x, y, half, bridge in [
            ("modular_thigh_frame", "modular_leg_motor", "modular_leg_bracket", sign*.12, .47, .12, .04),
            ("modular_shin_frame", "modular_leg_motor", "modular_leg_bracket", sign*.12, .23, .12, .04),
            ("modular_upper_arm_frame", "modular_arm_motor", "modular_arm_bracket", sign*.20, .77, .11, .032),
            ("modular_forearm_frame", "modular_arm_motor", "modular_arm_bracket", sign*.20, .55, .11, .032)]:
            layout += [(frame_id, (x, y, 0)), (motor_id, (x, y+half, 0)), (bracket_id, (x, y+half, 0))]
        layout += [("modular_leg_motor", (sign*.12, .11, 0)), ("modular_leg_bracket", (sign*.12, .11, 0)),
                   ("modular_foot", (sign*.12, .08, .035)), ("modular_gripper_hand", (sign*.20, .47, 0))]
    collection = bpy.data.collections.new("ASSEMBLED - separate modules")
    bpy.context.scene.collection.children.link(collection)
    for index, (part_id, position) in enumerate(layout):
        obj = parts[part_id].copy()
        obj.data = parts[part_id].data
        collection.objects.link(obj)
        obj.location = Vector(godot_to_blender(position))
        obj.name = f"{index:02d}_{part_id}"
        obj["ssok_part_id"] = part_id
    return collection


def main():
    args = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--blend", type=Path, required=True)
    parser.add_argument("--render", type=Path)
    options = parser.parse_args(args)
    options.out.mkdir(parents=True, exist_ok=True)
    options.blend.parent.mkdir(parents=True, exist_ok=True)
    reset_scene()
    M.update({name: configure_material(name) for name in load_catalog()["materials"] if name != "Temporary_cutter"})
    builders = [torso, chest, pelvis, head, controller, motor, lambda: motor(True), bracket,
                lambda: bracket(True), lambda: frame("modular_thigh_frame", .080, .18, .08),
                lambda: frame("modular_shin_frame", .067, .18, .065),
                lambda: frame("modular_upper_arm_frame", .057, .164, .06),
                lambda: frame("modular_forearm_frame", .050, .15, .056), hand, foot]
    parts = {}
    for build in builders:
        part = build()
        # Export helpers bake geometry around the original Godot origin.
        bpy.context.scene.cursor.location = (0, 0, 0)
        bpy.ops.object.select_all(action="DESELECT")
        part.select_set(True)
        bpy.context.view_layer.objects.active = part
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        # Boolean cut walls inherit the rail's metal, never the temporary tool material.
        metal_index = next((i for i, material in enumerate(part.data.materials)
                            if material.name == "ChassisMetal"), 0)
        for polygon in part.data.polygons:
            material = part.data.materials[polygon.material_index]
            if material.name.replace(" ", "_") == "Temporary_cutter":
                polygon.material_index = metal_index
        export_part(part, options.out / f"{part.name}.obj")
        parts[part.name] = part
        part.asset_mark()
        part.asset_data.description = "ssok original modular humanoid; real separate assembly part, SI metre dimensions"
        part["ssok_part_id"] = part.name
    assembled_instances(parts)
    library = bpy.data.collections.new("KIT - editable source modules")
    bpy.context.scene.collection.children.link(library)
    for index, part in enumerate(parts.values()):
        for collection in list(part.users_collection):
            collection.objects.unlink(part)
        library.objects.link(part)
        part.location = Vector((1.15 + index % 4 * .30, -(index // 4) * .36, .10))
    library.hide_render = True
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.world.color = (.2, .2, .2)
    for position, power, size in [((2, -3, 4), 500, 4), ((-3, -1, 2), 300, 3), ((0, 3, 3), 450, 2)]:
        bpy.ops.object.light_add(type="AREA", location=position)
        light = bpy.context.object
        light.data.energy, light.data.shape, light.data.size = power, "DISK", size
        light.rotation_euler = (Vector((0, 0, .5)) - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=(1.45, -2.25, 1.35))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, .55)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type, camera.data.ortho_scale = "ORTHO", 1.38
    scene.camera = camera
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 900, 1000, 100
    scene.render.film_transparent = True
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.shading.type = "MATERIAL"
                area.spaces.active.region_3d.view_location = Vector((0, 0, .55))
                area.spaces.active.region_3d.view_distance = 1.5
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.wm.save_as_mainfile(filepath=str(options.blend.resolve()), check_existing=False, compress=True)
    if options.render:
        scene.render.filepath = str(options.render.resolve())
        bpy.ops.render.render(write_still=True)
    print(f"modular humanoid: {len(parts)} meshes, editable assembled source at {options.blend}")


if __name__ == "__main__":
    main()
