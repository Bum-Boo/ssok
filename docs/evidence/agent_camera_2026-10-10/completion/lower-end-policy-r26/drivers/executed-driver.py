"""DEBUG-r26: one real camera-only candidate trial with frozen independent scoring."""
from pathlib import Path
from datetime import datetime, timezone, timedelta
import ast
import hashlib
import json
import msvcrt
import os
import secrets
import subprocess
import sys
import time

REPO = Path('C:/Users/Hojun/Projects/ssok-ai-loop')
BASE = Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010')
BACKUP = BASE / 'lower-end-policy-r26'
RUNTIME = REPO / 'build/ai-loop-evidence/completion/lower-end-policy-r26'
HEAD = '841bf63f436fa2ae7072d44888eae3099e55dc58'
SESSION = 'ssok-win-r24-fe05a224c5e54fbdab1b2ce07e021f07'
READER = 'C:/Users/Hojun/AppData/Local/Programs/Python/Python313/python.exe'
ACTOR_PYTHON = REPO / 'build/venv-native/Scripts/python.exe'
ACTOR = Path('C:/Users/Hojun/Projects/ssok-ai-r26-actor.py')
GOAL = REPO / 'docs/evidence/agent_camera_2026-10-10/repeated/refined-visual-goal/plan.json'
GOAL_SHA = 'd372505d199ce2e2ba4b12588487cafe9e722465b65171ca25fcbf8496f632a4'
sys.path.insert(0, str(REPO))
from tools.app_control.desktop_client import DesktopClient, DesktopError, CONTEXT_KEYS
from tools.app_control.camera_trial import score
from tools.app_control.doctor import inspect
from tools.app_control.run_goal import end_process

def sha(data): return hashlib.sha256(data).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def save(path, data): path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
def git(*args): return subprocess.check_output(['git', *args], cwd=REPO).decode().strip()
def stamp(): return datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')

def guard(clean=False):
    assert git('rev-parse', 'HEAD') == HEAD
    if clean: assert not git('status', '--porcelain')
    sources = read(BASE / 'host-raw-r25/contract.json')['sources']
    assert len(sources) == 433
    for name, digest in sources.items(): assert sha((REPO / name).read_bytes()) == digest, name
    assert sha(GOAL.read_bytes()) == GOAL_SHA
    return sources

def stock_prompt():
    tree = ast.parse((REPO / 'tools/app_control/run_goal.py').read_text(encoding='utf8'))
    candidates = [node.value for node in ast.walk(tree) if isinstance(node, ast.Constant)
                  and isinstance(node.value, str) and node.value.startswith('You are a bounded robot-camera operator.')]
    assert len(candidates) == 1
    return candidates[0]

def baseline():
    archived = REPO / 'docs/evidence/agent_camera_2026-10-10/completion/adaptive-ai-r21/runtime'
    evaluation, actor = read(archived / 'evaluation.json'), read(archived / 'actor/result.json')
    prior = read(archived / 'summary.json')
    physical = score(evaluation, actor, read(GOAL)['success_criteria'])
    result = {'source': str(archived), 'historical_runtime': True, 'new_native_trials': 0,
              'replayed_at': stamp(), 'image_pass': prior['image_pass'], 'physical': physical,
              'joint_pass': prior['image_pass'] and physical['success'],
              'latest_floor_pixels': prior['latest_floor_pixels'], 'final_gap_m': evaluation['final']['gap_x']}
    assert result['image_pass'] and not result['joint_pass']
    save(BACKUP / 'baseline-replay.json', result)
    return result

