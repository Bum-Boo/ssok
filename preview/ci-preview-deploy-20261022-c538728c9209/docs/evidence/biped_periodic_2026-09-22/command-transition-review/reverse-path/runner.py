from concurrent.futures import ThreadPoolExecutor
import hashlib,json,os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];GODOT="/home/hojun/.local/share/agent-remote/jobs/20260922-040405-ssok-godot-policy-923fd175/work/godot-bin"
out=ROOT/"out";out.mkdir(exist_ok=True)
cases=[]
for settle in [0,137]:
 for keys,frames in [(["W","D","W","A"],180),(["W","S","W"],240),(["S"],240),(["S"],720),(["D"],180),(["A"],180)]:
  cases.append(dict(name="-".join(keys)+str(frames),settle=settle,phases=[dict(keys=[key],frames=frames) for key in keys]))
plans=[(v,c) for v in ["baseline","reverse_time","reflect"] for c in cases]
(out/"plan.json").write_text(json.dumps(plans,indent=2))
subprocess.run([GODOT,"--headless","--path",str(ROOT),"--import"],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True,timeout=90)
def run(pair):
 i,(variant,c)=pair;inp=out/f"{i}.input.json";inp.write_text(json.dumps(c));env=dict(os.environ,SSOK_ANALOG_CASE=str(inp),SSOK_BACK_CURVE=variant)
 r=subprocess.run([GODOT,"--headless","--path",str(ROOT),"--fixed-fps","60","--script","probe/analog_check.gd"],env=env,capture_output=True,text=True,timeout=120);(out/f"{i}.log").write_text(r.stdout+r.stderr)
 rows=[s[len("ANALOG_JSON "):] for s in r.stdout.splitlines() if s.startswith("ANALOG_JSON ")]
 result=dict(variant=variant,case=c,exit_code=r.returncode,result=json.loads(rows[0]) if rows else None);print(variant,c["name"],c["settle"],r.returncode,flush=True);return result
with ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(run,enumerate(plans)))
(out/"results.json").write_text(json.dumps(results,indent=2))
