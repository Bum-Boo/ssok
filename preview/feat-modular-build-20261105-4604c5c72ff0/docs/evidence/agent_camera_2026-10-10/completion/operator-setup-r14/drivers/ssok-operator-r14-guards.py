from pathlib import Path
import hashlib, json, os, shutil, subprocess, sys

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
backup = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/operator-setup-r14')
runtime = repo / 'build/ai-loop-evidence/completion/operator-setup-r14/guards'
runtime.mkdir(exist_ok=False)
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda data: hashlib.sha256(data).hexdigest()
package = read(backup / 'package-receipt.json')
prepared = read(backup / 'setup-receipt.json')
root = Path(package['extracted_root'])
python = Path(prepared['executable'])
checks = []
env = dict(os.environ, PATH='')
env.pop('PYTHONPATH', None)
result = subprocess.run([str(python), '-X', 'utf8', '-c', 'from pathlib import Path;from tools.app_control.source_identity import source_head;print(source_head(Path.cwd()))'], cwd=root, env=env, capture_output=True, timeout=15)
assert result.returncode == 0 and result.stdout.decode().strip() == package['source_head']
checks.append({'name': 'Actual archive source identity with no Git executable on PATH', 'passed': True})
env = dict(os.environ)
env.pop('SSOK_AGENT_TOKEN', None)
result = subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(root / 'tools/app_control/start-operator.ps1'), '-Out', str(runtime / 'must-not-create')], cwd=repo, env=env, capture_output=True, timeout=60)
(runtime / 'missing-token.stdout').write_bytes(result.stdout)
(runtime / 'missing-token.stderr').write_bytes(result.stderr)
assert result.returncode == 1 and b'FIX: token' in result.stdout and not (runtime / 'must-not-create').exists()
checks.append({'name': 'Actual default local-Python launcher refuses missing token before app polling/model launch', 'passed': True})
def clone(name):
    target = runtime / name
    assert not target.exists() and target.resolve().is_relative_to(runtime.resolve())
    target.mkdir()
    for entry in package['files']:
        path = target / entry
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / entry, path)
    return target
changed = clone('changed-doctor')
with (changed / 'tools/app_control/doctor.py').open('ab') as stream:
    stream.write(b'\n# Intentionally altered identity test fixture.\n')
result = subprocess.run([str(python), '-X', 'utf8', '-m', 'tools.app_control.doctor', '--json'], cwd=changed, capture_output=True, timeout=30)
classified = json.loads(result.stdout)
assert result.returncode == 1 and not classified['ready']
assert [row['id'] for row in classified['checks']] == ['python', 'source']
(runtime / 'changed-doctor.json').write_bytes(result.stdout)
checks.append({'name': 'Actual altered doctor module is rejected before MCP/account probes', 'passed': True})
invalid = clone('invalid-existing-venv')
folder = invalid / '.operator-venv'
folder.mkdir()
sentinel = folder / 'preserve-this-file.txt'
sentinel.write_bytes(b'Existing user folder is not a Python environment.\n')
result = subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(invalid / 'tools/app_control/setup-operator.ps1')], cwd=repo, capture_output=True, timeout=30)
(runtime / 'invalid-venv.stdout').write_bytes(result.stdout)
(runtime / 'invalid-venv.stderr').write_bytes(result.stderr)
assert result.returncode != 0 and b'Preserve it and extract to a fresh directory' in result.stderr
assert sentinel.read_bytes() == b'Existing user folder is not a Python environment.\n'
assert not (folder / 'pyvenv.cfg').exists()
checks.append({'name': 'Actual setup preserves an existing non-environment folder and refuses installation', 'passed': True})
guard = repo / '.operator-package-guard-r14'
output = repo / 'build/operator-guard-r14-must-not-create.zip'
assert not guard.exists() and not output.exists() and guard.resolve().parent == repo.resolve()
try:
    guard.write_bytes(b'Owned temporary package guard fixture.\n')
    result = subprocess.run([sys.executable, '-X', 'utf8', '-m', 'tools.ci.operator_package', '--out', str(output)], cwd=repo, capture_output=True, timeout=15)
    assert result.returncode != 0 and b'Commit operator inputs' in result.stderr and not output.exists()
finally:
    assert guard.read_bytes() == b'Owned temporary package guard fixture.\n'
    guard.unlink()
checks.append({'name': 'Actual dirty checkout refuses package generation', 'passed': True})
assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo)
repeat = repo / 'build/ssok-0.2.0-operator-r14-determinism.zip'
result = subprocess.run([sys.executable, '-X', 'utf8', '-m', 'tools.ci.operator_package', '--out', str(repeat)], cwd=repo, capture_output=True, timeout=30)
assert result.returncode == 0 and sha(repeat.read_bytes()) == package['sha256']
checks.append({'name': 'Two clean operator builds have identical ZIP bytes', 'passed': True})
cfg = root / '.operator-venv/pyvenv.cfg'
before_cfg = cfg.read_bytes()
before_python = sha(python.read_bytes())
result = subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(root / 'tools/app_control/setup-operator.ps1')], cwd=repo, capture_output=True, timeout=120)
(backup / 'repeat-setup.private.stdout').write_bytes(result.stdout)
(backup / 'repeat-setup.private.stderr').write_bytes(result.stderr)
assert result.returncode == 0 and cfg.read_bytes() == before_cfg and sha(python.read_bytes()) == before_python
assert all(sha((root / name).read_bytes()) == digest for name, digest in package['files'].items())
checks.append({'name': 'Actual repeated setup reuses local environment and preserves interpreter/config and package bytes', 'passed': True})
receipt = {'checks': checks, 'passed': len(checks), 'failed': 0, 'model_calls': 0, 'app_launches': 0, 'killed_processes': 0}
(backup / 'archive-checks.json').write_bytes((json.dumps(receipt, indent=2) + '\n').encode())
print(json.dumps({'passed': len(checks), 'failed': 0, 'model_calls': 0}))
