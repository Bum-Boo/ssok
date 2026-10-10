"""Three exploratory runs with an observable goal; preserves the original failed study."""
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
    args = parser.parse_args()
    out = args.out.resolve();out.mkdir(parents=True, exist_ok=False)
    goal = ('Approach the wall using only the robot camera. At the horizontal center of the480-pixel-high image, '
            'aim to leave a narrow beige floor strip about5–8% of the image height (roughly24–38pixels) '
            'between the wall base and the bottom edge, then stop before contact. '
            'The bottom corners can contain robot parts; judge the center floor strip. '
            'Reobserve after every short step. Prefer shorter steps near the wall; stop if uncertain. '
            'Do not claim a physical distance or collision-free success from the images.')
    root = Path(__file__).resolve().parents[2]
    names = ['tools/app_control/refine_camera_goal.py','tools/app_control/run_goal.py',
             'tools/app_control/desktop_mcp.py','tools/app_control/desktop_session.py',
             'tools/app_control/desktop_client.py','tools/app_control/run_desktop.gd',
             'tools/app_control/camera_evaluator.gd','tools/app_control/camera_trial.py',
             'src/runtime/agent_camera_loop.gd','src/runtime/agent_desktop_bridge.gd','scenes/main.gd']
    plan = {'scope':'exploratory clarified visual goal; separate from the original9live/6control runs',
            'goal':goal,'layouts_wall_x_m':LAYOUTS,'success_criteria':CRITERIA,
            'limits':{'cli_launches':3,'steps_per_run':8,'images_per_run':9,'seconds_per_run':180},
            'provider':'OpenAI / requested gpt-6-astra / existing Codex ChatGPT login',
            'billing_limit':'No monetary/model-request cap exposed; no retries',
            'sent_data':['goal','camera PNG','public frame context','visual summaries','tool results'],
            'excluded_data':['layout distance','physical evaluator','graph','learner source','credentials'],
            'source_sha256':{n:hashlib.sha256((root/n).read_bytes()).hexdigest() for n in names}}
    write_json(out/'plan.json',plan);print(json.dumps(plan),flush=True)
    results=[]
    for index,distance in enumerate(LAYOUTS):
        result=run_trial(args.godot,out/f'layout{index+1}',distance,goal=goal,max_steps=8,seconds=180,criteria=CRITERIA)
        results.append(result);write_json(out/'results.json',results)
        if result['actor'].get('status') in ('runner_failed','cli_failed'):
            raise RuntimeError('Provider/runner failed; no automatic retry.')
    write_json(out/'summary.json',{'trials':3,'successful':sum(r['score']['success'] for r in results)})


if __name__=='__main__':main()
