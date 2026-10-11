from pathlib import Path
import json,os,sys,time
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');sys.path.insert(0,str(r))
from tools.app_control.desktop_client import DesktopClient,DesktopError,write_observation
root_out=r/'build/ai-loop-evidence/completion/package-camera-r5'
out=Path(os.environ.get('SSOK_PACKAGE_GATE_OUT',str(root_out)))
assert out.resolve() in [root_out.resolve(),(root_out/'corrected-native').resolve(),(root_out/'final-native').resolve(),(root_out/'final-native-focus-retry').resolve()]
client=DesktopClient();phase=sys.argv[1]
def ready():
    deadline=time.monotonic()+12;states=[]
    while True:
        snapshot=client.request('describe')
        if not states or snapshot!=states[-1]:states.append(snapshot)
        if snapshot['state']=='ready':break
        assert time.monotonic()<deadline,states
        time.sleep(.05)
    return snapshot,states
def save_frame(name):
    frame=client.observe(client.describe());write_observation(frame,out/(name+'.png'))
    assert (frame.metadata['width'],frame.metadata['height'])==(640,480)
    return frame.metadata
if phase=='before':
    state,states=ready();assert state['enabled'] and state['robot_supported'] and state['bridge_listening']
    result={'state':state,'poll_states':states,'metadata':save_frame('camera-before')}
elif phase=='after-native':
    before=json.loads((out/'bridge-before.json').read_text());state,states=ready()
    assert state['can_step'] is False,'Native Forward did not consume the current frame'
    assert state['control_generation']==before['metadata']['control_generation']
    after=save_frame('camera-after-native');assert after['frame_id']>before['metadata']['frame_id'] and after['sha256']!=before['metadata']['sha256']
    result={'state_before_reobserve':state,'poll_states':states,'metadata':after,'native_forward_consumed_frame':True,'configured_native_forward_ticks':20,'actual_png_changed':True}
elif phase=='bridge-eight':
    before=json.loads((out/'bridge-after-native.json').read_text())['metadata'];started=time.monotonic()
    action=client.drive_step(before['frame_id'],before['revision'],before['control_generation'],8,episode_id=before['episode_id'])
    assert action['state']=='ready';after=save_frame('camera-after-bridge')
    assert after['frame_id']>before['frame_id'] and after['physics_tick']>=before['physics_tick']+8
    result={'requested_ticks':8,'reply':action,'metadata':after,'seconds':time.monotonic()-started}
elif phase=='stopped':
    state=client.request('describe');old=json.loads((out/'bridge-bridge-eight.json').read_text())['metadata']
    assert state['state']=='stopped' and not state['enabled'] and state['control_generation']>old['control_generation']
    try:client.observe()
    except DesktopError as exc:observe_error=getattr(exc,'code','');assert observe_error=='agent_disabled'
    else:raise AssertionError('Late observe accepted')
    try:client.drive_step(old['frame_id'],old['revision'],old['control_generation'],1,episode_id=old['episode_id'])
    except DesktopError as exc:action_error=getattr(exc,'code','');assert action_error=='agent_not_ready'
    else:raise AssertionError('Late action accepted')
    result={'state':state,'late_observe_error':observe_error,'late_action_error':action_error,'actual_ui_stop_revoked':True}
else:raise ValueError('Unknown bounded phase')
(out/('bridge-'+phase+'.json')).write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'phase':phase,'passed':True}))
