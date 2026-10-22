from pathlib import Path
import hashlib, json, subprocess

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
backup = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/attitude-rate-r16')
root = repo/'build/ai-loop-evidence/completion/attitude-rate-r16'
read = lambda p: json.loads(p.read_text(encoding='utf8'))
sha = lambda b: hashlib.sha256(b).hexdigest()
baseline = read(root/'k32/summary.json')
assert not baseline['combined'] and baseline['last_image'] and not baseline['physical']
contract = read(backup/'contract.json')
assert all(sha((repo/n).read_bytes()) == h for n,h in (contract['source426']|contract['extra_operator7']).items())
hypotheses = [
    {'rank':1,'prediction':'If angle holding and angular-rate correction complement each other, adding fixed housing-axis rate16 to unchanged attitude32 should retain final image24..38 while improving physical4..14cm/travel/contact/rest/Stop; lower body-rate/span would support but not prove damping.'},
    {'rank':2,'prediction':'If the terms conflict through wheel/contact coupling, the combination may worsen image/spans or settling despite a changed final gap; reject rather than tune more gains.'},
    {'rank':3,'prediction':'If post-Stop ownership release dominates, camera-time pose/rate changes need not improve the final independent gap; separately retain last-frame-to-Stop displacement and fail the unchanged joint target.'}
]
(backup/'hypotheses.json').write_bytes((json.dumps(hypotheses,indent=2)+'\n').encode())
template = root/'attitude-k32.gd'; text = template.read_text(encoding='utf8')
needle = 'error_vector.dot(axis) * 32.0'
assert text.count(needle) == 1 and 'motor.housing.angular_velocity.dot(axis)' not in text
text = text.replace(needle,needle+' + motor.housing.angular_velocity.dot(axis) * 16.0')
text = text.replace('preserve last measured attitude during latency through finite graph motors only.', 'hold observed attitude and add housing-rate correction through finite graph motors only.')
text = text.replace('# wheel-speed feedback through the existing motors, never body/scene overrides.', '# wheel-speed, attitude and housing-rate feedback; never body/scene overrides.')
target = root/'attitude-combined.gd'; assert not target.exists(); target.write_bytes(text.encode())
command = [str(repo/'build/toolchain-windows/Godot_v4.7.2-stable_win64_console.exe'),'--headless','--path',str(repo),'--script',target.relative_to(repo).as_posix(),'--check-only']
result = subprocess.run(command,cwd=repo,capture_output=True,timeout=30)
(backup/'combined-preflight.log').write_bytes(result.stdout+result.stderr)
record = {'attitude_coefficient':32,'added_housing_rate_coefficient':16,'prototype_sha256':sha(target.read_bytes()),'template_sha256':sha(template.read_bytes()),'single_added_control_term':True,'pose_velocity_setters':0,'production_changed':False,'command':command,'exit_code':result.returncode}
(backup/'candidate-inputs.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
assert result.returncode == 0, result.stderr
print(json.dumps(record))
