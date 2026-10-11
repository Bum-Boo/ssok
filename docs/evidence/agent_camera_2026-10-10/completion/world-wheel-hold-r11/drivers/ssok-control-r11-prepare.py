from pathlib import Path
from datetime import datetime, timezone, timedelta
import hashlib, json, msvcrt, os, subprocess

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
base = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010')
backup = base / 'world-wheel-hold-r11'
root = repo / 'build/ai-loop-evidence/completion/world-wheel-hold-r11'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda d: hashlib.sha256(d).hexdigest()
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip() == '3070d2fe87d73944b2d5b18e190509b25de39003'
assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo)
inputs = read(base / 'current-package-goal-r10/contract.json')['source426']
assert len(inputs) == 426 and all(sha((repo / p).read_bytes()) == h for p, h in inputs.items())
goal = repo / 'docs/evidence/agent_camera_2026-10-10/repeated/refined-visual-goal/plan.json'
assert sha(goal.read_bytes()) == 'd372505d199ce2e2ba4b12588487cafe9e722465b65171ca25fcbf8496f632a4'
assert not backup.exists() and not root.exists()
backup.mkdir(); root.mkdir()
plan = Path('C:/Users/Hojun/Documents/Obsidians/Frieren (arch)/30_Projects/ssok/AI 관측·행동 루프 공동개발 계획.md')
old = plan.read_bytes()
prior = read(base / 'current-package-goal-r10/records/manifest.json')
assert sha(old) == prior[str(plan)]['post_sha256']
(backup / 'plan.before.md').write_bytes(old)
stamp = datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')
entry = '\n\n<!-- ssok-world-wheel-hold-r11 -->\n### 휠 제동 속도 기준의 단일변수 진단 — ' + stamp + '\n\nOutcome: 기존30/10/12 rendered replay의 영상24..38px/독립물리4..14cm 동시 실패를 같은 조건에서 진단한다. 상대 휠속도 대신 월드 휠 축속도만 PI 입력으로 바꾼 ignored per-instance prototype을 stock와 비교한다. P8/I16/cap25/forward25/settle12·240/DriveMotor·torque/graph/camera/physics/goal/평가 문턱/actor입력 불변, pose·velocity 할당0. 새 gain sweep/AI provider 호출0. Allowed: ignored debug fixtures, 외부 실행 helper, 기존 docs/evidence/plan/state. Acceptance: 실제8PNG·SHA/tick, poweredcallbacks30/10/12, 최종pixels/span·Stop독립거리/contact/travel/rest, source426/goal pre/post, 각90s 유한 own-process cleanup. 원래red-loop와 최소화한계는r8/r9 보존. 성공 시에도 반복/회귀/리뷰 전 앱 적용하지 않는다. Next Codex; 실제영상 Astra, 디자인 변경0, 필요Fable기능review/humanmerge. 기존 원본과 generatedtask16/donefalse/7aliases 보존. 전체goal incomplete.\n'
data = old + entry.encode('utf8')
with plan.open('r+b', buffering=0) as f:
    size = max(len(old), len(data)) + 1
    msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, size)
    try:
        assert f.read() == old
        f.seek(0); f.write(data); f.truncate(); os.fsync(f.fileno())
    finally:
        f.seek(0); msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, size)
assert plan.read_bytes() == data
contract = {'head': '3070d2fe87d73944b2d5b18e190509b25de39003', 'plan': str(plan), 'before_sha256': sha(old), 'post_sha256': sha(data), 'source426': inputs, 'frozen_goal_sha256': sha(goal.read_bytes()), 'global_goal_complete': False, 'scope': 'Single PI speed reference: relative wheel to world wheel. Developer prototype only.'}
(backup / 'contract.json').write_text(json.dumps(contract, indent=2) + '\n', encoding='utf8')
hypotheses = [
    {'rank': 1, 'prediction': 'If relative wheel holding permits residual world wheel roll, changing only PI speed reference to world wheel axis rate should lower that residual and capture gap/pixel spans without timeout/contact/Stop regression.'},
    {'rank': 2, 'prediction': 'If chassis/floor constraint drift dominates, wheel world rate may change but chassis pitch rate and pixel span will remain, or stricter holding will fail settling. A one-run gap improvement is not a causal fix.'},
    {'rank': 3, 'prediction': 'If the discrete action boundary independently dominates, unchanged30/10/12 can still fail simultaneous original image/physical thresholds even if holding is steadier.'}]
(backup / 'hypotheses.json').write_text(json.dumps(hypotheses, indent=2) + '\n', encoding='utf8')
source = (repo / 'src/runtime/agent_camera_loop.gd').read_text(encoding='utf8')
start = source.index('func _hold_brake(delta: float) -> void:')
method = source[start:source.index('\n\nfunc _exit_tree()', start)]
needle = '(motor.wheel.angular_velocity - motor.housing.angular_velocity).dot(axis)'
assert method.count(needle) == 1
variant = 'extends "res://src/runtime/agent_camera_loop.gd"\n\n## DEBUG-r11: world wheel speed reference only; original actuator/limits retained.\n' + method.replace(needle, 'motor.wheel.angular_velocity.dot(axis)') + '\n'
(root / 'world_wheel_loop.gd').write_text(variant, encoding='utf8')
oldroot = repo / 'build/ai-loop-evidence/completion/angular-feedback-r9'
for name in ['callback_probe.gd', 'callback_sampler.gd', 'motor_callback.gd']:
    text = (oldroot / name).read_text(encoding='utf8').replace('DEBUG-r9', 'DEBUG-r11').replace('angular-feedback-r9/', 'world-wheel-hold-r11/').replace('angular-k16', 'world-wheel').replace('angular_loop.gd', 'world_wheel_loop.gd')
    if name == 'callback_sampler.gd':
        needle = '"housing_axis_rate": body.angular_velocity.dot(axis),'
        assert text.count(needle) == 1
        text = text.replace(needle, needle + '\n\t\t\t"world_wheel_axis_rate": motor.wheel.angular_velocity.dot(axis),')
    (root / name).write_text(text, encoding='utf8')
driver = (repo.parent / 'ssok-control-r9-angular-v2.py').read_text(encoding='utf8').replace('angular-feedback-r9', 'world-wheel-hold-r11').replace('angular-k16', 'world-wheel').replace('angular_loop.gd', 'world_wheel_loop.gd')
needle = "'assigned_vs_callback_pitch_delta_rad':"
assert driver.count(needle) == 1
driver = driver.replace(needle, "'world_wheel_axis_rates':[[m['world_wheel_axis_rate'] for m in f['angular_pose_sample']['motors']] for f in idle]," + needle)
target = repo.parent / 'ssok-control-r11-run.py'
assert not target.exists()
target.write_text(driver, encoding='utf8')
files = [root / n for n in ['world_wheel_loop.gd', 'callback_probe.gd', 'callback_sampler.gd', 'motor_callback.gd']] + [target]
(backup / 'inputs.json').write_text(json.dumps({str(p): sha(p.read_bytes()) for p in files}, indent=2) + '\n', encoding='utf8')
print(json.dumps({'contract': str(backup / 'contract.json'), 'plan_post_sha256': sha(data), 'stock_command': 'python -X utf8 C:/Users/Hojun/Projects/ssok-control-r11-run.py stock', 'candidate_command': 'python -X utf8 C:/Users/Hojun/Projects/ssok-control-r11-run.py world-wheel'}))
