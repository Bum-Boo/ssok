"""One isolated rendered camera trial. Independent physical metrics never reach MCP."""
import argparse
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import time

from .desktop_client import DesktopClient, DesktopError, write_observation


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def score(evaluation, actor, criteria):
    checks = {
        'valid_evaluation': evaluation.get('valid') is True,
        'forward_progress': evaluation.get('travel_x', -1) >= criteria['minimum_travel'],
        'gap_in_target': criteria['minimum_gap'] <= evaluation.get('final', {}).get('gap_x', -1) <= criteria['maximum_gap'],
        'no_contact': evaluation.get('wall_contact') is False and evaluation.get('minimum_gap_x', -1) > 0,
        'rest_after_stop': evaluation.get('rest_ticks', 0) >= 12 and evaluation.get('stopped_state') == 'stopped',
        'action_reobservation_stop': actor.get('final_reobserved') is True and actor.get('stop_confirmed') is True,
    }
    return {'success': all(checks.values()), 'checks': checks}


def run_trial(godot, output, wall_x, *, goal=None, mode='live', max_steps=8, seconds=300,
              ticks=30, actions=1, criteria=None):
    root = Path(__file__).resolve().parents[2]
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    env['SSOK_AGENT_TOKEN'] = secrets.token_hex(32)
    env['XDG_DATA_HOME'] = str(output / 'user-data')
    env['XDG_CONFIG_HOME'] = str(output / 'config')
    if os.name == 'nt':
        # Godot uses APPDATA on Windows; XDG alone would touch normal user settings.
        env['APPDATA'] = str(output / 'user-data')
        env['LOCALAPPDATA'] = str(output / 'config')
    client = DesktopClient()
    log = (output / 'godot.log').open('w')
    process = subprocess.Popen([godot, '--path', str(root), '--script', 'tools/app_control/run_desktop.gd',
                                '--', '--ssok-agent-bridge', '--evaluate-camera', '--wall-x', str(wall_x)],
                               env=env, stdout=log, stderr=subprocess.STDOUT)
    previous_token = os.environ.get('SSOK_AGENT_TOKEN')
    os.environ['SSOK_AGENT_TOKEN'] = env['SSOK_AGENT_TOKEN']
    actor = {'status': 'not_started'}
    evaluation = {}
    try:
        deadline = time.monotonic() + 30
        while True:
            if process.poll() is not None:
                raise RuntimeError('Rendered fixture exited; inspect godot.log')
            try:
                if client.describe()['state'] == 'ready':
                    break
            except DesktopError:
                pass
            if time.monotonic() >= deadline:
                raise RuntimeError('Rendered fixture readiness timeout; inspect godot.log')
            time.sleep(.05)
        if goal:
            command = [sys.executable, '-m', 'tools.app_control.run_goal', '--goal', goal,
                       '--out', str(output / 'actor'), '--max-steps', str(max_steps),
                       '--max-observations', str(max_steps + 1), '--seconds', str(seconds)]
            if mode != 'live':
                command += ['--experiment-image', mode]
            result = subprocess.run(command, env=env, timeout=seconds + 45, capture_output=True)
            # Runner output is an explicit public manifest/result, never the model transcript.
            (output / 'runner.log').write_bytes(result.stdout + result.stderr)
            if (output / 'actor/result.json').is_file():
                actor = json.loads((output / 'actor/result.json').read_text(encoding='utf-8'))
            actor['runner_exit'] = result.returncode
        else:
            decisions = []
            for index in range(actions):
                observation = client.observe(client.describe())
                write_observation(observation, output / f'calibration-{index + 1}.png')
                meta = observation.metadata
                decisions.append(client.drive_step(meta['frame_id'], meta['revision'], meta['control_generation'],
                                                   ticks, episode_id=meta['episode_id']))
            final = client.observe(client.describe())
            write_observation(final, output / f'calibration-{actions + 1}.png')
            actor = {'status': 'deterministic_fixture', 'completed_actions': actions,
                     'observations': actions + 1, 'final_reobserved': True,
                     'stop_confirmed': client.stop()['state'] == 'stopped'}
            write_json(output / 'deterministic-actions.json', decisions)
        client.stop()
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            files = list((output / 'user-data').glob('godot/app_userdata/*/camera-evaluation.json'))
            if len(files) == 1:
                try:
                    evaluation = json.loads(files[0].read_text(encoding='utf-8'))
                    break
                except ValueError:
                    pass
            time.sleep(.05)
        if not evaluation:
            raise RuntimeError('Independent evaluator did not produce a final result; inspect godot.log')
        write_json(output / 'evaluation.json', evaluation)
        result = {'mode': mode, 'wall_x': wall_x, 'actor': actor, 'evaluation': evaluation}
        if criteria:
            result['score'] = score(evaluation, actor, criteria)
        write_json(output / 'trial.json', result)
        print(json.dumps({'trial': output.name, 'mode': mode, 'wall_x': wall_x,
                          'actions': actor.get('completed_actions'), 'travel': evaluation['travel_x'],
                          'gap': evaluation['final']['gap_x'], 'contact': evaluation['wall_contact'],
                          'score': result.get('score')}, ensure_ascii=False), flush=True)
        return result
    finally:
        try:
            client.stop()
        except DesktopError:
            pass
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        log.close()
        if previous_token is None:
            os.environ.pop('SSOK_AGENT_TOKEN', None)
        else:
            os.environ['SSOK_AGENT_TOKEN'] = previous_token


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--wall-x', type=float, default=.8)
    parser.add_argument('--ticks', type=int, default=30)
    parser.add_argument('--actions', type=int, default=1)
    args = parser.parse_args()
    if not .25 <= args.wall_x <= 1.2 or not 1 <= args.ticks <= 30 or not 1 <= args.actions <= 8:
        parser.error('Use a fixed wall in .25..1.2m, 1..30 ticks, 1..8 actions.')
    run_trial(args.godot, args.out, args.wall_x, ticks=args.ticks, actions=args.actions)


if __name__ == '__main__':
    main()
