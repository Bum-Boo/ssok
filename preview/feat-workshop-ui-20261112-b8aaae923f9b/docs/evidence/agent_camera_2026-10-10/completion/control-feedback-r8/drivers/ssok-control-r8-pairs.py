from pathlib import Path
import hashlib,json
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');b=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/control-feedback-r8');read=lambda f:json.loads(f.read_text(encoding='utf-8-sig'));sha=lambda d:hashlib.sha256(d).hexdigest();cases={}
for label,tape in [('baseline','30-10-12'),('repeat','30-10-12'),('minimal-two-step','30-22')]:
    case=r/('build/ai-loop-evidence/completion/control-feedback-r8-'+label)/('replay-near-'+tape);result=read(case/'result.json');paths=list((case/'user-data').glob('Godot/app_userdata/*/camera-calibration.jsonl'));assert len(paths)==1
    samples=[json.loads(line) for line in paths[0].read_text(encoding='utf8').splitlines()];frames=[]
    for frame in result['captures']:
        png=case/(frame['label']+'.png');assert sha(png.read_bytes())==frame['sha256'];matched=[x for x in samples if x['reason']=='camera' and x['capture_metadata'].get('sha256')==frame['sha256']];assert len(matched)==1;sample=matched[0];assert sample['capture_metadata']['physics_tick']==frame['metadata']['physics_tick']==sample['physics_tick']
        frames.append({'label':frame['label'],'png':str(png),'sha256':frame['sha256'],'pixels':frame['pixels'],'capture_metadata':frame['metadata'],'capture_physics':{n:sample[n] for n in ['gap_x','linear_speed','angular_speed','wheel_speed','position','rotation','linear_velocity','motors']},'pairing':'Original frame_ready callback matched by PNG SHA and actual physics tick; not later coroutine-return sample.'})
    out=case.parent/'frame-physics-pairs.json';assert not out.exists();out.write_bytes((json.dumps(frames,indent=2)+'\n').encode());e=result['evaluation'];last=frames[-1]['capture_physics'];cases[label]={'frames':[{n:f[n] for n in ['label','pixels','capture_physics']} for f in frames],'final_gap_m':e['final']['gap_x'],'stop_gap_delta_mm':(e['final']['gap_x']-last['gap_x'])*1000,'combined':read(case.parent/'combined-check.json')}
(b/'capture-comparison.json').write_bytes((json.dumps(cases,indent=2)+'\n').encode());print(json.dumps(cases,indent=2))
