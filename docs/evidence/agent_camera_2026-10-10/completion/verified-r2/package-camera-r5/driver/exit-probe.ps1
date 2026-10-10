$ErrorActionPreference='Stop'
$out='C:/Users/Hojun/.agents/backups/ssok-completion-20261010/package-camera-r5'
$rows=@()
foreach($case in @('uncached','refresh','cached')) {
    $stdout=Join-Path $out "exit-probe-$case.stdout"; $stderr=Join-Path $out "exit-probe-$case.stderr"
    if(Test-Path -LiteralPath $stdout){throw 'Fresh probe only'}
    $process=Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @('-NoProfile','-NonInteractive','-Command','exit 0') -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if($case -eq 'cached'){$ownedHandle=$process.Handle}
    $waited=$process.WaitForExit(10000)
    if($case -eq 'refresh'){$process.Refresh()}
    $code=$process.ExitCode
    $rows+=@{case=$case;waited=$waited;has_exited=$process.HasExited;exit_code=$code;is_null=($null -eq $code)}
}
$rows | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'exit-probe.json') -Encoding utf8
$rows | ConvertTo-Json
