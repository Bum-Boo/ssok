from pathlib import Path
import hashlib,json,os,secrets,subprocess,sys,time

repo=Path('C:/Users/Hojun/Projects/ssok-ai-loop');sys.path.insert(0,str(repo))
from tools.app_control.desktop_client import DesktopClient,assert_context,write_observation
from tools.app_control.camera_pixels import measure_floor
root=repo/'build/ai-loop-evidence/completion/observation-stop-r18/single-observe'
backup=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/observation-stop-r18')
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'));sha=lambda b:hashlib.sha256(b).hexdigest()
case=sys.argv[1];assert case in {'k32','combined'}
contract=read(backup/'contract.json')
assert all(sha((repo/n).read_bytes())==h for n,h in (contract['source426']|contract['extra_operator7']).items())
tag=sys.argv[2] if len(sys.argv)>2 else case;assert tag in {'k32','k32-v2','k32-v3','combined','combined-r2','combined-r3'}
out=root/tag;out.mkdir(exist_ok=False)
token=secrets.token_hex(32);old_token=os.environ.get('SSOK_AGENT_TOKEN')
env=dict(os.environ,SSOK_AGENT_TOKEN=token,APPDATA=str(out/'user-data'),LOCALAPPDATA=str(out/'config'),XDG_DATA_HOME=str(out/'user-data'),XDG_CONFIG_HOME=str(out/'config'))
cmd=[str(repo/'build/toolchain-windows/Godot_v4.7.2-stable_win64.exe'),'--path',str(repo),'--audio-driver','Dummy','--script','build/ai-loop-evidence/completion/observation-stop-r18/single-observe/callback_probe.gd','--','--ssok-agent-bridge','--case',case,'--output',str(out)]
fixture_files=[root/n for n in ['callback_probe.gd','callback_sampler.gd','motor_callback.gd','attitude-'+case+'.gd']]
plan={'command':cmd,'timeout_seconds':90,'fixture_sha256':{p.name:sha(p.read_bytes()) for p in fixture_files},'source426':contract['source426'],'endpoint':'Single bridge idle-1 checkpoint, actual DesktopClient observe, immediate context-bound Stop; image/physical metrics read only after Stop and native exit','model_calls':0,'production_applied':False}
(out/'plan.json').write_bytes((json.dumps(plan,indent=2)+'\n').encode())
plan['native_log_capture']='File sink as existing tools.app_control.camera_trial, not an unread pipe'
(out/'plan.json').write_bytes((json.dumps(plan,indent=2)+'\n').encode())
log_handle=(out/'godot.log').open('wb')
start=time.monotonic();proc=subprocess.Popen(cmd,cwd=repo,env=env,stdout=log_handle,stderr=subprocess.STDOUT)
client=DesktopClient();known_context=None;log=b'';failure=None;stop=None;remote=None;timed_out=False
os.environ['SSOK_AGENT_TOKEN']=token
try:
 deadline=start+80
 while True:
  if proc.poll() is not None:raise RuntimeError('Native fixture exited before fixed observation checkpoint')
  try:
   ready=read(out/'stop-ready.json');break
  except (FileNotFoundError,json.JSONDecodeError):pass
  if time.monotonic()>=deadline:raise TimeoutError('Fixed observation checkpoint deadline')
  time.sleep(.02)
 assert ready['bridge_listening'] and ready['label']=='bridge-idle-1-checkpoint'
 known_context=ready['metadata'];current=client.describe();assert_context(known_context,current,include_frame=True)
 remote=client.observe(known_context);known_context=remote.metadata
 write_observation(remote,out/'bridge-observed.png')
 returned=time.monotonic();stop=client.stop(known_context)
 assert stop['owner_revoked'] and stop['stop_scope']=='matched_context' and stop['state']=='stopped'
 (out/'bridge-stop.json').write_bytes((json.dumps({'observation':remote.metadata,'stop_result':stop,'observation_return_to_stop_ack_ms':(time.monotonic()-returned)*1000,'scope':'Existing authenticated desktop protocol; no model decision, pixel/physical input or global Stop'},indent=2)+'\n').encode())
 proc.wait(timeout=max(1,90-(time.monotonic()-start)))
