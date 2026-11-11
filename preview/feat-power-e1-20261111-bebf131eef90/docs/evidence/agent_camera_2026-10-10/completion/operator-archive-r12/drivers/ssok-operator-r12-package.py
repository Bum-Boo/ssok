from pathlib import Path
import ast, hashlib, json, os, subprocess, sys, zipfile

repo=Path('C:/Users/Hojun/Projects/ssok-ai-loop')
backup=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/operator-archive-r12')
out=repo/'build/ai-loop-evidence/completion/operator-archive-r12'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda b:hashlib.sha256(b).hexdigest()
contract=read(backup/'contract.json')
changed=[name for name,digest in contract['source426'].items() if sha((repo/name).read_bytes())!=digest]
assert changed==['tools/app_control/run_goal.py'],changed
old=(Path(contract['baseline_operator_root'])/'tools/app_control/run_goal.py').read_text(encoding='utf8')
new=(repo/'tools/app_control/run_goal.py').read_text(encoding='utf8')
def actor(text):
    for node in ast.walk(ast.parse(text)):
        if isinstance(node,ast.Call) and isinstance(node.func,ast.Attribute) and node.func.attr=='write_text' and node.args:
            try:value=ast.literal_eval(node.args[0])
            except (ValueError,TypeError):continue
            if isinstance(value,str) and value.startswith('You are a bounded robot-camera operator.'):return value
    raise AssertionError('Actor text not found')
assert actor(old)==actor(new)
for name in ['codex_command','end_process']:
    nodes=lambda text:[ast.dump(n,include_attributes=False) for n in ast.parse(text).body if isinstance(n,ast.FunctionDef) and n.name==name]
    assert nodes(old)==nodes(new),name
assert all(sha((repo/name).read_bytes())==digest for name,digest in contract['baseline_operator_files'].items() if not name.endswith('/run_goal.py'))
proof={'original_inputs':426,'unchanged_original_inputs':425,'changed_original_inputs':changed,'actor_text_sha256':sha(actor(new).encode()),'actor_text_unchanged':True,'codex_command_and_process_cancellation_ast_unchanged':True,'other_five_operator_modules_unchanged':True,'godot_app_source':contract['package']['source'],'global_goal_complete':False}
(backup/'implementation-proof.json').write_bytes((json.dumps(proof,indent=2)+'\n').encode())
files=['tools/app_control/run_goal.py','tools/app_control/source_identity.py','tools/app_control/start-operator.ps1','tools/app_control/OPERATOR.md','tools/ci/operator_package.py','tests/test_operator_release.py','docs/BUILD.md','docs/adr/0029-rendered-desktop-agent-camera-loop.md']
subprocess.run(['git','add','--',*files],cwd=repo,check=True)
subprocess.run(['git','-c','core.whitespace=cr-at-eol','diff','--cached','--check'],cwd=repo,check=True)
subprocess.run(['git','-c','user.name=Bum-Boo','-c','user.email=bumboo500y@gmail.com','commit','-m','Package the foreground camera operator without Git\n\nAgent: codex'],cwd=repo,check=True,capture_output=True)
assert not subprocess.check_output(['git','status','--porcelain'],cwd=repo)
archive=repo/'build/ssok-0.1.0-operator-r12.zip'
process=subprocess.run([sys.executable,'-X','utf8','-m','tools.ci.operator_package','--out',str(archive)],cwd=repo,capture_output=True,timeout=30)
(backup/'package.stdout').write_bytes(process.stdout);(backup/'package.stderr').write_bytes(process.stderr)
assert process.returncode==0,process.stderr.decode()
receipt=json.loads(process.stdout)
root=repo.parent/'ssok operator r12'/'별도 도구';assert not root.exists()
root.mkdir(parents=True)
with zipfile.ZipFile(archive) as package:
    assert set(package.namelist())==set(receipt['files']) and len(package.namelist())==12
    for name in package.namelist():
        assert (root/name).resolve().is_relative_to(root.resolve())
    package.extractall(root)
assert all(sha((root/name).read_bytes())==digest for name,digest in receipt['files'].items())
git=subprocess.run(['git','rev-parse','HEAD'],cwd=root,capture_output=True,timeout=15)
assert git.returncode!=0
receipt.update({'extracted_root':str(root),'actual_git_free_probe_exit':git.returncode,'entries':12,'extracted_all_hashes_match':True,'clean_source':True,'app_not_bundled':True,'python_cli_login_external':True})
(backup/'package-receipt.json').write_bytes((json.dumps(receipt,ensure_ascii=False,indent=2)+'\n').encode())
for name in ['layout.json','project.json']:
    target=out/'after'/name;target.parent.mkdir(exist_ok=True);target.write_bytes((out/'before'/name).read_bytes())
inspect=repo.parent/'ssok-operator-r12-after-inspect.py';assert not inspect.exists()
source=(repo.parent/'ssok-package-goal-r10-inspect.py').read_text(encoding='utf8').replace('completion/current-package-goal-r10','completion/operator-archive-r12/after')
source=source.replace("'account_login_packaged':False", "'account_login_packaged':False,'operator_archive_git_independent':True")
inspect.write_bytes(source.encode())
native=repo.parent/'ssok-operator-r12-after-native.ps1';assert not native.exists()
source=(repo.parent/'ssok-operator-r12-before-native.ps1').read_text(encoding='utf8').replace('ssok-operator-r12-before-inspect.py','ssok-operator-r12-after-inspect.py')
source=source.replace("Check ($operatorProcess.ExitCode -ne 0) 'Detached operator reproduces pre-dispatch Git failure'", "Check ($operatorProcess.ExitCode -eq 0) 'Extracted operator performs actual AI goal and exits successfully'")
line=next(line for line in source.splitlines() if '$operatorProcess=Start-Process -FilePath $Python' in line)
replacement="    $Launcher = Join-Path $OperatorRoot 'tools/app_control/start-operator.ps1'\n    $operatorProcess=Start-Process -FilePath 'powershell.exe' -WorkingDirectory 'C:/Users/Hojun/Projects/ssok-ai-loop' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"+'"'+"'+$Launcher+'"+'"'+"'),'-Python',$Python,'-Out',(Join-Path $Work 'actor'),'-Seconds','60') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $Work 'operator.stdout') -RedirectStandardError (Join-Path $Work 'operator.stderr')"
assert source.count(line)==1;source=source.replace(line,replacement)
native.write_bytes(source.encode())
inputs={str(p):sha(p.read_bytes()) for p in [inspect,native,Path(__file__),out/'after/layout.json',out/'after/project.json']}
(backup/'after-driver-inputs.json').write_bytes((json.dumps(inputs,indent=2)+'\n').encode())
print(json.dumps({'head':receipt['source_head'],'archive_sha256':receipt['sha256'],'git_free_exit':git.returncode,'entries':12,'source_changed':changed,'actor_unchanged':True,'prepared_actual_after':True},ensure_ascii=False))
