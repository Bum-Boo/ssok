from pathlib import Path
from datetime import datetime, timezone, timedelta
import hashlib
import json
import msvcrt
import os
import secrets
import subprocess
import sys
import time

repo = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
sys.path.insert(0,str(repo))
from tools.app_control.desktop_client import DesktopClient, DesktopError, CONTEXT_KEYS
from tools.app_control.camera_trial import score
from tools.app_control.camera_pixels import measure_floor
from tools.app_control.doctor import inspect
from tools.app_control.run_goal import end_process

base = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010')
backup = base/'adaptive-ai-r21'
runtime = repo/'build/ai-loop-evidence/completion/adaptive-ai-r21'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda b: hashlib.sha256(b).hexdigest()
save = lambda p,d: p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
old = read(base/'body-integral-r20/contract.json')
head = subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo).decode().strip()
assert head == '0b16d984096e00d4835bfb3ba6d48ad1b311e226'
assert not subprocess.check_output(['git','status','--porcelain'],cwd=repo)
for name,digest in {**old['source426'],**old['extra_operator7']}.items():
    assert sha((repo/name).read_bytes()) == digest,name
goal_file = repo/'docs/evidence/agent_camera_2026-10-10/repeated/refined-visual-goal/plan.json'
assert sha(goal_file.read_bytes()) == old['frozen_goal_sha256']
goal_plan = read(goal_file)
readback = '--readback' in sys.argv
reader_python = 'C:/Users/Hojun/AppData/Local/Programs/Python/Python313/python.exe'
if readback:
    contract = read(backup/'contract.json')
    assert contract['head'] == head
    assert sha(Path(contract['plan']).read_bytes()) == contract['post_sha256']
    out = runtime/'layout1'
    receipt = read(out/'receipt.json')
    assert receipt['native_exit'] == 0 and receipt['actor_exit'] == 0 and receipt['failure'] is None
