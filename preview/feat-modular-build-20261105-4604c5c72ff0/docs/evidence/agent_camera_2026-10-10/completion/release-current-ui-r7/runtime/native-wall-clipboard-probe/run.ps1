param([string]$App,[string]$Work,[string]$Layout)
$ErrorActionPreference="Stop"
$checks=[Collections.Generic.List[object]]::new()
function Check([bool]$Value,[string]$Name){$checks.Add([pscustomobject]@{name=$Name;passed=$Value});if(-not $Value){throw "FAIL: $Name"}}
. "C:/Users/Hojun/Projects/ssok-ai-loop/build/ai-loop-evidence/completion/release-current-ui-r7/native-wall-clipboard-probe/native_ui_readback.ps1"
try { VerifyNativeUi $App $Work $Layout } finally { $checks | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Work "checks.json") -Encoding utf8 }
