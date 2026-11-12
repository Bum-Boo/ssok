from pathlib import Path
import hashlib,json,subprocess,sys,time

r=Path('C:/Users/Hojun/Projects/ssok-ai-loop')
label=sys.argv[1] if len(sys.argv)>1 else 'baseline'
assert label == 'minimal-two-step'
last_ticks=13 if label=='tick13' else 12
tape=[30,22]
case='replay-near-'+'-'.join(map(str,tape))
out=r/('build/ai-loop-evidence/completion/control-feedback-r8-'+label)
out.mkdir(exist_ok=False)
source=json.loads((r/'docs/evidence/agent_camera_2026-10-10/completion/verified-r2/unchanged-camera-inputs.json').read_text())
assert all(hashlib.sha256((r/n).read_bytes()).hexdigest()==h for n,h in source['source_sha256'].items())
goal=r/'docs/evidence/agent_camera_2026-10-10/repeated/refined-visual-goal/plan.json'
assert hashlib.sha256(goal.read_bytes()).hexdigest()==source['goal_source_sha256']
from PIL import Image
command=[sys.executable,'-X','utf8','-m','tools.app_control.calibrate_camera_motion','--godot',str(r/'build/toolchain-windows/Godot_v4.7.2-stable_win64.exe'),'--out',str(out/case),'--wall-x','.35','--ticks',*map(str,tape),'--idle','0','--verify-goal']
plan={'scope':'Phase2 minimize: same52 total bounded forward ticks split into30/22 instead of30/10/12; removes one separately settled capture boundary only. No provider/source/physics/camera/criteria/pose change. Actual combined predicate retained; not a new AI reliability trial.','head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=r).decode().strip(),'source10_sha256':source['source_sha256'],'goal_sha256':source['goal_source_sha256'],'criteria':{'minimum_travel':.03,'minimum_gap':.04,'maximum_gap':.14},'tape':tape,'wall_x':.35,'condition':'real rendered native, existing motor action/observe/stop pipeline','timeout_seconds':90,'command':command}
(out/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
start=time.monotonic();proc=subprocess.Popen(command,cwd=r,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
timed_out=False
try:
    log,_=proc.communicate(timeout=90)
except subprocess.TimeoutExpired:
    timed_out=True
    subprocess.run(['taskkill.exe','/PID',str(proc.pid),'/T','/F'],capture_output=True,timeout=15)
    log,_=proc.communicate(timeout=15)
(out/'replay.log').write_bytes(log)
receipt={'exit_code':proc.returncode,'seconds':round(time.monotonic()-start,3),'timed_out':timed_out,'command':command,'source10_unchanged':all(hashlib.sha256((r/n).read_bytes()).hexdigest()==h for n,h in source['source_sha256'].items())}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
assert not timed_out, 'Diagnostic timed out; owned process tree stopped and raw result retained'
assert (out/case/'result.json').is_file(), 'Fixture did not produce result; preserve replay.log before diagnosis'
result=json.loads((out/case/'result.json').read_text())
evaluation=result['evaluation'];criteria=plan['criteria']
physical={'valid':evaluation['valid'],'travel':evaluation['travel_x']>=criteria['minimum_travel'],'gap':criteria['minimum_gap']<=evaluation['final']['gap_x']<=criteria['maximum_gap'],'no_contact':not evaluation['wall_contact'] and evaluation['minimum_gap_x']>0,'rest':evaluation['rest_ticks']>=12 and evaluation['stopped_state']=='stopped'}
combined={'image':result['final_image_target'],'physical':all(physical.values()),'physical_checks':physical,'gap_m':evaluation['final']['gap_x'],'final_floor_pixels':result['captures'][-1]['pixels']['floor_pixels'],'both':result['final_image_target'] and all(physical.values()),'scope':'Exact deterministic replay, no model success claim'}
(out/'combined-check.json').write_text(json.dumps(combined,indent=2)+'\n')
print(json.dumps({'receipt':receipt,'combined':combined}))
raise SystemExit(0 if combined['both'] else 1)
