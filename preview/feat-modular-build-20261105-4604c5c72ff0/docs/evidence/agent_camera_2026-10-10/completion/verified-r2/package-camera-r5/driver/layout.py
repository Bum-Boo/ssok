from pathlib import Path
import hashlib,json,os,subprocess
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');out=r/'build/ai-loop-evidence/completion/package-camera-r5'
env=os.environ.copy();env['APPDATA']=str(out/'layout-appdata');env['LOCALAPPDATA']=str(out/'layout-localappdata')
command=[str(r/'build/toolchain-windows/Godot_v4.7.2-stable_win64.exe'),'--headless','--path',str(r),'--audio-driver','Dummy','--script','build/ai-loop-evidence/completion/package-camera-r5/layout.gd']
p=subprocess.run(command,env=env,capture_output=True,timeout=45);(out/'layout.log').write_bytes(p.stdout+p.stderr)
assert p.returncode==0 and not any(t in p.stdout+p.stderr for t in [b'SCRIPT ERROR:',b'ERROR:'])
(out/'layout-receipt.json').write_text(json.dumps({'command':command,'exit_code':p.returncode,'source_layout_only':True,'sha256':{n:hashlib.sha256((out/n).read_bytes()).hexdigest() for n in ['layout.gd','layout.json','project.json']}},indent=2)+'\n')
print((out/'layout.json').read_text())
