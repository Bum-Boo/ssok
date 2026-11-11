from pathlib import Path

source = Path('C:/Users/Hojun/Projects/ssok-control-r16-target.py').read_text(encoding='utf8')
source = source.replace("root = repo/'build/ai-loop-evidence/completion/attitude-rate-r16'", "root = repo/'build/ai-loop-evidence/completion/attitude-rate-r16/variant18'")
source = source.replace('ssok-control-r16-run.py','ssok-control-r16-rate18-run.py')
source = source.replace("{'k32','combined'}", "{'combined'}")
exec(compile(source,'r16-rate18-original-target-check','exec'))
