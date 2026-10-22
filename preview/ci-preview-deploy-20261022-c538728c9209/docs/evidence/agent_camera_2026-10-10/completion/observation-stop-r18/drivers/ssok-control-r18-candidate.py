from pathlib import Path
import hashlib,json,subprocess

repo=Path('C:/Users/Hojun/Projects/ssok-ai-loop')
backup=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/observation-stop-r18')
root=repo/'build/ai-loop-evidence/completion/observation-stop-r18'
read=lambda p:json.loads(p.read_text(encoding='utf8'));sha=lambda b:hashlib.sha256(b).hexdigest()
baseline=read(root/'k32-v3/summary.json');assert not baseline['combined'] and baseline['last_image'] and not baseline['physical']
assert read(root/'k32-v3/receipt.json')['exit_code']==0
contract=read(backup/'contract.json');assert all(sha((repo/n).read_bytes())==h for n,h in (contract['source426']|contract['extra_operator7']).items())
hypotheses=[{'rank':1,'prediction':'If the existing brake-entry32/rate16 candidate can meet the original target at its earlier observation endpoint, the fixed idle1 checkpoint followed by actual bridge observe/context-bound Stop should yield last image24..38 AND independent final physical4..14cm/travel/contact/rest/stopped.'},{'rank':2,'prediction':'If the extra actual bridge observation or latency changes the pose, the final image may already be below24 even when earlier developer idle1 had24; retain it as jointFAIL rather than choosing an earlier image.'},{'rank':3,'prediction':'If post-Stop release dominates, the final independent gap/rest may fail despite a passing actual bridge image; retain paired frame-to-Stop displacement and reject instead of using camera-time distance.'}]
(backup/'hypotheses.json').write_bytes((json.dumps(hypotheses,indent=2)+'\n').encode())
source=repo/'build/ai-loop-evidence/completion/attitude-latch-r17/combo16/attitude-brake.gd'
target=root/'attitude-combined.gd';assert not target.exists();target.write_bytes(source.read_bytes())
cmd=[str(repo/'build/toolchain-windows/Godot_v4.7.2-stable_win64_console.exe'),'--headless','--path',str(repo),'--script',target.relative_to(repo).as_posix(),'--check-only']
result=subprocess.run(cmd,cwd=repo,capture_output=True,timeout=30)
(backup/'candidate-preflight.log').write_bytes(result.stdout+result.stderr)
(backup/'candidate-inputs.json').write_bytes((json.dumps({'original_r17_source':str(source),'original_sha256':sha(source.read_bytes()),'candidate_sha256':sha(target.read_bytes()),'candidate_control_bytes_identical_to_r17':True,'endpoint_change_only':'Fixed idle1 -> actual DesktopClient observe -> context-bound Stop ->132frames evaluation','command':cmd,'exit_code':result.returncode,'production_applied':False,'model_calls':0},indent=2)+'\n').encode())
assert result.returncode==0
print(json.dumps({'candidate_control_bytes_unchanged_from_r17':True,'preflight_exit':0,'production_applied':False}))
