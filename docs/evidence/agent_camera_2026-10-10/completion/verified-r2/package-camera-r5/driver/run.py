from pathlib import Path
import hashlib,json,subprocess,sys,time
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');out=r/'build/ai-loop-evidence/completion/package-camera-r5'
root_out=out
assert len(sys.argv)==2 and sys.argv[1] in ['corrected-native','final-native','final-native-focus-retry']
if sys.argv[1]=='final-native-focus-retry':
    prior=json.loads((root_out/'final-native/run-receipt.json').read_text())
    assert prior['exit_code']==1 and not prior['timed_out']
    assert b'Task app cannot acquire foreground; refusing input' in (root_out/'final-native/driver.log').read_bytes()
out=root_out/sys.argv[1];out.mkdir(exist_ok=False)
sources=json.loads((r/'build/ai-loop-evidence/completion/full-native-final-r2/source-before.json').read_text())['files']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert len(sources)==426 and all(sha(r/n)==h for n,h in sources.items())
assert not (out/'run-receipt.json').exists()
app=json.loads((root_out/'package-inputs.json').read_text())['app']
command=['powershell.exe','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File','C:/Users/Hojun/Projects/ssok-package-camera-r5-native.ps1','-App',app,'-Work',str(out),'-Layout',str(root_out/'layout-native-corrected.json'),'-Python',sys.executable,'-Fixture',str(root_out/'project.json')]
started=time.monotonic();process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
timed_out=False
try:log,_=process.communicate(timeout=120)
except subprocess.TimeoutExpired:
    timed_out=True;subprocess.run(['taskkill.exe','/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=15);log,_=process.communicate(timeout=15)
(out/'driver.log').write_bytes(log)
result={'command':command,'exit_code':process.returncode,'seconds':time.monotonic()-started,'timed_out':timed_out,'source426_unchanged':all(sha(r/n)==h for n,h in sources.items()),'provider_calls':0,'actual_default_packaged_ui':True,'app_source':'f31f8d5ea7b6b3eaa48df9e6d50f60621eb3dfa4','global_goal_complete':False}
(out/'run-receipt.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result));print(log.decode('utf-8-sig'))
assert not timed_out and process.returncode==0 and result['source426_unchanged']
