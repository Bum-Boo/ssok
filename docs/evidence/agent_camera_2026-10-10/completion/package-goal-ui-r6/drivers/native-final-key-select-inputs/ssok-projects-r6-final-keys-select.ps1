param([ValidateSet('large','compact')][string]$Case='large')
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
. 'C:/Users/Hojun/Projects/ssok-ai-loop/tools/ci/windows/native_ui.ps1'
$work='C:/Users/Hojun/Projects/ssok-ai-loop/build/ai-loop-evidence/completion/package-goal-ui-r6/native-final-keys-select-'+$Case
New-Item -ItemType Directory -Path $work -ErrorAction Stop | Out-Null
$originalApp=$env:APPDATA;$originalLocal=$env:LOCALAPPDATA
$clipboard=[Windows.Forms.Clipboard]::GetDataObject()
$script:UiProcess=$null;$checks=[Collections.Generic.List[object]]::new();$trail=[Collections.Generic.List[object]]::new()
function State { try{return Get-Content -LiteralPath (Join-Path $work 'state.json') -Raw -Encoding utf8 | ConvertFrom-Json}catch{return $null} }
function Until([scriptblock]$predicate){for($i=0;$i -lt 100;$i++){$s=State;if($s -and (& $predicate $s)){return $s};Start-Sleep -Milliseconds 100};throw 'Native UI state deadline reached'}
function Check([bool]$value,[string]$name){$checks.Add([pscustomobject]@{passed=$value;name=$name});if(-not $value){throw ('FAIL '+$name)}}
function Key([string]$value){UiFocus;[Windows.Forms.SendKeys]::SendWait($value);Start-Sleep -Milliseconds 350;$s=State;$trail.Add($s);return $s}
try {
    $env:APPDATA=Join-Path $work 'appdata';$env:LOCALAPPDATA=Join-Path $work 'localappdata'
    $resolution=if($Case -eq 'compact'){'960x640'}else{'1400x950'}
    $script:UiProcess=Start-Process -FilePath 'C:/Users/Hojun/Projects/ssok-ai-loop/build/toolchain-windows/Godot_v4.7.2-stable_win64.exe' -WorkingDirectory 'C:/Users/Hojun/Projects/ssok-ai-loop' -ArgumentList @('--path','.','--rendering-driver','opengl3','--audio-driver','Dummy','--single-window','--resolution',$resolution,'--position','0,0','--max-fps','60','--script','build/ai-loop-evidence/completion/package-goal-ui-r6/native-final-keys-select.gd','--',$Case) -PassThru -RedirectStandardOutput (Join-Path $work 'native.stdout') -RedirectStandardError (Join-Path $work 'native.stderr')
    $handle=$script:UiProcess.Handle
    @{pid=$script:UiProcess.Id;source_draft=$true;case=$Case} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $work 'owned-app.json') -Encoding utf8
    $s=Until {param($s) $s.dialog_visible -and $s.panel_visible};$script:UiLayout=$s
    UiCapture (Join-Path $work 'before-escape.png')
    $s=Key '{ESC}';$s=Until {param($s) -not $s.dialog_visible}
    Check ($s.panel_visible) 'Actual OS Escape cancels nested confirmation before Projects'
    for($i=0;$i -lt 40 -and $s.focus -ne 'name';$i++){$s=Key '+{TAB}'}
    Check ($s.focus -eq 'name' -and $s.focus_fits) 'Actual OS cancellation returns to visible project name in Saved flow'
    [Windows.Forms.Clipboard]::SetText('Final native keyboard '+$Case)
    $s=Key '^a';$s=Key '^v';$s=Key '{TAB}'
    Check ($s.focus -eq 'save' -and $s.focus_fits) 'Actual OS Tab exposes and focuses Save'
    $s=Key '{ENTER}';$s=Until {param($s) $s.saved_count -eq 2}
    Check (-not $s.runtime_running) 'Actual OS Enter saves another snapshot without running code'
    $seen=@{}
    for($i=0;$i -lt 40;$i++){
        $s=Key '{TAB}'
        if($s.focus -eq 'library'){$s=Key '{DOWN}';Check $s.library_selected 'Actual OS Down selects a saved snapshot'}
        if($s.focus -in @('open','delete','Close')){
            Check $s.focus_fits ('Actual OS Tab reveals '+$s.focus+' fully in viewport')
            if(-not $seen.ContainsKey($s.focus)){UiCapture (Join-Path $work ('focused-'+$s.focus+'.png'));$seen[$s.focus]=$true}
        }
        if($seen.ContainsKey('open') -and $seen.ContainsKey('delete') -and $seen.ContainsKey('Close')){break}
    }
    Check ($seen.ContainsKey('open') -and $seen.ContainsKey('delete') -and $seen.ContainsKey('Close')) 'Actual OS keyboard reaches Open, Delete and fixed Close'
    if($Case -eq 'compact'){Check ($s.scroll_vertical -gt 0) 'Actual compact 200 percent keyboard scrolled the body'}
    $s=Key '{ESC}';$s=Until {param($s) -not $s.panel_visible}
    Check $s.navigation 'Actual OS Escape closes Projects and restores navigation'
    Check ($script:UiProcess.CloseMainWindow()) 'Owned source UI receives normal close'
    Check ($script:UiProcess.WaitForExit(10000) -and $script:UiProcess.ExitCode -eq 0) 'Owned source UI exits normally'
} finally {
    if($script:UiProcess -and -not $script:UiProcess.HasExited){$script:UiProcess.Kill();$script:UiProcess.WaitForExit()}
    if($clipboard){[Windows.Forms.Clipboard]::SetDataObject($clipboard,$true)}else{[Windows.Forms.Clipboard]::Clear()}
    $env:APPDATA=$originalApp;$env:LOCALAPPDATA=$originalLocal
    $checks | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $work 'checks.json') -Encoding utf8
    $trail | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $work 'input-trail.json') -Encoding utf8
    @{owned_exit=($script:UiProcess -and $script:UiProcess.HasExited);clipboard_restored=$true;appdata_restored=($env:APPDATA -eq $originalApp);localappdata_restored=($env:LOCALAPPDATA -eq $originalLocal)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $work 'cleanup.json') -Encoding utf8
}
