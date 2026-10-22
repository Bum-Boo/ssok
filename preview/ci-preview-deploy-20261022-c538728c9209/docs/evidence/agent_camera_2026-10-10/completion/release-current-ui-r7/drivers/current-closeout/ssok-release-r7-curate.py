from pathlib import Path
from datetime import datetime,timezone,timedelta
import hashlib,json,re,subprocess
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');e=r/'build/ai-loop-evidence/completion/release-current-ui-r7';b=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/release-current-ui-r7');release=r/'build/projects-release-clean-r7';p=r/'docs/evidence/agent_camera_2026-10-10/completion/release-current-ui-r7'
read=lambda f:json.loads(f.read_text(encoding='utf-8-sig'));sha=lambda d:hashlib.sha256(d).hexdigest()
def file_sha(f):
    h=hashlib.sha256()
    with f.open('rb') as s:
        while data:=s.read(4*1024*1024):h.update(data)
    return h.hexdigest()
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=r).decode().strip();assert head=='fa868ca07cdd9d2b8edb27cbab89cd00263c851f'
assert not subprocess.check_output(['git','status','--porcelain'],cwd=r)
inputs=read(e/'source-before.json')['files'];assert len(inputs)==426 and all(file_sha(r/n)==h for n,h in inputs.items())
meta=read(release/'release.json');assert meta['commit']==head and not meta['dirty_worktree'] and not meta['source_changed_during_build']
artifacts=[]
for item in meta['artifacts']:
    f=release/item['file'];assert f.stat().st_size==item['bytes'] and file_sha(f)==item['sha256'];artifacts.append(item)
assert len(artifacts)==6
full=read(e/'native-full-receipt.json');fix=read(e/'native-encoding-recovery-receipt.json');final=read(e/'native-gate-final.json')
assert (full['checks'],full['failures'])==(81,2) and (fix['checks'],fix['failures'])==(2,0) and final['initial_full_passes_retained']==79 and final['failures']==0
browser=read(e/'browser/receipt.json');assert len(browser['results'])==5 and browser['failures']==0 and not browser['source_changed']
assert all(x['passed'] and x['exit_code']==0 for x in browser['results'])
initial=read(e/'windows-installer/receipt.json');serial=read(e/'windows-installer-serial/receipt.json');project=read(e/'package-projects/receipt.json');comparison=read(e/'package-projects/export-comparison.json')
assert (initial['checks'],initial['failures'],initial['exit_code'])==(10,1,1)
assert (serial['checks'],serial['failures'],serial['exit_code'])==(17,0,0) and serial['user_added_file_preserved'] and not any(serial['registration_remaining'].values())
assert serial['installed_exact_export_bytes']=={n:file_sha(release/'windows'/n) for n in ['ssok.exe','ssok.pck']}
assert (project['checks'],project['failures'],project['exit_code'])==(6,0,0) and project['source426_unchanged'] and project['package_bytes_unchanged']
assert comparison['actual_graph_source_format_version_equal_to_imported_fixture']
diagnostic=read(e/'native-wall-clipboard-probe/receipt.json');assert diagnostic['exit_code']==1 and len(diagnostic['checks'])==2 and all(x['passed'] for x in diagnostic['checks'])
cleanup=read(b/'runtime-cleanup.json');assert not any(cleanup[n] for n in ['owned_project_process_ids','port8127_listener_process_ids','uninstall_registration_remaining','location_registration_remaining','start_menu_shortcut_remaining'])
camera=read(r/'docs/evidence/agent_camera_2026-10-10/completion/verified-r2/unchanged-camera-inputs.json')
assert all(file_sha(r/n)==h for n,h in camera['source_sha256'].items())
assert file_sha(r/'docs/evidence/agent_camera_2026-10-10/repeated/refined-visual-goal/plan.json')==camera['goal_source_sha256']
opus=read(r/'docs/evidence/agent_camera_2026-10-10/completion/package-goal-ui-r6/reviews/opus-final-verdict.json');assert opus['verdict']=='pass' and not opus['blocking_findings']
assert file_sha(r/'src/ui/project_panel.gd')=='8778866482ba39592df7545e99f612991fa9d4046a65760fbf6984b6d459e038'
stamp=datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')
after={'checkpoint':stamp,'package_source':head,'files':{n:file_sha(r/n) for n in inputs},'source426_unchanged':True,'camera10_unchanged':True,'frozen_goal_sha256':camera['goal_source_sha256'],'published':False}
assert not (e/'source-after.json').exists();(e/'source-after.json').write_bytes((json.dumps(after,indent=2)+'\n').encode())
p.mkdir(exist_ok=False);(p/'.gitattributes').write_bytes(b'* -text\n');rows=[]
def copy(f,rel):
    rel=Path(rel);assert not set(rel.parts)&{'appdata','localappdata','data','isolated-data','isolated-config','config','portable'}
    dest=p/rel;assert not dest.exists();dest.parent.mkdir(parents=True,exist_ok=True);data=f.read_bytes();dest.write_bytes(data);assert dest.read_bytes()==data
    rows.append({'source':str(f),'output':rel.as_posix(),'bytes':len(data),'sha256':sha(data)})
