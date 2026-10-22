from pathlib import Path
import json,sys
repo=Path('C:/Users/Hojun/Projects/ssok-ai-loop');sys.path.insert(0,str(repo))
from tools.app_control.desktop_client import DesktopClient
out=repo/'build/ai-loop-evidence/completion/operator-archive-r12/before'
client=DesktopClient();phase=sys.argv[1];state=client.request('describe')
if phase=='enter':
    assert not state['enabled'] and state['state']=='disabled' and state['robot_supported']
    assert not (out/'actor').exists()
    result={'intentional_enter_did_not_dispatch':True,'state':state}
elif phase=='final':
    actor=json.loads((out/'actor/result.json').read_text(encoding='utf8'))
    assert actor['status']=='runner_failed' and actor['cli_exit'] is None
    assert actor['completed_actions']==0 and actor['observations']==0 and not actor['final_reobserved']
    assert actor['stop_confirmed'] and state['state']=='stopped' and not state['enabled']
    stderr=(out/'operator.stderr').read_text(encoding='utf-8-sig')
    assert 'not a git repository' in stderr
    result={'actual_git_free_runner_failed_before_model_dispatch':True,'provider_cli_launches':0,'state':state,'actor_result':actor,'git_failure_in_stderr':True}
else:raise ValueError('Unsupported phase')
(out/('inspect-'+phase+'.json')).write_bytes((json.dumps(result,indent=2)+'\n').encode())
print(json.dumps({'phase':phase,'passed':True,'scope':'Expected Git-free baseline failure, not AI success.'}))
