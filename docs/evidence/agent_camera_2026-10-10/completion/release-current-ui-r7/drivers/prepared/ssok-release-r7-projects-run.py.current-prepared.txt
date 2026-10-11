from pathlib import Path
import hashlib,json,os,subprocess,time
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');e=r/'build/ai-loop-evidence/completion/release-current-ui-r7';out=e/'package-projects';release=r/'build/projects-release-clean-r7';b=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/release-current-ui-r7')
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
meta=read(release/'release.json');assert meta['commit']=='fa868ca07cdd9d2b8edb27cbab89cd00263c851f' and not meta['dirty_worktree'] and not meta['source_changed_during_build']
assert not (out/'layout.json').exists() and not (out/'checks.json').exists()
inputs=read(e/'source-before.json')['files'];assert all(sha(r/n)==h for n,h in inputs.items())
env=os.environ.copy();env['APPDATA']=str(out/'layout-appdata');env['LOCALAPPDATA']=str(out/'layout-localappdata')
cmd=[str(r/'build/toolchain-windows/Godot_v4.7.2-stable_win64.exe'),'--path',str(r),'--rendering-driver','opengl3','--audio-driver','Dummy','--single-window','--resolution','1400x950','--position','0,0','--max-fps','60','--script','build/ai-loop-evidence/completion/release-current-ui-r7/package-projects/layout.gd'];x=subprocess.run(cmd,env=env,capture_output=True,timeout=90);log=x.stdout+x.stderr;(out/'layout.log').write_bytes(log);assert x.returncode==0 and b'ERROR:' not in log
(out/'layout-receipt.json').write_bytes((json.dumps({'command':cmd,'exit_code':x.returncode,'native_rendered_geometry_only':True,'layout_sha256':sha(out/'layout.json'),'project_fixture_sha256':sha(out/'project.json'),'confirmation_anchor':read(out/'layout.json')['points']['project_confirm'],'app_ui_raw_sha256':sha(r/'src/ui/project_panel.gd')},indent=2)+'\n').encode())
driver=Path('C:/Users/Hojun/Projects/ssok-release-r7-projects-native.ps1');(b/'package-projects-driver.before-execution.ps1').write_bytes(driver.read_bytes())
app=release/'windows/ssok.exe';package={n:sha(app.parent/n) for n in ['ssok.exe','ssok.pck']}
cmd=['powershell.exe','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',str(driver),'-App',str(app),'-Work',str(out),'-Layout',str(out/'layout.json'),'-Fixture',str(out/'project.json')];started=time.monotonic()
timed_out=False
with (out/'driver.log').open('wb') as log:
    process=subprocess.Popen(cmd,cwd=r,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    try:code=process.wait(timeout=120)
    except subprocess.TimeoutExpired:
        timed_out=True;subprocess.run(['taskkill.exe','/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=20);process.wait(timeout=20);code=124
checks=read(out/'checks.json') if (out/'checks.json').is_file() else [];receipt={'command':cmd,'exit_code':code,'timed_out':timed_out,'seconds':time.monotonic()-started,'checks':len(checks),'failures':sum(not x['passed'] for x in checks),'package_source':meta['commit'],'package_version':meta['version'],'pe_pck_sha256':package,'source426_unchanged':all(sha(r/n)==h for n,h in inputs.items()),'package_bytes_unchanged':all(sha(app.parent/n)==h for n,h in package.items()),'provider_calls':0,'published':False}
(out/'receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode());print(json.dumps(receipt),flush=True);assert code==0 and not timed_out and not receipt['failures'] and receipt['source426_unchanged'] and receipt['package_bytes_unchanged']
actual=read(out/'actual-export.json');fixture=read(out/'project.json');assert actual['format']==fixture['format'] and actual['version']==fixture['version'] and actual['graph']==fixture['graph'] and actual['source']==fixture['source']
comparison={'actual_graph_source_format_version_equal_to_imported_fixture':True,'actual_export_sha256':sha(out/'actual-export.json'),'original_fixture_sha256':sha(out/'project.json'),'scope':'Actual Windows packaged Copy JSON after two Import clicks separated by Escape cancellation; no learner code/provider execution.'}
(out/'export-comparison.json').write_bytes((json.dumps(comparison,indent=2)+'\n').encode());print(json.dumps(comparison))
