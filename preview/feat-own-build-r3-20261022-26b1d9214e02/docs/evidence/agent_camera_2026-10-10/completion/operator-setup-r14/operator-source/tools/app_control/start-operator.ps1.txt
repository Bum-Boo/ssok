param(
    [string]$Out,
    [string]$Python,
    [int]$Seconds = 900,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
if (-not $CheckOnly -and -not $Out) {
    throw 'Choose a new evidence directory with -Out, or use -CheckOnly for preparation.'
}
$ArchiveRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
if (-not $Python) {
    $LocalPython = Join-Path $ArchiveRoot '.operator-venv/Scripts/python.exe'
    $Python = if (Test-Path -LiteralPath $LocalPython) { $LocalPython } else { 'python' }
}
# Resolve the caller's output before changing to the archive's module root.
if (-not $CheckOnly) { $OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out) }
$PythonExecutable = (Get-Command $Python -ErrorAction Stop).Source
& $PythonExecutable -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)'
if ($LASTEXITCODE -ne 0) { throw 'Operator requires Python3.11 or newer. Run setup-operator.ps1 with a supported Python.' }
Push-Location $ArchiveRoot
try {
    $DoctorArgs = @('-m', 'tools.app_control.doctor')
    if (-not $CheckOnly) { $DoctorArgs += '--check-token' }
    & $PythonExecutable @DoctorArgs
    $OperatorExit = $LASTEXITCODE
    if ($OperatorExit -eq 0 -and -not $CheckOnly) {
        & $PythonExecutable -m tools.app_control.run_operator --out $OutputPath --seconds $Seconds
        $OperatorExit = $LASTEXITCODE
    }
} finally {
    Pop-Location
}
exit $OperatorExit
