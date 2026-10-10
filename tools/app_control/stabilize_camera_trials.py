"""Bounded stability follow-up; original failures and physical thresholds remain unchanged."""
import argparse
import hashlib
import json
from pathlib import Path

from .camera_trial import run_trial, write_json
from .repeat_camera_trials import CRITERIA, LAYOUTS


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--condition', choices=('original','clarified'), required=True)
    parser.add_argument('--repeats', type=int, choices=(1,3), required=True)
    parser.add_argument('--image', choices=('live','blank','frozen'), default='live')
    parser.add_argument('--live', action='store_true', help='Explicitly authorize the bounded provider calls')
    args = parser.parse_args()
    if not args.live: parser.error('--live is required; no implicit provider calls')
    root = Path(__file__).resolve().parents[2]
    baseline = root/'docs/evidence/agent_camera_2026-10-10/repeated'
    goal_file = baseline/('live-suite/plan.json' if args.condition=='original' else 'refined-visual-goal/plan.json')
    goal = json.loads(goal_file.read_text(encoding='utf-8'))['goal']
    out = args.out.resolve(); out.mkdir(parents=True, exist_ok=False)
    names = ['tools/app_control/stabilize_camera_trials.py','tools/app_control/run_goal.py',
             'tools/app_control/desktop_mcp.py','tools/app_control/desktop_session.py',
             'tools/app_control/desktop_client.py','tools/app_control/run_desktop.gd',
             'tools/app_control/camera_evaluator.gd','tools/app_control/camera_trial.py',
             'src/runtime/agent_camera_loop.gd','src/runtime/agent_desktop_bridge.gd']
    plan = {'scope':'new stabilization follow-up; never overwrites or replaces prior studies',
            'condition':args.condition,'image':args.image,'goal':goal,'goal_source':str(goal_file.relative_to(root)),
            'layouts_wall_x_m':LAYOUTS,'success_criteria':CRITERIA,
            'limits':{'cli_launches':3*args.repeats,'steps_per_run':8,'images_per_run':9,'seconds_per_run':180},
            'provider':'OpenAI / requested gpt-6-astra / existing Codex ChatGPT login',
            'billing_limit':'No monetary/model-request cap exposed; no automatic retries',
            'sent_data':['goal','delivered PNG','public frame context','short summaries','tool results'],
            'excluded_data':['layout distance','physical evaluator','graph','learner source','credentials'],
            'source_sha256':{n:hashlib.sha256((root/n).read_bytes()).hexdigest() for n in names},
            'goal_source_sha256':hashlib.sha256(goal_file.read_bytes()).hexdigest()}
    write_json(out/'plan.json',plan); print(json.dumps(plan),flush=True)
    results=[]
    for repeat in range(args.repeats):
        for index,distance in enumerate(LAYOUTS):
            result=run_trial(args.godot,out/f'layout{index+1}-run{repeat+1}',distance,
                             goal=goal,mode=args.image,max_steps=8,seconds=180,criteria=CRITERIA)
            results.append(result); write_json(out/'results.json',results)
            if result['actor'].get('status') in ('runner_failed','cli_failed'):
                raise RuntimeError('Provider/runner failed; stopped without an automatic retry')
    write_json(out/'summary.json',{'trials':len(results),'successful':sum(r['score']['success'] for r in results),
                                  'transport_failures':sum(any(e.get('event')=='request_error' for e in
                                      [json.loads(line) for line in (out/f'layout{i%3+1}-run{i//3+1}'/'actor/camera/events.jsonl').read_text(encoding='utf-8').splitlines()])
                                      for i in range(len(results)))})


if __name__=='__main__': main()
