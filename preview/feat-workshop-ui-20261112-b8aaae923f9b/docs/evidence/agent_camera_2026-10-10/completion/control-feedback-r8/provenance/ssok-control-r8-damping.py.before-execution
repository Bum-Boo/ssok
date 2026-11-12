from pathlib import Path
import hashlib,json,os,subprocess,sys,time
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');sys.path.insert(0,str(r));from tools.app_control.camera_pixels import measure_floor
root=r/'build/ai-loop-evidence/completion/control-feedback-r8';b=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/control-feedback-r8');case=sys.argv[1];assert case in {'damping-p24'};out=root/case;out.mkdir(exist_ok=False)
read=lambda f:json.loads(f.read_text(encoding='utf-8-sig'));sha=lambda d:hashlib.sha256(d).hexdigest();inputs=read(b/'contract.json')['source426'];assert all(sha((r/n).read_bytes())==h for n,h in inputs.items())
env=dict(os.environ,APPDATA=str(out/'user-data'),LOCALAPPDATA=str(out/'config'),XDG_DATA_HOME=str(out/'user-data'),XDG_CONFIG_HOME=str(out/'config'))
cmd=[str(r/'build/toolchain-windows/Godot_v4.7.2-stable_win64.exe'),'--path',str(r),'--audio-driver','Dummy','--script','build/ai-loop-evidence/completion/control-feedback-r8/damping_probe.gd','--','--case',case,'--output',str(out)]
plan={'case':case,'command':cmd,'timeout_seconds':90,'source426':inputs,'fixture_sha256':{f.name:sha(f.read_bytes()) for f in [root/'damping_probe.gd',root/'damping_loop.gd']},'production_applied':False,'model_calls':0};(out/'plan.json').write_bytes((json.dumps(plan,indent=2)+'\n').encode())
started=time.monotonic();proc=subprocess.Popen(cmd,cwd=r,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);timed_out=False
try:log,_=proc.communicate(timeout=90)
except subprocess.TimeoutExpired:
    timed_out=True;subprocess.run(['taskkill.exe','/PID',str(proc.pid),'/T','/F'],capture_output=True,timeout=15);log,_=proc.communicate(timeout=15)
(out/'godot.log').write_bytes(log);receipt={'command':cmd,'exit_code':proc.returncode,'seconds':time.monotonic()-started,'timed_out':timed_out,'source426_unchanged':all(sha((r/n).read_bytes())==h for n,h in inputs.items()),'production_applied':False};(out/'receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode());assert not timed_out and receipt['source426_unchanged']
assert (out/'result.json').exists(),'No result; retain Godot log before diagnosis';result=read(out/'result.json')
if result.get('failure'):
    print(json.dumps({'receipt':receipt,'failure':result}),flush=True);raise SystemExit(1)
assert proc.returncode==0 and result['stop_confirmed'] and len(result['frames'])==8
paths=list((out/'user-data').glob('Godot/app_userdata/*/camera-calibration.jsonl'));assert len(paths)==1;samples=[json.loads(line) for line in paths[0].read_text(encoding='utf8').splitlines()]
for frame in result['frames']:
    png=out/(frame['label']+'.png');assert sha(png.read_bytes())==frame['png_sha256'];frame['pixels']=measure_floor(png);matched=[s for s in samples if s['reason']=='camera' and s['capture_metadata'].get('sha256')==frame['png_sha256']];assert len(matched)==1;s=matched[0];assert s['physics_tick']==frame['metadata']['physics_tick']==s['capture_metadata']['physics_tick'];frame['post_return_physics']=frame['capture_physics'];frame['capture_physics']={n:s[n] for n in ['gap_x','angular_speed','linear_speed','wheel_speed','position','rotation','linear_velocity','motors']};frame['pairing']='Actual frame_ready callback by SHA/tick; camera pose was assigned at capture_requested_tick, callback physics may be later.'
e=result['evaluation'];physical=e['valid'] and e['travel_x']>=.03 and .04<=e['final']['gap_x']<=.14 and not e['wall_contact'] and e['minimum_gap_x']>0 and e['rest_ticks']>=12 and e['stopped_state']=='stopped';idle=result['frames'][-5:];pixels=[f['pixels']['floor_pixels'] for f in idle];gaps=[f['capture_physics']['gap_x'] for f in idle];summary={'case':case,'floor_pixels':pixels,'pixel_span':max(pixels)-min(pixels),'capture_gap_span_mm':(max(gaps)-min(gaps))*1000,'angular_rates':[f['capture_physics']['angular_speed'] for f in idle],'final_gap_m':e['final']['gap_x'],'stop_delta_from_last_frame_mm':(e['final']['gap_x']-gaps[-1])*1000,'physical':physical,'last_image':idle[-1]['pixels']['image_target'],'combined':physical and idle[-1]['pixels']['image_target'],'source426_unchanged':True,'production_applied':False}
(out/'measured.json').write_bytes((json.dumps(result,indent=2)+'\n').encode());(out/'summary.json').write_bytes((json.dumps(summary,indent=2)+'\n').encode());print(json.dumps({'receipt':receipt,'summary':summary}),flush=True)
