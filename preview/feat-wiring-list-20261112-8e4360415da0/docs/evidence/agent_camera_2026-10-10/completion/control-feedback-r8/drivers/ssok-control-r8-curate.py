from pathlib import Path
from datetime import datetime,timezone,timedelta
import hashlib,json,re,subprocess
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');base=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010');b=base/'control-feedback-r8';root=r/'build/ai-loop-evidence/completion/control-feedback-r8';p=r/'docs/evidence/agent_camera_2026-10-10/completion/control-feedback-r8'
read=lambda f:json.loads(f.read_text(encoding='utf-8-sig'));sha=lambda d:hashlib.sha256(d).hexdigest();git=lambda *a:subprocess.check_output(['git',*a],cwd=r).decode('utf8').strip()
head=git('rev-parse','HEAD');assert head=='dd9c81494487e20e145e2ab9502daf1a36974770' and not git('status','--porcelain');inputs=read(b/'contract.json')['source426'];assert len(inputs)==426 and all(sha((r/n).read_bytes())==h for n,h in inputs.items())
camera=read(r/'docs/evidence/agent_camera_2026-10-10/completion/verified-r2/unchanged-camera-inputs.json');assert all(sha((r/n).read_bytes())==h for n,h in camera['source_sha256'].items());goal=r/'docs/evidence/agent_camera_2026-10-10/repeated/refined-visual-goal/plan.json';assert sha(goal.read_bytes())==camera['goal_source_sha256']
stamp=datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds');p.mkdir(exist_ok=False);(p/'.gitattributes').write_bytes(b'* -text\n');rows=[]
def copy(f,rel):
    f=Path(f);rel=Path(rel);assert not set(rel.parts)&{'user-data','config','appdata','localappdata'};out=p/rel;assert not out.exists();out.parent.mkdir(parents=True,exist_ok=True);data=f.read_bytes();out.write_bytes(data);assert out.read_bytes()==data;rows.append({'source':str(f),'output':rel.as_posix(),'bytes':len(data),'sha256':sha(data)})
def bounded(directory,target):
    for f in sorted(directory.iterdir()):
        if f.is_file() and f.suffix in {'.json','.jsonl','.log','.png'}:copy(f,Path(target)/f.name)
    for n in ['camera-calibration.jsonl','camera-evaluation.json']:
        matches=list((directory/'user-data').glob('Godot/app_userdata/*/'+n))
        assert len(matches)<=1
        for f in matches:copy(f,Path(target)/'developer-evaluator'/n)
cases={}
for label in ['baseline','repeat','minimal-two-step']:
    directory=r/('build/ai-loop-evidence/completion/control-feedback-r8-'+label);bounded(directory,Path('runtime/replay')/label);subdir=next(f for f in directory.iterdir() if f.is_dir() and f.name.startswith('replay-near-'));bounded(subdir,Path('runtime/replay')/label/subdir.name);cases[label]=read(directory/'combined-check.json')
labels=['stock','strict-angle','action-brake','action-forward','tick-trace','motor-callback-trace','damping-p24','damping-p4','partition-13-a','partition-13-b','partition-13-c']
for label in labels:
    directory=root/label;bounded(directory,Path('runtime/direct')/label);receipt=read(directory/'receipt.json');assert receipt['source426_unchanged'] and not receipt['timed_out'];result=read(directory/'result.json');cases[label]=read(directory/'summary.json') if (directory/'summary.json').exists() else {'failure':result['failure'],'failure_state':result['failure_state'],'ownership_revoked':result['stop_confirmed'],'native_exit_code':receipt['exit_code'],'physical_result_unavailable':True}
for f in sorted(root.iterdir()):
    if f.is_file() and f.suffix=='.gd':copy(f,Path('fixtures')/(f.name+'.txt'))
for f in sorted(b.iterdir()):
    if f.is_file() and (f.suffix=='.json' or 'before-execution' in f.name):copy(f,Path('provenance')/(f.name+'.txt' if f.suffix=='.gd' else f.name))
for n in ['ssok-camera-gap-replay-r8.py','ssok-camera-gap-minimal-r8.py','ssok-control-r8-prototype.py','ssok-control-r8-action.py','ssok-control-r8-ticks.py','ssok-control-r8-callback.py','ssok-control-r8-damping.py','ssok-control-r8-lower-damping.py','ssok-control-r8-calibration.py','ssok-control-r8-pairs.py','ssok-control-r8-curate.py']:
    copy(r.parent/n,Path('drivers')/n)
for n in camera['source_sha256']:
    copy(r/n,Path('production-source')/(n.replace('/','__')+'.txt'))
