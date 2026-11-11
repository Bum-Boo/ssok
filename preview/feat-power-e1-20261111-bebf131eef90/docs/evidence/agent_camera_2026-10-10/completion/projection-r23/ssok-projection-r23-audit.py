from pathlib import Path
import hashlib, json, math, shutil, subprocess

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
root = repo/'build/ai-loop-evidence/completion/projection-r23'
backup = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/projection-r23')
public = repo/'docs/evidence/agent_camera_2026-10-10/completion/projection-r23'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda b: hashlib.sha256(b).hexdigest()
save = lambda p,d: p.write_bytes((json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode('utf8'))
contract = read(backup/'contract.json')
data = read(root/'projection.json'); source = read(root/'input.json')
assert read(root/'receipt.json')['exit_code'] == 0
assert 'ERROR:' not in (root/'godot.log').read_text(encoding='utf8')
focal = 240/math.tan(math.radians(data['camera_fov'])/2)
audited = []
for row in data['rows']:
    position = row['camera_position']; basis = row['camera_basis']
    center = [-v for v in basis[2]]
    wall = data['wall_front_x_m']; floor = data['floor_y_m']
    point = [wall, floor, position[2]+(wall-position[0])*center[2]/center[0]]
    relative = [point[i]-position[i] for i in range(3)]
    local_y = sum(basis[1][i]*relative[i] for i in range(3))
    depth = -sum(basis[2][i]*relative[i] for i in range(3))
    arithmetic_floor = 240+focal*local_y/depth
    independent_error = abs(arithmetic_floor-row['predicted_floor_pixels'])
    assert independent_error < .0001, (row['label'],independent_error)
    target_errors = []
    for target,value in row['target_gap_m'].items():
        local_y_ray = (int(target)-240)/focal
        ray = [basis[1][i]*local_y_ray-basis[2][i] for i in range(3)]
        gap = ray[0]*(floor-position[1])/ray[1]-row['camera_to_robot_front_x_m']
        target_errors.append(abs(gap-value))
    assert max(target_errors) < 1e-7
    audited.append({'case':row['case'],'label':row['label'],
        'image_sha256':row['sha256'],'engine_vs_arithmetic_error_pixels':independent_error,
        'engine_vs_arithmetic_target_error_m':max(target_errors),
        'projection_vs_classifier_error_pixels':row['prediction_error_pixels'],
        'gap24_cm':row['target_gap_m']['24']*100,'gap31_cm':row['target_gap_m']['31']*100,
        'gap38_cm':row['target_gap_m']['38']*100,
        'observed_vs_level_body_pixels':row['predicted_floor_pixels']-row['level_body_at_same_origin_floor_pixels'],
        'smallest_original_pixel_goal_exceeds_camera_time14cm':row['target_gap_m']['24']>.14})
assert len(audited) == 9 and max(abs(r['prediction_error_pixels']) for r in data['rows']) < 1
stock_final = next(r for r in data['rows'] if r['case']=='r21-stock' and r['label']=='observation-5')
summary = {'archived_poses':9,'assigned_camera_poses':4,'same_tick_source_inferred_camera_poses':5,
    'max_projection_vs_classifier_error_pixels':max(abs(r['prediction_error_pixels']) for r in data['rows']),
    'max_independent_arithmetic_error_pixels':max(r['engine_vs_arithmetic_error_pixels'] for r in audited),
    'poses_where24px_camera_time_gap_exceeds14cm':sum(r['smallest_original_pixel_goal_exceeds_camera_time14cm'] for r in audited),
    'gap24_cm_range':[min(r['gap24_cm'] for r in audited),max(r['gap24_cm'] for r in audited)],
    'gap31_cm_range':[min(r['gap31_cm'] for r in audited),max(r['gap31_cm'] for r in audited)],
    'gap38_cm_range':[min(r['gap38_cm'] for r in audited),max(r['gap38_cm'] for r in audited)],
    'level_body_counterfactual_difference_pixels_range':[min(r['observed_vs_level_body_pixels'] for r in audited),max(r['observed_vs_level_body_pixels'] for r in audited)],
    'r21_latest_gap31_cm':stock_final['target_gap_m']['31']*100,
    'r21_actual_camera_time_gap_cm':stock_final['observed_gap_m']*100,
    'r21_actual_stopped_gap_cm':source['r21_final_gap_m']*100,
    'r21_latest14cm_predicted_floor_pixels':stock_final['fixed_gap_floor_pixels']['0.14'],
    'calibration_mismatch_at_observed_poses_supported':True,'global_impossibility_proven':False,
    'measurement_failure_found':False,'counterfactual_is_physical_control_success':False,
    'new_physical_or_rendered_or_ai_trials':0,'goal_changed':False,'calibration12_20_adopted_or_run':False,
    'product_adoption_requires_user_decision':True,'whole_goal_complete':False}
save(root/'arithmetic-audit.json',{'rows':audited,'summary':summary})
save(root/'summary.json',summary)
assert all(sha(Path(p).read_bytes())==h for p,h in source['input_sha256'].items())
assert all(sha((repo/p).read_bytes())==h for p,h in contract['sources'].items())

public.mkdir(exist_ok=False)
files = []
for src in [root/'input.json',root/'projection.json',root/'arithmetic-audit.json',root/'summary.json',root/'receipt.json',root/'godot.log',root/'projection.gd',Path(__file__),repo.parent/'ssok-projection-r23.py']:
    dest = public/src.name
    shutil.copyfile(src,dest)
    assert sha(src.read_bytes()) == sha(dest.read_bytes())
    files.append({'source':str(src),'output':dest.name,'sha256':sha(dest.read_bytes())})
save(public/'copy-manifest.json',{'files':files,'original_images_not_duplicated':True,
    'image_sources':['../adaptive-ai-r21/runtime/actor/camera/','../brake-integral-r22/runtime/integral/']})
(public/'.gitattributes').write_bytes(b'* -text\n')
report = '''# Archived camera projection diagnosis r23

Source **afbc89968e1f11037dee10b12020baf5bf61b436**, issue32, 2026-10-11.
One pinned Godot4.7.2 headless numerical replay completed in1.026s/exit0.
This is a diagnosis of already captured images/poses, not a new physical,
rendered, AI or immutable packaged-app trial. No controller or target changed.

The wall/floor boundary is explained by camera geometry: nine archived640×480
PNGs agree with projection within0.968px. Independent Python pinhole arithmetic
agrees with Godot projection within0.0001px. The replay checks actual graph
chassis/body identity offset, wall mesh front0.340m, floor top0.050m, mount,
FOV60 and viewport640×480. Four r22 poses were actually assigned to the camera;
five r21 poses are inferred from same-tick frame_ready bodies and unchanged
source/mount (not a fresh assigned-pose measurement). SHA/tick matches verified.

| Camera target | Gap at nine observed poses, fixed orientation |
|---|---|
|24px|13.9919–14.2278cm|
|31px|14.4799–14.7269cm|
|38px|15.0005–15.2599cm|

At the latest r21 stock AI pose,31px corresponds to camera-time14.6625cm;
the actual image classified31px had camera-time14.7204cm and separately
measured stopped gap14.5838cm. At that pose14cm projects to21.56px.
Seven of nine observed poses put the smallest original image goal24px beyond
camera-time14cm. Two poses have a tiny geometric overlap. **This does not prove
the joint goal impossible** or predict final gap after Stop. Projection uses
continuous pixel coordinates; the classifier quantizes and has±1px uncertainty.

Making only the replay body orientation identity at the same body origin changes
the projected strip by6.19–11.02px. This counterfactual includes rotation of the
mount and camera height; it is not a physical pose correction, successful
controller, isolated pitch effect or fresh causal experiment. It supports
accounting for pose when calibrating the demonstration.

Ranked predictions were written in the existing project plan before replay.
The observed-pose calibration hypothesis is supported; a large measurement
discrepancy was not found. Next distinguish a user-approved calibrated goal
from further control work. Existing12–20px proposal remains unadopted/unrun;
even plausible geometry would require separate actual AI/physics verification.

[Numerical summary](summary.json), [independent arithmetic](arithmetic-audit.json),
[engine projection](projection.json), [input identities](input.json),
[command/receipt](receipt.json), [nine copied raw artifacts](copy-manifest.json).
Original images remain in [r21](../adaptive-ai-r21/README.md) and
[r22](../brake-integral-r22/README.md), whose existing Astra views are dated evidence.
No new visual judgment or Opus design work was required for this numerical audit.

Source426+operator7 unchanged; frozen24–38px AND stopped4–14cm unchanged.
Historical3layouts×3AI image9/9 physical0/9 and separate r21 jointFAIL are retained.
No UI/localization/provider/auth/request-limit change, model inference0.
Docs maintenance/tests only; app import/fullnative/Web/export/installer unrun.
Fable functional review/integration, original precision, fresh account, native Mac,
Arch raw/task16 CLI release, human merge and exact-version publication remain open.
External helpers require the original checkout/private contract and original
artifacts; they are archived diagnostic tools, not product launchers.
'''
(public/'README.md').write_bytes(report.encode('utf8'))
owned = [repo/'docs/STATUS.md',repo/'CLAUDE-REVIEW.md',repo/'docs/evidence/agent_camera_2026-10-10/completion/README.md']
doc_manifest = {}
for p in owned:
    original = p.read_bytes(); (backup/(p.name+'.before')).write_bytes(original)
    text = p.read_text(encoding='utf8')
    if p.name == 'STATUS.md':
        lines = text.splitlines(keepends=True)
        assert lines[2].startswith('2026-10-11 r22:')
        lines[2] = '2026-10-11 r23: 영상9개 기하 재생0.968px 이내;24px 대부분14cm초과·자세 의존. 기준/제어 결정 대기. [진단·한계](evidence/agent_camera_2026-10-10/completion/projection-r23/README.md). 원래 정밀도/계정/Mac·Arch/통합공개 미완료.\n'
        revised = ''.join(lines)
    elif p.name == 'CLAUDE-REVIEW.md':
        revised = '# ssok — archived camera projection diagnosis r23\n\n[9 poses/independent arithmetic/no runtime changes](docs/evidence/agent_camera_2026-10-10/completion/projection-r23/README.md).\nProjection matches original PNG within0.968px;24px maps13.9919–14.2278cm,31px14.4799–14.7269cm at observed poses.\nCamera-time geometry is distinct from stopped physical success. No impossibility proof/calibration adoption/newAI.\nSource433/frozen goal/controller/UI unchanged. Fable review exact local docs; human merges.\nNext user calibration decision or bounded control work; Mac/Arch/account/publication remain open.\n\n## Frozen r22 milestone\n\n'+text
    else:
        marker = '## Dated r2 checkpoint'
        assert marker in text
        revised = '# Camera precision and stabilization — reviewed local draft\n\nCurrent checkpoint,2026-10-11: [r23 projection diagnosis](projection-r23/README.md), sourceafbc899.\n9 archived camera poses agree with image boundaries within0.968px; most original24px targets exceed camera-time14cm.\nOrientation matters; two tiny overlaps prevent a general impossibility conclusion. Original target/controller unchanged.\n[Actual stock AI r21](adaptive-ai-r21/README.md):31px/14.5838cm jointFAIL; [r22 candidate](brake-integral-r22/README.md):22px/13.9092cm jointFAIL/unapplied.\nApp fa868ca/0.3.1-projects-r7 and [r14 operator](operator-setup-r14/README.md) unchanged;\n[r7 actual release verification](release-current-ui-r7/README.md) and original3layouts×3AI image9/9 physical0/9 remain dated evidence.\nCalibration12–20 proposal unadopted/unrun; freshaccount/nativeMac/Archraw/task16CLI/humanmerge/publication open.\n\n'+marker+text.split(marker,1)[1]
    assert p.read_bytes() == original
    p.write_bytes(revised.encode('utf8'))
    doc_manifest[str(p)] = {'before_sha256':sha(original),'post_sha256':sha(p.read_bytes()),'before_copy':str(backup/(p.name+'.before'))}
save(backup/'documentation-writes.json',doc_manifest)
checks=[]
for argv in [['python','-X','utf8','tools/docs/maintain.py','--check'],['python','-X','utf8','-m','unittest','discover','-s','tools/docs','-p','test_*.py']]:
    result = subprocess.run(argv,cwd=repo,capture_output=True,timeout=60)
    log = backup/f'docs-check-{len(checks)+1}.log'; log.write_bytes(result.stdout+result.stderr)
    checks.append({'command':argv,'exit_code':result.returncode,'log':str(log),'log_sha256':sha(log.read_bytes())})
save(backup/'documentation-checks.json',checks)
assert all(r['exit_code']==0 for r in checks),checks
print(json.dumps(summary,ensure_ascii=False))
