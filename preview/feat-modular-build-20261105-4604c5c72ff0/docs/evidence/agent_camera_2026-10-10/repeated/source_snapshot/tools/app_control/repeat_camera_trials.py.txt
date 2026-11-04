"""Freeze a bounded camera experiment before dispatch; no automatic model retries."""
import argparse
import hashlib
import json
from pathlib import Path

from .camera_trial import run_trial, write_json


GOAL = ('Approach the wall visible in the robot camera, then stop with a visible small gap before touching it. '
        'Make meaningful forward progress. Use only images and short forward steps, reobserve after each step, '
        'and stop when the image indicates you are near enough or uncertain. Do not infer hidden metric distances.')
LAYOUTS = [.35, .5, .6]
CRITERIA = {'minimum_travel': .03, 'minimum_gap': .04, 'maximum_gap': .14}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--live', action='store_true', help='Explicitly dispatch at most15 Astra/Codex sessions after calibration passes')
    parser.add_argument('--calibration', type=Path, help='Reuse completed calibration with identical evaluator/control sources; no repeated physics tests')
    args = parser.parse_args()
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    root = Path(__file__).resolve().parents[2]
    sources = ['tools/app_control/camera_evaluator.gd', 'tools/app_control/camera_trial.py',
               'tools/app_control/repeat_camera_trials.py', 'tools/app_control/experiment_session.py',
               'tools/app_control/run_goal.py', 'tools/app_control/desktop_session.py',
               'tools/app_control/desktop_mcp.py', 'tools/app_control/run_desktop.gd']
    plan = {'schema': 1, 'goal': GOAL, 'layouts_wall_x_m': LAYOUTS, 'success_criteria': CRITERIA,
            'rest': {'chassis_linear_m_s': .015, 'chassis_angular_rad_s': .1, 'wheel_angular_rad_s': .5, 'consecutive_ticks': 12},
            'conditions': {'live': 3, 'frozen': 1, 'blank': 1}, 'live_provider_authorized': args.live,
            'limits': {'maximum_cli_launches': 15, 'actions_per_session': 8, 'images_per_session': 9, 'seconds_per_session': 300},
            'provider': 'OpenAI / requested gpt-6-astra / existing Codex ChatGPT login',
            'billing_limit': 'No monetary/model-request cap exposed; action/image/time limits only',
            'sent_data': ['same goal', 'delivered PNGs', 'public frame context and tool results', 'public summaries'],
            'excluded_data': ['layout distance', 'physical evaluator', 'graph', 'learner source', 'credentials'],
            'method_limits': ['small convenience fixture; three positions, no turns', 'controls1/run/layout vs live3',
                              'independent physical observer uses same physics runtime', 'requested backend identity unattested',
                              'no automatic paid retry or post-hoc threshold change'],
            'source_sha256': {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in sources}}
    results = []
    if args.calibration:
        prior = args.calibration.resolve()
        old_plan = json.loads((prior / 'plan.json').read_text())
        old_calibration = json.loads((prior / 'calibration.json').read_text())
        assert old_plan['layouts_wall_x_m'] == LAYOUTS and old_plan['success_criteria'] == CRITERIA
        assert old_calibration['passed'] is True
        # The orchestration script now supports reuse; all observation/action/evaluation inputs must match.
        for name, digest in plan['source_sha256'].items():
            if name != 'tools/app_control/repeat_camera_trials.py':
                assert old_plan['source_sha256'][name] == digest, 'Calibration source changed: ' + name
        results = json.loads((prior / 'deterministic.json').read_text())
        assert len(results) == 7 and all(r['actor']['status'] == 'deterministic_fixture' for r in results)
        plan['calibration_evidence'] = {'path': str(prior), 'plan_sha256': hashlib.sha256((prior/'plan.json').read_bytes()).hexdigest(),
                                        'results_sha256': hashlib.sha256((prior/'deterministic.json').read_bytes()).hexdigest()}
        write_json(output / 'plan.json', plan)
    else:
        write_json(output / 'plan.json', plan)
        for index, distance in enumerate(LAYOUTS):
            result = run_trial(args.godot, output / f'calibration-{index + 1}', distance,
                               ticks=30, actions=index + 2, criteria=CRITERIA)
            results.append(result)
        contact = run_trial(args.godot, output / 'contact-detector-check', .25, ticks=30, actions=3, criteria=CRITERIA)
        results.append(contact)
        calibration_ok = all(result['score']['success'] for result in results[:3]) and contact['evaluation']['wall_contact'] is True
        write_json(output / 'calibration.json', {'passed': calibration_ok, 'trials': results})
        if not calibration_ok:
            raise RuntimeError('Calibration/contact observer failed before provider dispatch. Freeze a NEW plan after a documented correction.')
        for index, distance in enumerate(LAYOUTS):
            results.append(run_trial(args.godot, output / f'fixed-baseline-{index + 1}', distance,
                                     ticks=20, actions=4, criteria=CRITERIA))
        write_json(output / 'deterministic.json', results)
    if args.live:
        for mode, repetitions in plan['conditions'].items():
            for index, distance in enumerate(LAYOUTS):
                for repetition in range(repetitions):
                    name = f'{mode}-layout{index + 1}-run{repetition + 1}'
                    result = run_trial(args.godot, output / name, distance, goal=GOAL, mode=mode,
                                       max_steps=8, seconds=300, criteria=CRITERIA)
                    results.append(result)
                    write_json(output / 'results.json', results)
                    if result['actor'].get('status') in ('runner_failed', 'cli_failed'):
                        raise RuntimeError('Provider/runner failed; preserve this trial and stop dispatch. No automatic retry.')
    write_json(output / 'results.json', results)
    summary = {mode: {'trials': len(selected := [r for r in results if r['actor'].get('status') != 'deterministic_fixture' and r['mode'] == mode]),
                       'successful': sum(r['score']['success'] for r in selected)} for mode in plan['conditions']}
    write_json(output / 'summary.json', summary)
    print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