def prepare():
    assert Path(sys.executable).resolve() == ACTOR_PYTHON.resolve(), 'Use build/venv-native/Scripts/python.exe, not global Python'
    sources = guard(clean=True)
    assert not BACKUP.exists() and not RUNTIME.exists(), 'Do not overwrite/retry an existing experiment'
    dependency = subprocess.run([READER,'-X','utf8','-c','import PIL; print(PIL.__version__)'],capture_output=True,timeout=15)
    assert dependency.returncode == 0, 'Reader dependency missing before launch'
    doctor = inspect(REPO)
    assert doctor['ready'], doctor
    BACKUP.mkdir(); RUNTIME.mkdir(parents=True)
    save(BACKUP / 'doctor.json', doctor)
    save(BACKUP / 'prepare-recovery.json', {'first_command':'global python prepare',
        'first_exit':1,'failure':'selected global Python has no MCP SDK',
        'before_backup_or_contract_write':True,'new_native_or_actor_launches':0,
        'recovery':'reuse verified existing build/venv-native/Scripts/python.exe',
        'no_install_or_global_configuration_change':True,'selected_python':sys.executable})
    import importlib.util
    spec = importlib.util.spec_from_file_location('candidate_actor', ACTOR)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    original = stock_prompt(); candidate = module.candidate_prompt(original)
    (BACKUP / 'stock-actor.md').write_text(original, encoding='utf8')
    (BACKUP / 'candidate-actor.md').write_text(candidate, encoding='utf8')
    baseline_result = baseline()
    plan = Path(read(BASE / 'host-raw-r25/contract.json')['plan'])
    previous = read(BASE / 'host-raw-r25/records/manifest.json')
    before = plan.read_bytes()
    assert sha(before) == previous[str(plan)]['post_sha256']
    when = stamp()
    entry = ('\n\n<!-- ssok-r26-contract -->\n' + when + ' — r26: 원래24–38px/4–14cm 독립 기준 불변; '
             '현재 stock controller/camera/evaluator/source433에서 actor의 first-valid/middle Stop 선택만 '
             'lower-end24–26px 선호로 바꾸는 외부 임시 policy 한회 시험. 24–26은 정책선호이며 성공조건이 아님. '
             'Rank1 조기정지정책이면 최신pixel/gap 감소로 jointPASS 가능; Rank2 단일틱이 구간을 건너면 imageFAIL; '
             'Rank3 camera-time/Stop drift 차이가 남으면 최종gapFAIL. 기존 r21 actual31px/14.5838cm jointFAIL '
             '원본재채점은 결정적offline red이며 새로운AI/물리재현 아님; 실제AI loop는 비결정적·초단위루프불가, '
             '최소화로 goal/physics를 제거하지 않음. 회귀단위테스트로 물리정밀도 증명하지 않음. '
             'OpenAI requestedgpt-6-astra/medium/기존ChatGPT login, 1CLI/8actions9images180s, no retry/paidfallback; '
             '전송goal/PNG/publiccontext/summary/toolresults+공개 pixel정책만, scene/evaluator/거리/graph/source/auth 제외. '
             '첫jointFAIL이면 후보시험 종료, 첫PASS라도 새계약/반복검증 전 제품미채택. Allowed외부driver/ignoredfixture/'
             '공개sanitizedevidence/기존plan·state·Wiki, source/UI/ZIP/provider/limits/frozengoal변경0. '
             '실제 Windows checkout C:/Users/Hojun/Projects/ssok-ai-loop HEAD'+HEAD+'; '
             'officialtask22/Codex, nextFableintegration/humanmerge; 정밀도/계정/개인Mac/Arch/정확공개미완료.\n')
    after = before + entry.encode('utf8')
    (BACKUP / 'plan.before.md').write_bytes(before)
    with plan.open('r+b', buffering=0) as handle:
        length = max(len(before),len(after))+1
        msvcrt.locking(handle.fileno(),msvcrt.LK_NBLCK,length)
        try:
            assert handle.read() == before
            handle.seek(0);handle.write(after);handle.truncate();os.fsync(handle.fileno())
        finally:
            handle.seek(0);msvcrt.locking(handle.fileno(),msvcrt.LK_UNLCK,length)
    assert plan.read_bytes() == after
    task = Path('C:/Users/Hojun/Documents/Obsidians/Frieren (arch)/00_System/Agent Tasks/ssok/robot-camera-loop-20261010')
    old_events = {p.name:sha(p.read_bytes()) for p in (task/'events').glob('*.json') if int(p.stem)<=21}
    assert len(old_events) == 21
    save(BACKUP/'contract.json',{'head':HEAD,'session':SESSION,'stamp':when,'sources':sources,
        'plan':str(plan),'before_sha256':sha(before),'post_sha256':sha(after),'goal_sha256':GOAL_SHA,
        'actor_wrapper_sha256':sha(ACTOR.read_bytes()),'driver_sha256':sha(Path(__file__).read_bytes()),
        'stock_prompt_sha256':sha(original.encode()),'candidate_prompt_sha256':sha(candidate.encode()),
        'limits':{'cli_launches':1,'steps':8,'images':9,'seconds':180},'old_task_events':old_events,
        'provider':'OpenAI / requested gpt-6-astra / existing Codex ChatGPT login',
        'ranked_predictions':['lower-end stop narrows final gap','one tick may skip valid interval','post-Stop drift/pose may retain gap failure'],
        'production_applied':False,'calibration_proposal_adopted':False,'global_goal_complete':False})
    print(json.dumps({'prepared':True,'historical_red_replay':baseline_result,'doctor_ready':True,'new_ai_trials':0}))

