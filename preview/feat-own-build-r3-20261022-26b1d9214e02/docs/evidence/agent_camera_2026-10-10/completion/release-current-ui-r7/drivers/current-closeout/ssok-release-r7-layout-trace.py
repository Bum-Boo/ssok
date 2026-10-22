from pathlib import Path
import hashlib,json,os,subprocess,time
assert os.name=='posix'
r=Path('/mnt/c/Users/Hojun/Projects/ssok-ai-loop');out=r/'build/ai-loop-evidence/completion/release-current-ui-r7/ci-layout-trace-2';out.mkdir(exist_ok=False)
source=r/'tools/ci/browser_layout.gd';code=source.read_text();original_sha=hashlib.sha256(source.read_bytes()).hexdigest()
replacements={
 'func _run() -> void:\n':'func _run() -> void:\n\tprint("[DEBUG-r7-layout] run begin")\n',
 '\troot.add_child(main)\n':'\tprint("[DEBUG-r7-layout] before main ready")\n\troot.add_child(main)\n\tprint("[DEBUG-r7-layout] after main ready")\n',
 '\tmain.projects.request_open()\n':'\tprint("[DEBUG-r7-layout] before request_open")\n\tmain.projects.request_open()\n\tprint("[DEBUG-r7-layout] after request_open")\n',
 '\tconfirmation.wrap_controls = false\n':'\tprint("[DEBUG-r7-layout] before wrapping override")\n\tconfirmation.wrap_controls = false\n',
 '\tconfirmation.min_size = Vector2i.ZERO\n':'\tprint("[DEBUG-r7-layout] before minsize override")\n\tconfirmation.min_size = Vector2i.ZERO\n\tprint("[DEBUG-r7-layout] after minsize override")\n',
 'func _point(name: String, control: Control) -> void:\n':'func _point(name: String, control: Control) -> void:\n\tprint("[DEBUG-r7-layout] point ", name)\n',
}
for a,z in replacements.items():assert code.count(a)==1,a;code=code.replace(a,z)
(out/'trace.gd').write_text(code);env=os.environ.copy();env['XDG_DATA_HOME']=str(out/'data');env['XDG_CONFIG_HOME']=str(out/'config')
command=[str(r/'build/toolchain-linux/godot'),'--headless','--path',str(r),'--quit-after','600','--language','en','--script','res://'+(out/'trace.gd').relative_to(r).as_posix(),'--',str(out/'browser-layout.json')];started=time.monotonic();timed_out=False
with (out/'console.log').open('wb') as log:
    process=subprocess.Popen(command,env=env,cwd=r,stdout=log,stderr=subprocess.STDOUT)
    try:code=process.wait(timeout=15)
    except subprocess.TimeoutExpired:timed_out=True;process.kill();process.wait();code=124
text=(out/'console.log').read_text(errors='replace');receipt={'command':command,'exit_code':code,'timed_out':timed_out,'seconds':time.monotonic()-started,'layout_file_exists':(out/'browser-layout.json').is_file(),'canonical_source_sha256':original_sha,'canonical_source_unchanged':hashlib.sha256(source.read_bytes()).hexdigest()==original_sha,'instrumentation':'Targeted [DEBUG-r7-layout] stage boundaries; ignored diagnostic copy only.'};(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt));print(text[-5500:]);assert code==0 and receipt['layout_file_exists'] and 'ERROR:' not in text
