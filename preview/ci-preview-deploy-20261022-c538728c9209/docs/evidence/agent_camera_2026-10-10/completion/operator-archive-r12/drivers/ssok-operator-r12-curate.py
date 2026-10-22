from pathlib import Path
from datetime import datetime,timezone,timedelta
import hashlib,json,subprocess
repo=Path('C:/Users/Hojun/Projects/ssok-ai-loop');backup=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/operator-archive-r12')
runtime=repo/'build/ai-loop-evidence/completion/operator-archive-r12';public=repo/'docs/evidence/agent_camera_2026-10-10/completion/operator-archive-r12'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'));sha=lambda b:hashlib.sha256(b).hexdigest()
package=read(backup/'package-receipt.json');contract=read(backup/'contract.json');inspection=read(backup/'astra-inspection.json')
assert len(inspection['viewed'])==10 and inspection['requested_model']=='gpt-6-astra'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo).decode().strip()==package['source_head']
assert not subprocess.check_output(['git','status','--porcelain'],cwd=repo)
for phase in ['before','after']:
    folder=runtime/phase;receipt=read(folder/'run-receipt.json');checks=read(folder/'checks.json')
    assert receipt['exit_code']==0 and not receipt['timed_out'] and len(checks)==12 and all(row['passed'] for row in checks)
    assert all(read(folder/'driver-cleanup.json').values())
before=read(runtime/'before/actor/result.json');after=read(runtime/'after/actor/result.json')
assert before['status']=='runner_failed' and before['cli_exit'] is None and before['completed_actions']==before['observations']==0 and before['stop_confirmed']
assert after['cli_exit']==0 and after['completed_actions']==1 and after['observations']==2 and after['final_reobserved'] and after['stop_confirmed']
goal=repo/'docs/evidence/agent_camera_2026-10-10/repeated/refined-visual-goal/plan.json'
assert sha(goal.read_bytes())=='d372505d199ce2e2ba4b12588487cafe9e722465b65171ca25fcbf8496f632a4'
public.mkdir(exist_ok=False);(public/'.gitattributes').write_bytes(b'* -text\n');rows=[]
def copy(path,relative):
    target=public/relative;assert target.resolve().is_relative_to(public.resolve()) and not target.exists()
    target.parent.mkdir(parents=True,exist_ok=True);data=path.read_bytes();target.write_bytes(data)
    rows.append({'source':str(path),'output':Path(relative).as_posix(),'bytes':len(data),'sha256':sha(data)})
for phase in ['before','after']:
    folder=runtime/phase
    for name in ['run-receipt.json','checks.json','driver-cleanup.json','normal-exit.json','operator-exit.json','inspect-enter.json','inspect-final.json','owned-app.json','owned-operator.json','layout.json','project.json','native.stdout','native.stderr','operator.stdout','operator.stderr','driver.log']:
        copy(folder/name,Path('runtime')/phase/name)
    for path in sorted(folder.glob('*.png')):copy(path,Path('runtime')/phase/path.name)
    for path in sorted((folder/'actor').rglob('*')):
        if path.is_file():
            assert path.suffix in {'.json','.jsonl','.png'}
            copy(path,Path('runtime')/phase/'actor'/path.relative_to(folder/'actor'))
for name in ['implementation-proof.json','package-receipt.json','archive-checks.json','before-driver-inputs.json','after-driver-inputs.json','astra-inspection.json','portable-regression-before.log','python-checks.log','docs-tests.log','launcher-no-token.stdout','launcher-no-token.stderr']:
    copy(backup/name,Path('provenance')/name)
for name in ['before','before-inspect','before-native','package','after','after-inspect','after-native','guards','curate']:
    ext='.ps1' if name.endswith('-native') else '.py';path=repo.parent/('ssok-operator-r12-'+name+ext)
    copy(path,Path('drivers')/(path.name+'.txt' if ext=='.ps1' else path.name))
for name in package['files']:
    copy(Path(package['extracted_root'])/name,Path('operator-source')/(name+'.txt' if name.endswith('.ps1') else name))
copy(goal,'frozen-goal.json')
viewed=[]
for item in inspection['viewed']:
    row=next(row for row in rows if Path(row['source'])==Path(item['path']));assert row['sha256']==item['sha256']
    viewed.append(dict(item,public_copy=row['output']))
