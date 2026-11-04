from pathlib import Path
from datetime import datetime, timezone, timedelta
import hashlib
import json
import re
import subprocess

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
base = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010')
backup = base / 'angular-feedback-r9'
root = repo / 'build/ai-loop-evidence/completion/angular-feedback-r9'
public = repo / 'docs/evidence/agent_camera_2026-10-10/completion/angular-feedback-r9'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda b: hashlib.sha256(b).hexdigest()
contract = read(backup / 'contract.json')
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip()
assert head == contract['head'] and not subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo)
assert all(sha((repo / n).read_bytes()) == h for n, h in contract['source426'].items())
camera = read(repo / 'docs/evidence/agent_camera_2026-10-10/completion/verified-r2/unchanged-camera-inputs.json')
assert all(sha((repo / n).read_bytes()) == h for n, h in camera['source_sha256'].items())
goal = repo / 'docs/evidence/agent_camera_2026-10-10/repeated/refined-visual-goal/plan.json'
assert sha(goal.read_bytes()) == camera['goal_source_sha256']
inspection = read(backup / 'astra-inspection.json')
assert inspection['requested_model'] == 'gpt-6-astra'
assert len(inspection['viewed']) == 6
public.mkdir(exist_ok=False)
(public / '.gitattributes').write_bytes(b'* -text\n')
rows = []
def copy(path, relative):
    target = public / relative
    assert not target.exists()
    assert not set(Path(relative).parts) & {'user-data', 'config', 'appdata', 'localappdata'}
    target.parent.mkdir(parents=True, exist_ok=True)
    raw = path.read_bytes()
    target.write_bytes(raw)
    rows.append({'source': str(path), 'output': Path(relative).as_posix(), 'bytes': len(raw), 'sha256': sha(raw)})
cases = {}
for label in ['stock', 'angular-k16']:
    directory = root / label
    receipt = read(directory / 'receipt.json')
    assert receipt['exit_code'] == 0 and not receipt['timed_out'] and receipt['source426_unchanged']
    cases[label] = read(directory / 'summary.json')
    for path in sorted(directory.iterdir()):
        if path.is_file() and path.suffix in {'.json', '.log', '.png'}:
            copy(path, Path('runtime') / label / path.name)
    for name in ['camera-calibration.jsonl', 'camera-evaluation.json']:
        matches = list((directory / 'user-data').glob('Godot/app_userdata/*/' + name))
        assert len(matches) == 1
        copy(matches[0], Path('runtime') / label / 'developer-evaluator' / name)
for path in sorted(root.glob('*.gd')):
    copy(path, Path('fixtures') / (path.name + '.txt'))
for name in ['contract.json', 'hypotheses.json', 'inputs.json', 'observer-recovery.json', 'astra-inspection.json', 'stock-readback.before-case-recovery.py']:
    copy(backup / name, Path('provenance') / name)
for path in sorted(backup.glob('*.before-execution')):
    copy(path, Path('provenance') / (path.name + '.txt'))
for name in ['ssok-control-r9-prepare.py', 'ssok-control-r9-angular.py', 'ssok-control-r9-angular-v2.py', 'ssok-control-r9-observer-recovery.py', 'ssok-control-r9-stock-readback.py', 'ssok-control-r9-curate.py']:
    copy(repo.parent / name, Path('drivers') / name)
for name in camera['source_sha256']:
    copy(repo / name, Path('production-source') / (name.replace('/', '__') + '.txt'))
copy(goal, 'production-source/frozen-goal.json')
viewed = []
for item in inspection['viewed']:
    path = Path(item['path'])
    row = next(x for x in rows if Path(x['source']) == path)
    viewed.append({'path': str(path), 'public_copy': row['output'], 'dimensions': item['dimensions'], 'sha256': row['sha256'], 'hash_owner': 'Coordinator; explicit requested Astra selection is not independent backend attestation'})
stamp = datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')
summary = {'checkpoint': stamp, 'source_head': head, 'immutable_package_source': 'fa868ca07cdd9d2b8edb27cbab89cd00263c851f', 'package_version': '0.3.1-projects-r7', 'source426_unchanged': True, 'camera10_unchanged': True, 'frozen_goal_sha256': camera['goal_source_sha256'], 'diagnostic_runs': 2, 'model_navigation_calls': 0, 'cases': cases, 'png_preserved': 16, 'astra_actual_png_views': 6, 'observer_frame_samples_per_run': 7, 'initial_before_observer_attach': True, 'recovery': 'Original stock native8frames/exit0; wrapper8-versus7callback assertion failed. First readback recovery also missed local case variable. Original driver and failed recovery before-copy retained; postprocessing-only recovery uses exact SHA mapping for7post-initial callbacks, all8PNGs retained; no native rerun or original bytes changed.', 'repair_applied': False, 'causation_proved': False, 'global_impossibility_proved': False, 'historical_ai_image': '9/9 unchanged', 'historical_ai_physical': '0/9 unchanged', 'merged': False, 'published': False, 'global_goal_complete': False}
for name, value in [('summary.json', summary), ('viewed-input-hashes.json', viewed), ('copy-manifest.json', {'scope': 'Exact selected developer runtime/debug/source copies; no private briefs/auth/user/config/session data. Evaluator files specifically extracted from isolated developer user directories.', 'files': rows})]:
    (public / name).write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode())
