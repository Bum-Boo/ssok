"""Reproduce the same CI check plan when local mock sockets are unavailable.

Run from repository root. Failures remain failures; this is not a release verification.
"""
import os,sys,json,tempfile
from pathlib import Path
sys.path.insert(0,str(Path.cwd()))
from tools.ci.verify import checks,run,report
output=Path('build/verification-b-all').resolve();output.mkdir(exist_ok=True)
(output/'.gdignore').touch()
with tempfile.TemporaryDirectory(prefix='ssok-b-verify-') as data:
 env=dict(os.environ)
 for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
  env[key]=str(Path(data)/key.lower())
 env['PYTHONDONTWRITEBYTECODE']='1'
 env['GODOT']=str(Path('build/toolchain/godot').resolve())
 for key in ['OPENAI_API_KEY','SSOK_LIVE','SSOK_MODEL','SSOK_BRIDGE_TOKEN']:
  env.pop(key,None)
 results=[]
 for check in checks(env['GODOT'],sys.executable):
  results.append(run(check,output,env))
  report(results,output)
print(json.dumps({'checks':len(results),'failures':sum(not r['passed'] for r in results)}))

raise SystemExit(1 if any(not row["passed"] for row in results) else 0)
