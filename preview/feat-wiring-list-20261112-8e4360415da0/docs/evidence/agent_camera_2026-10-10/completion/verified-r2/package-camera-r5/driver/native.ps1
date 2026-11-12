param([string]$App,[string]$Work,[string]$Layout,[string]$Python,[string]$Fixture)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$OutputEncoding=[Text.UTF8Encoding]::new($false)
. 'C:/Users/Hojun/Projects/ssok-ai-loop/tools/ci/windows/native_ui.ps1'
$script:UiLayout=Get-Content -LiteralPath $Layout -Raw -Encoding utf8 | ConvertFrom-Json
$clipboard=[Windows.Forms.Clipboard]::GetDataObject()
$originalAppData=$env:APPDATA; $originalLocalData=$env:LOCALAPPDATA; $originalToken=$env:SSOK_AGENT_TOKEN
$originalGateOut=$env:SSOK_PACKAGE_GATE_OUT
$checks=[Collections.Generic.List[object]]::new()
function Check([bool]$Value,[string]$Name) { $checks.Add([pscustomobject]@{name=$Name;passed=$Value});if(-not $Value){throw "FAIL: $Name"} }
function Bridge([string]$Phase) {
    & $Python -X utf8 'C:/Users/Hojun/Projects/ssok-package-camera-r5-bridge.py' $Phase
    Check ($LASTEXITCODE -eq 0) "Authenticated bridge phase $Phase"
}
$script:UiProcess=$null
try {
    Check (-not (Get-NetTCPConnection -LocalPort 8127 -State Listen -ErrorAction SilentlyContinue)) 'Fresh bridge port is unused'
    $env:APPDATA=Join-Path $Work 'appdata';$env:LOCALAPPDATA=Join-Path $Work 'localappdata'
    Check (-not (Test-Path -LiteralPath $env:APPDATA)) 'Fresh isolated app data'
    $env:SSOK_AGENT_TOKEN=[Guid]::NewGuid().ToString('N')+[Guid]::NewGuid().ToString('N')
    $env:SSOK_PACKAGE_GATE_OUT=$Work
    $script:UiProcess=Start-Process -FilePath $App -WorkingDirectory (Split-Path $App) -ArgumentList @('--rendering-driver','opengl3','--audio-driver','Dummy','--language','en','--single-window','--resolution','1400x950','--position','0,0','--max-fps','60','--','--ssok-agent-bridge') -PassThru -RedirectStandardOutput (Join-Path $Work 'native.stdout') -RedirectStandardError (Join-Path $Work 'native.stderr')
    # Start-Process loses ExitCode on Windows PowerShell unless the handle is retained while live.
    $ownedProcessHandle=$script:UiProcess.Handle
    @{pid=$script:UiProcess.Id;app=$App} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Work 'owned-app.json') -Encoding utf8
    for($i=0;$i -lt 100;$i++){ $script:UiProcess.Refresh();if($script:UiProcess.HasExited){throw 'App exited before window'};if($script:UiProcess.MainWindowHandle -ne [IntPtr]::Zero){break};Start-Sleep -Milliseconds 100 }
    Start-Sleep -Seconds 3
    UiCapture (Join-Path $Work 'title.png')
    UiClick 'title_projects';Start-Sleep -Seconds 2
    UiCapture (Join-Path $Work 'projects.png')
    UiClick 'project_transfer_tab';UiClick 'transfer_text'
    [Windows.Forms.Clipboard]::SetText((Get-Content -LiteralPath $Fixture -Raw -Encoding utf8))
    UiFocus;[Windows.Forms.SendKeys]::SendWait('^a');[Windows.Forms.SendKeys]::SendWait('^v');Start-Sleep -Milliseconds 700
    UiClick 'project_import';UiCapture (Join-Path $Work 'import-confirm.png')
    UiClick 'project_confirm';UiCapture (Join-Path $Work 'car-imported.png')
    for($i=0;$i -lt 6;$i++){UiClick 'tabs_right'}
    UiClick 'ai_tab';UiCapture (Join-Path $Work 'ai-before-enable.png')
    UiClick 'agent_enable';Bridge 'before';UiCapture (Join-Path $Work 'ai-ready.png')
    UiClick 'agent_forward';Bridge 'after-native';UiCapture (Join-Path $Work 'ai-after-native.png')
    Bridge 'bridge-eight';UiCapture (Join-Path $Work 'ai-after-bridge.png')
    UiClick 'agent_stop';Bridge 'stopped';UiCapture (Join-Path $Work 'ai-stopped.png')
    Check ($script:UiProcess.CloseMainWindow()) 'Owned native window receives normal close'
    Check ($script:UiProcess.WaitForExit(10000)) 'Owned package closes normally'
    @{has_exited=$script:UiProcess.HasExited;exit_code=$script:UiProcess.ExitCode;retained_handle=($ownedProcessHandle -ne [IntPtr]::Zero)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Work 'normal-exit.json') -Encoding utf8
    Check ($script:UiProcess.ExitCode -eq 0) 'Owned package normal exit code'
    $log=(Get-Content -LiteralPath (Join-Path $Work 'native.stdout') -Raw)+(Get-Content -LiteralPath (Join-Path $Work 'native.stderr') -Raw)
    Check ($log -notmatch '(?m)^(SCRIPT ERROR:|ERROR:)') 'Actual packaged graphics and bridge log has no engine errors'
    Check (-not (Get-NetTCPConnection -LocalPort 8127 -State Listen -ErrorAction SilentlyContinue)) 'Bridge listener released on normal close'
} finally {
    if($script:UiProcess -and -not $script:UiProcess.HasExited){$script:UiProcess.Kill();$script:UiProcess.WaitForExit()}
    if($clipboard){[Windows.Forms.Clipboard]::SetDataObject($clipboard,$true)}else{[Windows.Forms.Clipboard]::Clear()}
    $env:APPDATA=$originalAppData;$env:LOCALAPPDATA=$originalLocalData;$env:SSOK_AGENT_TOKEN=$originalToken
    $env:SSOK_PACKAGE_GATE_OUT=$originalGateOut
    @{clipboard_restoration_completed=$true;appdata_restored=($env:APPDATA -eq $originalAppData);localappdata_restored=($env:LOCALAPPDATA -eq $originalLocalData);token_restored=($env:SSOK_AGENT_TOKEN -eq $originalToken);owned_process_exited=($script:UiProcess -and $script:UiProcess.HasExited)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Work 'driver-cleanup.json') -Encoding utf8
    $checks | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Work 'checks.json') -Encoding utf8
}