copy(goal,'production-source/frozen-goal.json')
callback=read(root/'motor-callback-trace/result.json');counts=[]
for i,c in enumerate(callback['commands']):
    actual=[sum(row['command_index']==i and abs(row['applied_duty']-.25)<1e-8 for row in motor) for motor in callback['actual_motor_callbacks']];assert actual==[c['ticks'],c['ticks']];counts.append({'requested_ticks':c['ticks'],'actual_powered_callbacks_per_motor':actual})
astra=[]
for n in ['astra-repro-inspection.json','astra-partition-inspection.json']:
    report=read(b/n);assert report['requested_model']=='gpt-6-astra'
    for viewed in report['viewed']:
        f=Path(viewed['path']);match=next(row for row in rows if row['source']==str(f));astra.append({'report':n,'actual_viewed_path':str(f),'public_copy':match['output'],'dimensions':viewed['dimensions'],'sha256':match['sha256'],'hash_owner':'Coordinator; model/backend identity not independently attested'})
assert len(astra)==12
def generated(name,value):(p/name).write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode())
generated('viewed-input-hashes.json',astra)
summary={'checkpoint':stamp,'source_head':head,'immutable_package_source':'fa868ca07cdd9d2b8edb27cbab89cd00263c851f','package_version':'0.3.1-projects-r7','source426_unchanged':True,'camera10_unchanged':True,'frozen_goal_sha256':camera['goal_source_sha256'],'diagnostic_runs':14,'model_navigation_calls':0,'cases':cases,'actual_motor_counts':counts,'astra_actual_png_views':12,'astra_classifier_disagreement':'partition-13-a/idle-4 visual16±1 vs classifier18px; both fail24px, exact visual estimate disagreement retained','repair_applied':False,'historical_ai_nominal_image':'9/9 unchanged','historical_ai_strict_physical':'0/9 unchanged','new_partition13_deterministic_replays':{'fresh_runs':3,'physical_passes':3,'image_passes':0,'combined_passes':0,'same_fixture_only':True},'causation_proved':False,'global_impossibility_proved':False,'merged':False,'published':False,'global_goal_complete':False}
generated('summary.json',summary);generated('copy-manifest.json',{'scope':'Exact developer runtime/source/debug-fixture copies; source10 and frozen goal are unchanged. Only specifically named developer evaluator files are extracted from isolated user directories. No credentials, private briefs, user projects, account/config/session or original clipboard data.','files':rows})
readme=f'''# Camera/physical boundary diagnosis r8

{stamp}; issue32, `feat/32-robot-camera-loop`, source HEAD `{head}`.
Current426 inputs, camera10 and frozen goal are unchanged. Immutable reviewed package
fa868ca / **0.3.1-projects-r7** and its [r7 gates](../release-current-ui-r7/README.md) remain
separate. This follow-up applies **no app repair**, performs no model-navigation call,
and does not merge or publish. The global ssok objective is incomplete.

The actual user goal is a reliable camera/action loop. The bounded bug signal combines
the unchanged nominal image goal24–38px with the complete independent physical criterion:
valid geometry, forward travel≥3cm, final support gap4–14cm inclusive, no wall contact,
positive minimum gap, rest≥12ticks and stopped state. Neither side alone is success.
The [ranked hypotheses](provenance/hypotheses.json) were recorded before probes/source theory.

Original rendered TCP/calibrator30/10/12 was freshly reproduced twice:

| Replay | Final nominal pixels | Final stopped gap | Image | Physical | Combined |
|---|---:|---:|---|---|---|
| baseline |25|14.0000701cm|pass|fail|fail|
| repeat |23|13.9928192cm|fail|pass|fail|
| reduced30/22 |1|12.6100540cm|fail|pass|fail|

[Receipts/raw output](copy-manifest.json), [case summary](summary.json).
The baseline excess is0.7µm and still fails the unchanged strict limit. Combined failure
reproduced2/2; the individual failed subcriterion changes. Removing one intermediate
capture/settle while preserving52total forward ticks does not preserve the near-boundary
symptom: three action partitions are load-bearing for that replay. Minimization is limited
to these actual cuts, not proof that every remaining item was independently eliminated.

SHA/tick pairing uses the actual `frame_ready` evaluator callback. Camera pose is assigned
at `capture_requested_tick`, which may precede that callback: this pairing does not prove
image pose equals callback physics. [Aligned comparisons](provenance/capture-comparison.json).
Original final captures already exceed14cm; Stop moves closer by1.0014/1.4068mm in the
two original replays. Stop alone is therefore not sufficient cause for their excess gap.

Direct in-process/frame-counted stock (no TCP) still has final five floor heights
23/25/27/23/23px, gap span0.9587mm and nonzero angular rates. Eliminating external transport
does not remove variation; it does not prove transport never contributes.

Two one-gain developer interventions and one admission intervention were rejected:
angular gate0.1→0.003rad/s fails initial settling within240ticks; P8→24 with I16 unchanged
fails after the first forward30; P8→4 completes but still has4px variation and final
14.1215cm physical failure. No candidate was applied. Fault receipts prove ownership
revocation/native exit, not an independently evaluated physical stop for those failed probes.
Body/camera transforms, velocities, motor physics/torque, independent criteria and frozen
goal never change. Per-instance scripts are retained solely as labeled debug fixtures.

Adding allowed brake1 or forward1 as a fourth partition also fails combined acceptance.
An initial post-controller duty sampler appears to show N−1 active outputs. That is a
measurement seam error: the final command is already braked when the sampler reads duty,
although its motor impulse was applied earlier. An exact callback wrapper delegates to the
unchanged production `DriveMotor._physics_process` and observes **30/10/12/1 powered
callbacks for each motor**, matching the requests. All motor parameters/state are preserved.
[Actual callback rows](runtime/direct/motor-callback-trace/result.json),
[observer source](fixtures/motor_callback.gd.txt). Original misleading post-controller trace
is retained; no off-by-one controller repair is warranted.

Increasing the last original partition12→13 (30/10/13), without changing controller or goal,
has three fresh deterministic replays: each13.800904cm and final18px, with final five
19/21/22/20/18px. **Physical3/3, image0/3, combined0/3** applies only to this exact diagnostic
fixture; no AI reliability score or global impossibility follows. Moving one tick within
an existing partition differs from adding a new one-tick partition/capture/settle.

Astra actually inspected12 original640×480 PNGs across two bounded reports. The center
strip is unobstructed, original near-boundary and reduced/tick13 images visibly below the
goal. [First six](provenance/astra-repro-inspection.json),
[stock/partition13 six](provenance/astra-partition-inspection.json),
[coordinator hashes](viewed-input-hashes.json). Visual estimates are separate from the
fixed classifier; partition13 idle4 has16±1px versus classifier18px, retained disagreement.
Both fail24px. Still inspection does not establish distance, causation or backend identity.

No new strings, localization, layout, style, physics, provider or app input changed.
Existing unchanged Opus Projects review remains dated r6. Source import/fullnative/Web/
installer gates were not rerun for these documentation-only changes; r7 results remain
source-specific history. Documentation maintain/10unit/ZIP1 checks run on this follow-up.
FLOWS/API/ADR0029/CONTROLS/data/storage semantics are unchanged, so existing diagrams remain.

Next owner Codex: a bounded motor-only angular-damping prototype may test residual chassis
pitch motion, with original combined red signal and exact motor-callback sampling. Keep
camera/physics/goal/evaluator/actor inputs frozen; apply a repair only after causal evidence
and meaningful regression. A separately versioned image-goal calibration is a proposal,
not a silent replacement of this frozen study. Historical AI nominalimage9/9 versus strict
physical0/9 remains unchanged. General navigation, native Mac, Arch originals/formalCLI,
current-package AI end-to-end, human merge and exact-version publication approval remain.

Claude Fable owns the bounded docs integration review/actual rebase; human merges.
Canonical records/Now/readback/recovery receipts remain outside this docs commit under
`C:/Users/Hojun/.agents/backups/ssok-completion-20261010/control-feedback-r8/`.
Generated taskrev16 is not manually edited. No new task ledger, service or schedule.
'''
(p/'README.md').write_bytes(readme.encode())
patterns=[re.compile(rb'sk-[A-Za-z0-9_-]{20,}'),re.compile(rb'Bearer\s+[A-Za-z0-9_-]{20,}'),re.compile(rb'"token"\s*:\s*"[A-Za-z0-9_-]{32,}"')];hits=[]
for f in p.rglob('*'):
    if f.is_file() and f.suffix!='.png' and any(x.search(f.read_bytes()) for x in patterns):hits.append(f.relative_to(p).as_posix())
assert not hits,hits
(b/'curation.json').write_bytes((json.dumps({'raw_copies':len(rows),'images':sum(x['output'].endswith('.png') for x in rows),'three_sensitive_shape_hits':hits,'public_directory':str(p),'source426_unchanged':True,'frozen_goal_unchanged':True,'global_goal_complete':False},indent=2)+'\n').encode())
print(json.dumps({'raw_copies':len(rows),'images':sum(x['output'].endswith('.png') for x in rows),'actual_motor_counts':counts,'source426_unchanged':True,'repair_applied':False,'global_goal_complete':False}),flush=True)
