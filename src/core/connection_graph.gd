class_name ConnectionGraph
extends Resource

## Single source of truth: assembly, run-mode physics, wiring->pin mapping and presets all derive from this.

## Each entry: { "part_def": PartDef, "transform": Transform3D }
@export var parts: Array[Dictionary] = []

## Each entry: { "a_part": int, "a_port": StringName, "b_part": int, "b_port": StringName }
@export var links: Array[Dictionary] = []
