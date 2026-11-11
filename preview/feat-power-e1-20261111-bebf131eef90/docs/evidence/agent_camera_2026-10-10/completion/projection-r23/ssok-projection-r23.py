"""Developer-only replay of already captured poses through pinned Godot projection.

No controller, evaluator, frozen goal or original runtime artifact is modified.
"""
from pathlib import Path
from datetime import datetime, timezone, timedelta
import hashlib, json, msvcrt, os, subprocess, sys, time

REPO = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
BASE = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010')
OUT = REPO / 'build/ai-loop-evidence/completion/projection-r23'
BACKUP = BASE / 'projection-r23'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda b: hashlib.sha256(b).hexdigest()
save = lambda p, d: p.write_bytes((json.dumps(d, ensure_ascii=False, indent=2)+'\n').encode('utf8'))

HEAD = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO).decode().strip()
assert HEAD == 'afbc89968e1f11037dee10b12020baf5bf61b436'
assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=REPO)
old = read(BASE/'brake-integral-r22/contract.json')
sources = old['source426'] | old['extra_operator7']
assert all(sha((REPO/n).read_bytes()) == h for n,h in sources.items())
OUT.mkdir(parents=True, exist_ok=False)
BACKUP.mkdir(exist_ok=False)
plan = Path(old['plan'])
before = plan.read_bytes()
stamp = datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')
entry = ('\n\n<!-- ssok-r23-contract -->\n### '+stamp+' — r23 projection replay contract\n\n'
    '既存issue32/task16 readonly. Outcome: archived r21 stock AI5 / r22 assigned-camera4 posesをpinned Godot projectionで再生し、画像境界・14cm・姿勢依存を区別。Allowed: ignored build fixture/external reader/public evidence/docs/existing canonical CAS records; production/controller/evaluator/actor/goal/provider/UI changes0. '
    'Rank1 calibration mismatch predicts rendered boundary agreement within2px but24/31/38px maps beyond14cm at observed pose. Rank2 pose dependence predicts fixed-gap orientation changes alter pixels materially; report counterfactual geometry only. Rank3 measurement mismatch predicts projection/image discrepancy above2px, requiring measurement diagnosis instead of gain tuning. '
    'Checks: original PNG SHA/dimensions/tick pairing, actual graph part offset/floor/wall mesh geometry, engine projection and independent arithmetic agreement, all433 source hashes unchanged. Native headless projection is not new rendered/physics/AI/packaged trial; no new pass pooling. Frozen24..38px AND4..14cm unchanged,12..20 proposal unadopted/unrun. Next coordinator: report findings, Fable review; product calibration decision remains user-owned. Whole goal incomplete.\n')
after = before + entry.encode('utf8')
(BACKUP/'plan.before.md').write_bytes(before)
with plan.open('r+b', buffering=0) as f:
    length = max(len(before),len(after))+1
    msvcrt.locking(f.fileno(),msvcrt.LK_NBLCK,length)
    try:
        assert f.read() == before
        f.seek(0); f.write(after); f.truncate(); os.fsync(f.fileno())
    finally:
        f.seek(0); msvcrt.locking(f.fileno(),msvcrt.LK_UNLCK,length)
assert plan.read_bytes() == after
save(BACKUP/'contract.json', {'head':HEAD,'stamp':stamp,'sources':sources,'plan':str(plan),
    'before_sha256':sha(before),'post_sha256':sha(after),'global_goal_complete':False})

sys.path.insert(0,str(REPO))
from tools.app_control.camera_pixels import measure_floor
rows, artifacts = [], {}
r21 = REPO/'docs/evidence/agent_camera_2026-10-10/completion/adaptive-ai-r21'
audit = read(r21/'provenance/adaptive-audit.json')
artifacts[str(r21/'provenance/adaptive-audit.json')] = sha((r21/'provenance/adaptive-audit.json').read_bytes())
for pair in audit['camera_physics_pairs']:
    meta = pair['metadata']; sample = pair['native_camera_sample']
    png = r21/f"runtime/actor/camera/observation-{pair['observation']}.png"
    assert sha(png.read_bytes()) == meta['sha256'] == sample['capture_metadata']['sha256']
    assert meta['part_id'] == 0 and meta['physics_tick'] == meta['capture_requested_tick'] == sample['physics_tick']
    artifacts[str(png)] = sha(png.read_bytes())
    rows.append({'case':'r21-stock','label':f"observation-{pair['observation']}",'png_sha256':meta['sha256'],
        'position':sample['position'],'rotation':sample['rotation'],'gap_m':sample['gap_x'],
        'pixels':measure_floor(png),'pose_provenance':'same-tick frame_ready body; assigned camera inferred from unchanged source/mount',
        'physics_tick':meta['physics_tick']})
