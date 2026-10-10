from pathlib import Path
from datetime import datetime, timezone, timedelta
import hashlib
import json
import msvcrt
import os
import subprocess

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
base = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010')
backup = base / 'current-package-goal-r10'
out = repo / 'build/ai-loop-evidence/completion/current-package-goal-r10'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda b: hashlib.sha256(b).hexdigest()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip()
assert head == read(base / 'angular-feedback-r9/closeout.json')['head']
assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo)
source = read(base / 'angular-feedback-r9/contract.json')['source426']
assert all(sha((repo / n).read_bytes()) == h for n, h in source.items())
assert not backup.exists() and not out.exists()
backup.mkdir()
out.mkdir()
release = repo / 'build/projects-release-clean-r7'
meta = read(release / 'release.json')
assert meta['commit'] == 'fa868ca07cdd9d2b8edb27cbab89cd00263c851f' and meta['version'] == '0.3.1-projects-r7'
assert not meta['dirty_worktree'] and not meta['source_changed_during_build']
app = release / 'windows/ssok.exe'
pe_pck = {n: sha((app.parent / n).read_bytes()) for n in ['ssok.exe', 'ssok.pck']}
prior = read(repo / 'build/ai-loop-evidence/completion/release-current-ui-r7/package-projects/receipt.json')
assert pe_pck == prior['pe_pck_sha256']
plan = Path('C:/Users/Hojun/Documents/Obsidians/Frieren (arch)/30_Projects/ssok/AI 관측·행동 루프 공동개발 계획.md')
old = plan.read_bytes()
previous = read(base / 'angular-feedback-r9/records/manifest.json')[str(plan)]
assert sha(old) == previous['post_sha256']
(backup / 'plan.before.md').write_bytes(old)
stamp = datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')
entry = '\n\n<!-- ssok-current-package-goal-r10 -->\n### 현재 r7 실제 AI 전체 경로 검증 — ' + stamp + '\n\nOutcome: 같은 fa868ca/0.3.1-projects-r7 실제PE/PCK의 defaultTitle→프로젝트UIimport/confirm→goal붙여넣기→Enter dispatch0→externalexistingforegroundoperator→intentionalRun→기존Codex ChatGPTlogin/requestedAstra→한번forward3ticks/2realPNG/reobserve/Stop→정상close를 관측한다. 원래검증된 r6 smoke Goal은 Observe the camera, move forward only3 ticks once, observe again, then stop. 로봇fixture의 wall0.8은 이smoke용 원본이고 frozenwall.35/24..38px/4..14cm목표의 개선시험이 아니다. Allowed: 기존r6native/inspectdriver를 freshoutput/currentr7package/source426/currentr7layout로만 적응한 outsidehelpers·ignored runtime/evidence/docs/기존정본. No app/UI/style/physics/camera/goal/threshold/engine/provider/auth/settings changes. One CLI launch, model autoretry0/fallback0; 기존8steps9images300s tool/time bounds는request/billing 상한이 아님. Auth/token/privateWiki/graph/source/evaluator metrics를actor입력에주지 않는다. Existing locked nativePythonSDK; inheritedprocess-local PYTHONUTF8=1 only, originalclipboard/env restore. Acceptance: samePE/PCK/source426SHA pre/post, Enter0intent, actualRunclaim1/action3ticks exactly1/actualcameraSHA metadata2/differenthashes/finalreobserve/Stopownership+currentdisabled/normalexit0/engineERROR0/port8127cleanup. Onefinite415sownedprocess tree and scopedStop onfailure. Source-only alreadyverified r7layout/projectfixture reuse is geometry, gate usesactualdefaultpackagedUI and Windowsinput. Actualscreenshots Astra, nodesignchange/Opus retained; finalFableintegration/humanmerge. Accountlogin/operator notpackaged/backendidentity/requestcostcap/generalAI navigation/Mac/Arch formalCLI16/physical0/9/publication remainlimits. Coordinator Codex, globalgoal incomplete and donefalse/aliases/generatedtask preserved.\n'
data = old + entry.encode()
with plan.open('r+b', buffering=0) as stream:
    size = max(len(old), len(data)) + 1
    msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, size)
    try:
        assert stream.read() == old
        stream.seek(0)
        stream.write(data)
        stream.truncate()
        os.fsync(stream.fileno())
    finally:
        stream.seek(0)
        msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, size)
