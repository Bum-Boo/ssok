from pathlib import Path
import json,hashlib,sys
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');sys.path.insert(0,str(r))
from tools.app_control.camera_pixels import measure_floor
out=r/'build/ai-loop-evidence/completion/angular-feedback-r9/stock'
case='stock'
read=lambda f:json.loads(f.read_text(encoding='utf-8-sig'))
sha=lambda d:hashlib.sha256(d).hexdigest()
receipt=read(out/'receipt.json')
class Completed:
    returncode=receipt['exit_code']
proc=Completed()
assert (out/'result.json').exists(),'No result; retain Godot log before diagnosis';result=read(out/'result.json')
if result.get('failure'):
    print(json.dumps({'receipt':receipt,'failure':result}),flush=True);raise SystemExit(1)
assert proc.returncode==0 and result['stop_confirmed'] and len(result['frames'])==8
paths=list((out/'user-data').glob('Godot/app_userdata/*/camera-calibration.jsonl'));assert len(paths)==1;samples=[json.loads(line) for line in paths[0].read_text(encoding='utf8').splitlines()]
for frame in result['frames']:
    png=out/(frame['label']+'.png');assert sha(png.read_bytes())==frame['png_sha256'];frame['pixels']=measure_floor(png);matched=[s for s in samples if s['reason']=='camera' and s['capture_metadata'].get('sha256')==frame['png_sha256']];assert len(matched)==1;s=matched[0];assert s['physics_tick']==frame['metadata']['physics_tick']==s['capture_metadata']['physics_tick'];frame['post_return_physics']=frame['capture_physics'];frame['capture_physics']={n:s[n] for n in ['gap_x','angular_speed','linear_speed','wheel_speed','position','rotation','linear_velocity','motors']};frame['pairing']='Actual frame_ready callback by SHA/tick; camera pose was assigned at capture_requested_tick, callback physics may be later.'
assert len(result['frame_samples'])==7
samples_by_sha={row['sha256']:row for row in result['frame_samples']}
assert len(samples_by_sha)==7
for frame in result['frames'][1:]:
    sample=samples_by_sha[frame['png_sha256']]
    assert frame['metadata']['physics_tick']==sample['physics_tick']
    frame['angular_pose_sample']=sample
counts=[[sum(1 for row in motor if row['command_index']==index and abs(row['applied_duty']-.25)<1e-12) for motor in result['actual_motor_callbacks']] for index in range(3)]
assert counts==[[30,30],[10,10],[12,12]],counts
e=result['evaluation'];physical=e['valid'] and e['travel_x']>=.03 and .04<=e['final']['gap_x']<=.14 and not e['wall_contact'] and e['minimum_gap_x']>0 and e['rest_ticks']>=12 and e['stopped_state']=='stopped';idle=result['frames'][-5:];pixels=[f['pixels']['floor_pixels'] for f in idle];gaps=[f['capture_physics']['gap_x'] for f in idle];summary={'case':case,'floor_pixels':pixels,'pixel_span':max(pixels)-min(pixels),'capture_gap_span_mm':(max(gaps)-min(gaps))*1000,'angular_rates':[f['capture_physics']['angular_speed'] for f in idle],'final_gap_m':e['final']['gap_x'],'stop_delta_from_last_frame_mm':(e['final']['gap_x']-gaps[-1])*1000,'actual_motor_counts':counts,'signed_housing_axis_rates':[[m['housing_axis_rate'] for m in f['angular_pose_sample']['motors']] for f in idle],'assigned_vs_callback_pitch_delta_rad':[f['angular_pose_sample']['callback_body_rotation'][2]-f['angular_pose_sample']['render_assigned_body_rotation'][2] for f in idle],'physical':physical,'last_image':idle[-1]['pixels']['image_target'],'combined':physical and idle[-1]['pixels']['image_target'],'source426_unchanged':True,'production_applied':False}
(out/'measured.json').write_bytes((json.dumps(result,indent=2)+'\n').encode());(out/'summary.json').write_bytes((json.dumps(summary,indent=2)+'\n').encode());print(json.dumps({'receipt':receipt,'summary':summary}),flush=True)
