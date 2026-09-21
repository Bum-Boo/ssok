"""Generate only the additional board, preserving validated construction-kit assets."""

import json
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_construction_kit as kit

catalog = json.loads((kit.ROOT / "assets/construction_kit/catalog.json").read_text())
part = next(item for item in catalog["parts"] if item["id"] == "kit_controller_16")
kit.reset_scene()
kit.MATERIALS.update({name: kit.configure_material(name)
                     for name in kit.load_catalog()["materials"] if name != "Temporary_cutter"})
obj = kit.build_part(part)
kit.export_part(obj, kit.ROOT / "assets/construction_kit/obj/kit_controller_16.obj")
bpy.ops.wm.save_as_mainfile(filepath=str(kit.ROOT / "assets/blender/ssok_controller_16.blend"))
