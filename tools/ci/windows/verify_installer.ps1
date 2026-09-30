param([string]$Installer, [string]$Work, [string]$Layout)
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
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $Executable
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.WorkingDirectory = Split-Path $Executable
    $quoted = foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]' -and -not $argument.StartsWith('/D=')) {
            '"' + $argument.Replace('"', '\"') + '"'
        } else { $argument }
    }
    $info.Arguments = $quoted -join ' '
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    $process.Start() | Out-Null
    $output = $process.StandardOutput.ReadToEndAsync()
    $errors = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($Seconds * 1000)
    if ($timedOut) {
        $process.Kill()
        $process.WaitForExit()
    }
    [IO.File]::WriteAllText("$Log.stdout", $output.GetAwaiter().GetResult())
    [IO.File]::WriteAllText("$Log.stderr", $errors.GetAwaiter().GetResult())
    if ($timedOut) { throw "Timed out: task process $($process.Id); logs retained at $Log" }
    return $process.ExitCode
}
$Installed = $false
try {
    $Code = RunBounded $Installer @('/S', "/D=$Install") (Join-Path $Work 'install')
    $Installed = Test-Path (Join-Path $Install 'Uninstall.exe')
    Check ($Code -eq 0) 'Silent per-user installer exits successfully'
    Check $Installed 'Uninstaller is installed'
    Check (Test-Path (Join-Path $Install 'ssok.exe')) 'App executable is installed'
    Check (Test-Path (Join-Path $Install 'ssok.pck')) 'App resource pack is installed'
    Check ((Get-ItemProperty $Registration).InstallLocation -eq $Install) 'Apps uninstall registration targets this installation'
    Check (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'ssok\ssok.lnk')) 'Start-menu launch shortcut is installed'
    $App = Join-Path $Install 'ssok.exe'
    $Code = RunBounded $App @('--version') (Join-Path $Work 'version')
    Check ($Code -eq 0 -and (Get-Content (Join-Path $Work 'version.stdout') -Raw).Trim() -eq '4.7.2.stable.official.ed1daf0bf') 'Installed executable contains the pinned Godot engine'
    . (Join-Path $PSScriptRoot 'native_ui.ps1')
    VerifyNativeUi $App $Work $Layout
    Check ((Get-ChildItem $Work -Filter 'stage-*.png').Count -eq 3) 'Native Windows graphics capture all three stages'
    Set-Content (Join-Path $Install 'user-added.keep') 'synthetic file not owned by installer'
    $Code = RunBounded (Join-Path $Install 'Uninstall.exe') @('/S') (Join-Path $Work 'uninstall')
    for ($i=0; $i -lt 300; $i++) {
        if (-not (Test-Path (Join-Path $Install 'ssok.exe')) -and -not (Test-Path $Registration) -and -not (Test-Path $LocationKey) -and -not (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'ssok\ssok.lnk'))) { break }
        Start-Sleep -Milliseconds 100
    }
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
