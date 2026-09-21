#!/usr/bin/env python3
"""Check the original modular humanoid meshes without requiring Blender."""

from __future__ import annotations

import json
import math
from pathlib import Path

from check_obj import bounds, load_obj


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    catalog = json.loads((root / "assets/materials/catalog.json").read_text())
    paths = sorted((root / "assets/modular_humanoid/obj").glob("*.obj"))
    assert len(paths) == 15, "Expected fifteen distinct authored meshes"
    triangles = 0
    for path in paths:
        mesh = load_obj(path)
        assert all(math.isfinite(value) for vertex in mesh.vertices for value in vertex), path
        assert 20 < len(mesh.faces) < 5000, (path, len(mesh.faces))
        for indices, material in mesh.faces:
            assert len(indices) == 3 and len(set(indices)) == 3, (path, indices)
            assert all(0 <= index < len(mesh.vertices) for index in indices), path
            assert material in catalog["materials"] and material != "Temporary_cutter", (path, material)
        minimum, maximum = bounds(mesh.vertices)
        assert all(0.001 < maximum[i] - minimum[i] < 0.5 for i in range(3)), (path, minimum, maximum)
        triangles += len(mesh.faces)
        print(f"{path.stem}: {len(mesh.faces)} triangles, {len(set(material for _, material in mesh.faces))} PBR surfaces")
    print(f"check_modular_obj: {len(paths)} meshes, {triangles} triangles, all checks passed")


if __name__ == "__main__":
    main()
