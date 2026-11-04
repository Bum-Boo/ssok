from pathlib import Path
import hashlib,json,subprocess,time
r=Path('C:/Users/Hojun/Projects/ssok-ai-loop');out=r/'build/ai-loop-evidence/completion/release-current-ui-r7/native-wall-clipboard-probe';out.mkdir(exist_ok=False)
canonical=r/'tools/ci/windows/native_ui.ps1';code=canonical.read_text(encoding='utf8');original=hashlib.sha256(canonical.read_bytes()).hexdigest()
needle="$ids=@('raise-flag','finish-line','wall-brake')";assert code.count(needle)==1;code=code.replace(needle,"$ids=@('wall-brake')")
assert code.count('$index -lt 3')==1;code=code.replace('$index -lt 3','$index -lt $ids.Count')
needle="            Start-Sleep -Milliseconds 700\n            UiClick \"game_run_$id\"";assert code.count(needle)==1
guard='''            Start-Sleep -Milliseconds 700
            # Reset the clipboard before Copy so readback cannot merely reuse caller input.
            [Windows.Forms.Clipboard]::SetText('ssok-editor-readback-sentinel')
            UiFocus
            [Windows.Forms.SendKeys]::SendWait('^a')
            [Windows.Forms.SendKeys]::SendWait('^c')
            Start-Sleep -Milliseconds 500
            $actualSource=[Windows.Forms.Clipboard]::GetText()
            [IO.File]::WriteAllText((Join-Path $Work "actual-code-$id.txt"),$actualSource,[Text.UTF8Encoding]::new($false))
            UiCapture (Join-Path $Work "code-entered-$id.png")
            Check ($actualSource.Replace("`r`n","`n").TrimEnd() -ceq $script:UiLayout.native_solutions.$id.Replace("`r`n","`n").TrimEnd()) "Actual native Code editor readback matches intended $id program"
            UiClick "game_run_$id"'''
code=code.replace(needle,guard)
needle='            Check $cleared "Native title/map/code input clears $id from actual stage evaluation"';assert code.count(needle)==1;code=code.replace(needle,'            UiCapture (Join-Path $Work "before-result-$id.png")\n'+needle)
code=code.replace("if ($index -lt 2)","if ($id -ne 'wall-brake')")
driver=out/'native_ui_readback.ps1';driver.write_bytes(code.encode('utf8'))
app=r/'build/projects-release-clean-r7/windows/ssok.exe';layout=r/'build/projects-release-clean-r7/export-logs/browser-layout.json'
wrapper=out/'run.ps1';wrapper.write_bytes(('param([string]$App,[string]$Work,[string]$Layout)\n$ErrorActionPreference="Stop"\n$checks=[Collections.Generic.List[object]]::new()\nfunction Check([bool]$Value,[string]$Name){$checks.Add([pscustomobject]@{name=$Name;passed=$Value});if(-not $Value){throw "FAIL: $Name"}}\n. "'+str(driver).replace('\\','/')+'"\ntry { VerifyNativeUi $App $Work $Layout } finally { $checks | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Work "checks.json") -Encoding utf8 }\n').encode('utf8'))
command=['powershell.exe','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',str(wrapper),'-App',str(app),'-Work',str(out),'-Layout',str(layout)];started=time.monotonic();timed_out=False
with (out/'driver.log').open('wb') as log:
    process=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    try:exit_code=process.wait(timeout=120)
    except subprocess.TimeoutExpired:timed_out=True;subprocess.run(['taskkill.exe','/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=20);process.wait(timeout=20);exit_code=124
checks=json.loads((out/'checks.json').read_text(encoding='utf-8-sig')) if (out/'checks.json').exists() else []
receipt={'command':command,'exit_code':exit_code,'seconds':time.monotonic()-started,'timed_out':timed_out,'checks':checks,'original_native_helper_sha256':original,'canonical_helper_unchanged':hashlib.sha256(canonical.read_bytes()).hexdigest()==original,'package_pck_sha256':hashlib.sha256((app.parent/'ssok.pck').read_bytes()).hexdigest(),'browser_clipboard_gates_finished_before_probe':True,'scope':'One actual native wall-brake stage; intended code verified by resetting clipboard sentinel then actual app Ctrl+C, existing physical threshold unchanged.'}
(out/'receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode());print(json.dumps(receipt),flush=True);print((out/'driver.log').read_text(errors='replace')[-1800:]);assert exit_code==0 and not timed_out and checks and all(x['passed'] for x in checks)
