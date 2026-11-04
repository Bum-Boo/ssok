from pathlib import Path
import hashlib,json,os,subprocess,time
repo=Path('C:/Users/Hojun/Projects/ssok-ai-loop')
backup=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/operator-archive-r12')
out=repo/'build/ai-loop-evidence/completion/operator-archive-r12/after'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda d:hashlib.sha256(d).hexdigest()
package=read(backup/'package-receipt.json');contract=read(backup/'contract.json')
root=Path(package['extracted_root']);app=Path(contract['package']['app'])
assert not (out/'run-receipt.json').exists()
assert all(sha((root/n).read_bytes())==h for n,h in package['files'].items())
assert all(sha((app.parent/n).read_bytes())==h for n,h in contract['package']['exact_export_and_installer_bytes'].items())
cmd=['powershell.exe','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',str(repo.parent/'ssok-operator-r12-after-native.ps1'),'-App',str(app),'-Work',str(out),'-Layout',str(out/'layout.json'),'-Python',str(repo/'build/venv-native/Scripts/python.exe'),'-Fixture',str(out/'project.json'),'-OperatorRoot',str(root)]
start=time.monotonic();process=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,env=dict(os.environ,PYTHONUTF8='1'),creationflags=subprocess.CREATE_NO_WINDOW);timeout=False
try:log,_=process.communicate(timeout=415)
except subprocess.TimeoutExpired:
    timeout=True;subprocess.run(['taskkill.exe','/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=15);log,_=process.communicate(timeout=15)
(out/'driver.log').write_bytes(log)
changed=[n for n,h in contract['source426'].items() if sha((repo/n).read_bytes())!=h]
receipt={'exit_code':process.returncode,'seconds':time.monotonic()-start,'timed_out':timeout,'command':cmd,'original_source_changed':changed,'operator_archive_source':package['source_head'],'operator_archive_sha256':package['sha256'],'actual_extracted_root':str(root),'package_files_unchanged':all(sha((root/n).read_bytes())==h for n,h in package['files'].items()),'app_pe_pck_unchanged':all(sha((app.parent/n).read_bytes())==h for n,h in contract['package']['exact_export_and_installer_bytes'].items()),'app_source':contract['package']['source'],'app_version':contract['package']['version'],'global_goal_complete':False}
(out/'run-receipt.json').write_bytes((json.dumps(receipt,ensure_ascii=False,indent=2)+'\n').encode())
print(json.dumps(receipt,ensure_ascii=False));print(log.decode('utf-8-sig'))
assert not timeout and process.returncode==0 and receipt['package_files_unchanged'] and receipt['app_pe_pck_unchanged'] and changed==['tools/app_control/run_goal.py']
