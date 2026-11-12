param([string]$Python = 'python')
$ErrorActionPreference = 'Stop'
$ArchiveRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$PythonExecutable = (Get-Command $Python -ErrorAction Stop).Source
& $PythonExecutable -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)'
if ($LASTEXITCODE -ne 0) { throw 'Local operator setup requires Python3.11 or newer.' }
$VenvPath = Join-Path $ArchiveRoot '.operator-venv'
$VenvPython = Join-Path $VenvPath 'Scripts/python.exe'
if (Test-Path -LiteralPath $VenvPath) {
    if (-not (Test-Path -LiteralPath (Join-Path $VenvPath 'pyvenv.cfg')) -or -not (Test-Path -LiteralPath $VenvPython)) {
        throw 'The local .operator-venv folder is not a usable environment. Preserve it and extract to a fresh directory.'
    }
} else {
    & $PythonExecutable -m venv $VenvPath
    if ($LASTEXITCODE -ne 0) { throw 'Local Python environment creation failed; inspect the preceding error.' }
}
$Requirements = Join-Path $ArchiveRoot 'requirements.txt'
if (-not (Test-Path -LiteralPath $Requirements)) {
    $Requirements = Join-Path $ArchiveRoot 'tools/motion_lab/requirements-mcp.txt'
}
Push-Location $ArchiveRoot
try {
    & $VenvPython -m pip install --disable-pip-version-check --timeout 30 --retries 0 -r $Requirements
    if ($LASTEXITCODE -ne 0) { throw 'Local dependency installation failed; inspect the preceding error and rerun setup.' }
    & $VenvPython -m tools.app_control.doctor --dependencies-only
    if ($LASTEXITCODE -ne 0) { throw 'Local dependencies are incomplete; follow the listed steps.' }
} finally {
    Pop-Location
}
Write-Output 'Local environment is ready. Run start-operator.ps1 -CheckOnly to check your existing Codex ChatGPT login.'
