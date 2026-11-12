from pathlib import Path
import hashlib,json,msvcrt,os,subprocess,zipfile
from datetime import datetime,timezone,timedelta

r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');b=Path('C:/Users/Hojun/.agents/backups/ssok-completion-20261010/package-camera-r5')
b.mkdir(exist_ok=False);out=r/'build/ai-loop-evidence/completion/package-camera-r5';out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=r).decode().strip()=='f2d581c3dd995d09f0797ccbef1ed543e56f23ea'
assert not subprocess.check_output(['git','status','--porcelain'],cwd=r)
plan=Path('C:/Users/Hojun/Documents/Obsidians/Frieren (arch)/30_Projects/ssok/AI 관측·행동 루프 공동개발 계획.md')
old=plan.read_bytes();(b/'plan.before.md').write_bytes(old)
stamp=datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')
contract='\n\n<!-- ssok-package-camera-r5 -->\n### 실제 Windows 배포본 카메라 경로 검증 — '+stamp+'\n\n기존 issue32/task의 r2 소스f31/0.3.1-camera-r2 고정. 목표: 실제 기본 Title→Open my project→Lab 프로젝트 JSON 가져오기/확인→AI탭 Enable/Forward/Stop과 인증된 loopback 관측·유한8틱행동·재관측·늦은관측 거부를 관찰. 가져올 graph는 기존 RobotCarPreset.build(.8)의 정상 ssok-project 직렬화, 런타임에 숨겨 넣지 않고 실제 UI 붙여넣기/가져오기 확인을 거친다. 수동Forward는 기존20틱. Source layout harness는 좌표와 fixture만 만들고 배포본 통과 근거로 합산하지 않는다. 허용: ignored build의 한정 metadata harness/PNG/log/영수증, 외부 1회 기능 검사 script와 기존 문서·정본기록. 금지: 앱/디자인/목표/물리/판정/모델입력/개인data 수정, provider호출/공개/merge. 실제 ZIP/PE/PCK SHA·source426·격리APPDATA/LOCALAPPDATA/메모리토큰/clipboard복구/ownedPID/정상종료/8127해제·640×480 PNG metadata/hash·정지/context검증, Astra 실제화면/센서PNG로 평가. 모든 subprocess 유한; 실패원본 보존. Output completion/package-camera-r5 및 backup동명; coordinator Codex 기록/검사, Astra 시각, source변경 필요시 기존Claude 역할. Strict image9/9·physical0/9/Mac/Arch인계/humanmerge/버전별공개승인 미완료 유지.\n'
value=old+contract.encode('utf8')
with plan.open('r+b',buffering=0) as f:
    msvcrt.locking(f.fileno(),msvcrt.LK_NBLCK,len(value)+1)
    try:assert f.read()==old;f.seek(0);f.write(value);f.truncate();os.fsync(f.fileno())
    finally:f.seek(0);msvcrt.locking(f.fileno(),msvcrt.LK_UNLCK,len(value)+1)
(b/'contract.json').write_text(json.dumps({'path':str(plan),'before_sha256':hashlib.sha256(old).hexdigest(),'post_sha256':sha(plan),'timestamp':stamp},indent=2)+'\n',encoding='utf8')
archive=r/'build/camera-release-clean-r2/ssok-0.3.1-camera-r2-windows-x86_64.zip'
assert sha(archive)=='572ae8eb14b90149938b9e8b10d9498ccc3b2863d7ccebf7674ba215e1e07f6e'
dest=out/'portable';dest.mkdir()
with zipfile.ZipFile(archive) as z:
    for n in z.namelist():assert (dest/n).resolve().is_relative_to(dest.resolve())
    z.extractall(dest)
apps=list(dest.rglob('ssok.exe'));assert len(apps)==1
app=apps[0];expected={'ssok.exe':'7aee4fe55877f0b03c94a809f7223b6e22960b94fe276d9b0411d8c5bd9254fb','ssok.pck':'2d4c4143b201f3b4cb3315a811673ea182247a09a18d1cf5a30e049a17928fe3'}
assert all(sha(app.parent/n)==h for n,h in expected.items())
(out/'package-inputs.json').write_text(json.dumps({'archive':str(archive),'archive_sha256':sha(archive),'app':str(app),'exact_export_and_installer_bytes':expected,'source':'f31f8d5ea7b6b3eaa48df9e6d50f60621eb3dfa4','version':'0.3.1-camera-r2','layout_only_not_app_verification':True},indent=2)+'\n')
print(json.dumps({'output':str(out),'app':str(app),'contract_recorded':True,'zip_and_export_sha_match':True}))
