from pathlib import Path
import ast, hashlib, json, os, subprocess, sys, zipfile

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
backup = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/operator-setup-r14')
runtime = repo / 'build/ai-loop-evidence/completion/operator-setup-r14'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda data: hashlib.sha256(data).hexdigest()
contract = read(backup / 'contract.json')
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip() == contract['head']
assert sha((repo / 'tools/app_control/run_goal.py').read_bytes()) == contract['source426']['tools/app_control/run_goal.py']
changed = [name for name, digest in contract['source426'].items() if sha((repo / name).read_bytes()) != digest]
assert changed == ['tools/ci/build.py'], changed
assert sha((repo / 'docs/evidence/agent_camera_2026-10-10/repeated/refined-visual-goal/plan.json').read_bytes()) == contract['frozen_goal_sha256']
# Classify the old notice allowlist failure using the actual test and historical source.
sys.path.insert(0, str(repo))
from tools.ci import build
from tests.test_release_documents import ReleaseDocumentsTest
from unittest import TestResult
from unittest.mock import patch
old_build = subprocess.check_output(['git', 'show', contract['head'] + ':tools/ci/build.py'], cwd=repo)
original = next(ast.literal_eval(node.value) for node in ast.parse(old_build).body if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == 'DOCUMENTATION_REFERENCES' for target in node.targets))
result = TestResult()
with patch.object(build, 'DOCUMENTATION_REFERENCES', original):
    ReleaseDocumentsTest('test_documentation_links_survive_packaging_and_extraction').run(result)
assert len(result.failures) == 1 and not result.errors and 'OPERATOR.md' in result.failures[0][1]
(backup / 'notice-before.log').write_bytes(result.failures[0][1].encode())
# A narrowly extended allowlist copies only the already-linked Markdown document.
assert len(build.DOCUMENTATION_REFERENCES) == len(original) + 1
assert set(build.DOCUMENTATION_REFERENCES) - set(original) == {'tools/app_control/OPERATOR.md'}
checks = []
python = repo / 'build/venv-native/Scripts/python.exe'
commands = [
    [str(python), '-X', 'utf8', '-m', 'unittest', 'tests.desktop_client_check', 'tests.desktop_session_check', 'tests.test_operator_release', 'tests.test_operator_doctor', 'tests.test_release_documents', '-v'],
    [str(python), '-X', 'utf8', '-m', 'unittest', 'discover', '-s', 'tools/docs', '-p', 'test_*.py'],
    [str(python), '-X', 'utf8', 'tools/docs/maintain.py', '--check'],
]
for index, command in enumerate(commands):
    result = subprocess.run(command, cwd=repo, env=dict(os.environ, PYTHONUTF8='1'), capture_output=True, timeout=120)
    log = backup / ('check-' + str(index) + '.log')
    log.write_bytes(result.stdout + result.stderr)
    checks.append({'command': command, 'exit_code': result.returncode, 'log': str(log), 'sha256': sha(log.read_bytes())})
    (backup / 'checks.json').write_bytes((json.dumps(checks, indent=2) + '\n').encode())
    assert result.returncode == 0, str(log)
files = ['.gitignore', 'tools/app_control/doctor.py', 'tools/app_control/setup-operator.ps1', 'tools/app_control/start-operator.ps1',
         'tools/app_control/source_identity.py', 'tools/app_control/OPERATOR.md', 'tools/ci/operator_package.py', 'tools/ci/build.py',
         'tests/test_operator_doctor.py', 'tests/test_operator_release.py', 'docs/BUILD.md', 'docs/adr/0029-rendered-desktop-agent-camera-loop.md']
subprocess.run(['git', 'add', '--', *files], cwd=repo, check=True)
subprocess.run(['git', '-c', 'core.whitespace=cr-at-eol', 'diff', '--cached', '--check'], cwd=repo, check=True)
subprocess.run(['git', '-c', 'user.name=Bum-Boo', '-c', 'user.email=bumboo500y@gmail.com', 'commit', '-m', 'Add local operator setup and preparation checks\n\nAgent: codex'], cwd=repo, check=True, capture_output=True)
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip()
assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo)
archive = repo / 'build/ssok-0.2.0-operator-r14.zip'
result = subprocess.run([sys.executable, '-X', 'utf8', '-m', 'tools.ci.operator_package', '--out', str(archive)], cwd=repo, capture_output=True, timeout=30)
assert result.returncode == 0, result.stderr.decode('utf8')
package = json.loads(result.stdout)
root = Path('C:/Users/Hojun/Projects/ssok operator r14') / '\uC2E4\uD589 \uC900\uBE44'
assert not root.exists()
root.mkdir(parents=True)
with zipfile.ZipFile(archive) as bundle:
    assert len(bundle.namelist()) == 14 and set(bundle.namelist()) == set(package['files'])
    assert all(not Path(name).is_absolute() and '..' not in Path(name).parts for name in bundle.namelist())
    bundle.extractall(root)