r22 = REPO/'build/ai-loop-evidence/completion/brake-integral-r22/integral'
measured = read(r22/'measured.json')
artifacts[str(r22/'measured.json')] = sha((r22/'measured.json').read_bytes())
for frame in measured['frames'][1:]:
    sample = frame['angular_pose_sample']; meta = frame['metadata']; png = r22/(frame['label']+'.png')
    assert sha(png.read_bytes()) == meta['sha256'] == sample['sha256']
    assert sample['physics_tick'] == meta['physics_tick'] == meta['capture_requested_tick']
    artifacts[str(png)] = sha(png.read_bytes())
    rows.append({'case':'r22-integral','label':frame['label'],'png_sha256':meta['sha256'],
        'position':sample['render_assigned_body_position'],'rotation':sample['render_assigned_body_rotation'],
        'gap_m':frame['capture_physics']['gap_x'],'pixels':measure_floor(png),
        'pose_provenance':'actual assigned camera * inverse mount, archived frame callback', 'physics_tick':meta['physics_tick']})
save(OUT/'input.json', {'source_head':HEAD,'wall_x':.35,'rows':rows,'input_sha256':artifacts,
    'r21_final_gap_m':audit['final_stopped_gap_m'],'r22_final_gap_m':measured['evaluation']['final']['gap_x']})