for f in sorted(e.iterdir()):
    if f.is_file() and f.suffix in ['.json','.log']:copy(f,Path('runtime')/f.name)
for label in ['native-full','native-encoding-recovery','windows-installer','windows-installer-serial','package-projects','native-wall-clipboard-probe','ci-layout-trace-2']:
    for f in sorted((e/label).iterdir()):
        if f.is_file() and f.suffix in ['.json','.log','.stdout','.stderr','.png','.txt','.ps1','.gd','.xml','.md']:
            copy(f,Path('runtime')/label/(f.name+'.txt' if f.suffix=='.gd' else f.name))
for f in sorted((e/'browser').iterdir()):
    if f.is_file() and f.suffix in ['.json','.log']:copy(f,Path('runtime/browser')/f.name)
for label in ['smoke','authoring','physics','learning','settings']:
    for f in sorted((e/'browser'/label).iterdir()):
        if f.is_file() and f.suffix in ['.json','.png','.log','.txt']:copy(f,Path('runtime/browser')/label/f.name)
for n in ['release.json','SHA256SUMS']:copy(release/n,Path('build')/n)
for f in sorted((release/'export-logs').iterdir()):
    if f.is_file() and f.suffix in ['.json','.log','.txt']:copy(f,Path('build/export-logs')/f.name)
for n in ['runtime-verifier-inputs.json','native-serial-dispatch.json','native-serial-driver.before-execution.py','package-projects-driver.before-execution.ps1','package-projects-layout.before-execution.gd','package-projects-layout-inputs.json','runtime-cleanup.json']:
    copy(b/n,Path('provenance')/(n+'.txt' if n.endswith('.gd') else n))
for f in sorted(b.iterdir()):
    if f.is_file() and (f.name.endswith('.before-execution') or f.name.endswith('.current-prepared')):copy(f,Path('drivers/prepared')/(f.name+'.txt'))
for n in ['ssok-release-r7-clipboard-probe.py','ssok-release-r7-layout-probe.py','ssok-release-r7-layout-trace.py','ssok-native-final-r7-serial.py','ssok-release-r7-projects-run.py','ssok-release-r7-curate.py','ssok-release-r7-cleanup.ps1']:
    copy(r.parent/n,Path('drivers/current-closeout')/n)
views=[]
for name in ['astra-web-native-diagnostic.json','astra-packaged-final.json']:
    report=read(b/name);assert report['requested_model']=='gpt-6-astra' and not report['material_issues'];copy(b/name,Path('reviews')/name)
    for frame in report['viewed']:
        f=Path(frame['path']);row=next(x for x in rows if x['source']==str(f));views.append({'report':name,'actual_viewed_source':str(f),'public_copy':row['output'],'dimensions':frame['dimensions'],'sha256':row['sha256'],'hash_verification_owner':'Coordinator; inspector did not independently attest source/backend identity.'})
