from pathlib import Path
import hashlib, json, os, subprocess, time

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
backup = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/operator-setup-r14')
out = repo / 'build/ai-loop-evidence/completion/operator-setup-r14/native'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda data: hashlib.sha256(data).hexdigest()
package = read(backup / 'package-receipt.json')
prepared = read(backup / 'setup-receipt.json')
contract = read(backup / 'contract.json')
app = repo / 'build/projects-release-clean-r7/windows/ssok.exe'
root = Path(package['extracted_root'])
assert not (out / 'run-receipt.json').exists()
assert all(sha((root / name).read_bytes()) == digest for name, digest in package['files'].items())
assert prepared['after_check_only_exit'] == 0
cmd = ['powershell.exe', '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', str(repo.parent / 'ssok-operator-r14-native.ps1'),
       '-App', str(app), '-Work', str(out), '-Layout', str(out / 'layout.json'), '-Python', str(repo / 'build/venv-native/Scripts/python.exe'),
       '-Fixture', str(out / 'project.json'), '-OperatorRoot', str(root)]
start = time.monotonic()
process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=dict(os.environ, PYTHONUTF8='1'), creationflags=subprocess.CREATE_NO_WINDOW)
(out / 'owned-driver.json').write_bytes((json.dumps({'pid': process.pid, 'command': cmd}, indent=2) + '\n').encode())
timed_out = False
try:
    log, _ = process.communicate(timeout=415)
except subprocess.TimeoutExpired:
    timed_out = True
    subprocess.run(['taskkill.exe', '/PID', str(process.pid), '/T', '/F'], capture_output=True, timeout=15)
    log, _ = process.communicate(timeout=15)
(out / 'driver.log').write_bytes(log)
changed = [name for name, digest in contract['source426'].items() if sha((repo / name).read_bytes()) != digest]
receipt = {'exit_code': process.returncode, 'seconds': time.monotonic() - start, 'timed_out': timed_out, 'command': cmd,
           'original_source_changed': changed, 'operator_source': package['source_head'], 'operator_zip_sha256': package['sha256'],
           'launcher_python_override': False, 'actor_python': prepared['executable'], 'actor_python_version': prepared['python'],
           'developer_inspection_python_separate': True, 'package_files_unchanged': all(sha((root / name).read_bytes()) == digest for name, digest in package['files'].items()),
           'app_source': 'fa868ca07cdd9d2b8edb27cbab89cd00263c851f', 'app_version': '0.3.1-projects-r7', 'global_goal_complete': False}
(out / 'run-receipt.json').write_bytes((json.dumps(receipt, ensure_ascii=False, indent=2) + '\n').encode())
print(json.dumps(receipt), flush=True)
print(log.decode('utf-8-sig'))
assert not timed_out and process.returncode == 0 and receipt['package_files_unchanged'] and changed == ['tools/ci/build.py']
