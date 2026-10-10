from pathlib import Path
import hashlib,json,os,subprocess,sys
repo=Path('C:/Users/Hojun/Projects/ssok-ai-loop');backup=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/operator-archive-r12')
read=lambda p:json.loads(p.read_text(encoding='utf8'));package=read(backup/'package-receipt.json');root=Path(package['extracted_root'])
checks=[]
environment=dict(os.environ);environment['PATH']='';environment.pop('PYTHONPATH',None)
result=subprocess.run([sys.executable,'-X','utf8','-c','from pathlib import Path;from tools.app_control.source_identity import source_head;print(source_head(Path.cwd()))'],cwd=root,env=environment,capture_output=True,timeout=15)
assert result.returncode==0 and result.stdout.decode().strip()==package['source_head']
checks.append({'name':'Archive identity works with no Git executable on PATH','passed':True})
environment=dict(os.environ);environment.pop('SSOK_AGENT_TOKEN',None)
result=subprocess.run(['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(root/'tools/app_control/start-operator.ps1'),'-Out',str(backup/'must-not-create')],cwd=repo,env=environment,capture_output=True,timeout=15)
(backup/'launcher-no-token.stdout').write_bytes(result.stdout);(backup/'launcher-no-token.stderr').write_bytes(result.stderr)
assert result.returncode!=0 and not (backup/'must-not-create').exists()
checks.append({'name':'Foreground launcher without token refuses before app/model launch','passed':True})
guard=repo/'.operator-package-guard-r12';archive=repo/'build/operator-guard-must-not-create.zip'
assert not guard.exists() and not archive.exists() and guard.resolve().parent==repo.resolve()
try:
    guard.write_bytes(b'Owned temporary package guard fixture.\n')
    result=subprocess.run([sys.executable,'-X','utf8','-m','tools.ci.operator_package','--out',str(archive)],cwd=repo,capture_output=True,timeout=15)
    assert result.returncode!=0 and b'Commit operator inputs' in result.stderr and not archive.exists()
finally:
    assert guard.read_bytes()==b'Owned temporary package guard fixture.\n';guard.unlink()
checks.append({'name':'Actual dirty checkout refuses release archive','passed':True})
assert not subprocess.check_output(['git','status','--porcelain'],cwd=repo)
repeat=repo/'build/ssok-0.1.0-operator-r12-determinism.zip';assert not repeat.exists()
result=subprocess.run([sys.executable,'-X','utf8','-m','tools.ci.operator_package','--out',str(repeat)],cwd=repo,capture_output=True,timeout=15)
assert result.returncode==0 and hashlib.sha256(repeat.read_bytes()).hexdigest()==package['sha256']
checks.append({'name':'Second clean package has byte-identical ZIP hash','passed':True})
(backup/'archive-checks.json').write_bytes((json.dumps({'checks':checks,'passed':len(checks),'failed':0,'provider_calls':0},indent=2)+'\n').encode())
print(json.dumps({'passed':len(checks),'failed':0,'provider_calls':0}))
