from pathlib import Path
from datetime import datetime, timezone, timedelta
import hashlib
import json
import re
import subprocess

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
base = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010')
backup = base / 'current-package-goal-r10'
out = repo / 'build/ai-loop-evidence/completion/current-package-goal-r10'
public = repo / 'docs/evidence/agent_camera_2026-10-10/completion/current-package-goal-r10'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda b: hashlib.sha256(b).hexdigest()
contract = read(backup / 'contract.json')
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip()
assert head == contract['head'] and not subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo)
assert len(contract['source426']) == 426 and all(sha((repo / n).read_bytes()) == h for n, h in contract['source426'].items())
receipt = read(out / 'run-receipt.json')
assert receipt['exit_code'] == 0 and not receipt['timed_out'] and receipt['source426_unchanged'] and receipt['current_pe_pck_bytes_unchanged']
checks = read(out / 'checks.json')
assert len(checks) == 12 and all(row['passed'] for row in checks)
cleanup = read(out / 'driver-cleanup.json')
assert all(cleanup.values())
actor = read(out / 'actor/result.json')
assert actor['cli_exit'] == 0 and actor['completed_actions'] == 1 and actor['observations'] == 2 and actor['final_reobserved'] and actor['stop_confirmed'] and actor['owner_revocation_confirmed']
events = [json.loads(line) for line in (out / 'actor/camera/events.jsonl').read_text(encoding='utf8').splitlines()]
decisions = [row for row in events if row['event'] == 'decision']
assert len(decisions) == 1 and decisions[0]['data']['ticks'] == 3
inspection = read(backup / 'astra-inspection.json')
assert inspection['requested_model'] == 'gpt-6-astra' and len(inspection['viewed']) == 10
app = Path(contract['package']['app'])
assert all(sha((app.parent / n).read_bytes()) == h for n, h in contract['package']['exact_export_and_installer_bytes'].items())
camera = read(repo / 'docs/evidence/agent_camera_2026-10-10/completion/verified-r2/unchanged-camera-inputs.json')
assert all(sha((repo / n).read_bytes()) == h for n, h in camera['source_sha256'].items())
goal = repo / 'docs/evidence/agent_camera_2026-10-10/repeated/refined-visual-goal/plan.json'
assert sha(goal.read_bytes()) == camera['goal_source_sha256']
public.mkdir(exist_ok=False)
(public / '.gitattributes').write_bytes(b'* -text\n')
rows = []
def copy(path, relative):
    target = public / relative
    assert not target.exists()
    target.parent.mkdir(parents=True, exist_ok=True)
    raw = path.read_bytes()
    target.write_bytes(raw)
    rows.append({'source': str(path), 'output': Path(relative).as_posix(), 'bytes': len(raw), 'sha256': sha(raw)})
for name in ['run-receipt.json', 'checks.json', 'driver-cleanup.json', 'normal-exit.json', 'operator-exit.json', 'inspect-enter.json', 'inspect-final.json', 'owned-app.json', 'owned-operator.json', 'layout.json', 'project.json', 'native.stdout', 'native.stderr', 'operator.stdout', 'operator.stderr', 'driver.log']:
    copy(out / name, Path('runtime') / name)
for path in sorted(out.glob('*.png')):
    copy(path, Path('runtime') / path.name)
for name in ['result.json', 'dispatch.json']:
    copy(out / 'actor' / name, Path('runtime/actor') / name)
for path in sorted((out / 'actor/camera').iterdir()):
    assert path.suffix in {'.png', '.json', '.jsonl'}, path
    copy(path, Path('runtime/actor/camera') / path.name)
for name in ['contract.json', 'package-inputs.json', 'reused-geometry.json', 'native-driver-inputs.json', 'astra-inspection.json']:
    copy(backup / name, Path('provenance') / name)
for path in sorted((backup / 'native-driver-inputs').iterdir()):
    copy(path, Path('drivers/prepared') / (path.name + '.txt' if path.suffix == '.ps1' else path.name))
for name in ['ssok-package-goal-r10-prepare.py', 'ssok-package-goal-r10-curate.py']:
    copy(repo.parent / name, Path('drivers') / name)
for name in camera['source_sha256']:
    copy(repo / name, Path('production-source') / (name.replace('/', '__') + '.txt'))
copy(goal, 'production-source/frozen-goal.json')
viewed = []
for item in inspection['viewed']:
    path = Path(item['path'])
    row = next(row for row in rows if Path(row['source']) == path)
    viewed.append({'path': str(path), 'public_copy': row['output'], 'dimensions': item['dimensions'], 'sha256': row['sha256'], 'hash_owner': 'Coordinator; visual backend identity not independently attested'})
summary = {'checkpoint': datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds'), 'source_head': head, 'immutable_package_source': contract['package']['source'], 'package_version': contract['package']['version'], 'package_pe_pck_sha256': contract['package']['exact_export_and_installer_bytes'], 'source426_unchanged': True, 'camera10_unchanged': True, 'frozen_goal_sha256': camera['goal_source_sha256'], 'actual_current_package_smoke_runs': 1, 'actual_cli_launches': 1, 'model_auto_retry': 0, 'native_checks': 12, 'native_failures': 0, 'seconds': receipt['seconds'], 'actual_default_packaged_ui': True, 'enter_dispatches': 0, 'actions': 1, 'action_ticks': 3, 'observations': 2, 'final_reobserved': True, 'stop_confirmed': True, 'owner_revocation_confirmed': True, 'normal_native_exit': 0, 'cli_exit': 0, 'operator_external_developer_tool': True, 'requested_model': actor['requested_model'], 'resolved_model': actor['resolved_model'], 'request_count_or_cost_cap_attested': False, 'account_login_packaged': False, 'png_preserved': 10, 'astra_actual_png_views': 10, 'wall_smoke_fixture_m': .8, 'frozen_precision_experiment_changed': False, 'historical_ai_nominal_image': '9/9 unchanged', 'historical_ai_strict_physical': '0/9 unchanged', 'app_repair_applied': False, 'merged': False, 'published': False, 'global_goal_complete': False}
for name, value in [('summary.json', summary), ('viewed-input-hashes.json', viewed), ('copy-manifest.json', {'scope': 'Only named public developer runtime/ordinary synthetic fixture/source proof; no raw private model CLI transcripts, auth/token/login/account/config/isolated user directories or original clipboard data.', 'files': rows})]:
    (public / name).write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode())