def launch():
    assert Path(sys.executable).resolve() == ACTOR_PYTHON.resolve(), 'Use existing MCP Python environment'
    guard()
    contract = read(BACKUP/'contract.json')
    assert sha(Path(__file__).read_bytes()) == contract['driver_sha256']
    assert sha(ACTOR.read_bytes()) == contract['actor_wrapper_sha256']
    assert sha(Path(contract['plan']).read_bytes()) == contract['post_sha256']
    assert not (RUNTIME/'layout1').exists(), 'An existing trial cannot be retried'
    launcher = RUNTIME/'run_adaptive.gd'
    launcher.write_text('''extends "res://tools/app_control/run_desktop.gd"

## DEBUG-r26: same normal Stop evaluation timing as archived r21.
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
\t\tif FileAccess.file_exists("user://r26-runner-finished.json"):
\t\t\tbreak
\t\tawait physics_frame
\tapp.free()
\tquit(0)
''',encoding='utf8')
    preflight = [str(REPO/'build/toolchain-windows/Godot_v4.7.2-stable_win64_console.exe'),
        '--headless','--path',str(REPO),'--script',launcher.relative_to(REPO).as_posix(),'--check-only']
    checked = subprocess.run(preflight,cwd=REPO,capture_output=True,timeout=30)
    (BACKUP/'preflight.log').write_bytes(checked.stdout+checked.stderr)
    save(BACKUP/'preflight.json',{'command':preflight,'exit':checked.returncode,'launcher_sha256':sha(launcher.read_bytes())})
    assert checked.returncode == 0
    out = RUNTIME/'layout1';out.mkdir()
    old_token = os.environ.get('SSOK_AGENT_TOKEN')
    token = secrets.token_hex(32)
    env = dict(os.environ,SSOK_AGENT_TOKEN=token,APPDATA=str(out/'user-data'),LOCALAPPDATA=str(out/'config'),
        XDG_DATA_HOME=str(out/'user-data'),XDG_CONFIG_HOME=str(out/'config'))
    env.pop('OPENAI_API_KEY',None);os.environ['SSOK_AGENT_TOKEN']=token
    client = DesktopClient();context=None;native=None;actor=None;failure=None;start=time.monotonic()
    goal = read(GOAL)
    command = [str(REPO/'build/toolchain-windows/Godot_v4.7.2-stable_win64.exe'),'--path',str(REPO),
        '--audio-driver','Dummy','--script',launcher.relative_to(REPO).as_posix(),
        '--','--ssok-agent-bridge','--evaluate-camera','--wall-x','0.35']
    save(out/'plan.json',{'command':command,'goal':goal['goal'],'frozen_goal_sha256':GOAL_SHA,
        'wall_x':0.35,'limits':contract['limits'],'provider':contract['provider'],
        'actor_policy':'lower-end stop preference / not stock prompt', 'physical_inputs_to_actor':False,
        'automatic_retry':False,'paid_fallback':False,'native_readiness_seconds':80,
        'fixture_post_stop_readback_frames':132,'new_controller':False})
    with (out/'godot.log').open('wb') as native_log,(out/'runner.log').open('wb') as runner_log:
        try:
            native=subprocess.Popen(command,cwd=REPO,env=env,stdout=native_log,stderr=subprocess.STDOUT)
            while True:
                if native.poll() is not None:raise RuntimeError('Native exited before readiness')
                try:
                    state=client.describe()
                    if state['state']=='ready':
                        context={key:state[key] for key in CONTEXT_KEYS};break
                except DesktopError:pass
                if time.monotonic()>start+80:raise TimeoutError('Native readiness deadline')
                time.sleep(.05)
            save(out/'ready-context.json',context)
            print(json.dumps({'phase':'native_ready','head':HEAD,'provider':contract['provider'],
                'policy':'lower-end preference','limits':contract['limits']}),flush=True)
            actor_cmd=[sys.executable,'-X','utf8',str(ACTOR),'--goal',goal['goal'],'--out',str(out/'actor'),
                '--codex','C:/Users/Hojun/.codex/launchers/no-daemon/codex.cmd','--max-steps','8',
                '--max-observations','9','--seconds','180','--expected-context',json.dumps(context)]
            actor=subprocess.Popen(actor_cmd,cwd=REPO,env=env,stdout=runner_log,stderr=subprocess.STDOUT)
            actor.wait(timeout=225)
            save(out/'user-data/Godot/app_userdata/ssok/r26-runner-finished.json',{'runner_terminal':True})
            native.wait(timeout=15)
        except Exception as exc:
            failure=type(exc).__name__+': '+str(exc)
            if context is not None:
                try:client.stop(context)
                except DesktopError:pass
            if actor is not None:end_process(actor)
            if native is not None and native.poll() is None:
                try:native.wait(timeout=5)
                except subprocess.TimeoutExpired:end_process(native)
        finally:
            if old_token is None:os.environ.pop('SSOK_AGENT_TOKEN',None)
            else:os.environ['SSOK_AGENT_TOKEN']=old_token
    receipt={'source_head':HEAD,'native_exit':native.returncode if native else None,
        'actor_exit':actor.returncode if actor else None,'seconds':time.monotonic()-start,'failure':failure,
        'source433_unchanged':all(sha((REPO/n).read_bytes())==h for n,h in contract['sources'].items()),
        'caller_environment_restored':os.environ.get('SSOK_AGENT_TOKEN')==old_token,
        'cli_launches':int(actor is not None),'automatic_retries':0,'production_applied':False,
        'backend_identity_attested':False,'owned_native_pid':native.pid if native else None,
        'owned_actor_pid':actor.pid if actor else None}
    for name in ['godot.log','runner.log']:assert token.encode() not in (out/name).read_bytes()
    save(out/'receipt.json',receipt)
    assert failure is None and receipt['native_exit']==0 and receipt['source433_unchanged'],receipt
    finished=subprocess.run([READER,'-X','utf8',str(Path(__file__)),'readback'],cwd=REPO)
    raise SystemExit(finished.returncode)

