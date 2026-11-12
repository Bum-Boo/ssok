from pathlib import Path
import hashlib,json,os,secrets,subprocess,sys,time
sys.path.insert(0,'C:/Users/Hojun/Projects/ssok-ai-loop')
from tools.app_control.desktop_client import DesktopClient,DesktopError,write_observation
from tools.app_control.camera_pixels import measure_floor

r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');out=r/'build/ai-loop-evidence/completion/physical-compatibility-r3-jitter';out.mkdir(exist_ok=False)
sources=json.loads((r/'docs/evidence/agent_camera_2026-10-10/completion/verified-r2/unchanged-camera-inputs.json').read_text())
assert all(hashlib.sha256((r/n).read_bytes()).hexdigest()==h for n,h in sources['source_sha256'].items())
plan={'scope':'Developer-only same motor/observation path, fixed near wall, four actions30/10/12/1 followed by four additional idle observations. No model calls/target or physics changes. Capture-time gap comes only from independent observer file; never bridge/model input.','tape':[30,10,12,1],'wall_x':.35,'total_images':9,'idle_interval_s':.5,'source10_sha256':sources['source_sha256'],'goal_sha256':sources['goal_source_sha256']}
(out/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
env=dict(os.environ,SSOK_AGENT_TOKEN=secrets.token_hex(32),APPDATA=str(out/'user-data'),LOCALAPPDATA=str(out/'config'),XDG_DATA_HOME=str(out/'user-data'),XDG_CONFIG_HOME=str(out/'config'))
previous=os.environ.get('SSOK_AGENT_TOKEN');os.environ['SSOK_AGENT_TOKEN']=env['SSOK_AGENT_TOKEN']
client=DesktopClient();log=(out/'godot.log').open('wb');command=[str(r/'build/toolchain-windows/Godot_v4.7.2-stable_win64.exe'),'--path',str(r),'--script','tools/app_control/run_desktop.gd','--','--ssok-agent-bridge','--evaluate-camera','--wall-x','.35'];process=subprocess.Popen(command,cwd=r,env=env,stdout=log,stderr=subprocess.STDOUT);frames=[];start=time.monotonic()
try:
    deadline=time.monotonic()+30
    while True:
        if process.poll() is not None:raise RuntimeError('Rendered fixture exited')
        try:
            if client.describe()['state']=='ready':break
        except DesktopError:pass
        if time.monotonic()>deadline:raise RuntimeError('Readiness timeout')
        time.sleep(.05)
    def capture(label):
        frame=client.observe(client.describe());path=out/(label+'.png');write_observation(frame,path);frames.append({'label':label,'metadata':frame.metadata,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'pixels':measure_floor(path)});return frame.metadata
    meta=capture('initial')
    for i,ticks in enumerate(plan['tape']):
        client.drive_step(meta['frame_id'],meta['revision'],meta['control_generation'],ticks,episode_id=meta['episode_id']);meta=capture('post-'+str(i+1))
    for i in range(4):
        time.sleep(.5);meta=capture('idle-'+str(i+1))
    assert len(frames)==9
    stopped=client.stop();time.sleep(2.2)
    files=list((out/'user-data').glob('Godot/app_userdata/*/camera-calibration.jsonl'));assert len(files)==1
    samples=[json.loads(line) for line in files[0].read_text(encoding='utf8').splitlines()];paired=[]
    for frame in frames:
        sample=next(s for s in samples if s['reason']=='camera' and s['capture_metadata'].get('sha256')==frame['sha256']);paired.append({'label':frame['label'],'pixels':frame['pixels']['floor_pixels'],'gap_m':sample['gap_x'],'position':sample['position'],'rotation':sample['rotation'],'linear_speed':sample['linear_speed'],'angular_speed':sample['angular_speed'],'wheel_speed':sample['wheel_speed'],'metadata':frame['metadata'],'sha256':frame['sha256'],'both_at_frame':frame['pixels']['image_target'] and .04<=sample['gap_x']<=.14})
    evaluation=json.loads(next((out/'user-data').glob('Godot/app_userdata/*/camera-evaluation.json')).read_text(encoding='utf8'))
    result={'plan':plan,'frames':paired,'evaluation':evaluation,'stop_confirmed':stopped['state']=='stopped','seconds':round(time.monotonic()-start,3),'source10_unchanged':all(hashlib.sha256((r/n).read_bytes()).hexdigest()==h for n,h in sources['source_sha256'].items()),'scope_limit':'both_at_frame only pairs image/gap; full travel/contact/rest/stop score is independent final evaluation, not these flags'}
    (out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'frames':[{'label':x['label'],'pixels':x['pixels'],'gap_m':x['gap_m'],'both_at_frame':x['both_at_frame']} for x in paired],'final_gap_m':evaluation['final']['gap_x'],'seconds':result['seconds']}))
finally:
    try:client.stop()
    except DesktopError:pass
    process.terminate()
    try:process.wait(timeout=5)
    except subprocess.TimeoutExpired:process.kill();process.wait()
    log.close()
    if previous is None:os.environ.pop('SSOK_AGENT_TOKEN',None)
    else:os.environ['SSOK_AGENT_TOKEN']=previous
