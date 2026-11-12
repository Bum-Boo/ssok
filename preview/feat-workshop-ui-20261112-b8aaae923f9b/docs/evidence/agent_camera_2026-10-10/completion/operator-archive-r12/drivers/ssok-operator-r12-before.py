from pathlib import Path
import hashlib, json, os, subprocess, time

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
backup = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/operator-archive-r12')
out = repo/'build/ai-loop-evidence/completion/operator-archive-r12/before'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda b: hashlib.sha256(b).hexdigest()
contract = read(backup/'contract.json')
assert all(sha((repo/n).read_bytes())==h for n,h in contract['source426'].items())
assert not (out/'run-receipt.json').exists() and not (out/'actor').exists()
operator_root = Path(contract['baseline_operator_root'])
assert all(sha((operator_root/n).read_bytes())==h for n,h in contract['baseline_operator_files'].items())
probe = subprocess.run(['git','rev-parse','HEAD'],cwd=operator_root,capture_output=True,timeout=15)
assert probe.returncode != 0
inspect = repo.parent/'ssok-operator-r12-before-inspect.py'; assert not inspect.exists()
inspect.write_bytes(b'''from pathlib import Path
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
(out/('inspect-'+phase+'.json')).write_bytes((json.dumps(result,indent=2)+'\\n').encode())
print(json.dumps({'phase':phase,'passed':True,'scope':'Expected Git-free baseline failure, not AI success.'}))
''')
old = repo.parent/'ssok-package-goal-r10-native.ps1'
native = repo.parent/'ssok-operator-r12-before-native.ps1'; assert not native.exists()
source = old.read_text(encoding='utf8')
source = source.replace('[string]$Fixture)', '[string]$Fixture,[string]$OperatorRoot)', 1)
source = source.replace('ssok-package-goal-r10-inspect.py', 'ssok-operator-r12-before-inspect.py')
needle = "-WorkingDirectory 'C:/Users/Hojun/Projects/ssok-ai-loop'"
assert source.count(needle)==1
source = source.replace(needle, '-WorkingDirectory $OperatorRoot')
source = source.replace("Check ($operatorProcess.ExitCode -eq 0) 'Actual requested AI operator exits successfully'", "Check ($operatorProcess.ExitCode -ne 0) 'Detached operator reproduces pre-dispatch Git failure'")
native.write_bytes(source.encode('utf8'))
inputs = [native, inspect, Path(__file__), out/'layout.json', out/'project.json', repo/'tools/ci/windows/native_ui.ps1']
saved=backup/'before-driver-inputs'; saved.mkdir(exist_ok=False)
hashes={}
for p in inputs:
    data=p.read_bytes(); (saved/p.name).write_bytes(data); hashes[str(p)]=sha(data)
(backup/'before-driver-inputs.json').write_bytes((json.dumps(hashes,indent=2)+'\n').encode())
app=Path(contract['package']['app'])
assert all(sha((app.parent/n).read_bytes())==h for n,h in contract['package']['exact_export_and_installer_bytes'].items())
cmd=['powershell.exe','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',str(native),'-App',str(app),'-Work',str(out),'-Layout',str(out/'layout.json'),'-Python',str(repo/'build/venv-native/Scripts/python.exe'),'-Fixture',str(out/'project.json'),'-OperatorRoot',str(operator_root)]
start=time.monotonic(); p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,env=dict(os.environ,PYTHONUTF8='1'),creationflags=subprocess.CREATE_NO_WINDOW);timed_out=False
try: log,_=p.communicate(timeout=415)
except subprocess.TimeoutExpired:
    timed_out=True;subprocess.run(['taskkill.exe','/PID',str(p.pid),'/T','/F'],capture_output=True,timeout=15);log,_=p.communicate(timeout=15)
(out/'driver.log').write_bytes(log)
receipt={'command':cmd,'exit_code':p.returncode,'seconds':time.monotonic()-start,'timed_out':timed_out,'source426_unchanged':all(sha((repo/n).read_bytes())==h for n,h in contract['source426'].items()),'actual_git_free_root':str(operator_root),'preexisting_actual_git_probe_exit':probe.returncode,'expected_runner_failure_before_provider_dispatch':True,'app_pe_pck_unchanged':all(sha((app.parent/n).read_bytes())==h for n,h in contract['package']['exact_export_and_installer_bytes'].items()),'app_source':contract['package']['source'],'version':contract['package']['version'],'global_goal_complete':False}
(out/'run-receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
print(json.dumps(receipt));print(log.decode('utf-8-sig'))
assert not timed_out and p.returncode==0 and receipt['source426_unchanged']
