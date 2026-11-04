from pathlib import Path
import hashlib, json, subprocess, sys

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
backup = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/attitude-gain-r15')
root = repo/'build/ai-loop-evidence/completion/attitude-gain-r15'
read = lambda p: json.loads(p.read_text(encoding='utf8'))
sha = lambda b: hashlib.sha256(b).hexdigest()
case = sys.argv[1]; assert case in {'k32','k64','n16'}
stock = read(root/'stock/summary.json')
assert not stock['combined'] and stock['floor_pixels'] == [23,25,27,23,23]
contract = read(backup/'contract.json')
assert all(sha((repo/n).read_bytes()) == h for n,h in (contract['source426']|contract['extra_operator7']).items())
if case == 'k64':
    previous = read(root/'k32/summary.json')
    assert not previous['combined'] and not read(root/'k32/receipt.json')['timed_out']
if case == 'n16':
    assert all(not read(root/p/'summary.json')['combined'] and read(root/p/'summary.json')['pixel_span'] >= stock['pixel_span'] for p in ['k32','k64'])
hypotheses = [
    {'rank':1,'prediction':'If attitude holding is too weak, coefficient32 should lower pixel span and signed housing-axis body rates; coefficient64 is considered only if32 settles normally but still fails the joint target.'},
    {'rank':2,'prediction':'If the sign is counterproductive, stronger positive gains should not improve the same signal; negative16 is a bounded sign control only after positive32/64 both fail without span reduction.'},
    {'rank':3,'prediction':'If contact/joint and post-Stop dynamics dominate, coefficients may shift single pixels/gap but not reduce jitter or satisfy the unchanged joint goal; reject rather than relax criteria.'}
]
if not (backup/'hypotheses.json').exists():
    (backup/'hypotheses.json').write_bytes((json.dumps(hypotheses,indent=2)+'\n').encode())
gain = {'k32':32,'k64':64,'n16':-16}[case]
template = repo/'build/ai-loop-evidence/completion/attitude-hold-r13/attitude_loop.gd'
text = template.read_text(encoding='utf8')
assert 'func cancel(reason: String = "local_stop")' in text and text.count('error_vector.dot(axis) * 16.0') == 1
text = text.replace('DEBUG-r13','DEBUG-r15').replace('error_vector.dot(axis) * 16.0','error_vector.dot(axis) * '+str(gain)+'.0')
target = root/('attitude-'+case+'.gd'); assert not target.exists(); target.write_bytes(text.encode())
command = [str(repo/'build/toolchain-windows/Godot_v4.7.2-stable_win64_console.exe'),'--headless','--path',str(repo),'--script',target.relative_to(repo).as_posix(),'--check-only']
result = subprocess.run(command,cwd=repo,capture_output=True,timeout=30)
record = {'case':case,'coefficient':gain,'prototype_sha256':sha(target.read_bytes()),'template_sha256':sha(template.read_bytes()),'only_feedback_coefficient_changed':True,'command':command,'exit_code':result.returncode}
(backup/(case+'-preflight.log')).write_bytes(result.stdout+result.stderr)
(backup/(case+'-inputs.json')).write_bytes((json.dumps(record,indent=2)+'\n').encode())
assert result.returncode == 0, result.stderr
print(json.dumps(record))