readme = '''# Motor-only chassis angular feedback diagnostic r9

''' + stamp + '''; issue32, source HEAD `''' + head + '''`, local diagnostic only.
App input426, camera10, goal and immutable **fa868ca / 0.3.1-projects-r7** remain unchanged.
No app repair, model-navigation call, merge or publication. The global ssok goal is incomplete.

The [r8 original red signal](../control-feedback-r8/README.md) remains simultaneous image24–38px
and independent valid/travel≥3cm/gap4–14cm/no contact/positive minimum gap/rest12ticks/Stop.
Three [ranked falsifiable predictions](provenance/hypotheses.json) precede these probes.
The same actual rendered30/10/12, four30-tick idle/capture intervals and original Stop132ticks
run once stock and once with only a per-instance angular feedback term K0→16 added to holding.
Both use identical read-only observers. P8/I16,25% duty cap, fixed forward25%,12stableticks,
240timeout and original DriveMotor callback/physical torque limits are unchanged. The added term
reads only existing housing angular velocity along the graph motor axis; no distance/contact
or target pose is control/actor input, and no transforms/velocities are assigned.

| Probe | Final five pixels | Span | Final stopped gap | Physical | Final image | Both |
|---|---|---:|---:|---|---|---|
|stock|23/25/27/23/23|4px|14.106308cm|fail|fail|fail|
|K16|22/24/21/22/21|3px|13.850644cm|pass|fail|fail|

[Exact summaries](summary.json), [original runtime/PNG/source hashes](copy-manifest.json).
Native stock19.356s and K16 19.051s both exit0; this means bounded diagnostic completion,
not acceptance. Every motor has actual powered callbacks30/10/12. Last five signed housing-axis
rates remain about0.0040–0.0044rad/s in both runs. K16 does not clearly reduce that rate; one-pixel
span reduction in one run is insufficient evidence of a jitter fix. Stop gap reduction changes
from0.930mm to2.018mm. The candidate is **not applied** and its causal hypothesis is unproved.

The observer records actual assigned camera transform and later `frame_ready` chassis pose.
In these final five samples, inferred chassis pitch from the assigned camera and callback
matches to floating precision (≤9.4e-10rad). This does not establish every frame/provider/render
stage has identical timing or exclude all timing effects. Seven SHA/tick-matched post-initial
callbacks per run are observed; the initial image precedes observer attachment and is explicitly
unobserved for this pitch/rate sampler. All eight real PNGs in each run are retained.

The original stock wrapper incorrectly asserted eight observer callbacks instead of seven.
Its native run completed normally, but whole wrapper exit1 is retained. A first postprocessing
recovery then had a missing local `case` variable and failed. The failed script before-copy and
original driver are preserved; a postprocessing-only recovery reads original files and matches
callbacks by SHA, without rerunning native or changing original result/PNG/log/receipt. The K16
wrapper uses that corrected binding. This is a tool recovery, not an app fix.

Astra actually viewed six original640×480 PNGs, stock/K16 post3/idle2/idle4.
[Actual findings](provenance/astra-inspection.json), [coordinator-bound hashes](viewed-input-hashes.json).
Visual estimates and exact classifier outputs stay separate; screenshots alone do not prove
physical distance, cause, motion rates, broad reliability or backend identity.

No user text, localization, layout, style, provider, physical solver, camera or package changed.
App import/fullnative/Web/installer are not rerun for this docs/evidence follow-up; r7 gates
remain dated history. Documentation maintenance/10unit/ZIP1 checks accompany this new evidence.
FLOWS/API/ADR0029/CONTROLS/data/storage behavior is unchanged. Existing Opus UI review is preserved.

Next Codex: current r7 actual Run-with-AI/operator end-to-end, and a separately scoped control
or calibration decision supported by evidence. Further uncontrolled gain sweeps are not a fix.
Frozen AI image9/9 versus physical0/9 and r8 deterministic13tick3/3physical/0/3image remain
separate. Mac native, Arch originals/formal task CLI release, human merge and exact-version
publication approval are pending. Claude Fable reviews the bounded docs integration; human merges.
Canonical existing project records/Now/readback/recovery receipts are under
`C:/Users/Hojun/.agents/backups/ssok-completion-20261010/angular-feedback-r9/` outside this commit.
'''
(public / 'README.md').write_bytes(readme.encode())
patterns = [re.compile(rb'sk-[A-Za-z0-9_-]{20,}'), re.compile(rb'Bearer\s+[A-Za-z0-9_-]{20,}'), re.compile(rb'"token"\s*:\s*"[A-Za-z0-9_-]{32,}"')]
hits = [str(path.relative_to(public)) for path in public.rglob('*') if path.is_file() and path.suffix != '.png' and any(pattern.search(path.read_bytes()) for pattern in patterns)]
assert not hits
result = {'raw_copies': len(rows), 'images': sum(row['output'].endswith('.png') for row in rows), 'actual_astra_views': 6, 'three_sensitive_shape_hits': hits, 'public_directory': str(public), 'source426_unchanged': True, 'global_goal_complete': False}
assert result['images'] == 16
(backup / 'curation.json').write_bytes((json.dumps(result, indent=2) + '\n').encode())
print(json.dumps(result), flush=True)