assert all(sha((root / name).read_bytes()) == digest for name, digest in package['files'].items())
package['extracted_root'] = str(root)
package['entries'] = 14
(backup / 'package-receipt.json').write_bytes((json.dumps(package, ensure_ascii=False, indent=2) + '\n').encode())
proof = {'head': head, 'unchanged_original_inputs': 425, 'changed_original_inputs': changed,
         'godot_actor_prompt_command_frozen_goal_unchanged': True, 'new_packaged_module_count': 8,
         'documentation_allowlist_addition_only': 'tools/app_control/OPERATOR.md',
         'full_discovery_first_failure': '40 tests, release-notice link failure1, POSIX-platform skip1',
         'actual_historical_notice_allowlist_repro_failures': 1, 'global_goal_complete': False}
(backup / 'implementation-proof.json').write_bytes((json.dumps(proof, indent=2) + '\n').encode())
print(json.dumps({'operator_source': head, 'archive_entries': 14, 'zip_sha256': package['sha256'], 'extracted_root': str(root), 'checks': len(checks)}), flush=True)
cmd = ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(root / 'tools/app_control/start-operator.ps1'), '-CheckOnly']
result = subprocess.run(cmd, cwd=repo, capture_output=True, timeout=60)
(runtime / 'check-only-before.stdout').write_bytes(result.stdout)
(runtime / 'check-only-before.stderr').write_bytes(result.stderr)
assert result.returncode == 1 and b'The selected Python has no MCP SDK' in result.stdout
assert not (root / '.operator-venv').exists()
cmd = ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(root / 'tools/app_control/setup-operator.ps1')]
result = subprocess.run(cmd, cwd=repo, capture_output=True, timeout=240)
# Installation log stays private; public receipt contains classification and exact module hashes.
(backup / 'setup.private.stdout').write_bytes(result.stdout)
(backup / 'setup.private.stderr').write_bytes(result.stderr)
assert result.returncode == 0, 'Inspect private setup log before retrying.'
cmd = ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(root / 'tools/app_control/start-operator.ps1'), '-CheckOnly']
result = subprocess.run(cmd, cwd=repo, capture_output=True, timeout=60)
(runtime / 'check-only-after.stdout').write_bytes(result.stdout)
(runtime / 'check-only-after.stderr').write_bytes(result.stderr)
assert result.returncode == 0 and b'Existing Codex ChatGPT login is available' in result.stdout
local_python = root / '.operator-venv/Scripts/python.exe'
result = subprocess.run([str(local_python), '-X', 'utf8', '-c', 'import json,sys,importlib.metadata;print(json.dumps({"python":sys.version,"executable":sys.executable,"mcp":importlib.metadata.version("mcp")}))'], cwd=repo, capture_output=True, timeout=15)
assert result.returncode == 0
prepared = json.loads(result.stdout)
assert prepared['mcp'] == '2.2.0' and prepared['python'].startswith('3.13.3') and Path(prepared['executable']).resolve() == local_python.resolve()
result = subprocess.run([sys.executable, '-X', 'utf8', '-c', 'import importlib.util;raise SystemExit(0 if importlib.util.find_spec("mcp") is None else 1)'], cwd=repo, capture_output=True, timeout=15)
assert result.returncode == 0
prepared.update({'explicit_local_setup_exit': 0, 'before_check_only_exit': 1, 'after_check_only_exit': 0, 'default_python_still_missing_mcp': True, 'app_or_model_launches_in_setup_or_doctor': 0, 'sign_in_started': False, 'raw_login_output_recorded': False})
(backup / 'setup-receipt.json').write_bytes((json.dumps(prepared, ensure_ascii=False, indent=2) + '\n').encode())
print(json.dumps(prepared, ensure_ascii=False), flush=True)
