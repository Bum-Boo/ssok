"""Reproduce monitor/actor accept-order inversion in the actual rendered app, no provider."""
import argparse
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import threading
import time

from .desktop_client import DesktopClient, DesktopError


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve(); out.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy(); env['SSOK_AGENT_TOKEN'] = secrets.token_hex(32)
    env['XDG_DATA_HOME'] = str(out/'user-data'); env['XDG_CONFIG_HOME'] = str(out/'config')
    if os.name == 'nt':
        env['APPDATA'] = str(out/'user-data'); env['LOCALAPPDATA'] = str(out/'config')
    previous = os.environ.get('SSOK_AGENT_TOKEN'); os.environ['SSOK_AGENT_TOKEN'] = env['SSOK_AGENT_TOKEN']
    log = (out/'godot.log').open('w')
    process = subprocess.Popen([args.godot, '--path', '.', '--script', 'tools/app_control/run_desktop.gd',
                                '--', '--ssok-agent-bridge'], env=env, stdout=log, stderr=subprocess.STDOUT)
    client = DesktopClient()
    try:
        deadline = time.monotonic()+30
        while True:
            if process.poll() is not None: raise RuntimeError('Rendered fixture exited')
            try:
                if client.describe()['state'] == 'ready': break
            except DesktopError: pass
            if time.monotonic() > deadline: raise RuntimeError('Readiness timeout')
            time.sleep(.05)
        frame = client.observe(client.describe()); meta = frame.metadata
        checks = []
        def invert(operation):
            peer = socket.create_connection(('127.0.0.1',8127), timeout=3)
            wire = json.dumps({'id':'monitor-race','token':env['SSOK_AGENT_TOKEN'],'tool':'describe','args':{}}).encode()
            peer.sendall(wire); time.sleep(.15)
            timer = threading.Timer(.15, lambda: peer.sendall(b'\n')); timer.start()
            try:
                return operation()
            finally:
                timer.join()
                body = b''
                while chunk := peer.recv(4096): body += chunk
                peer.close()
                assert json.loads(body)['id']=='monitor-race'
        # Monitor gets the primary slot first. Fragment only its final newline to pin the race.
        peer = socket.create_connection(('127.0.0.1',8127), timeout=3)
        wire = json.dumps({'id':'monitor-race','token':env['SSOK_AGENT_TOKEN'],'tool':'describe','args':{}}).encode()
        peer.sendall(wire); time.sleep(.15)
        timer = threading.Timer(.15, lambda: peer.sendall(b'\n')); timer.start()
        error = None
        try:
            receipt = client.trace_dispatch(meta['frame_id'],meta['sha256'],meta['control_generation'],
                                            'Transport regression: actual camera frame.', 'fixture', 1,
                                            episode_id=meta['episode_id'])
        except DesktopError as exc:
            error = getattr(exc,'code',str(exc)); receipt = {}
        timer.join(); body = b''
        while chunk := peer.recv(4096): body += chunk
        peer.close()
        result = {'monitor_reply': json.loads(body), 'actor_error':error,
                  'receipt_matched':receipt.get('receipt')=='hash_matched'}
        (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps(result),flush=True)
        assert result['receipt_matched'], 'Monitor accept-order must not reject an authenticated actor receipt'
        checks.append('receipt_after_monitor')
        invert(lambda: client.drive_step(meta['frame_id'],meta['revision'],meta['control_generation'],1,episode_id=meta['episode_id']))
        checks.append('finite_action_after_monitor')
        final = invert(lambda: client.observe(client.describe()))
        assert final.metadata['frame_id'] != meta['frame_id']
        checks.append('fresh_observe_after_monitor')
        meta = final.metadata
        # A queued actor must not occupy the priority Stop lane or survive revocation.
        held = socket.create_connection(('127.0.0.1',8127), timeout=3)
        held.sendall(json.dumps({'id':'stop-race','token':env['SSOK_AGENT_TOKEN'],'tool':'describe','args':{}}).encode())
        time.sleep(.15)
        outcome = []
        def queued_receipt():
            try:
                client.trace_dispatch(meta['frame_id'],meta['sha256'],meta['control_generation'],
                                      'Queued before Stop.', 'fixture', 1,episode_id=meta['episode_id'])
                outcome.append('unexpected_accept')
            except DesktopError as exc: outcome.append(getattr(exc,'code',str(exc)))
        worker = threading.Thread(target=queued_receipt); worker.start(); time.sleep(.15)
        started = time.monotonic(); stopped = client.stop(); stop_seconds = time.monotonic()-started
        assert stopped['state']=='stopped' and stop_seconds < 1
        held.sendall(b'\n')
        while held.recv(4096): pass
        held.close(); worker.join(timeout=3)
        assert not worker.is_alive() and outcome==['stale_dispatch'], outcome
        checks.append('priority_stop_revokes_queued_actor')
        assert client.describe()['state']=='stopped'
        result |= {'checks':checks,'priority_stop_seconds':stop_seconds,'queued_actor_after_stop':outcome}
        (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps(result),flush=True)
    finally:
        try: client.stop()
        except DesktopError: pass
        process.terminate()
        try: process.wait(timeout=5)
        except subprocess.TimeoutExpired: process.kill(); process.wait()
        log.close()
        if previous is None: os.environ.pop('SSOK_AGENT_TOKEN',None)
        else: os.environ['SSOK_AGENT_TOKEN']=previous


if __name__=='__main__': main()
