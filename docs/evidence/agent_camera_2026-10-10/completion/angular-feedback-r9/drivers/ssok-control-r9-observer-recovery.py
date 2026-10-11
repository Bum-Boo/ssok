from pathlib import Path
import hashlib
import json

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
out = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/angular-feedback-r9')
original = repo.parent / 'ssok-control-r9-angular.py'
data = original.read_bytes()
source = data.decode('utf8')
start = source.index("assert len(result['frame_samples'])==8")
end = source.index('counts=', start)
replacement = """assert len(result['frame_samples'])==7
samples_by_sha={row['sha256']:row for row in result['frame_samples']}
assert len(samples_by_sha)==7
for frame in result['frames'][1:]:
    sample=samples_by_sha[frame['png_sha256']]
    assert frame['metadata']['physics_tick']==sample['physics_tick']
    frame['angular_pose_sample']=sample
"""
source = source[:start] + replacement + source[end:]
target = repo.parent / 'ssok-control-r9-angular-v2.py'
assert not target.exists()
target.write_bytes(source.encode())
(out / 'ssok-control-r9-angular-v2.py.before-execution').write_bytes(target.read_bytes())
analysis_start = source.index("assert (out/'result.json').exists()")
analysis = """from pathlib import Path
import json,hashlib,sys
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');sys.path.insert(0,str(r))
from tools.app_control.camera_pixels import measure_floor
out=r/'build/ai-loop-evidence/completion/angular-feedback-r9/stock'
read=lambda f:json.loads(f.read_text(encoding='utf-8-sig'))
sha=lambda d:hashlib.sha256(d).hexdigest()
receipt=read(out/'receipt.json')
class Completed:
    returncode=receipt['exit_code']
proc=Completed()
""" + source[analysis_start:]
recovery = repo.parent / 'ssok-control-r9-stock-readback.py'
assert not recovery.exists()
recovery.write_bytes(analysis.encode())
(out / 'observer-recovery.json').write_bytes((json.dumps({'failure': 'Initial capture precedes observer attachment; original native run completed8frames but wrapper incorrectly required8observer callbacks instead of actual7post-initial callbacks.', 'original_retained': str(original), 'original_sha256': hashlib.sha256(data).hexdigest(), 'revised_driver': str(target), 'revised_sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'scope': 'Postprocessing binding only; no change to app, prototype, native fixture, original result/PNG/log/receipt. Exact SHA mapping for all7 observed frames; initial unobserved explicitly excluded.'}, indent=2) + '\n').encode())
print('Prepared postprocessing-only recovery; original failed wrapper retained.')
