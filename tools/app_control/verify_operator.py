"""Explicit one-call rendered app-button smoke check, using the real foreground operator."""
import argparse
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import time

from .desktop_client import DesktopClient, DesktopError


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = args.out.resolve();out.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy();env['SSOK_AGENT_TOKEN'] = secrets.token_hex(32)
    env['XDG_DATA_HOME'] = str(out/'user-data');env['XDG_CONFIG_HOME'] = str(out/'config')
    if os.name == 'nt':
        env['APPDATA'] = str(out/'user-data');env['LOCALAPPDATA'] = str(out/'config')
    goal = 'Observe the camera, move forward only3 ticks once, observe again, then stop.'
    manifest = {'provider':'OpenAI', 'requested_model':'gpt-6-astra', 'auth':'existing Codex ChatGPT login',
                'sent_data':['goal','camera PNGs','public frame context','short visual summaries','tool results'],
                'limits':{'cli_launches':1,'actions':8,'images':9,'seconds':300},
                'scope':'test-simulated app Run click through real foreground operator; no navigation-success claim'}
    (out/'dispatch.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest),flush=True)
    log=(out/'godot.log').open('w')
    app=subprocess.Popen([args.godot,'--path',str(root),'--script','tools/app_control/run_desktop.gd','--',
                          '--ssok-agent-bridge','--evaluate-camera','--wall-x','.5','--test-app-goal',goal],
                         env=env,stdout=log,stderr=subprocess.STDOUT)
    operator=None;previous=os.environ.get('SSOK_AGENT_TOKEN');os.environ['SSOK_AGENT_TOKEN']=env['SSOK_AGENT_TOKEN'];client=DesktopClient()
    try:
        deadline=time.monotonic()+30
        while time.monotonic()<deadline:
            try:
                if client.describe()['state']=='ready':break
            except DesktopError:pass
            if app.poll() is not None:raise RuntimeError('Fixture exited; inspect godot.log')
            time.sleep(.05)
        else:raise RuntimeError('App readiness timeout')
        operator=subprocess.Popen([sys.executable,'-m','tools.app_control.run_operator','--out',str(out/'actor'),'--seconds','60'],
                                  env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        stdout,_=operator.communicate(timeout=365);(out/'operator.log').write_bytes(stdout)
        result=json.loads((out/'actor/result.json').read_text())
        deadline=time.monotonic()+5
        while time.monotonic()<deadline:
            files=list((out/'user-data').glob('godot/app_userdata/*/camera-evaluation.json'))
            if files:break
            time.sleep(.05)
        clicks=list((out/'user-data').glob('godot/app_userdata/*/operator-ui-click.json'))
        click=json.loads(clicks[0].read_text());evaluation=json.loads(files[0].read_text())
        (out/'ui-click.json').write_text(json.dumps(click,indent=2)+'\n');(out/'evaluation.json').write_text(json.dumps(evaluation,indent=2)+'\n')
        assert operator.returncode==0 and click=={'test_simulated_button_click':True,'queued':True,'goal_preserved':True}
        assert result['completed_actions']==1 and result['observations']==2 and result['final_reobserved'] and result['stop_confirmed']
        print(json.dumps({'app_button_to_operator_to_real_ai':True,'completed_actions':1,'images':2,'final_reobserved':True,'stop':True}),flush=True)
    finally:
        try:client.stop()
        except DesktopError:pass
        if operator and operator.poll() is None:
            operator.terminate()
            try:operator.wait(timeout=15)
            except subprocess.TimeoutExpired:operator.kill();operator.wait()
        app.terminate()
        try:app.wait(timeout=5)
        except subprocess.TimeoutExpired:app.kill();app.wait()
        log.close()
        if previous is None:os.environ.pop('SSOK_AGENT_TOKEN',None)
        else:os.environ['SSOK_AGENT_TOKEN']=previous


if __name__=='__main__':main()
