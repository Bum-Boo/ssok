"""Foreground, single-goal desktop operator. App click dispatches; no background service."""
import argparse
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import time

from .desktop_client import DesktopClient, DesktopError
from .desktop_session import validate_goal_context
from .run_goal import end_process


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True, help='New public goal evidence directory')
    parser.add_argument('--seconds', type=int, default=900, help='Foreground waiting limit, at most15 minutes')
    args = parser.parse_args()
    if not 15 <= args.seconds <= 900:
        parser.error('Waiting limit must be15..900 seconds.')
    output = args.out.resolve()
    if output.exists():
        parser.error('Output must be a new directory.')
    client = DesktopClient(allow_operator=True)
    identity = secrets.token_hex(16)
    active = None
    claimed_context = None
    try:
        codex = shutil.which('codex')
        if not codex:
            raise DesktopError('Codex CLI unavailable.')
        auth = subprocess.run([codex, 'login', 'status'], capture_output=True, timeout=15)
        if auth.returncode or b'Logged in using ChatGPT' not in auth.stdout + auth.stderr:
            raise DesktopError('Operator requires the existing Codex ChatGPT login.')
        deadline = time.monotonic() + args.seconds
        print('Foreground operator waiting for one intentional app goal; existing Codex login,8steps/9images/300seconds.', flush=True)
        while time.monotonic() < deadline:
            reply = client.request('operator_poll', {'operator_id': identity})
            job = reply.get('job', {})
            if job:
                claimed_context = validate_goal_context({key: job.get(key) for key in ('episode_id', 'revision', 'control_generation')})
                if reply.get('policy') != {'max_steps': 8, 'max_observations': 9, 'seconds': 300}:
                    raise DesktopError('Unsupported operator policy; stopped before dispatch.')
                context = client.describe()
                if any(job.get(key) != context.get(key) for key in ('episode_id', 'revision', 'control_generation')):
                    raise DesktopError('App goal context changed; stopped before dispatch.')
                goal = job.get('goal')
                if not isinstance(goal, str) or not 1 <= len(goal.strip()) <= 1000:
                    raise DesktopError('Invalid app goal; stopped before dispatch.')
                active = subprocess.Popen([sys.executable, '-m', 'tools.app_control.run_goal', '--goal', goal,
                                           '--out', str(output), '--max-steps', '8', '--max-observations', '9', '--seconds', '300',
                                           '--expected-context', json.dumps(claimed_context)],
                                          env=os.environ.copy(), start_new_session=os.name == 'posix')
                try:
                    return active.wait(timeout=345)
                except subprocess.TimeoutExpired:
                    raise DesktopError('Goal runner deadline reached; stopped.') from None
            time.sleep(.25)
        return 0
    except (DesktopError, KeyboardInterrupt, OSError, subprocess.SubprocessError) as exc:
        if active is not None:
            try: client.stop(claimed_context)
            except DesktopError: pass
            try: active.wait(timeout=15)
            except subprocess.TimeoutExpired:
                end_process(active)
        print(str(exc) if isinstance(exc, DesktopError) else 'Operator ended; inspect public goal result or use local Stop.', file=sys.stderr)
        return 1
    finally:
        try:
            client.request('operator_leave', {'operator_id': identity})
        except DesktopError:
            pass


if __name__=='__main__':
    raise SystemExit(main())
