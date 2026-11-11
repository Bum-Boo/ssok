from pathlib import Path
import json,os,sys,time
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');sys.path.insert(0,str(r))
from tools.app_control.desktop_client import DesktopClient,DesktopError,load_observation
out=r/'build/ai-loop-evidence/completion/operator-archive-r12/after';client=DesktopClient();phase=sys.argv[1]
if phase=='enter':
    state=client.request('describe');assert not state['enabled'] and state['state']=='disabled' and state['robot_supported']
    assert not (out/'actor').exists(),'Enter unexpectedly dispatched goal'
    result={'intentional_enter_did_not_dispatch':True,'state':state}
elif phase=='final':
    result=json.loads((out/'actor/result.json').read_text());assert result['cli_exit']==0 and result['completed_actions']==1 and result['observations']==2 and result['final_reobserved'] and result['stop_confirmed'] and result['owner_revocation_confirmed'],result
    events=[json.loads(line) for line in (out/'actor/camera/events.jsonl').read_text().splitlines()]
    decisions=[event for event in events if event['event']=='decision'];assert len(decisions)==1 and decisions[0]['data']['ticks']==3,decisions
    frames=list((out/'actor/camera').glob('*.json'));metadata=[]
    for frame in frames:
        if frame.with_suffix('.png').exists():metadata.append(load_observation(frame).metadata)
    assert len(metadata)==2 and len({x['sha256'] for x in metadata})==2 and all((x['width'],x['height'])==(640,480) for x in metadata)
    state=client.request('describe');assert state['state']=='stopped' and not state['enabled']
    result={'actual_native_run_to_external_operator_and_requested_astra':True,'goal': 'Observe the camera, move forward only3 ticks once, observe again, then stop.','actions':1,'ticks':3,'observations':2,'verified_camera_metadata':metadata,'state':state,'actor_result':result,'provider_backend_identity_attested':False,'account_login_packaged':False,'operator_archive_git_independent':True}
else:raise ValueError('Unsupported phase')
(out/('inspect-'+phase+'.json')).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'phase':phase,'passed':True}))
