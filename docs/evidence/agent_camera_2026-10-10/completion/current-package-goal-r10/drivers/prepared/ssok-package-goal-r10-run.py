from pathlib import Path
import hashlib,json,os,subprocess,time
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');out=r/'build/ai-loop-evidence/completion/current-package-goal-r10'
b=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/current-package-goal-r10')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert not (out/'run-receipt.json').exists() and not (out/'actor').exists()
sources=json.loads((b/'contract.json').read_text())['source426']
assert len(sources)==426 and all(sha(r/n)==h for n,h in sources.items())
package=json.loads((b/'package-inputs.json').read_text())
app=Path(package['app'])
assert all(sha(app.parent/n)==h for n,h in package['exact_export_and_installer_bytes'].items())
driver=Path('C:/Users/Hojun/Projects/ssok-package-goal-r10-native.ps1')
tools=[driver,Path(__file__),Path('C:/Users/Hojun/Projects/ssok-package-goal-r10-inspect.py'),out/'layout.json',out/'project.json',r/'tools/ci/windows/native_ui.ps1']
saved=b/'native-driver-inputs';saved.mkdir(exist_ok=False)
inputs=[]
for p in tools:
    target=saved/p.name;assert not target.exists();target.write_bytes(p.read_bytes());inputs.append({'path':str(p),'backup':str(target),'sha256':sha(p)})
(b/'native-driver-inputs.json').write_text(json.dumps({'inputs':inputs,'package':package,'source426_unchanged':True},indent=2)+'\n')
command=['powershell.exe','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',str(driver),'-App',str(app),'-Work',str(out),'-Layout',str(out/'layout.json'),'-Python',str(r/'build/venv-native/Scripts/python.exe'),'-Fixture',str(out/'project.json')]
start=time.monotonic();p=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,env=dict(os.environ,PYTHONUTF8='1'),creationflags=subprocess.CREATE_NO_WINDOW);timed_out=False
try:log,_=p.communicate(timeout=415)
except subprocess.TimeoutExpired:
    timed_out=True;subprocess.run(['taskkill.exe','/PID',str(p.pid),'/T','/F'],capture_output=True,timeout=15);log,_=p.communicate(timeout=15)
(out/'driver.log').write_bytes(log)
result={'command':command,'exit_code':p.returncode,'seconds':time.monotonic()-start,'timed_out':timed_out,'source426_unchanged':all(sha(r/n)==h for n,h in sources.items()),'provider_cli_launch_limit':1,'actual_default_packaged_ui':True,'process_local_python_utf8':True,'current_pe_pck_bytes_unchanged':all(sha(app.parent/n)==h for n,h in package['exact_export_and_installer_bytes'].items()),'app_source':package['source'],'version':package['version'],'external_repo_operator':True,'global_goal_complete':False}
(out/'run-receipt.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));print(log.decode('utf-8-sig'))
assert not timed_out and p.returncode==0 and result['source426_unchanged']
