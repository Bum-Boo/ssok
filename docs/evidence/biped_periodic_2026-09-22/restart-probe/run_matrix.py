from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import os,sys,subprocess,json,shutil
root=Path.cwd();out=root/'out';out.mkdir(exist_ok=True);(out/'.gdignore').touch()
godot=sys.argv[1]
version=subprocess.check_output([godot,'--version'],text=True).strip()
if version != '4.7.2.stable.official.ed1daf0bf':raise SystemExit('Wrong engine: '+version)
shutil.copyfile('source.json',out/'source.json')
(out/'engine.txt').write_text(version+'\n')
with (out/'import.log').open('w') as log:
 result=subprocess.run([godot,'--headless','--path','.', '--editor','--import','--quit'],stdout=log,stderr=subprocess.STDOUT,timeout=180)
if result.returncode or 'ERROR:' in (out/'import.log').read_text():raise SystemExit('Import failed')
def run_case(case):
 warmup,gap=case;name=f'warmup-{warmup}-gap-{gap}';env=os.environ.copy()
 for key,leaf in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
  d=out/'xdg'/name/leaf;d.mkdir(parents=True,exist_ok=True);env[key]=str(d)
 command=[godot,'--headless','--path','.', '--language','en','--fixed-fps','60','--script','tests/review_biped_restart.gd','--',f'--warmup={warmup}',f'--gap={gap}']
 with (out/f'{name}.log').open('w') as log:
  try:code=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=90).returncode
  except subprocess.TimeoutExpired:code=124
 text=(out/f'{name}.log').read_text();lines=[x.split('=',1)[1] for x in text.splitlines() if x.startswith('SSOK_RESTART_RESULT=')]
 item={'warmup':warmup,'gap':gap,'exit_code':code,'log':name+'.log','result':json.loads(lines[0]) if len(lines)==1 else None,'engine_errors':[x for x in text.splitlines() if x.startswith(('ERROR:','SCRIPT ERROR:'))]}
 (out/f'{name}.json').write_text(json.dumps(item,indent=2)+'\n')
 print(json.dumps(item),flush=True);return item
cases=[(warmup,gap) for warmup in [60,120,300] for gap in [1,6,18,90]]
with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(run_case,cases))
summary={'engine':version,'cases':results,'passed':sum(x['exit_code']==0 and x['result'] and x['result']['passed'] and not x['engine_errors'] for x in results),'total':len(results)}
(out/'results.json').write_text(json.dumps(summary,indent=2)+'\n')
print('TOTAL',summary['passed'],'/',summary['total'],flush=True)
raise SystemExit(0 if summary['passed']==summary['total'] else 1)