readme = '''# Current r7 packaged Run-with-AI end-to-end smoke r10

''' + summary['checkpoint'] + '''; issue32; input HEAD `''' + head + '''`.
Actual clean **fa868ca / 0.3.1-projects-r7** Windows PE/PCK, identical to the
[r7 reviewed package](../release-current-ui-r7/README.md). No app/UI/physics/provider/goal
change, no merge or publication. Global ssok goal remains incomplete.

The default packaged Title → Open my project → paste ordinary project → actual Import/OK
→ enter goal → Enter (no dispatch) → existing external foreground operator → actual Run
with AI completed **12 checks,0 failures,54.463s**. One existing Codex ChatGPT-login CLI
launch requested Astra, actually performed one forward3tick action, produced two distinct
640×480 camera PNGs, reobserved and stopped. Actor and native both exit0; actual final app
state stopped/disabled, scoped-owner revocation confirmed, normal owned-window close,
no engine ERROR, listener8127 released. Original clipboard and process environment restored.
[Raw checks/result](runtime/checks.json), [actor result](runtime/actor/result.json),
[runtime receipt](runtime/run-receipt.json), [all exact hashes](copy-manifest.json).

Goal: `Observe the camera, move forward only3 ticks once, observe again, then stop.`
This is one bounded smoke, not general navigation reliability. The original ordinary fixture
has wall0.8m and is not the frozen wall0.35/24–38px/4–14cm precision study. Historical AI
nominal image9/9 versus strict physical0/9, r8/r9 failures, thresholds and goal remain unchanged.
The two sensor metadata SHA values differ and bind the actual events. Stop_scope context_replaced
means this actor's scoped owner was revoked; separate authenticated describe and native checks
confirm the actual current desktop is stopped. These are distinct observations.

The operator/login remain external developer tools, absent from the package ZIP. Existing
CLI login status is used, not a new packaged account onboarding flow. Requested model is
gpt-6-astra, while CLI JSON does not independently attest resolved backend identity. Existing
8actions/9images/300seconds are tool/time limits; model request count and billing cap are not
attested. Auto retry/fallback0. No evaluation distance/graph/source/auth/private Wiki was added
to the declared camera actor inputs. Private raw CLI transcripts are not copied here.

Source426/camera10/frozen-goal SHA and exact PE7aee4f…9254fb/PCKcada9f…e8535 match before/after.
Already verified r7 source-only geometry/project fixture are reused as coordinates, while
the actual gate drives the immutable default package with Windows input. Inherited process-local
PYTHONUTF8=1 follows r7's diagnosed child encoding recovery; global settings untouched.
Only owned finite process tree cleanup is permitted; no unrelated processes are killed.

Astra actually inspected all10 preserved original PNGs: eight actual app captures and two
actual sensor images. [Findings](provenance/astra-inspection.json),
[coordinator-bound hashes](viewed-input-hashes.json). Still inspection is separate from runtime
proof, cannot infer physical distance, cause, backend identity or broad reliability, and does
not attest every character of the raw goal if clipped/partially visible. Existing Opus UI source
and review stay unchanged; no visual-layout/style/localization edits need a new design review.

Documentation maintenance/10unit/ZIP1 checks accompany new evidence. App import/fullnative/Web/
installer not rerun; r7 historical gates remain source-specific. FLOWS/API/ADR0029/CONTROLS/data/
storage contracts do not change. Fable reviews claim consistency and actual integration rebase,
human merges. Canonical records/Now/recovery/readback are outside the docs commit under
`C:/Users/Hojun/.agents/backups/ssok-completion-20261010/current-package-goal-r10/`.

Remaining: simultaneous frozen image/physical precision, evidence-backed separate control or
versioned calibration decision, account/operator packaging, general robots/navigation, native
Mac, powered-off Arch originals/formal task CLI16 handoff, human merge and reviewed exact-version
publication approval. Generated task/done/aliases preserved; no new task ledger or service.
'''
(public / 'README.md').write_bytes(readme.encode())
patterns = [re.compile(rb'sk-[A-Za-z0-9_-]{20,}'), re.compile(rb'Bearer\s+[A-Za-z0-9_-]{20,}'), re.compile(rb'"token"\s*:\s*"[A-Za-z0-9_-]{32,}"')]
hits = [str(path.relative_to(public)) for path in public.rglob('*') if path.is_file() and path.suffix != '.png' and any(pattern.search(path.read_bytes()) for pattern in patterns)]
assert not hits
result = {'raw_copies': len(rows), 'images': sum(row['output'].endswith('.png') for row in rows), 'actual_astra_views': 10, 'three_sensitive_shape_hits': hits, 'public_directory': str(public), 'source426_unchanged': True, 'global_goal_complete': False}
assert result['images'] == 10
(backup / 'curation.json').write_bytes((json.dumps(result, indent=2) + '\n').encode())
print(json.dumps(result), flush=True)