except Exception as exc:
 failure=type(exc).__name__+': '+str(exc)
 if known_context is not None:
  try:client.stop(known_context)
  except Exception:pass
 if proc.poll() is None:
  timed_out=isinstance(exc,(TimeoutError,subprocess.TimeoutExpired))
  subprocess.run(['taskkill.exe','/PID',str(proc.pid),'/T','/F'],capture_output=True,timeout=15)
 proc.wait(timeout=15)
finally:
 if old_token is None:os.environ.pop('SSOK_AGENT_TOKEN',None)
 else:os.environ['SSOK_AGENT_TOKEN']=old_token
log_handle.close()
log=(out/'godot.log').read_bytes()
assert token.encode() not in log
(out/'godot.log').write_bytes(log)
receipt={'command':cmd,'exit_code':proc.returncode,'seconds':time.monotonic()-start,'timed_out':timed_out,'failure':failure,'source426_unchanged':all(sha((repo/n).read_bytes())==h for n,h in contract['source426'].items()),'model_calls':0,'production_applied':False,'token_persisted':False,'caller_process_environment_restored':os.environ.get('SSOK_AGENT_TOKEN')==old_token}
(out/'receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
assert failure is None and proc.returncode==0 and receipt['source426_unchanged'],receipt
result=read(out/'result.json');assert result['stop_confirmed'] and not result.get('failure') and len(result['frames'])==4 and len(result['frame_samples'])==4
result['frames'].append({'label':'bridge-observed','metadata':remote.metadata,'png_sha256':remote.metadata['sha256'],'source':'Actual DesktopClient observation supplied directly to context-bound Stop; all metrics computed after native exit'})
samples=[json.loads(line) for line in (out/'user-data/Godot/app_userdata/ssok/camera-calibration.jsonl').read_text(encoding='utf8').splitlines()]
for frame in result['frames']:
 path=out/(frame['label']+'.png');assert sha(path.read_bytes())==frame['png_sha256'];frame['pixels']=measure_floor(path)
 matched=[s for s in samples if s['reason']=='camera' and s['capture_metadata'].get('sha256')==frame['png_sha256'] and s['physics_tick']==frame['metadata']['physics_tick']]
 assert len(matched)==1
 s=matched[0];frame['capture_physics']={n:s[n] for n in ['gap_x','angular_speed','linear_speed','wheel_speed','position','rotation','linear_velocity','motors']}
 frame['pairing']='Actual frame_ready by SHA/tick; computed after Stop/native exit, no physical input to control'
counts=[[sum(1 for row in motor if row['command_index']==i and abs(row['applied_duty']-.25)<1e-12) for motor in result['actual_motor_callbacks']] for i in range(3)]
assert counts==[[30,30],[10,10],[12,12]]
for frame in result['frames'][1:]:
 matched=[s for s in result['frame_samples'] if s['sha256']==frame['png_sha256'] and s['physics_tick']==frame['metadata']['physics_tick']]
 assert len(matched)==1
 frame['angular_pose_sample']=matched[0]
e=result['evaluation'];physical=e['valid'] and e['travel_x']>=.03 and .04<=e['final']['gap_x']<=.14 and not e['wall_contact'] and e['minimum_gap_x']>0 and e['rest_ticks']>=12 and e['stopped_state']=='stopped'
final=result['frames'][-1];summary={'case':case,'floor_pixels':[f['pixels']['floor_pixels'] for f in result['frames']],'last_floor_pixels':final['pixels']['floor_pixels'],'final_gap_m':e['final']['gap_x'],'last_image_gap_m':final['capture_physics']['gap_x'],'stop_delta_from_last_frame_mm':(e['final']['gap_x']-final['capture_physics']['gap_x'])*1000,'actual_motor_counts':counts,'physical':physical,'last_image':final['pixels']['image_target'],'combined':physical and final['pixels']['image_target'],'bridge_observation_and_matched_context_stop':True,'model_calls':0,'production_applied':False,'source426_unchanged':True}
for name,value in [('measured.json',result),('summary.json',summary),('target-check.json',{'target':'Original24..38px AND independent4..14cm/travel/contact/rest/Stop','passed':summary['combined'],'physical':physical,'image':summary['last_image'],'model_calls':0,'production_applied':False})]:
 (out/name).write_bytes((json.dumps(value,indent=2)+'\n').encode())
for p in out.glob('*.json'):assert token.encode() not in p.read_bytes()
print(json.dumps({'receipt':receipt,'summary':summary}))
raise SystemExit(0 if summary['combined'] else 1)
