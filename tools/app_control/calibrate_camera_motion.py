"""Replay bounded camera actions and idle captures without a model/provider.

The independent pixel/physics measurements stay in developer output. They never
become observations or inputs of desktop_mcp/run_goal.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import time

from .camera_pixels import measure_floor
from .desktop_client import DesktopClient, DesktopError, write_observation


def replay(godot, output, wall_x, ticks, idle):
    root = Path(__file__).resolve().parents[2]
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, SSOK_AGENT_TOKEN=secrets.token_hex(32),
               XDG_DATA_HOME=str(output / 'user-data'), XDG_CONFIG_HOME=str(output / 'config'))
    if os.name == 'nt':
        env.update(APPDATA=str(output / 'user-data'), LOCALAPPDATA=str(output / 'config'))
    original = os.environ.get('SSOK_AGENT_TOKEN')
    os.environ['SSOK_AGENT_TOKEN'] = env['SSOK_AGENT_TOKEN']
    client = DesktopClient()
    captures = []
    log = (output / 'godot.log').open('w', encoding='utf-8')
    process = subprocess.Popen([godot, '--path', str(root), '--script', 'tools/app_control/run_desktop.gd',
                                '--', '--ssok-agent-bridge', '--evaluate-camera', '--wall-x', str(wall_x)],
                               env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 30
        while True:
            if process.poll() is not None:
                raise RuntimeError('Fixture exited; inspect godot.log')
            try:
                if client.describe()['state'] == 'ready':
                    break
            except DesktopError:
                pass
            if time.monotonic() >= deadline:
                raise RuntimeError('Fixture readiness timeout')
            time.sleep(.05)

        def capture(label):
            frame = client.observe(client.describe())
            path = output / f'{label}.png'
            write_observation(frame, path)
            captures.append({'label': label, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                             'metadata': frame.metadata, 'pixels': measure_floor(path)})
            return frame.metadata

        meta = capture('initial')
        for index, count in enumerate(ticks):
            if idle:
                time.sleep(idle)
                meta = capture(f'pre-{index + 1}-idle')
            client.drive_step(meta['frame_id'], meta['revision'], meta['control_generation'],
                              count, episode_id=meta['episode_id'])
            meta = capture(f'post-{index + 1}')
        time.sleep(2)
        capture('final-idle')
        client.stop()
        time.sleep(2.2)
        evaluations = list((output / 'user-data').glob('godot/app_userdata/*/camera-evaluation.json'))
        evaluation = json.loads(evaluations[0].read_text()) if len(evaluations) == 1 else None
        result = {'schema': 1, 'wall_x': wall_x, 'ticks': ticks, 'idle_seconds': idle,
                  'captures': captures, 'evaluation': evaluation,
                  'final_image_target': captures[-1]['pixels']['image_target']}
        (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({'captures': [(x['label'], x['pixels']['floor_pixels']) for x in captures],
                          'final_image_target': result['final_image_target'],
                          'travel': evaluation.get('travel_x') if evaluation else None}, indent=2))
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
        if original is None:
            os.environ.pop('SSOK_AGENT_TOKEN', None)
        else:
            os.environ['SSOK_AGENT_TOKEN'] = original


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--wall-x', type=float, default=.6)
    parser.add_argument('--ticks', nargs='+', type=int, default=[25, 25, 25, 15, 1])
    parser.add_argument('--idle', type=float, default=0)
    parser.add_argument('--verify-goal', action='store_true')
    args = parser.parse_args()
    if not .25 <= args.wall_x <= 1.2 or len(args.ticks) > 8 or not all(1 <= t <= 30 for t in args.ticks) or not 0 <= args.idle <= 10:
        parser.error('Use .25..1.2m, at most 8 actions of 1..30 ticks and 0..10s idle.')
    result = replay(args.godot, args.out, args.wall_x, args.ticks, args.idle)
    if args.verify_goal and not result['final_image_target']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