else:
    dependency = subprocess.run([reader_python,'-X','utf8','-c','import PIL; print(PIL.__version__)'], capture_output=True, timeout=15)
    assert dependency.returncode == 0, 'Offline reader requires Pillow before model launch'
    resume = '--resume' in sys.argv
    if not resume:
        backup.mkdir(exist_ok=False)
        runtime.mkdir(exist_ok=False)
        doctor = inspect(repo)
        save(backup/'doctor.json',doctor)
        assert doctor['ready'],doctor
        plan = Path(old['plan'])
        before = plan.read_bytes()
        previous = read(base/'body-integral-r20/records/manifest.json')
        assert sha(before) == previous[str(plan)]['post_sha256']
        (backup/'plan.before.md').write_bytes(before)
        stamp = datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')
        entry = '\n\n<!-- ssok-r21-contract -->\n'+stamp+' — r21: 고정30/10/12의 실패를 AI정책 실패와 동일시하지 않고 현재stock앱에 실제 image-only Astra를 연결해 원래동결goal/8actions9images180초로 우선layout0.35 한회 실행한다. Rank1 fixedtape와 AI의adaptive관측/Stop 차이가 핵심이면 source426+7/actorprompt/모터/카메라 불변에서도 jointPASS 가능; Rank2 영상구간 안의 조기Stop이면 imagePASS/physicalgap>14cm를 재현한다; Rank3 actualprovider/deadline/bridge 오류이면 goal정밀도와 별도 실패로 보존하고 scopedStop/ownedPIDcleanup 확인. 첫jointPASS일 때만 original3layouts×3의 나머지8회를 동일policy로 별도추가계약 후 이어가며 첫FAIL이면 반복/후보/gain/threshold완화0. 기존Login/OpenAI requestedgpt-6-astra/medium, 3MCPobserve·decide·stop, no shell/files/scene/evaluator/reasoning input, no APIkeyfallback/retry. Toolbounds는모델request/과금cap이아님. NativeGL80초준비/132postStop자동종료 ignoredlauncher만 새로 만들며 actualnativeevaluator final30+rest12또는120/externalmetrics afterStop+nativeexit. 전송goal/PNG/publiccontext/간결summary/toolresults, privatevault/auth/config/graph/source/physicaldistance 제외. Gitissue32 currentopen/designonly/noassignee 확인; user가별도승인한 cameraimplementation/MVP범위 유지, 원격issue수정0. Source426+7/app/ZIP/goal/provider/UI 불변. Allowedignoredfixture/외부driver/evidence/docs/기존기록만. NextCodex/Fableintegration/humanmerge; originalprecision/nav/freshaccount/Mac/Archraw/task16/publication 미완료.\n'
        data = before+entry.encode()
        with plan.open('r+b',buffering=0) as handle:
            length = max(len(before),len(data))+1
            msvcrt.locking(handle.fileno(),msvcrt.LK_NBLCK,length)
            try:
                assert handle.read() == before
                handle.seek(0);handle.write(data);handle.truncate();os.fsync(handle.fileno())
            finally:
                handle.seek(0);msvcrt.locking(handle.fileno(),msvcrt.LK_UNLCK,length)
        assert plan.read_bytes() == data
        contract = {**old,'head':head,'before_sha256':sha(before),'post_sha256':sha(data),
            'scope':'Fresh unchanged stock adaptive camera-only AI benchmark, first original layout; not a controller prototype',
            'provider':'OpenAI / requested gpt-6-astra / existing Codex ChatGPT login',
            'limits':{'cli_launches':1,'steps':8,'images':9,'seconds':180},
            'ranked_predictions':['Adaptive camera-only policy can differ from the developer fixed tape',
                'Image-goal satisfaction can still leave independent stopped gap beyond14cm',
                'Actual provider/bridge/deadline failure is distinct from target failure'],
            'global_goal_complete':False}
        save(backup/'contract.json',contract)
    else:
        contract = read(backup/'contract.json')
        assert contract['head'] == head
        assert sha(Path(contract['plan']).read_bytes()) == contract['post_sha256']
        assert not (runtime/'layout1').exists()
        stamp = datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')
    launcher = runtime/'run_adaptive.gd'
    launcher.write_text('''extends "res://tools/app_control/run_desktop.gd"

    ## DEBUG-r21: own rendered fixture only, normal exit after actual Stop evaluation readback.
    var _seen_active: bool = false
    var _closing: bool = false

    func _process(_delta: float) -> bool:
    \tif app == null or _closing:
    \t\treturn false
    \tif app.agent_loop.enabled:
    \t\t_seen_active = true
    \telif _seen_active:
    \t\t_closing = true
    \t\t_finish.call_deferred()
    \treturn false

    func _finish() -> void:
    \tfor tick: int in 132:
    \t\tawait physics_frame
    \tfor tick: int in 900:
    \t\tif FileAccess.file_exists("user://r21-runner-finished.json"):
    \t\t\tbreak
    \t\tawait physics_frame
    \tapp.free()
    \tquit(0)
    ''',encoding='utf8')
    preflight = [str(repo/'build/toolchain-windows/Godot_v4.7.2-stable_win64_console.exe'),
        '--headless','--path',str(repo),'--script',launcher.relative_to(repo).as_posix(),'--check-only']
    checked = subprocess.run(preflight,cwd=repo,capture_output=True,timeout=30)
    (backup/'preflight.log').write_bytes(checked.stdout+checked.stderr)
    save(backup/'inputs.json',{'head':head,'timestamp':stamp,'launcher_sha256':sha(launcher.read_bytes()),
        'driver_sha256':sha(Path(__file__).read_bytes()),'goal_sha256':old['frozen_goal_sha256'],
        'actor_source_sha256':sha((repo/'tools/app_control/run_goal.py').read_bytes()),
        'preflight':preflight,'preflight_exit':checked.returncode,'doctor_ready':True,'production_applied':False})
    assert checked.returncode == 0
    out = runtime/'layout1'
    out.mkdir(exist_ok=False)
    old_token = os.environ.get('SSOK_AGENT_TOKEN')
    token = secrets.token_hex(32)
    env = dict(os.environ,SSOK_AGENT_TOKEN=token,APPDATA=str(out/'user-data'),LOCALAPPDATA=str(out/'config'),
        XDG_DATA_HOME=str(out/'user-data'),XDG_CONFIG_HOME=str(out/'config'))
    env.pop('OPENAI_API_KEY',None)
    os.environ['SSOK_AGENT_TOKEN'] = token
    client = DesktopClient()
    context = None
    native = None
    actor_process = None
    start = time.monotonic()
    failure = None
    with (out/'godot.log').open('wb') as native_log, (out/'runner.log').open('wb') as runner_log:
        command = [str(repo/'build/toolchain-windows/Godot_v4.7.2-stable_win64.exe'),'--path',str(repo),
            '--audio-driver','Dummy','--script',launcher.relative_to(repo).as_posix(),
            '--','--ssok-agent-bridge','--evaluate-camera','--wall-x','0.35']
        save(out/'plan.json',{'command':command,'goal':goal_plan['goal'],'wall_x':0.35,'limits':contract['limits'],
            'provider':contract['provider'],'physical_inputs_to_actor':False,'automatic_retry':False,'paid_fallback':False,
            'native_readiness_seconds':80,'fixture_post_stop_readback_frames':132,'new_controller':False})
        try:
            native = subprocess.Popen(command,cwd=repo,env=env,stdout=native_log,stderr=subprocess.STDOUT)
            ready_deadline = start+80
            while True:
                if native.poll() is not None:
                    raise RuntimeError('Native fixture exited before camera readiness')
                try:
                    state = client.describe()
                    if state['state'] == 'ready':
                        context = {key:state[key] for key in CONTEXT_KEYS}
                        break
                except DesktopError:
                    pass
                if time.monotonic() >= ready_deadline:
                    raise TimeoutError('Native camera readiness deadline')
                time.sleep(.05)
            save(out/'ready-context.json',context)
            print(json.dumps({'phase':'native_ready','head':head,'provider':contract['provider'],'limits':contract['limits']}),flush=True)
            actor_command = [sys.executable,'-X','utf8','-m','tools.app_control.run_goal',
                '--goal',goal_plan['goal'],'--out',str(out/'actor'),'--codex','C:/Users/Hojun/.codex/launchers/no-daemon/codex.cmd',
                '--max-steps','8','--max-observations','9','--seconds','180','--expected-context',json.dumps(context)]
            actor_process = subprocess.Popen(actor_command,cwd=repo,env=env,stdout=runner_log,stderr=subprocess.STDOUT)
            actor_process.wait(timeout=225)
            save(out/'user-data/Godot/app_userdata/ssok/r21-runner-finished.json',{'runner_terminal':True})
            native.wait(timeout=15)
        except Exception as exc:
            failure = type(exc).__name__+': '+str(exc)
            if context is not None:
                try:
                    client.stop(context)
                except DesktopError:
                    pass
            if actor_process is not None:
                end_process(actor_process)
            if native is not None and native.poll() is None:
                try:
                    native.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    end_process(native)
        finally:
            if old_token is None: os.environ.pop('SSOK_AGENT_TOKEN',None)
            else: os.environ['SSOK_AGENT_TOKEN'] = old_token
    receipt = {'native_exit':native.returncode if native else None,'actor_exit':actor_process.returncode if actor_process else None,
        'seconds':time.monotonic()-start,'failure':failure,'source426_operator7_unchanged':
        all(sha((repo/n).read_bytes()) == h for n,h in {**old['source426'],**old['extra_operator7']}.items()),
        'caller_environment_restored':os.environ.get('SSOK_AGENT_TOKEN') == old_token,
        'source_head':head,'production_applied':False,'cli_launches':int(actor_process is not None),
        'automatic_retries':0,'backend_identity_attested':False}
    for name in ['godot.log','runner.log']:
        assert token.encode() not in (out/name).read_bytes()
    save(out/'receipt.json',receipt)
    assert failure is None and native.returncode == 0 and receipt['source426_operator7_unchanged'],receipt
    finished = subprocess.run([reader_python,'-X','utf8',str(Path(__file__)),'--readback'],cwd=repo)
    raise SystemExit(finished.returncode)
