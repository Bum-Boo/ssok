from pathlib import Path
import json,os,subprocess,time
assert os.name=='posix'
r=Path('/mnt/c/Users/Hojun/Projects/ssok-ai-loop');out=r/'build/ai-loop-evidence/completion/release-current-ui-r7/ci-layout-probe-1';out.mkdir(exist_ok=False)
env=os.environ.copy();env['XDG_DATA_HOME']=str(out/'data');env['XDG_CONFIG_HOME']=str(out/'config')
command=[str(r/'build/toolchain-linux/godot'),'--headless','--path',str(r),'--quit-after','600','--language','en','--script','res://tools/ci/browser_layout.gd','--',str(out/'browser-layout.json')];started=time.monotonic();x=subprocess.run(command,env=env,cwd=r,capture_output=True,timeout=40);log=x.stdout+x.stderr;(out/'console.log').write_bytes(log)
receipt={'command':command,'exit_code':x.returncode,'seconds':time.monotonic()-started,'layout_file_exists':(out/'browser-layout.json').is_file(),'engine_error':b'ERROR:' in log,'scope':'Focused original canonical Linux CI layout with finite600 process-iteration cap; unchanged source, separate user data.'};(out/'receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode());print(json.dumps(receipt),flush=True);print(log.decode(errors='replace')[-5000:]);assert x.returncode==0 and receipt['layout_file_exists'] and not receipt['engine_error']
