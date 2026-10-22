from pathlib import Path
from datetime import datetime, timezone, timedelta
import hashlib
import json
import msvcrt
import os
import subprocess

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
base = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010')
out = base / 'angular-feedback-r9'
root = repo / 'build/ai-loop-evidence/completion/angular-feedback-r9'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda b: hashlib.sha256(b).hexdigest()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip()
assert head == 'f86fadd184129f88ced525c6def2a0ca574cc0ae'
assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo)
assert read(base / 'control-feedback-r8/closeout.json')['bounded_diagnostic_milestone_recorded']
source = read(base / 'control-feedback-r8/contract.json')['source426']
assert len(source) == 426 and all(sha((repo / n).read_bytes()) == h for n, h in source.items())
assert not out.exists() and not root.exists()
out.mkdir()
root.mkdir()
plan = Path('C:/Users/Hojun/Documents/Obsidians/Frieren (arch)/30_Projects/ssok/AI 관측·행동 루프 공동개발 계획.md')
old = plan.read_bytes()
previous = read(base / 'control-feedback-r8/records/manifest.json')[str(plan)]
assert sha(old) == previous['post_sha256']
(out / 'plan.before.md').write_bytes(old)
stamp = datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')
entry = '\n\n<!-- ssok-angular-feedback-r9 -->\n### 차체 각속도의 모터 제동 진단 — ' + stamp + '\n\nOutcome: original30/10/12 실제 rendered loop의 jitter4px 및 frozen image24..38px/physical4..14cm 동시 실패를 줄일 수 있는지 확인한다. r8의 원래 red-capable replay와 최소화 한계(두 구간으로 줄이면 증상 불보존)를 유지한다. 먼저 읽기 전용 actual motor/frame_ready pitch-rate 관측 stock를 실행하고, 같은 계측에서 housing angular_velocity dot motor axis의 제동항만 K0→16 (%duty per rad/s)으로 바꾼 단일변수 developer prototype을 비교한다. 상대 휠속도 P8/I16, 전체25% cap, 원래모터callback/torque/physics/camera/pose/velocity/goals/evaluator/action25%/settle12ticks240bound를 보존한다. 내부 기존 body angular_velocity만 읽으며 distance/contact/rotation target/hidden evaluator data를 actor 입력이나 controller에 전달하지 않는다. No production app change until causal evidence and actual regression seam. Allowed: ignored debug fixtures and outside helper, evidence/docs/current existing plan/state records. No visual-layout/provider/package/main/publish change. Acceptance: actual rendered original8PNGs, exact motor callbacks30/10/12, SHA/tick frame_ready pose/rate binding with request/callback distinction, pixel span/independent Stop physical both, finite90s owned cleanup, source426/goal/camera hashes. Separate diagnostic completion from combined pass and AI reliability. Owner Codex; actualimages Astra, no design change; eventual Fable integration review/humanmerge. Generatedtaskrev16/donefalse7aliases untouched; r8 raw283/r7raw277 immutable.\n'
data = old + entry.encode('utf8')
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
contract = {'head': head, 'plan': str(plan), 'before_sha256': sha(old), 'post_sha256': sha(data), 'source426': source, 'scope': 'Single motor-only housing angular damping per-instance developer probe; camera/physics/evaluator/goal/actor inputs frozen', 'global_goal_complete': False}
(out / 'contract.json').write_bytes((json.dumps(contract, indent=2) + '\n').encode())
hypotheses = [
    {'rank': 1, 'prediction': 'If residual chassis pitch drives camera jitter, adding motor-only positive housing-axis angular feedback K16 at unchanged PI/cap should reduce absolute pitch rate and original4px repeated-capture span without settle/physical/contact regression.'},
    {'rank': 2, 'prediction': 'If capture request/render timing dominates, actual pitch rate can reduce while camera transform versus frame_ready chassis pose mismatch and pixel span remain.'},
    {'rank': 3, 'prediction': 'If discrete action resolution remains independent, jitter may reduce but unchanged30/10/12 still misses physical14cm/image simultaneous goal. Do not relax the goal or read distance into control.'}]
(out / 'hypotheses.json').write_bytes((json.dumps(hypotheses, indent=2) + '\n').encode())

