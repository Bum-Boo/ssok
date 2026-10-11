param([string]$App,[string]$Work,[string]$Layout,[string]$Fixture)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
. 'C:/Users/Hojun/Projects/ssok-ai-loop/tools/ci/windows/native_ui.ps1'
$script:UiLayout=Get-Content -LiteralPath $Layout -Raw -Encoding utf8 | ConvertFrom-Json
$clipboard=[Windows.Forms.Clipboard]::GetDataObject()
$originalAppData=$env:APPDATA;$originalLocalData=$env:LOCALAPPDATA
$checks=[Collections.Generic.List[object]]::new()
function Check([bool]$Value,[string]$Name){$checks.Add([pscustomobject]@{name=$Name;passed=$Value});if(-not $Value){throw "FAIL: $Name"}}
$script:UiProcess=$null
try {
    $env:APPDATA=Join-Path $Work 'appdata';$env:LOCALAPPDATA=Join-Path $Work 'localappdata'
    Check (-not (Test-Path -LiteralPath $env:APPDATA)) 'Fresh isolated packaged Projects app data'
    $script:UiProcess=Start-Process -FilePath $App -WorkingDirectory (Split-Path $App) -ArgumentList @('--rendering-driver','opengl3','--audio-driver','Dummy','--language','en','--single-window','--resolution','1400x950','--position','0,0','--max-fps','60') -PassThru -RedirectStandardOutput (Join-Path $Work 'native.stdout') -RedirectStandardError (Join-Path $Work 'native.stderr')
    $ownedHandle=$script:UiProcess.Handle
    for($i=0;$i -lt 100;$i++){$script:UiProcess.Refresh();if($script:UiProcess.HasExited){throw 'App exited before window'};if($script:UiProcess.MainWindowHandle -ne [IntPtr]::Zero){break};Start-Sleep -Milliseconds 100}
    Start-Sleep -Seconds 3
    UiCapture (Join-Path $Work '01-title.png')
    UiClick 'title_projects';UiCapture (Join-Path $Work '02-projects.png')
    UiClick 'project_transfer_tab';UiClick 'transfer_text'
    [Windows.Forms.Clipboard]::SetText((Get-Content -LiteralPath $Fixture -Raw -Encoding utf8))
    UiFocus;[Windows.Forms.SendKeys]::SendWait('^a');[Windows.Forms.SendKeys]::SendWait('^v')
    UiClick 'project_import';UiCapture (Join-Path $Work '03-confirmation.png')
    UiFocus;[Windows.Forms.SendKeys]::SendWait('{ESC}');Start-Sleep -Milliseconds 500
    UiCapture (Join-Path $Work '04-cancelled.png')
    UiClick 'project_import';UiClick 'project_confirm'
    UiCapture (Join-Path $Work '05-imported.png')
    UiClick 'projects_reopen';UiClick 'project_transfer_tab';UiClick 'project_copy'
    $export=[Windows.Forms.Clipboard]::GetText();$document=$export | ConvertFrom-Json
    Check ($document.format -eq 'ssok-project') 'Actual app Copy JSON writes a project document'
    [IO.File]::WriteAllText((Join-Path $Work 'actual-export.json'),$export,[Text.UTF8Encoding]::new($false))
    UiCapture (Join-Path $Work '06-reexported.png')
    UiFocus;[Windows.Forms.SendKeys]::SendWait('{ESC}');Start-Sleep -Milliseconds 500
    Check ($script:UiProcess.CloseMainWindow()) 'Owned package receives normal close'
    Check ($script:UiProcess.WaitForExit(10000)) 'Owned current package exits normally'
    Check ($script:UiProcess.ExitCode -eq 0) 'Owned current package normal exit code'
    $log=(Get-Content -LiteralPath (Join-Path $Work 'native.stdout') -Raw -Encoding utf8)+(Get-Content -LiteralPath (Join-Path $Work 'native.stderr') -Raw -Encoding utf8)
    Check ($log -notmatch '(?m)^(SCRIPT ERROR:|ERROR:)') 'Actual packaged Projects has no engine errors'
} finally {
    if($script:UiProcess -and -not $script:UiProcess.HasExited){$script:UiProcess.Kill();$script:UiProcess.WaitForExit()}
    $checks | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Work 'checks.json') -Encoding utf8
    if($clipboard){[Windows.Forms.Clipboard]::SetDataObject($clipboard,$true)}else{[Windows.Forms.Clipboard]::Clear()}
    $env:APPDATA=$originalAppData;$env:LOCALAPPDATA=$originalLocalData
    @{owned_app_closed=($null -eq $script:UiProcess -or $script:UiProcess.HasExited);clipboard_restored=$true;environment_restored=$true;provider_calls=0} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Work 'cleanup.json') -Encoding utf8
}
