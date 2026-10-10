from pathlib import Path
import hashlib, json, msvcrt, os

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
backup = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/world-wheel-hold-r11')
root = repo / 'build/ai-loop-evidence/completion/world-wheel-hold-r11'
read = lambda p: json.loads(p.read_text(encoding='utf8'))
sha = lambda b: hashlib.sha256(b).hexdigest()
contract = read(backup / 'contract.json')
assert all(sha((repo / p).read_bytes()) == h for p, h in contract['source426'].items())
for case in ['stock', 'world-wheel']:
    assert read(root / case / 'receipt.json')['exit_code'] == 0
    assert read(root / case / 'summary.json')['combined'] is False
plan = Path(contract['plan']); old = plan.read_bytes()
assert sha(old) == contract['post_sha256']
(backup / 'plan-integral.before.md').write_bytes(old)
entry = '\n\n<!-- ssok-r11-integral-prediction -->\nR11 single-variable continuation: world-wheel 후보는 영상PASS/거리14.1212cmFAIL·차체각속도감소불명확이라 앱미적용. R9 K16의 상대휠 PI 적분이 housing angular P보정을 상쇄하는지 같은K16/같은observer 두실행을 비교한다. K16reference는원래 r9method; joint-integral은P항(-8relative+16housing)과gain/cap 그대로, 적분error만 relative→relative-2housing으로변경. Prediction1: 상쇄가원인이면signedhousingrate·repeatedpixelspan 감소; Prediction2: contact/solverdrift면rate/spans유지또는settleFAIL; Prediction3: 변동감소에도action경계로combinedFAIL 가능. 앞선 모든goal/source/actor/physics/pose금지·90s·independentStop/PNGs/hash검사 유지. 새gain탐색/production적용0.\n'
data = old + entry.encode('utf8')
with plan.open('r+b', buffering=0) as f:
    n = max(len(old), len(data)) + 1
    msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, n)
    try:
        assert f.read() == old
        f.seek(0); f.write(data); f.truncate(); os.fsync(f.fileno())
    finally:
        f.seek(0); msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, n)
assert plan.read_bytes() == data
contract['post_sha256'] = sha(data)
contract['continuation'] = 'K16 P term unchanged; change only integral error to relative wheel speed minus twice housing-axis rate.'
(backup / 'contract.json').write_text(json.dumps(contract, indent=2) + '\n', encoding='utf8')
source = (repo / 'build/ai-loop-evidence/completion/angular-feedback-r9/angular_loop.gd').read_text(encoding='utf8').replace('DEBUG-r9', 'DEBUG-r11')
(root / 'angular_reference_loop.gd').write_text(source, encoding='utf8')
needle = '+ speed * delta * HOLD_I'
assert source.count(needle) == 1
candidate = source.replace(needle, '+ (speed - 2.0 * motor.housing.angular_velocity.dot(axis)) * delta * HOLD_I')
(root / 'joint_integral_loop.gd').write_text(candidate, encoding='utf8')
probe = (root / 'callback_probe.gd').read_text(encoding='utf8')
probe = probe.replace('["stock", "world-wheel"]', '["angular-reference", "joint-integral"]')
start = probe.index('\tif variant == "world-wheel":')
end = probe.index('\tapp._load_preset', start)
probe = probe[:start] + '\tapp.agent_loop.set_script(load("res://build/ai-loop-evidence/completion/world-wheel-hold-r11/" + ("angular_reference_loop.gd" if variant == "angular-reference" else "joint_integral_loop.gd")))\n\tapp.agent_loop.app = app\n\tapp.agent_loop.controller = app.app_controller\n' + probe[end:]
(root / 'integral_probe.gd').write_text(probe, encoding='utf8')
driver = (repo.parent / 'ssok-control-r11-run.py').read_text(encoding='utf8').replace("{'stock','world-wheel'}", "{'angular-reference','joint-integral'}").replace('callback_probe.gd', 'integral_probe.gd')
driver = driver.replace("root/'world_wheel_loop.gd']", "root/'angular_reference_loop.gd',root/'joint_integral_loop.gd']")
target = repo.parent / 'ssok-control-r11-integral.py'; assert not target.exists()
target.write_text(driver, encoding='utf8')
files = [root / n for n in ['angular_reference_loop.gd', 'joint_integral_loop.gd', 'integral_probe.gd']] + [target]
(backup / 'integral-inputs.json').write_text(json.dumps({str(p): sha(p.read_bytes()) for p in files}, indent=2) + '\n', encoding='utf8')
print(json.dumps({'plan_post_sha256': sha(data), 'candidate_integral_changed_only': True, 'production_applied': False}))
