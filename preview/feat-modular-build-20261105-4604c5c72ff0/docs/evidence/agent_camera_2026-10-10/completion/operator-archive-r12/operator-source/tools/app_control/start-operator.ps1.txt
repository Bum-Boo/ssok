param(
    [Parameter(Mandatory=$true)][string]$Out,
    [string]$Python = 'python',
    [int]$Seconds = 900
)
$ErrorActionPreference = 'Stop'
if (-not $env:SSOK_AGENT_TOKEN -or $env:SSOK_AGENT_TOKEN.Length -lt 32) {
    throw 'Start ssok with the same SSOK_AGENT_TOKEN (at least 32 characters) first.'
}
# Resolve the caller's output before changing to the archive's module root.
$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$PythonExecutable = (Get-Command $Python -ErrorAction Stop).Source
Push-Location (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..'))
try {
    & $PythonExecutable -c 'import mcp'
    if ($LASTEXITCODE -ne 0) { throw 'Install the pinned operator requirements in this Python environment first.' }
    & $PythonExecutable -m tools.app_control.run_operator --out $OutputPath --seconds $Seconds
    $OperatorExit = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $OperatorExit