method_source = (repo / 'src/runtime/agent_camera_loop.gd').read_text(encoding='utf8')
start = method_source.index('func _hold_brake(delta: float) -> void:')
end = method_source.index('\n\nfunc _exit_tree()', start)
method = method_source[start:end]
needle = '-speed * HOLD_P - integral'
assert method.count(needle) == 1
variant = 'extends "res://src/runtime/agent_camera_loop.gd"\n\n## DEBUG-r9: motor-only housing angular damping; PI/25% cap/physical actuator unchanged.\n' + method.replace(needle, needle + ' + motor.housing.angular_velocity.dot(axis) * 16.0') + '\n'
(root / 'angular_loop.gd').write_bytes(variant.encode())
oldroot = repo / 'build/ai-loop-evidence/completion/control-feedback-r8'
probe = (oldroot / 'callback_probe.gd').read_text(encoding='utf8').replace('DEBUG-r8', 'DEBUG-r9').replace('control-feedback-r8/', 'angular-feedback-r9/')
probe = probe.replace('variant != "motor-callback-trace"', 'variant not in ["stock", "angular-k16"]')
probe = probe.replace('variant == "strict-angle"', 'variant == "angular-k16"').replace('strict_angle_loop.gd', 'angular_loop.gd')
probe = probe.replace('var tape: Array[int] = [30, 10, 12, 1]', 'var tape: Array[int] = [30, 10, 12]')
probe = probe.replace('"action": "brake" if index == 3 and variant == "action-brake" else "forward"', '"action": "forward"')
probe = probe.replace('"commands": sampler.commands, "tick_rows": sampler.rows,', '"commands": sampler.commands, "tick_rows": sampler.rows, "frame_samples": sampler.frame_samples,')
(root / 'callback_probe.gd').write_bytes(probe.encode())
sampler = (oldroot / 'callback_sampler.gd').read_text(encoding='utf8').replace('DEBUG-r8', 'DEBUG-r9')
sampler = sampler.replace('var active: bool = false', 'var active: bool = false\nvar frame_samples: Array[Dictionary] = []')
sampler = sampler.replace('app.agent_loop.event_recorded.connect(_event)', 'app.agent_loop.event_recorded.connect(_event)\n\tapp.agent_loop.frame_ready.connect(_frame)')
sampler += '''
func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]

func _frame(_png: PackedByteArray, metadata: Dictionary) -> void:
	var body: RigidBody3D = app.run_mode.bodies[app.agent_loop._part]
	var motor_samples: Array[Dictionary] = []
	for motor: DriveMotor in app.agent_loop._channels:
		var axis: Vector3 = (motor.housing.global_basis * motor.axis_local).normalized()
		motor_samples.append({"axis": _vector(axis), "housing_axis_rate": body.angular_velocity.dot(axis),
			"duty": motor.duty, "torque_nm": motor.applied_torque_nm})
	var camera_pose: Transform3D = app.agent_loop._camera.global_transform
	var implied_body: Transform3D = camera_pose * app.agent_loop._mount.affine_inverse()
	frame_samples.append({"sha256": metadata.sha256, "physics_tick": Engine.get_physics_frames(),
		"capture_requested_tick": metadata.capture_requested_tick,
		"callback_body_position": _vector(body.global_position), "callback_body_rotation": _vector(body.global_rotation),
		"callback_body_angular_velocity": _vector(body.angular_velocity),
		"render_assigned_body_position": _vector(implied_body.origin),
		"render_assigned_body_rotation": _vector(implied_body.basis.get_euler()),
		"motors": motor_samples,
		"scope": "Actual assigned camera pose versus later frame_ready body; no claim of identical moments."})
'''
(root / 'callback_sampler.gd').write_bytes(sampler.encode())
motor = (oldroot / 'motor_callback.gd').read_text(encoding='utf8').replace('DEBUG-r8', 'DEBUG-r9')
motor = motor.replace('var actual_duty: float = duty', 'var actual_duty: float = duty\n\tvar housing_axis_rate: float = housing.angular_velocity.dot((housing.global_basis * axis_local).normalized())')
motor = motor.replace('"speed_rad_s": measured_rad_s}', '"speed_rad_s": measured_rad_s, "housing_axis_rate_before": housing_axis_rate}')
(root / 'motor_callback.gd').write_bytes(motor.encode())
driver = (repo.parent / 'ssok-control-r8-callback.py').read_text(encoding='utf8').replace('control-feedback-r8', 'angular-feedback-r9')
driver = driver.replace("{'motor-callback-trace'}", "{'stock','angular-k16'}").replace("len(result['frames'])==9", "len(result['frames'])==8")
driver = driver.replace("root/'motor_callback.gd']", "root/'motor_callback.gd',root/'angular_loop.gd']")
driver = driver.replace("e=result['evaluation'];", "assert len(result['frame_samples'])==8\nfor frame,sample in zip(result['frames'],result['frame_samples']):\n    assert frame['png_sha256']==sample['sha256'] and frame['metadata']['physics_tick']==sample['physics_tick']\n    frame['angular_pose_sample']=sample\ncounts=[[sum(1 for row in motor if row['command_index']==index and abs(row['applied_duty']-.25)<1e-12) for motor in result['actual_motor_callbacks']] for index in range(3)]\nassert counts==[[30,30],[10,10],[12,12]],counts\ne=result['evaluation'];")
driver = driver.replace("'physical':physical,", "'actual_motor_counts':counts,'signed_housing_axis_rates':[[m['housing_axis_rate'] for m in f['angular_pose_sample']['motors']] for f in idle],'assigned_vs_callback_pitch_delta_rad':[f['angular_pose_sample']['callback_body_rotation'][2]-f['angular_pose_sample']['render_assigned_body_rotation'][2] for f in idle],'physical':physical,")
target = repo.parent / 'ssok-control-r9-angular.py'
assert not target.exists()
target.write_bytes(driver.encode())
files = [root / name for name in ['angular_loop.gd', 'callback_probe.gd', 'callback_sampler.gd', 'motor_callback.gd']] + [target]
for path in files:
    (out / (path.name + '.before-execution')).write_bytes(path.read_bytes())
(out / 'inputs.json').write_bytes((json.dumps({'files': {str(p): sha(p.read_bytes()) for p in files}, 'stock_and_candidate_same_observers': True, 'production_applied': False}, indent=2) + '\n').encode())
print(json.dumps({'head': head, 'plan_post_sha256': sha(data), 'stock_command': 'python -X utf8 C:/Users/Hojun/Projects/ssok-control-r9-angular.py stock', 'candidate_command': 'python -X utf8 C:/Users/Hojun/Projects/ssok-control-r9-angular.py angular-k16'}), flush=True)
