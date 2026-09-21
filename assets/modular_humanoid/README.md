# Legacy humanoid subassemblies — not the elementary construction kit

This is the earlier 37-object robot-specific prefab. Its torso and limb objects join multiple
rails, panels and guards; their decorative holes are not individual attachment ports. Do not
describe these as Science Box-style interchangeable elementary parts. Kept unchanged for old
scenarios and physics regressions. The replacement is [the construction kit](../../docs/CONSTRUCTION_KIT.md),
with new Blender source `assets/blender/ssok_construction_kit.blend`.

Original ssok virtual modules, not calibrated replicas of a commercial humanoid or motor.
The earlier `assets/humanoid/` block robot remains a separate compatibility example.

`ModularHumanoidPreset.build()` creates **38 graph parts**: 37 independently editable robot
modules and the existing 0.4 kg practice box. There are **18 catalog definitions**, **15
Blender-authored meshes** and **10 separately wired motor housings**. Shared instances are
separate graph entries, not a single character mesh or animation rig.

Each joint is assembled as:

```text
parent frame --fixed--> motor housing --output hinge--> U-bracket --fixed--> passive frame
```

The chest/pelvis covers, optical head, PWM controller and padded hands are removable fixed
modules. All mechanical connections have coincident anchors and opposing normals; output
ports and bolted mounts use distinct compatibility tags. Electrical wires resolve actual
numeric addresses through the graph. The example uses virtual pins 20–29; these are not an
Arduino hardware claim.

## Physics and code

`merge_fixed_connections` opts these modules into graph-derived rigid-body clusters. The
38 part indices map to 12 dynamic solver bodies (torso, ten articulated links, box). Original
presets do not opt in. Each part retains its own geometry, collision transform, mass and graph
identity. Summed robot mass is 10.92 kg, or 11.32 kg including the box. Structural reference
frames remain at limb centers for controller kinematics. The hollow torso uses five collision
boxes matching its crossmembers; a solid bounding box would incorrectly fill space around arms.

Motor housings specify `actuator_drives_connected_body = true`, so their output link rotates
relative to the housing. Internal hinge motors apply bounded equal/opposite impulses. Legs
use virtual 30–35 Nm limits, arms 12 Nm; these are design parameters, not vendor ratings.

`ModularHumanoidPreset.answer_code(graph)` produces a wired-pin standing example using
`Servo(pin).write_relative(angle)` and `sleep(2.0)`. `HumanoidMotion` resolves passive limb roles
and the separate wired actuators from actual motor/bracket/frame connections.

Hands have passive padded fingers, not individually actuated fingers. Pickup uses the existing
contact-verified two-point grasp constraint after bilateral contact. It is not a calibrated
finger friction or tactile simulation. No body teleporting, gravity overrides or external torso
propulsion are used. Running remains experimental and is not certified by these tests.

## Blender source and rebuild

Editable assembled scene and asset-browser kit:
`assets/blender/ssok_modular_humanoid.blend` (Blender 5.2.1 LTS).
It is separate from the previous `ssok_parts.blend` and ignored by Godot's Blender importer.
White ABS shells, teal trim, brushed metal, optical inserts, circuit board and rubber contact
surfaces use the existing `assets/materials/catalog.json` in both Blender and Godot.

Close running app/editor instances before regenerating resources so readers never observe a
partially written mesh. From the repository root:

```sh
blender --background --python tools/blender/make_modular_humanoid.py -- --out assets/modular_humanoid/obj --blend assets/blender/ssok_modular_humanoid.blend
godot --headless --path . --import
godot --headless --path . --script tools/godot/make_modular_humanoid_defs.gd
python3 tools/blender/check_modular_obj.py
godot --headless --path . --fixed-fps 60 --script tests/modular_humanoid_check.gd -- pick
godot --headless --path . --fixed-fps 60 --script tests/modular_humanoid_check.gd -- pick --reverse-links
godot --headless --path . --fixed-fps 60 --script tests/modular_humanoid_check.gd -- walk
```

Optional offline Blender preview: append `--render /tmp/ssok_modular_humanoid.png` to the
Blender command. The `.blend` retains separately selectable assembled modules and a separate
source-kit collection. Runtime uses OBJ-derived meshes with external shared PBR resources;
Blender is not required to run or export the app.

## Measured local baseline (2026-09-15)

Godot 4.7.2 / GodotPhysics / 60 Hz / 20 simulated seconds, fixed baseline controller:

- Walking, with the box moved away in the test setup: 0.86 m forward after a 3-second settle;
  minimum torso upright dot product 0.998.
- Pickup at the preset location: 0.42 m box lift, stable hold, then gravity-driven release;
  minimum torso upright dot product 0.924. Reversing link endpoint ordering also passes.
- Original block humanoid pickup, original servo-arm physics and original biped regression
  checks remain passing.

These are simulation baselines, not Luna training results. The pickup lab separately records
fresh candidate outcomes; saved metrics never guarantee a later replay or real-world transfer.