stamp=datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')
summary={'checkpoint':stamp,'operator_source_head':package['source_head'],'operator_version':package['version'],'operator_zip_sha256':package['sha256'],'operator_zip_entries':12,'app_source':contract['package']['source'],'app_version':contract['package']['version'],'app_pe_pck_sha256':contract['package']['exact_export_and_installer_bytes'],'original_inputs':426,'unchanged_original_inputs':425,'only_changed_original_input':'tools/app_control/run_goal.py: source identity recording','actor_prompt_and_codex_command_unchanged':True,'before_actual_git_free_exit':128,'before_native_checks':12,'before_native_expected_failure':True,'before_model_launches':0,'after_native_checks':12,'after_native_failures':0,'after_seconds':read(runtime/'after/run-receipt.json')['seconds'],'actual_actions':1,'actual_ticks':3,'actual_observations':2,'scoped_stop_and_native_cli_exit_zero':True,'archive_guards':4,'python_checks':63,'docs_tests':10,'png_preserved':18,'astra_actual_views':10,'requested_model':'gpt-6-astra','resolved_model':'CLI JSON does not attest serving model identity','account_python_codex_external':True,'frozen_goal_changed':False,'historical_ai_image':'9/9 unchanged','historical_ai_physical':'0/9 unchanged','merged':False,'published':False,'global_goal_complete':False}
for name,value in [('summary.json',summary),('viewed-input-hashes.json',viewed),('copy-manifest.json',{'scope':'Named public synthetic runtime/operator modules/checks only; excludes private model transcripts, account/auth/token/config, isolated appdata, private Wiki and original clipboard.','files':rows})]:
    (public/name).write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode())
