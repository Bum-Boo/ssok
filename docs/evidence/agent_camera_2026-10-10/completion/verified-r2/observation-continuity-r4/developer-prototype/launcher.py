"""Run one explicit isolated, bounded rendered observation comparison case."""
from pathlib import Path
import hashlib,json,os,subprocess,sys,time
sys.path.insert(0,'C:/Users/Hojun/Projects/ssok-ai-loop')
from tools.app_control.camera_pixels import measure_floor

r=Path('C:/Users/Hojun/Projects/ssok-ai-loop')
case=sys.argv[1];assert case in {'stock','no-pulse'}
mode=sys.argv[2] if len(sys.argv)>2 else 'run';assert mode in {'run','rederive'}
root=r/'build/ai-loop-evidence/completion/observation-continuity-r4'
out=root/case
sources=json.loads((r/'build/ai-loop-evidence/completion/full-native-final-r2/source-before.json').read_text())['files'];assert len(sources)==426
sha=lambda data:hashlib.sha256(data).hexdigest();assert all(sha((r/n).read_bytes())==h for n,h in sources.items())
if mode=='run':
    out.mkdir(exist_ok=False)
    env=dict(os.environ,APPDATA=str(out/'user-data'),LOCALAPPDATA=str(out/'config'),XDG_DATA_HOME=str(out/'user-data'),XDG_CONFIG_HOME=str(out/'config'))
    command=[str(r/'build/toolchain-windows/Godot_v4.7.2-stable_win64.exe'),'--path',str(r),'--audio-driver','Dummy','--script','build/ai-loop-evidence/completion/observation-continuity-r4/probe.gd','--','--case',case,'--output',str(out)]
    plan={'case':case,'command':command,'timeout_seconds':90,'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=r).decode().strip(),'source426_sha256':sources,'fixture_sha256':{str(p.relative_to(r)):sha(p.read_bytes()) for p in [root/'probe.gd',root/'no_pulse_loop.gd']},'pulse_variable':'Only ready->observe _start_settle stops motors in stock; variant preserves existing command, identical PI/motor/camera/evaluator/Stop.','model_calls':0}
    (out/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
    start=time.monotonic();process=subprocess.Popen(command,cwd=r,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);timed_out=False
    try:log,_=process.communicate(timeout=90)
    except subprocess.TimeoutExpired:
        timed_out=True;subprocess.run(['taskkill.exe','/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=15);log,_=process.communicate(timeout=15)
    (out/'godot.log').write_bytes(log)
    receipt={'command':command,'exit_code':process.returncode,'timed_out':timed_out,'seconds':round(time.monotonic()-start,3),'source426_unchanged':all(sha((r/n).read_bytes())==h for n,h in sources.items())}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
else:
    receipt=json.loads((out/'receipt.json').read_text())
    for name in ['measured.json','summary.json']:
        original=out/name;backup=out/('post-return-'+name)
        assert original.is_file() and not backup.exists();backup.write_bytes(original.read_bytes())
assert not receipt['timed_out'] and receipt['exit_code']==0,'Actual fixture failed; retain raw log'
assert receipt['source426_unchanged']
result=json.loads((out/'result.json').read_text());assert len(result['frames'])==9 and result['stop_confirmed']
calibration_files=list((out/'user-data').glob('Godot/app_userdata/*/camera-calibration.jsonl'));assert len(calibration_files)==1
samples=[json.loads(line) for line in calibration_files[0].read_text(encoding='utf8').splitlines()]
for frame in result['frames']:
    png=out/(frame['label']+'.png');assert sha(png.read_bytes())==frame['png_sha256'];frame['pixel_measurement']=measure_floor(png)
    matches=[s for s in samples if s['reason']=='camera' and s['capture_metadata'].get('sha256')==frame['png_sha256']];assert len(matches)==1
    sample=matches[0];assert sample['capture_metadata']['physics_tick']==frame['metadata']['physics_tick']==sample['physics_tick']
    frame['post_return_physics']=frame['capture_physics']
    frame['capture_physics']={key:sample[key] for key in ['x','gap_x','linear_speed','angular_speed','wheel_speed','position','rotation','linear_velocity','motors']}
    frame['pairing_basis']='Original evaluator frame_ready callback matched by PNG SHA and actual metadata/physics tick, not later coroutine return.'
idle=result['frames'][-5:];gaps=[f['capture_physics']['gap_x'] for f in idle];pixels=[f['pixel_measurement']['floor_pixels'] for f in idle]
e=result['evaluation'];fullphysical=e['valid'] and e['travel_x']>=.03 and .04<=e['final']['gap_x']<=.14 and not e['wall_contact'] and e['minimum_gap_x']>0 and e['rest_ticks']>=12 and e['stopped_state']=='stopped'
summary={'case':case,'floor_pixels':pixels,'pixel_span':max(pixels)-min(pixels),'capture_gap_range_mm':(max(gaps)-min(gaps))*1000,'final_gap_m':e['final']['gap_x'],'final_image_target':result['frames'][-1]['pixel_measurement']['image_target'],'full_physical':fullphysical,'combined':fullphysical and result['frames'][-1]['pixel_measurement']['image_target'],'request_before_after_duty':[(f['label'],[m['duty'] for m in f['request_before_physics']['motors']],[m['duty'] for m in f['request_after_physics']['motors']]) for f in result['frames']],'source426_unchanged':True,'scope':'Developer-only hypothesis comparison, no production repair or AI success claim.'}
(out/'measured.json').write_text(json.dumps(result,indent=2)+'\n');(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({'receipt':receipt,'summary':summary}))