def readback():
    guard()
    from tools.app_control.camera_pixels import measure_floor
    out=RUNTIME/'layout1';receipt=read(out/'receipt.json')
    actor=read(out/'actor/result.json')
    evaluation=read(out/'user-data/Godot/app_userdata/ssok/camera-evaluation.json')
    events=[json.loads(line) for line in (out/'actor/camera/events.jsonl').read_text(encoding='utf8').splitlines()]
    observations=[e for e in events if e['event']=='observe']
    for index,event in enumerate(observations,1):
        assert sha((out/f'actor/camera/observation-{index}.png').read_bytes())==event['data']['metadata']['sha256']
    pixels=measure_floor(out/f'actor/camera/observation-{len(observations)}.png')
    physical=score(evaluation,actor,read(GOAL)['success_criteria'])
    policy=read(out/'actor/policy.json');contract=read(BACKUP/'contract.json')
    assert policy['candidate_actor_prompt_sha256']==contract['candidate_prompt_sha256']
    result={'head':HEAD,'new_ai_trials':1,'wall_x':0.35,'actions':actor['completed_actions'],
        'observations':actor['observations'],'latest_floor_pixels':pixels['floor_pixels'],
        'image_pass':pixels['image_target'],'final_gap_m':evaluation['final']['gap_x'],'physical':physical,
        'joint_pass':pixels['image_target'] and physical['success'],'actor_status':actor['status'],
        'actor_exit':receipt['actor_exit'],'native_exit':receipt['native_exit'],
        'actor_stop_confirmed':actor['stop_confirmed'],'stop_scope':actor['stop_scope'],
        'requested_model':actor['requested_model'],'resolved_model':actor['resolved_model'],
        'actor_policy':'lower-end preference; original24–38pixel acceptance',
        'model_request_count_not_attested':True,'production_applied':False,'global_goal_complete':False}
    save(out/'evaluation.json',evaluation);save(out/'summary.json',result)
    print(json.dumps(result),flush=True)
    raise SystemExit(0 if result['joint_pass'] else 1)

if __name__=='__main__':
    modes={'prepare':prepare,'launch':launch,'readback':readback}
    assert len(sys.argv)==2 and sys.argv[1] in modes
    modes[sys.argv[1]]()