text=f'''# Git-independent foreground operator r12

{stamp}; issue32; local draft, no merge/push/publication.
Operator clean source **{package['source_head']}**, version **{package['version']}**;
ZIP SHA256 `{package['sha256']}`. The immutable Godot app is a separate
**fa868ca / 0.3.1-projects-r7** PE/PCK. Source425/426 unchanged; the sole original
input changed is run_goal.py provenance recording. Actor text and Codex-command/
process-cancellation AST are identical; all five other operator modules are unchanged.
[Exact scope proof](provenance/implementation-proof.json).

Before: copied original six operator modules outside Git, actual git exit128.
Actual native app default Title→Projects import/OK→goalEnter(no dispatch)→operator/
existing ChatGPT login→intentional Run failed at the Git source-head lookup before
model/MCP launch. Actor0 actions/0 images, scoped Stop confirmed; app normal exit0.
Native12/0 verifies the **expected failure**, not AI success. [Before receipt](runtime/before/inspect-final.json).
The legacy portable positive unit regression also failed1/3. A missing PIPE in
the new provider test mock was then fixed when the runner reached model launch;
that unit mock is not provider/runtime evidence.

After: the actual12-entry ZIP was extracted outside Git to a path containing
spaces and Korean. Its packaged PowerShell launcher was started from another
cwd and resolved the archive/Python correctly. Same immutable app and same goal:
`Observe the camera, move forward only3 ticks once, observe again, then stop.`
Default native Title→Projects import/OK→Enter(no dispatch)→existing login/
intentional app Run→one requested-Astra3tick action→two distinct640×480 PNGs/
final reobserve→scoped Stop→normal CLI/launcher/native exit0: **12/0,{summary['after_seconds']:.3f}s**.
Separate authenticated describe confirms current app stopped/disabled; actor
context_replaced alone certifies owner revocation. Clipboard/env restored,
no engine errors and listener8127 released. [After receipt](runtime/after/run-receipt.json),
[actor result](runtime/after/actor/result.json), [native checks](runtime/after/checks.json).

Four actual archive guards pass: valid identity with no Git on PATH; missing
token launcher rejects; dirty checkout packaging rejects; two clean builds have
identical ZIP bytes. Missing/changed/malformed seven-module identity rejects
before model launch through the scoped-Stop goal entry point in unit checks.
Python63/0 with MCP SDK/no skips; documentation tests10/0. [Guard results](provenance/archive-checks.json).
Build from clean checkout: `python -m tools.ci.operator_package --out build/ssok-operator.zip`.
[Included setup](operator-source/README.md), [all12 hashes](provenance/package-receipt.json).
Python, pinned MCP installation, Codex CLI, existing login and Godot remain external.
No service/autostart, credentials, environment, Git checkout or evaluator is shipped.
Module hashes prove consistency with the included record, not publisher authenticity.

Astra actually viewed10 after-stills:8UI/2sensor. Disclosure/Stop/state readable,
goal text partial and action trace outside visible scroll. Tooltip overlap does
not obscure primary controls. Camera centers unobstructed with a small wall-edge
difference. [Actual inspection](provenance/astra-inspection.json). Stills do not
certify the3ticks, physical rest or provider backend; those runtime facts have
separate coordinator checks. Exactly18 before/after PNGs and all named raw files
are preserved byte-for-byte; [copy manifest](copy-manifest.json).

This wall0.8m one-goal smoke is separate from the frozen three-layout precision
benchmark. Image9/9/strictphysical0/9 remains unchanged. No physics/camera/goal/
threshold, UI/style/localization, provider/auth/action-limit change. Requested
Astra is not independent backend attestation;8actions/9images/300seconds are
tool/time limits, not a request or billing cap. Automatic retry/paid fallback0.
Existing Opus design review remains applicable. Actual app import/fullnative/
Web/installer gates were not rerun; r7 remains their dated source-specific evidence.

Next Codex: camera/physical precision and external-account onboarding/navigation.
Native Mac, Arch raw-data/formal task16 CLI release remain unverified/uncollected.
Fable reviews/rebases this local branch; human merges and approves exact published
version/scope. This operator archive does not update the Godot ZIP or public site.
Global ssok goal remains incomplete. FLOWS/API/CONTROLS diagrams remain valid:
only provenance/package entry changes; action ownership/actor contract is unchanged.
'''
(public/'README.md').write_bytes(text.encode())
handoff=repo/'CLAUDE-REVIEW.md';old=handoff.read_bytes();(backup/'CLAUDE-REVIEW.before').write_bytes(old)
prefix=f'''# ssok — Git-independent foreground operator r12

Issue32, feat/32-robot-camera-loop. Operator clean e645d220 / 0.1.0-operator-r12,
immutable Godot fa868ca / 0.3.1-projects-r7, exact app PE/PCK unchanged.
[Before/after18PNG, actual12/0, source/ZIP identity and limits](docs/evidence/agent_camera_2026-10-10/completion/operator-archive-r12/README.md).
Actual Git-free before runner fails before model; expected-native12/0 is not AI success.
Extracted12-entry archive/packagedPS launcher in Korean+spaces path works withoutGit,
actualRun→one3tick action/2PNG/reobserve/scopedStop→CLI/native exit0,52.909s.
425/426 original inputs unchanged; only run_goal source metadata changes. Actor prompt,
Codex-command/cancellation AST and other5modules unchanged; no Godot/UI/physics/goal edit.
New identity validates7module bytes before model; archive dirty-source refusal and
determinism verified. Python63/0/no SDKskip, docs10/0, archive4/0; Astra actually10
after-stills (goalpartial/traceoffscroll limits). Raw before/provider-mock failure retained.
Python/MCP/Codex/login/app remain external. No service, paidfallback, retries, credentials,
Gitcheckout/evaluator shipment; module hashes check record consistency, not a signature.
Tool8/9/300 limits are not billing/requestcap or backendmodel certification.
No app import/fullnative/Web/installer rerun; datedr7 gates and existingOpus review retained.
Historical AIimage9/9physical0/9 unchanged. Globalgoal incomplete; no merge/push/publication.
Next Codex: physical/image precision/account onboarding/navigation; Macnative/Archraw/
formalCLI16release remain. Fable reviews/rebases final docs; humanmerges/exactscopepublishes.
Canonical record/recovery: C:/Users/Hojun/.agents/backups/ssok-completion-20261010/operator-archive-r12/.

## Frozen r11 milestone — rejected paired holding candidates

'''
handoff.write_bytes(prefix.encode()+old)
status=repo/'docs/STATUS.md';old=status.read_bytes();(backup/'STATUS.before').write_bytes(old)
needle='# 현재 방향과 문서 기준\n\n';value=old.decode();assert value.count(needle)==1
latest='2026-10-11 r12: 별도operator ZIP/Git-free 한글·공백 경로에서 실제Run→3틱1행동/2PNG·재관측·Stop/정상종료12/0·52.909s. 원래Git실패/Stop 보존, Python63/0·archive4/0·Astra10. [원본18PNG·버전·한계](evidence/agent_camera_2026-10-10/completion/operator-archive-r12/README.md). 앱fa868ca 불변/도구별도version; Python/MCP/Codex/login 외부. 물리0/9·Mac/Arch·humanmerge/공개 미완료.\n\n'
value=value.replace(needle,needle+latest,1)
while sum(len((repo/p).read_text(encoding='utf8').splitlines()) for p in ['AGENTS.md','docs/START_HERE.md'])+len(value.splitlines())>250:
    assert '\n\n\n' in value;value=value.replace('\n\n\n','\n\n',1)
status.write_bytes(value.encode())
print(json.dumps({'raw_files':len(rows),'pngs':sum(row['output'].endswith('.png') for row in rows),'astra':len(viewed),'operator_source':package['source_head'],'record_ready':True}))
