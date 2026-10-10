"""Bounded rendered desktop check; explicit --goal additionally launches the direct Astra CLI."""
import argparse
import asyncio
import json
import os
from pathlib import Path
import secrets
import selectors
import socket
import subprocess
import sys
import time

from tools.app_control.desktop_client import DesktopClient, DesktopError, write_observation


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--interactive', action='store_true')
    parser.add_argument('--wall-x', type=float, default=0.8)
    parser.add_argument('--goal', help='Explicit goal for the direct Astra/Codex CLI pilot')
    parser.add_argument('--goal-output', type=Path)
    parser.add_argument('--goal-seconds', type=int, default=240)
    parser.add_argument('--goal-max-steps', type=int, default=4)
    parser.add_argument('--goal-contract-check', action='store_true', help='Check real MCP goal bounds without calling a provider')
    args = parser.parse_args()
    if args.goal and (args.interactive or not args.goal_output):
        parser.error('--goal requires a new --goal-output and cannot use --interactive')
    if not 0.25 <= args.wall_x <= 1.2:
        parser.error('wall-x must be between0.25 and1.2 metres')
    root = Path.cwd()
    out = root / 'build/ai-loop-evidence/desktop'
    out.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env['SSOK_AGENT_TOKEN'] = secrets.token_hex(32)
    env['XDG_DATA_HOME'] = str(out/'user-data')
    env['XDG_CONFIG_HOME'] = str(out/'config')
    os.environ['SSOK_AGENT_TOKEN'] = env['SSOK_AGENT_TOKEN']
    logfile = (out/'godot.log').open('w')
    process = subprocess.Popen([args.godot, '--path', str(root), '--script', 'tools/app_control/run_desktop.gd', '--', '--ssok-agent-bridge', '--wall-x', str(args.wall_x)], env=env, stdout=logfile, stderr=subprocess.STDOUT)
    client = DesktopClient()
    last = None
    pilot_log = out/'pilot-events.jsonl'
    if args.interactive:
        pilot_log.write_text('')
    try:
        deadline = time.monotonic()+30
        state = {}
        last_error = ''
        while True:
            if process.poll() is not None:
                raise RuntimeError('Godot exited; see desktop/godot.log')
            try:
                state = client.describe()
                if state['state'] == 'ready': break
            except DesktopError as exc:
                last_error=str(exc)
            if time.monotonic()>deadline: raise RuntimeError('Desktop did not become ready: '+json.dumps(state)+' '+last_error)
            time.sleep(.05)
        print(json.dumps({'ready': True, 'state': state}), flush=True)

        def observe():
            nonlocal last
            last = client.observe(client.describe())
            path = out/f'frame-{last.metadata["frame_id"]}.png'
            write_observation(last, path)
            return {'path': str(path), 'metadata': last.metadata}

        if args.goal:
            result = subprocess.run([sys.executable, '-m', 'tools.app_control.run_goal', '--goal', args.goal,
                                     '--out', str(args.goal_output), '--max-steps', str(args.goal_max_steps),
                                     '--max-observations', str(args.goal_max_steps+1), '--seconds', str(args.goal_seconds)],
                                    env=env, timeout=args.goal_seconds+45)
            if result.returncode:
                raise RuntimeError('Direct goal pilot did not complete; inspect its result.json')
        elif args.goal_contract_check:
            async def contract_check():
                from mcp import ClientSession, StdioServerParameters
                from mcp.client.stdio import stdio_client
                params = StdioServerParameters(command=sys.executable,
                    args=['-m', 'tools.app_control.desktop_mcp', '--allow-actions', '--goal-output',
                          str(root/'build/ai-loop-evidence/goal-contract-camera'), '--max-steps', '1', '--max-observations', '2'], env=env)
                async with stdio_client(params) as (reader, writer):
                    async with ClientSession(reader, writer) as session:
                        await session.initialize()
                        listed = await session.list_tools()
                        assert {tool.name for tool in listed.tools} == {'observe', 'decide', 'stop'}
                        image = await session.call_tool('observe', {})
                        assert not image.is_error and image.content[1].type == 'image'
                        metadata = json.loads(image.content[0].text)
                        decision = {'frame_sha256': metadata['sha256'], 'summary': 'Contract fixture: floor is visible.', 'action': 'forward', 'ticks': 8}
                        action = await session.call_tool('decide', decision)
                        assert not action.is_error
                        final = await session.call_tool('observe', {})
                        assert not final.is_error
                        metadata = json.loads(final.content[0].text)
                        excess = await session.call_tool('decide', decision | {'frame_sha256': metadata['sha256']})
                        assert excess.is_error and client.describe()['state'] == 'stopped'
                        late = await session.call_tool('observe', {})
                        assert late.is_error
                        return {'goal_mcp_tools': 3, 'images': 2, 'finite_action': True, 'budget_rejection_stopped': True, 'late_observe_rejected': True}
            print(json.dumps(asyncio.run(contract_check())), flush=True)
        elif args.interactive:
            selector=selectors.DefaultSelector()
            selector.register(sys.stdin,selectors.EVENT_READ)
            pilot_deadline=time.monotonic()+900
            while time.monotonic()<pilot_deadline:
                if not selector.select(timeout=1): continue
                line=sys.stdin.readline()
                if not line: break
                command = json.loads(line)
                tool = command['tool']
                if tool == 'observe': result = observe()
                elif tool == 'drive_step':
                    if last is None: raise ValueError('Observe first')
                    meta = last.metadata
                    result = client.drive_step(meta['frame_id'],meta['revision'],meta['control_generation'],command['ticks'],command.get('action','forward'),episode_id=meta['episode_id'])
                elif tool == 'trace_dispatch':
                    meta=last.metadata
                    result=client.trace_dispatch(meta['frame_id'],meta['sha256'],meta['control_generation'],command['summary'],'gpt-6-astra native worker',8,episode_id=meta['episode_id'])
                elif tool == 'stop': result=client.stop()
                elif tool == 'finish': break
                else: raise ValueError('Unsupported pilot command')
                with pilot_log.open('a',encoding='utf-8') as log:
                    log.write(json.dumps({'tool':tool,'args':command,'data':result},ensure_ascii=False)+'\n')
                print(json.dumps({'tool': tool,'data':result},ensure_ascii=False),flush=True)
        else:
            before=observe()
            meta=last.metadata
            receipt=client.trace_dispatch(meta['frame_id'],meta['sha256'],meta['control_generation'],'한국어 관측 요약 검증','protocol check fixture',8,episode_id=meta['episode_id'])
            assert receipt['receipt']=='hash_matched'
            # A rejected authenticated envelope must preserve its public request ID.
            try:
                client.request('trace_dispatch',{'episode_id':'stale-test-episode'})
            except DesktopError as exc:
                assert getattr(exc,'code','')=='stale_dispatch'
            else:
                raise AssertionError('Stale receipt accepted')
            peer=socket.create_connection(('127.0.0.1',8127),timeout=3)
            wire=(json.dumps({'id':'rejected-id','token':'invalid-token','tool':'describe','args':{}})+'\n').encode()
            peer.sendall(wire[:20]); time.sleep(.02); peer.sendall(wire[20:])
            reply=b''
            while chunk:=peer.recv(4096): reply+=chunk
            peer.close()
            assert json.loads(reply)=={'id':'rejected-id','error':'unauthorized_or_invalid_request'}
            moved=client.drive_step(meta['frame_id'],meta['revision'],meta['control_generation'],20,episode_id=meta['episode_id'])
            after=observe()
            assert after['metadata']['frame_id']>before['metadata']['frame_id']
            assert after['metadata']['sha256']!=before['metadata']['sha256']

            async def check_stdio():
                from mcp import ClientSession, StdioServerParameters
                from mcp.client.stdio import stdio_client
                params=StdioServerParameters(command=sys.executable,args=['-m','tools.app_control.desktop_mcp','--allow-actions'],env=env)
                async with stdio_client(params) as (reader,writer):
                    async with ClientSession(reader,writer) as session:
                        await session.initialize()
                        listed=await session.list_tools()
                        assert {x.name for x in listed.tools}=={'describe','observe','drive_step','stop'}
                        frame=await session.call_tool('observe',{})
                        assert not frame.is_error
                        assert [x.type for x in frame.content]==['text','image']
                        metadata=json.loads(frame.content[0].text)
                        step=await session.call_tool('drive_step',{k:metadata[k] for k in ['episode_id','frame_id','revision','control_generation']}|{'ticks':10,'action':'brake'})
                        assert not step.is_error
                        return {'tools':len(listed.tools),'image_bytes_verified':True,'bounded_action':True}
            mcp_result=asyncio.run(check_stdio())
            # Interrupt an outstanding capture through the independent authenticated Stop lane.
            peer=socket.create_connection(('127.0.0.1',8127),timeout=3)
            peer.sendall((json.dumps({'id':'pending-capture','token':env['SSOK_AGENT_TOKEN'],'tool':'observe','args':{}})+'\n').encode())
            time.sleep(.05)
            state_during_capture = client.describe()
            assert state_during_capture['state'] in ('ready', 'capturing', 'settling', 'drawing')
            start=time.monotonic()
            stopped=client.stop()
            elapsed=time.monotonic()-start
            response=peer.recv(4096)
            peer.close()
            assert b'local_stop' in response and stopped['state']=='stopped' and elapsed<1
            result={'tcp_observe_step_observe':True,'mcp_stdio':mcp_result,'pending_describe':state_during_capture['state'],'pending_stop_seconds':elapsed,'stop_generation':stopped['control_generation'],'source':'dirty local draft based4eb059f'}
            (out/'result.json').write_text(json.dumps(result,indent=2))
            print(json.dumps(result),flush=True)
    finally:
        try: client.stop()
        except DesktopError: pass
        process.terminate()
        try: process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill(); process.wait()
        logfile.close()
        os.environ.pop('SSOK_AGENT_TOKEN',None)


if __name__=='__main__':
    main()
