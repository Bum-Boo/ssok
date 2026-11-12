from pathlib import Path
import hashlib,json,subprocess

repo=Path('C:/Users/Hojun/Projects/ssok-ai-loop')
root=repo/'build/ai-loop-evidence/completion/attitude-latch-r17'
backup=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/attitude-latch-r17')
read=lambda p:json.loads(p.read_text(encoding='utf8'))
sha=lambda b:hashlib.sha256(b).hexdigest()
baseline=read(root/'k32/summary.json')
assert not baseline['combined']
assert read(root/'k32/target-check.json')['passed'] is False
contract=read(backup/'contract.json')
assert all(sha((repo/n).read_bytes())==h for n,h in (contract['source426']|contract['extra_operator7']).items())
hypotheses=[
 {'rank':1,'prediction':'If unbinding reference during accepted forward and latching only after settling preserves a braking-induced tilt, retaining the valid immediately preceding observation through settling (prior) should change settled angle/pixels and reach original joint24..38px/4..14cm without gain changes. No improvement falsifies this repair prediction.'},
 {'rank':2,'prediction':'If the preceding observed attitude conflicts with new inertial/contact conditions, prior may worsen image/gap or time out. Latching once at actual powered-forward brake entry (brake) tests the phase boundary instead, with identical32/P8I16/caps and no pose setter.'},
 {'rank':3,'prediction':'If later contact dynamics or post-Stop release dominates, both reference policies can change the active-hold pose yet retain joint failure; retain last-frame-to-Stop displacement and reject the policies rather than relax targets.'}
]
(backup/'hypotheses.json').write_bytes((json.dumps(hypotheses,indent=2)+'\n').encode())
template=root/'attitude-k32.gd'; original=template.read_text(encoding='utf8')
assert original.count('\t\t_attitude_bound = false')==1
prior=original.replace('\t\t_attitude_bound = false\n','')
prior=prior.replace('preserve last measured attitude during latency through finite graph motors only.','keep prior observed attitude through forward settling; finite graph motors only.')
brake=original.replace('preserve last measured attitude during latency through finite graph motors only.','latch actual powered-forward brake-entry attitude; finite graph motors only.')
anchor='func cancel(reason: String = "local_stop") -> void:'
method='''func _start_settle() -> void:
	if enabled and state == "driving" and _forward_driving and _remaining <= 0:
		_observed_attitude = app.run_mode.bodies[_part].global_basis.get_rotation_quaternion()
		_attitude_bound = true
		debug_latches.append({"reason": "brake_entry", "tick": Engine.get_physics_frames(), "frame_id": frame_id, "rotation": app.run_mode.bodies[_part].global_rotation, "bound": _attitude_bound})
	super._start_settle()

'''
assert brake.count(anchor)==1
brake=brake.replace(anchor,method+anchor)
records=[]
for case,value in [('prior',prior),('brake',brake)]:
 path=root/('attitude-'+case+'.gd'); assert not path.exists(); path.write_bytes(value.encode())
 cmd=[str(repo/'build/toolchain-windows/Godot_v4.7.2-stable_win64_console.exe'),'--headless','--path',str(repo),'--script',path.relative_to(repo).as_posix(),'--check-only']
 result=subprocess.run(cmd,cwd=repo,capture_output=True,timeout=30)
 (backup/(case+'-preflight.log')).write_bytes(result.stdout+result.stderr)
 row={'case':case,'reference_policy':case,'coefficient32_unchanged':True,'housing_rate_coefficient':0,'motor_feedback_law_unchanged':True,'prototype_sha256':sha(path.read_bytes()),'template_sha256':sha(template.read_bytes()),'command':cmd,'exit_code':result.returncode,'production_applied':False}
 records.append(row)
 (backup/'candidate-inputs.json').write_bytes((json.dumps(records,indent=2)+'\n').encode())
 assert result.returncode==0, row
print(json.dumps(records))