GDSCRIPT = '''extends SceneTree
## DEBUG-r23: geometry replay only; no simulation, actor, image generation or production edit.
func vector(a: Array) -> Vector3:
\treturn Vector3(a[0], a[1], a[2])

func run_projection() -> void:
\tvar location: String = "res://build/ai-loop-evidence/completion/projection-r23/"
\tvar input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(location + "input.json"))
\tvar graph: ConnectionGraph = RobotCarPreset.build(input.wall_x)
\tvar mode: RunMode = RunMode.new()
\troot.add_child(mode)
\tmode.build(graph)
\tvar offset: Transform3D = mode._body_offsets[0]
\tassert(offset.is_equal_approx(Transform3D.IDENTITY), "Replay requires graph chassis/body identity")
\tvar wall: PartDef = graph.parts[-1].part_def
\tvar bounds: AABB = wall.mesh.get_aabb()
\tvar wall_front: float = input.wall_x + bounds.position.x
\tvar main: Node3D = load("res://scenes/main.tscn").instantiate()
\tvar floor_mesh: MeshInstance3D = main.get_node("Floor/MeshInstance3D")
\tvar floor_bounds: AABB = floor_mesh.mesh.get_aabb()
\tvar floor_y: float = floor_mesh.transform.origin.y + floor_bounds.end.y
\tvar viewport: SubViewport = SubViewport.new()
\tviewport.size = Vector2i(640, 480)
\troot.add_child(viewport)
\tvar camera: Camera3D = Camera3D.new()
\tcamera.fov = 60.0
\tcamera.near = 0.005
\tcamera.far = 20.0
\tviewport.add_child(camera)
\tcamera.current = true
\tvar loop: AgentCameraLoop = AgentCameraLoop.new()
\tvar mount: Transform3D = loop._mount
\tvar rows: Array[Dictionary] = []
\tfor row: Dictionary in input.rows:
\t\tvar body_pose: Transform3D = Transform3D(Basis.from_euler(vector(row.rotation)), vector(row.position))
\t\tcamera.global_transform = body_pose * offset * mount
\t\tvar position: Vector3 = camera.global_position
\t\tvar center: Vector3 = camera.project_ray_normal(Vector2(320, 240))
\t\tvar z_wall: float = position.z + (wall_front - position.x) * center.z / center.x
\t\tvar boundary: Vector2 = camera.unproject_position(Vector3(wall_front, floor_y, z_wall))
\t\tvar targets: Dictionary = {}
\t\tvar projected_gaps: Dictionary = {}
\t\tvar camera_to_front: float = wall_front - row.gap_m - position.x
\t\tfor pixel: int in [12, 20, 24, 31, 38]:
\t\t\tvar ray: Vector3 = camera.project_ray_normal(Vector2(320, 480 - pixel))
\t\t\tvar distance_x: float = ray.x * (floor_y - position.y) / ray.y
\t\t\ttargets[str(pixel)] = distance_x - camera_to_front
\t\tfor gap: float in [0.04, 0.14]:
\t\t\tvar virtual_wall_x: float = position.x + camera_to_front + gap
\t\t\tvar virtual_z: float = position.z + (virtual_wall_x - position.x) * center.z / center.x
\t\t\tprojected_gaps[str(gap)] = 480 - camera.unproject_position(Vector3(virtual_wall_x, floor_y, virtual_z)).y
\t\tvar leveling: Transform3D = Transform3D(Basis.IDENTITY, body_pose.origin) * mount
\t\tvar actual: Transform3D = camera.global_transform
\t\tcamera.global_transform = leveling
\t\tvar leveled_z: float = camera.global_position.z
\t\tvar leveled_floor: float = 480 - camera.unproject_position(Vector3(wall_front, floor_y, leveled_z)).y
\t\tcamera.global_transform = actual
\t\trows.append({"case":row.case,"label":row.label,"sha256":row.png_sha256,
\t\t\t"predicted_floor_pixels":480 - boundary.y,"classified_floor_pixels":row.pixels.floor_pixels,
\t\t\t"prediction_error_pixels":480 - boundary.y - row.pixels.floor_pixels,
\t\t\t"target_gap_m":targets,"fixed_gap_floor_pixels":projected_gaps,
\t\t\t"level_body_at_same_origin_floor_pixels":leveled_floor,
\t\t\t"camera_position":[position.x,position.y,position.z],
\t\t\t"camera_basis":[[actual.basis.x.x,actual.basis.x.y,actual.basis.x.z],[actual.basis.y.x,actual.basis.y.y,actual.basis.y.z],[actual.basis.z.x,actual.basis.z.y,actual.basis.z.z]],
\t\t\t"camera_to_robot_front_x_m":camera_to_front,"observed_gap_m":row.gap_m,
\t\t\t"pose_provenance":row.pose_provenance})
\tvar file: FileAccess = FileAccess.open(location + "projection.json", FileAccess.WRITE)
\tfile.store_string(JSON.stringify({"rows":rows,"wall_front_x_m":wall_front,"floor_y_m":floor_y,
\t\t"graph_chassis_offset_identity":true,"camera_fov":camera.fov,"keep_aspect":camera.keep_aspect,
\t\t"viewport":[640,480],"scope":"Headless numerical replay of archived poses; no new images, physical trajectories or AI trials."}, "\\t") + "\\n")
\tfile.close()
\tmain.free()
\tloop.free()
\tmode.free()
\tviewport.free()
\tprint("DEBUG-r23 projected ", rows.size(), " archived poses")
\tquit(0)

func _initialize() -> void:
\trun_projection.call_deferred()
'''
fixture = OUT/'projection.gd'; fixture.write_bytes(GDSCRIPT.encode('utf8'))
command = [str(REPO/'build/toolchain-windows/Godot_v4.7.2-stable_win64_console.exe'),'--headless','--path',str(REPO),'--script',str(fixture)]
start = time.monotonic()
r = subprocess.run(command, cwd=REPO, capture_output=True, timeout=30)
(OUT/'godot.log').write_bytes(r.stdout+r.stderr)
receipt = {'command':command,'exit_code':r.returncode,'seconds':time.monotonic()-start,'fixture_sha256':sha(fixture.read_bytes()),
    'sources433_unchanged':all(sha((REPO/n).read_bytes())==h for n,h in sources.items()),'provider_calls':0,
    'new_rendered_trials':0,'new_physics_trials':0,'new_ai_trials':0,'production_applied':False,'whole_goal_complete':False}
save(OUT/'receipt.json', receipt)
assert r.returncode == 0 and receipt['sources433_unchanged'], receipt
print(json.dumps({'receipt':receipt,'projection':read(OUT/'projection.json')}, ensure_ascii=False))
