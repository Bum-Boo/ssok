from pathlib import Path
from datetime import datetime, timezone, timedelta
import hashlib, json, re, subprocess

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
backup = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/world-wheel-hold-r11')
root = repo / 'build/ai-loop-evidence/completion/world-wheel-hold-r11'
public = repo / 'docs/evidence/agent_camera_2026-10-10/completion/world-wheel-hold-r11'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda b: hashlib.sha256(b).hexdigest()
contract = read(backup / 'contract.json')
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip() == contract['head']
assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo)
assert all(sha((repo / n).read_bytes()) == h for n, h in contract['source426'].items())
camera = read(repo / 'docs/evidence/agent_camera_2026-10-10/completion/verified-r2/unchanged-camera-inputs.json')
assert all(sha((repo / n).read_bytes()) == h for n, h in camera['source_sha256'].items())
goal = repo / 'docs/evidence/agent_camera_2026-10-10/repeated/refined-visual-goal/plan.json'
assert sha(goal.read_bytes()) == contract['frozen_goal_sha256'] == camera['goal_source_sha256']
inspection = read(backup / 'astra-inspection.json')
assert inspection['requested_model'] == 'gpt-6-astra' and len(inspection['viewed']) == 8
public.mkdir(exist_ok=False)
(public / '.gitattributes').write_bytes(b'* -text\n')
rows = []
def copy(path, relative):
    relative = Path(relative)
    assert not set(relative.parts) & {'user-data', 'config', 'appdata', 'localappdata'}
    target = public / relative
    assert not target.exists()
    target.parent.mkdir(parents=True, exist_ok=True)
    data = path.read_bytes(); target.write_bytes(data)
    rows.append({'source': str(path), 'output': relative.as_posix(), 'bytes': len(data), 'sha256': sha(data)})
cases = {}
for name in ['stock', 'world-wheel', 'angular-reference', 'joint-integral']:
    folder = root / name
    receipt = read(folder / 'receipt.json')
    assert receipt['exit_code'] == 0 and not receipt['timed_out'] and receipt['source426_unchanged']
    cases[name] = read(folder / 'summary.json')
    assert cases[name]['combined'] is False
    for file in sorted(folder.iterdir()):
        if file.is_file() and file.suffix in {'.json', '.log', '.png'}:
            copy(file, Path('runtime') / name / file.name)
    for name2 in ['camera-calibration.jsonl', 'camera-evaluation.json']:
        matches = list((folder / 'user-data').glob('Godot/app_userdata/*/' + name2))
        assert len(matches) == 1
        copy(matches[0], Path('runtime') / name / 'developer-evaluator' / name2)
for file in sorted(root.glob('*.gd')):
    copy(file, Path('fixtures') / (file.name + '.txt'))
for name in ['contract.json', 'hypotheses.json', 'inputs.json', 'integral-inputs.json', 'astra-inspection.json']:
    copy(backup / name, Path('provenance') / name)
for name in ['prepare', 'run', 'integral-prepare', 'integral', 'curate']:
    file = repo.parent / ('ssok-control-r11-' + name + '.py')
    copy(file, Path('drivers') / file.name)
for name in camera['source_sha256']:
    copy(repo / name, Path('production-source') / (name.replace('/', '__') + '.txt'))
copy(goal, 'production-source/frozen-goal.json')
viewed = []
for item in inspection['viewed']:
    path = Path(item['path']); row = next(x for x in rows if Path(x['source']) == path)
    assert item['sha256'] == row['sha256']
    viewed.append({'path': str(path), 'public_copy': row['output'], 'dimensions': item['dimensions'], 'sha256': row['sha256']})