assert plan.read_bytes() == data
package = {'app': str(app), 'source': meta['commit'], 'version': meta['version'], 'exact_export_and_installer_bytes': pe_pck, 'current_source_head': head, 'operator_external_developer_tool': True}
(backup / 'package-inputs.json').write_bytes((json.dumps(package, indent=2) + '\n').encode())
(backup / 'contract.json').write_bytes((json.dumps({'head': head, 'plan': str(plan), 'before_sha256': sha(old), 'post_sha256': sha(data), 'source426': source, 'package': package, 'model_cli_launch_limit': 1, 'model_auto_retry': 0, 'scope': 'Current immutable r7 actual default packaged UI Run-with-AI smoke, no app repair or frozen physical-goal claim', 'global_goal_complete': False}, indent=2) + '\n').encode())
original = repo / 'build/ai-loop-evidence/completion/release-current-ui-r7/package-projects'
for name in ['layout.json', 'project.json']:
    (out / name).write_bytes((original / name).read_bytes())
(backup / 'reused-geometry.json').write_bytes((json.dumps({'layout': str(original / 'layout.json'), 'layout_sha256': sha((out / 'layout.json').read_bytes()), 'fixture': str(original / 'project.json'), 'fixture_sha256': sha((out / 'project.json').read_bytes()), 'scope': 'Source-only current r7 geometry previously verified in actual packaged Projects; new gate still uses actual package UI.'}, indent=2) + '\n').encode())
for name in ['native.ps1', 'inspect.py']:
    source_path = repo.parent / ('ssok-package-goal-r6-' + name)
    target = repo.parent / ('ssok-package-goal-r10-' + name)
    assert not target.exists()
    code = source_path.read_text(encoding='utf8').replace('package-goal-ui-r6', 'current-package-goal-r10').replace('ssok-package-goal-r6-inspect.py', 'ssok-package-goal-r10-inspect.py')
    target.write_bytes(code.encode())
    (backup / (target.name + '.before-execution')).write_bytes(target.read_bytes())
run = (repo.parent / 'ssok-package-goal-r6-run.py').read_text(encoding='utf8').replace('package-goal-ui-r6', 'current-package-goal-r10').replace('ssok-package-goal-r6-', 'ssok-package-goal-r10-')
run = run.replace("(r/'build/ai-loop-evidence/completion/full-native-final-r2/source-before.json').read_text())['files']", "(b/'contract.json').read_text())['source426']")
run = run.replace("(r/'build/ai-loop-evidence/completion/package-camera-r5/package-inputs.json').read_text()", "(b/'package-inputs.json').read_text()")
run = run.replace("out/'layout.gd',out/'layout-native.json',", "out/'layout.json',")
run = run.replace("str(out/'layout-native.json')", "str(out/'layout.json')")
run = run.replace('import hashlib,json,subprocess,time', 'import hashlib,json,os,subprocess,time')
run = run.replace('p=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)', "p=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,env=dict(os.environ,PYTHONUTF8='1'),creationflags=subprocess.CREATE_NO_WINDOW)")
run = run.replace("'actual_default_packaged_ui':True,", "'actual_default_packaged_ui':True,'process_local_python_utf8':True,'current_pe_pck_bytes_unchanged':all(sha(app.parent/n)==h for n,h in package['exact_export_and_installer_bytes'].items()),")
target = repo.parent / 'ssok-package-goal-r10-run.py'
assert not target.exists()
target.write_bytes(run.encode())
(backup / (target.name + '.before-execution')).write_bytes(target.read_bytes())
print(json.dumps({'head': head, 'package': package, 'prepared_current_package_goal_gate': str(target), 'model_launch_limit': 1}), flush=True)