actor = read(out/'actor/result.json')
evaluation_file = out/'user-data/Godot/app_userdata/ssok/camera-evaluation.json'
evaluation = read(evaluation_file)
camera = out/'actor/camera'
events = [json.loads(line) for line in (camera/'events.jsonl').read_text(encoding='utf8').splitlines()]
observations = [e for e in events if e['event'] == 'observe']
assert observations
for index,event in enumerate(observations,1):
    path = camera/('observation-'+str(index)+'.png')
    assert sha(path.read_bytes()) == event['data']['metadata']['sha256']
last_path = camera/('observation-'+str(len(observations))+'.png')
pixels = measure_floor(last_path)
physical = score(evaluation,actor,goal_plan['success_criteria'])
summary = {'head':head,'mode':'live','new_ai_trials':1,'wall_x':0.35,
    'actions':actor['completed_actions'],'observations':actor['observations'],
    'latest_floor_pixels':pixels['floor_pixels'],'image_pass':pixels['image_target'],
    'final_gap_m':evaluation['final']['gap_x'],'physical':physical,'joint_pass':
        pixels['image_target'] and physical['success'],
    'actor_status':actor['status'],'actor_exit':receipt['actor_exit'],'native_exit':receipt['native_exit'],
    'actor_stop_confirmed':actor['stop_confirmed'],'stop_scope':actor['stop_scope'],
    'requested_model':actor['requested_model'],'resolved_model':actor['resolved_model'],
    'model_request_count_not_attested':True,'production_applied':False,'global_goal_complete':False}
save(out/'evaluation.json',evaluation)
save(out/'summary.json',summary)
print(json.dumps({'receipt':receipt,'summary':summary}),flush=True)
raise SystemExit(0 if summary['joint_pass'] else 1)
