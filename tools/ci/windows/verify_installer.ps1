param([string]$Installer, [string]$Work, [string]$StageScript)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Work = [IO.Path]::GetFullPath($Work)
New-Item -ItemType Directory -Force -Path $Work | Out-Null
$Install = Join-Path $Work 'installed'
$Registration = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ssok'
$LocationKey = 'HKCU:\Software\Bum-Boo\ssok'
if ((Test-Path $Install) -or (Test-Path $Registration) -or (Test-Path $LocationKey)) {
    throw 'Existing installation or test path detected; refusing to overwrite it.'
}
$Results = [Collections.Generic.List[object]]::new()
function Check([bool]$Value, [string]$Name) {
    $Results.Add([pscustomobject]@{name=$Name; passed=$Value})
    if (-not $Value) { throw "FAIL: $Name" }
}
function RunBounded([string]$Executable, [string[]]$Arguments, [string]$Log, [int]$Seconds = 120) {
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -PassThru -RedirectStandardOutput "$Log.stdout" -RedirectStandardError "$Log.stderr"
    if (-not $process.WaitForExit($Seconds * 1000)) {
        $process.Kill()
        throw "Timed out: task process $($process.Id)"
    }
    return $process.ExitCode
}
$Installed = $false
try {
    $Code = RunBounded $Installer @('/S', "/D=$Install") (Join-Path $Work 'install')
    Check ($Code -eq 0) 'Silent per-user installer exits successfully'
    $Installed = Test-Path (Join-Path $Install 'Uninstall.exe')
    Check $Installed 'Uninstaller is installed'
    Check (Test-Path (Join-Path $Install 'ssok.exe')) 'App executable is installed'
    Check (Test-Path (Join-Path $Install 'ssok.pck')) 'App resource pack is installed'
    Check ((Get-ItemProperty $Registration).InstallLocation -eq $Install) 'Apps uninstall registration targets this installation'
    Check (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'ssok\ssok.lnk')) 'Start-menu launch shortcut is installed'
    $App = Join-Path $Install 'ssok.exe'
    $Code = RunBounded $App @('--version') (Join-Path $Work 'version')
    Check ($Code -eq 0 -and (Get-Content (Join-Path $Work 'version.stdout') -Raw).Trim() -eq '4.7.2.stable.official.ed1daf0bf') 'Installed executable contains the pinned Godot engine'
    $Code = RunBounded $App @('--rendering-driver', 'opengl3', '--audio-driver', 'Dummy', '--fixed-fps', '60', '--language', 'en', '--log-file', (Join-Path $Work 'stage-engine.log'), '--script', $StageScript, '--', $Work) (Join-Path $Work 'stages')
    $Log = (Get-Content (Join-Path $Work 'stages.stdout') -Raw) + (Get-Content (Join-Path $Work 'stages.stderr') -Raw)
    Check ($Code -eq 0 -and $Log -match 'stage_authoring_check: [1-9][0-9]* checks, 0 failures' -and $Log -notmatch '(?m)^(SCRIPT ERROR:|ERROR:)') 'Installed native Windows app clears all three stages and passes the authoring checks'
    Check ((Get-ChildItem $Work -Filter 'stage-*.png').Count -eq 3) 'Native Windows graphics capture all three measured stages'
    Set-Content (Join-Path $Install 'user-added.keep') 'synthetic file not owned by installer'
    $Code = RunBounded (Join-Path $Install 'Uninstall.exe') @('/S') (Join-Path $Work 'uninstall')
    for ($i=0; $i -lt 50 -and (Test-Path (Join-Path $Install 'ssok.exe')); $i++) { Start-Sleep -Milliseconds 100 }
    Check ($Code -eq 0 -and -not (Test-Path (Join-Path $Install 'ssok.exe'))) 'Silent uninstall removes only packaged application files'
    Check (-not (Test-Path $Registration) -and -not (Test-Path $LocationKey)) 'Uninstall registration is removed'
    Check (Test-Path (Join-Path $Install 'user-added.keep')) 'Uninstall preserves extra user files'
    Check (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'ssok\ssok.lnk'))) 'Start-menu shortcut is removed'
    $Installed = $false
} finally {
    $Results | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Work 'checks.json') -Encoding UTF8
    if ($Installed -and (Test-Path (Join-Path $Install 'Uninstall.exe'))) {
        RunBounded (Join-Path $Install 'Uninstall.exe') @('/S') (Join-Path $Work 'cleanup-uninstall') | Out-Null
    }
}
