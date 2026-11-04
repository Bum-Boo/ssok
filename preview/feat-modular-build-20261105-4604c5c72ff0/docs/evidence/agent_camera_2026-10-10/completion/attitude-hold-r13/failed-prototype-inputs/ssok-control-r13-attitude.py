from pathlib import Path
import hashlib,json,msvcrt,os
repo=Path('C:/Users/Hojun/Projects/ssok-ai-loop');backup=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/attitude-hold-r13');root=repo/'build/ai-loop-evidence/completion/attitude-hold-r13'
read=lambda p:json.loads(p.read_text(encoding='utf8'));sha=lambda b:hashlib.sha256(b).hexdigest();contract=read(backup/'contract.json')
baseline=read(root/'stock/summary.json');assert baseline['combined'] is False and baseline['floor_pixels']==[23,25,27,23,23]
assert all(sha((repo/n).read_bytes())==h for n,h in contract['source426'].items())
plan=Path(contract['plan']);old=plan.read_bytes();assert sha(old)==contract['post_sha256'];(backup/'plan.before-latch-clarification.md').write_bytes(old)
entry='\n\nR13試験前clarification: referenceは各actual frame_readyの車体姿勢をlatchし、次のaccepted forwardで無効化する。前進後は元のPIで実測settle/captureしてから新referenceをlatchする。最初の姿勢へ戻すと既存画像との差を意図的に増やすため、その方式は試験せず、カメラを待つ間の観測済み姿勢保持に限定。Bodyanglefeedback係数16固定/P8I16/cap25/forward25/同じmotor/settlecriteria、camera/物理pose直接変更0。これは原goal成功の保証ではない。\n'
data=old+entry.encode()
with plan.open('r+b',buffering=0) as stream:
    size=max(len(old),len(data))+1;msvcrt.locking(stream.fileno(),msvcrt.LK_NBLCK,size)
    try:assert stream.read()==old;stream.seek(0);stream.write(data);stream.truncate();os.fsync(stream.fileno())
    finally:stream.seek(0);msvcrt.locking(stream.fileno(),msvcrt.LK_UNLCK,size)
assert plan.read_bytes()==data;contract['post_sha256']=sha(data);contract['reference_scope']='Latch current measured body orientation at each frame_ready; invalidate on accepted forward; preserve ordinary settling before new capture.'
(backup/'contract.json').write_bytes((json.dumps(contract,indent=2)+'\n').encode())
hypotheses=[{'rank':1,'prediction':'If residual body-attitude change during camera/model latency dominates pixel jitter, adding a single fixed16 proportional world-quaternion attitude term through existing finite motor duty should lower signed body-rate and last-five pixel span.'},{'rank':2,'prediction':'If discrete action boundary dominates the simultaneous benchmark, the same30/10/12 can still fail image24..38 and physical4..14cm even with steadier pose; that is not a repair.'},{'rank':3,'prediction':'If graph/contact constraints dominate, finite motor correction will not reduce attitude drift or will worsen settling/timeout; no gain sweep follows this pair.'}]
(backup/'hypotheses.json').write_bytes((json.dumps(hypotheses,indent=2)+'\n').encode())
source=(repo/'src/runtime/agent_camera_loop.gd').read_text(encoding='utf8');start=source.index('func _hold_brake(delta: float) -> void:');method=source[start:source.index('\n\nfunc _exit_tree()',start)]
needle='\tfor motor: DriveMotor in _channels:';assert method.count(needle)==1
setup='''\tif not frame_ready.is_connected(_latch_observed_attitude):
\t\tframe_ready.connect(_latch_observed_attitude)
\t\tevent_recorded.connect(_invalidate_observed_attitude)
\tvar body: RigidBody3D = app.run_mode.bodies[_part]
\tvar error_vector: Vector3 = Vector3.ZERO
\tif _attitude_bound:
\t\tvar error: Quaternion = body.global_basis.get_rotation_quaternion() * _observed_attitude.inverse()
\t\terror_vector = Vector3(error.x, error.y, error.z) * (2.0 if error.w >= 0.0 else -2.0)
'''
method=method.replace(needle,setup+needle)
needle='clampf(-speed * HOLD_P - integral, -25.0, 25.0)';assert method.count(needle)==1
method=method.replace(needle,'clampf(-speed * HOLD_P - integral + error_vector.dot(axis) * 16.0, -25.0, 25.0)')
prefix='''extends "res://src/runtime/agent_camera_loop.gd"

## DEBUG-r13: preserve last measured attitude during latency through finite graph motors only.
var _observed_attitude: Quaternion = Quaternion()
var _attitude_bound: bool = false

func _latch_observed_attitude(_png: PackedByteArray, _metadata: Dictionary) -> void:
\t_observed_attitude = app.run_mode.bodies[_part].global_basis.get_rotation_quaternion()
\t_attitude_bound = true

func _invalidate_observed_attitude(event: Dictionary) -> void:
\tif event.get("tool") == "drive_step" and event.get("result") == "accepted" and event.args.action == "forward":
\t\t_attitude_bound = false

func cancel(reason: String) -> void:
\t_attitude_bound = false
\tsuper.cancel(reason)

'''
target=root/'attitude_loop.gd';assert not target.exists();target.write_bytes((prefix+method+'\n').encode())
driver=repo.parent/'ssok-control-r13-run.py';old=driver.read_bytes();(backup/'runner.before-candidate.py').write_bytes(old)
value=old.decode();needle="root/'motor_callback.gd']";assert value.count(needle)==1
value=value.replace(needle,"root/'motor_callback.gd'] + ([root/'attitude_loop.gd'] if case == 'attitude-hold' else [])")
driver.write_bytes(value.encode())
files=[target,driver,Path(__file__)]
(backup/'candidate-inputs.json').write_bytes((json.dumps({str(p):sha(p.read_bytes()) for p in files},indent=2)+'\n').encode())
print(json.dumps({'candidate_prepared':True,'body_pose_setters':0,'single_feedback_coefficient':16,'production_changed':False,'reference_scope':contract['reference_scope']}))
