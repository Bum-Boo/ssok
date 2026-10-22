from pathlib import Path
import hashlib, json, subprocess, sys

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
root = repo/'build/ai-loop-evidence/completion/attitude-latch-r17'
backup = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/attitude-latch-r17')
case = sys.argv[1]; assert case in {'k32','prior','brake'}
if '--existing' not in sys.argv:
    result = subprocess.run([sys.executable,'-X','utf8',str(repo.parent/'ssok-control-r17-run.py'),case],cwd=repo)
    if result.returncode != 0:
        raise SystemExit(result.returncode)
read = lambda p: json.loads(p.read_text(encoding='utf8'))
sha = lambda b: hashlib.sha256(b).hexdigest()
contract = read(backup/'contract.json')
assert all(sha((repo/n).read_bytes()) == h for n,h in (contract['source426']|contract['extra_operator7']).items())
plan = read(root/case/'plan.json')
assert all(sha((root/n).read_bytes()) == h for n,h in plan['fixture_sha256'].items())
summary = read(root/case/'summary.json')
record = {'case':case,'target':'Original image24..38px AND independent physical4..14cm/travel/contact/rest/Stop','passed':summary['combined'],'physical':summary['physical'],'image':summary['last_image'],'final_gap_m':summary['final_gap_m'],'last_floor_pixels':summary['floor_pixels'][-1],'source_inputs_unchanged':True,'model_calls':0,'production_applied':False}
(root/case/'target-check.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(record))
raise SystemExit(0 if record['passed'] else 1)