stamp = datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')
summary = {'checkpoint': stamp, 'source_head': contract['head'], 'immutable_package_source': 'fa868ca07cdd9d2b8edb27cbab89cd00263c851f', 'package_version': '0.3.1-projects-r7', 'source426_unchanged': True, 'camera10_unchanged': True, 'frozen_goal_sha256': camera['goal_source_sha256'], 'diagnostic_runs': 4, 'comparisons': ['stock to world-wheel: change only PI speed reference', 'angular-reference to joint-integral: same K16 P term; change only integral error'], 'cases': cases, 'png_preserved': 32, 'astra_actual_png_views': 8, 'model_navigation_calls': 0, 'repair_applied': False, 'causation_proved': False, 'global_impossibility_proved': False, 'historical_ai_image': '9/9 unchanged', 'historical_ai_physical': '0/9 unchanged', 'merged': False, 'published': False, 'global_goal_complete': False}
for name, data in [('summary.json', summary), ('viewed-input-hashes.json', viewed), ('copy-manifest.json', {'scope': 'Selected developer-only diagnostics; no private vault content, login, session, auth or raw private CLI transcripts.', 'files': rows})]:
    (public / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
table = '\n'.join('|'+ n +'|'+ '/'.join(str(x) for x in s['floor_pixels']) +'|'+str(s['pixel_span'])+'px|'+f"{s['final_gap_m']*100:.6f}cm"+'|'+('pass' if s['physical'] else 'fail')+'|'+('pass' if s['last_image'] else 'fail')+'|fail|' for n, s in cases.items())
readme = '''# Holding speed reference and angular integral diagnostic r11

''' + stamp + '''; issue32, input HEAD `''' + contract['head'] + '''`. Local diagnostic only.
Immutable app/package **fa868ca / 0.3.1-projects-r7**,426 source inputs, camera10,
frozen raw goal and independent physical thresholds are unchanged. No app repair or AI trial.

Two separate paired comparisons use actual graph motors and rendered camera:

- Stock versus world-wheel changes only PI speed from wheel-minus-housing to wheel world-axis rate.
- K16 angular-reference versus joint-integral retains the same proportional term
  `-8*relative_wheel_rate +16*housing_rate`. Only integral error changes from relative wheel rate
  to `relative_wheel_rate -2*housing_rate`, testing potential integral cancellation.

These are distinct experiments, not one four-case single-variable comparison or a gain sweep.
Each uses P8/I16,25% cap, forward25%, original30/10/12, four30-tick idle/capture intervals,
12stableticks/240timeout and original Stop132ticks. DriveMotor and torque/physics/graph/camera
remain unchanged. No evaluator distance/contact/target-pose inputs or pose/velocity assignments.
The [r8 red loop and minimization limits](../control-feedback-r8/README.md) remain the baseline.
Predictions precede runs in the [original contract and hypotheses](provenance/contract.json).

| Probe | Final five center floor pixels | Span | Final stopped gap | Physical | Final image | Both |
|---|---|---:|---:|---|---|---|
''' + table + '''

[Exact summaries](summary.json) and [original hashes](copy-manifest.json).
All four native runs and wrappers exit0 within19.15–20.88s; this is bounded execution,
not acceptance. Each motor has powered callbacks30/10/12 exactly. Physical pass also requires
valid evaluation/travel≥3cm/gap4–14cm/no contact/positive minimum gap/rest12/Stop.
Every candidate still fails the simultaneous24–38px image and independent physical target.
Signed housing rates remain roughly0.0040–0.0045rad/s. Neither comparison demonstrates
a clear chassis-rate reduction or causal jitter fix. One-pixel span changes in these
single runs cannot establish reliability. All candidates are **rejected and not applied**.

There are eight real640×480 PNGs per run,32 retained; seven post-initial frame_ready
samples per run are bound by exact SHA/tick. Initial PNG precedes observer attachment.
Camera pose assignment and later callback samples remain distinct timing claims.
Astra actually views eight stills (post3/idle4 for each case), with findings in
[its receipt](provenance/astra-inspection.json). Visual estimates and classifier results
remain separate. Stills do not prove continuous jitter, physics, causality or backend identity.

No UI, user strings, localization, provider, package or source426 change. Existing Opus design
review remains applicable. Documentation maintenance and existing document tests accompany
this evidence; app import/fullnative/Web/installer are not rerun, with dated r7 history preserved.
AI image9/9 versus physical0/9 remains unchanged; these developer replays do not update it.

Next Codex: identify the camera/physical boundary and a falsifiable observation-only remedy
before further controller candidates. A separately versioned calibration proposal must keep
this frozen benchmark and requires a product decision before adoption. Operator packaging,
Mac native, Arch originals/formal task release and human merge/versioned publication remain.
Fable performs bounded docs/integration review; human merges. No merge/push/publication.
Canonical records/recovery: C:/Users/Hojun/.agents/backups/ssok-completion-20261010/world-wheel-hold-r11/.
Global objective remains incomplete.
'''
(public / 'README.md').write_text(readme, encoding='utf8')
patterns = [re.compile(rb'sk-[A-Za-z0-9_-]{20,}'), re.compile(rb'Bearer\s+[A-Za-z0-9_-]{20,}'), re.compile(rb'"token"\s*:\s*"[A-Za-z0-9_-]{32,}"')]
hits = [str(p.relative_to(public)) for p in public.rglob('*') if p.is_file() and p.suffix != '.png' and any(q.search(p.read_bytes()) for q in patterns)]
assert not hits
result = {'raw_copies': len(rows), 'images': sum(x['output'].endswith('.png') for x in rows), 'actual_astra_views': 8, 'three_sensitive_shape_hits': hits, 'source426_unchanged': True, 'production_applied': False, 'global_goal_complete': False}
assert result['images'] == 32
(backup / 'curation.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
print(json.dumps(result))