copy(r/'src/ui/project_panel.gd',Path('provenance/project_panel.reviewed.gd.txt'))
copy(r/'tools/ci/browser_layout.gd',Path('provenance/browser_layout.excluded.gd.txt'))
copy(r/'docs/evidence/agent_camera_2026-10-10/completion/verified-r2/unchanged-camera-inputs.json',Path('provenance/unchanged-camera-inputs.json'))
def generated(rel,value):(p/rel).write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode('utf8'))
generated('reviews/viewed-input-hashes.json',views)
generated('artifact-readback.json',{'checkpoint':stamp,'actual_six_hashes_match_release_metadata':True,'artifacts':artifacts,'package_source':head,'published':False,'binary_outputs_retained_under':str(release)})
summary={'checkpoint':stamp,'package_source':head,'version':meta['version'],'clean_build':True,'build_exports':4,'artifact_hashes_verified':6,'build_seconds':read(e/'build-receipt.json')['seconds'],'source426_unchanged_before_after_runtime':True,'camera10_unchanged':True,'project_panel_sha256':file_sha(r/'src/ui/project_panel.gd'),'ci_layout_sha256':file_sha(r/'tools/ci/browser_layout.gd'),'native_gate':final,'browser_gates':5,'browser_failures':0,'windows_installer_initial':{'checks':10,'failures':1,'exit_code':1},'wall_diagnostic':{'passing_assertions':2,'exit_code':1,'post_assertion_fixture_error':'Missing layout anchor game_stage_ after single-stage loop incorrectly iterated to a nonexistent next stage'},'windows_installer_serial':{'checks':17,'failures':0,'exit_code':0,'installed_pe_pck_equal':True,'user_file_preserved':True},'actual_packaged_projects':{'checks':6,'failures':0,'exported_graph_source_format_version_equal':True,'provider_calls':0},'astra_actual_views':17,'existing_opus_review':'Unchanged r6 ProjectPanel; authored/revised and independent PASS','native_mac_tested':False,'native_linux_gui_tested':False,'linux_export_startup_resources_passed':True,'frozen_image_goal':'9/9 nominal historical','frozen_independent_physical_goal':'0/9 historical unchanged','published':False,'merged':False,'global_goal_complete':False}
generated('summary.json',summary)
generated('copy-manifest.json',{'scope':'Exact bounded current-release runtime/source/helper copies. No application binaries, personal saved data, original clipboard, account configuration, model prompts or private transcripts. Pre-execution/current-prepared/current-closeout snapshots are labeled by actual provenance.','files':rows})
readme=f'''# Current reviewed UI: clean release candidate r7

Checkpoint {stamp}. Clean immutable application source `{head}`, Godot4.7.2,
version **0.3.1-projects-r7**. Four exports and all six artifact hashes verified against
[release metadata](build/release.json), [actual hash readback](artifact-readback.json).
No merge or publication. Packages remain local in `build/projects-release-clean-r7/`.
This documentation/evidence follow-up is later than the immutable package: packaged docs are
the snapshot at fa868ca, not these newly written records. No package rebuild is implied.

Windows source verification initially ran **81 checks / 2 failures**: two child Python suites
used cp949 instead of UTF8. Per-process inherited `PYTHONUTF8=1`, without global settings or
source/test changes, recovered just those **2 / 0**. Final coverage is the original79 passes
plus2 recovery passes, **81 resolved / 0**, not another single81/0 invocation.
[Original full receipt](runtime/native-full-receipt.json),
[focused recovery](runtime/native-encoding-recovery-receipt.json),
[final composite](runtime/native-gate-final.json); every original suite log/result remains.
Godot import/load and rendered camera/goal/scoped Stop regressions actually ran. Transport
uses its test mock; no live AI provider call occurred in these deterministic gates.

The same clean exported Web bytes passed all five real Chromium gates: startup, authoring,
physics, learning and settings. Authoring9checks and settings14checks include actual clipboard,
IndexedDB/reload, download comparison, confirmation, graph/source and progress checks.
[Five actual commands/results](runtime/browser/receipt.json). Corrected CI layout fixture506…d0d5
also passed the original Linux build bound and produced64 anchors/OK782,504. Two optional
short probes (40s/15s) expired during initialization; the40s wrapper captured no raw console
or receipt, while the15s instrumented ignored copy retains its [timeout](runtime/ci-layout-trace-2/receipt.json)
and console. They do not establish an application hang or a repaired source regression.
Approximate170.932s from import-log to layout-log modification time is not an independent
command stopwatch. Canonical fixture and app were not instrumented or changed.

The first actual Windows install gate failed **10checks / 1**, wall-brake after two successes;
Godot logged `Unable to open clipboard`. A Web clipboard job was concurrently active, but
that correlation does not prove causality. Original [failed receipt](runtime/windows-installer/receipt.json),
stderr, progress and uninstall snapshot remain unchanged. Initial registration readback still
showed entries while asynchronous uninstall was finishing; later actual readback and final
serial verification show both true installer keys absent. An older r6 location-only cleanup
checked `HKCU\\Software\\ssok` incorrectly; the actual key is `HKCU\\Software\\Bum-Boo\\ssok`.

A wall-only diagnostic verified the program by actual app Ctrl+C after a clipboard sentinel,
then actually cleared the5–10cm stage at7.2cm. Both assertions passed, but its reduced fixture
incorrectly iterated beyond its one stage: **whole run exit1**, retained as a failed diagnostic,
not full acceptance. [Actual code/readback/stage and original exit](runtime/native-wall-clipboard-probe/receipt.json).
The future outside-repo wrapper was corrected to iterate the reduced list length; no app/source
change, overwrite of the failed receipt or diagnostic rerun occurred.

After all Web clipboard jobs ended, a fresh output path ran the unchanged canonical Windows
installer verifier with the identical setup bytes, layout and thresholds. **17 / 0,48.980s**,
all three stages, actual installed PE/PCK equal to export, per-user registration/shortcut,
uninstall and preservation of a synthetic user-added file passed.
[Serial receipt](runtime/windows-installer-serial/receipt.json),
[actual checks](runtime/windows-installer-serial/checks.json).
First failure cause remains unproved. Future clipboard UI jobs are serialized.

The actual current portable Windows package was opened from default Title; real paste/Import,
Escape cancellation, second Import/OK and actual Copy JSON passed **6 / 0,18.967s**.
Exported graph, source, format and version exactly equal the imported synthetic fixture.
[Package receipt](runtime/package-projects/receipt.json),
[strict comparison](runtime/package-projects/export-comparison.json).
Native source geometry is labeled as geometry only; actual Windows package input is separate.
No learner code or provider execution was triggered by this project transfer.

Astra actually viewed17 current PNGs, including five installed title/map/stage images and
six packaged Projects/cancel/import/reexport images. No material clipping or overlap;
warnings and primary controls readable. [Final11-image inspection](reviews/astra-packaged-final.json),
[Web plus wall diagnostic6-image inspection](reviews/astra-web-native-diagnostic.json),
[coordinator image hashes](reviews/viewed-input-hashes.json). Minor pre-existing underscore
tab separator, ellipsized library label and partial scroll rows remain. Still images do not
independently attest input, physics, storage equality, numerical contrast or backend identity.

Current ProjectPanel rawSHA877886…e038 is unchanged from Opus5-5 authored/revised and
independently PASS-reviewed [r6 design](../package-goal-ui-r6/reviews/opus-final-verdict.json).
Its80 native cases/1181checks/128images, real OS25checks and four-language/both-theme coverage
are dated r6 source proof, not new r7 executions. Out of the previous frozen426 input set,
only one application UI file and the PCK-excluded CI fixture differ; all current426 are
unchanged across r7 gates. Camera10, frozen goal, motors, physics and evaluator are unchanged.
No user strings or catalogs changed. FLOWS/DATA_MODEL/AUTHORING contracts remain reviewed as
in r6; this follow-up changes only documentation/evidence and Windows encoding guidance.

The r6 actual external-operator Run with AI12/0 used older immutable r2/f31 package bytes.
It is not an end-to-end AI invocation on this r7 PCK. Unchanged camera/controller inputs
support source continuity only. Account onboarding/operator packaging, billing/backend
attestation, broad robot navigation and catalog-camera serialization remain open.
Frozen nominal image9/9 and strict physical14cm **0/9** remain unchanged historical results;
the successful wall stage's5–10cm criterion is a different task.

Native Mac execution and native Linux GUI are untested; Linux exported startup/resources and
Mac cross-export/archive checks passed, which are narrower claims. Powered-off Arch originals
and generated revision16 official task CLI release, human merge and exact reviewed
version/scope publication approval remain pending. Fable owns actual feature rebase; the
human merges. The global ssok objective remains incomplete.

All [raw source/output copies](copy-manifest.json) have exact SHA256; binaries, isolated user
data, original clipboard, private model briefs/login state are excluded. Three specified
sensitive-shape patterns are checked separately, not a universal privacy certificate.
[Cleanup](provenance/runtime-cleanup.json) checks the actual two registry keys, shortcut,
owned project processes and port8127, without killing unrelated processes.
Final integration, canonical Wiki/Now readback, validator and recovery bundle receipts live
outside this immutable package/evidence commit under the existing completion backup/r7 folder.
'''
(p/'README.md').write_bytes(readme.encode('utf8'))
patterns=[re.compile(rb'sk-[A-Za-z0-9_-]{20,}'),re.compile(rb'Bearer\s+[A-Za-z0-9_-]{20,}'),re.compile(rb'"token"\s*:\s*"[A-Za-z0-9_-]{32,}"')];hits=[];count=0
for f in p.rglob('*'):
    if f.is_file() and f.suffix.lower() not in ['.png']:
        count+=1
        if any(x.search(f.read_bytes()) for x in patterns):hits.append(f.relative_to(p).as_posix())
assert not hits,hits
(b/'curation.json').write_bytes((json.dumps({'raw_copies':len(rows),'text_candidates':count,'three_sensitive_pattern_hits':hits,'source426_unchanged':True,'six_binary_hashes_verified':True,'public_directory':str(p),'global_goal_complete':False},indent=2)+'\n').encode())
print(json.dumps({'copies':len(rows),'images':sum(x['output'].endswith('.png') for x in rows),'three_sensitive_pattern_hits':hits,'head':head,'published':False}),flush=True)
