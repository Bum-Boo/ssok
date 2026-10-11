$ErrorActionPreference='Stop'
$out='C:/Users/Hojun/.agents/backups/ssok-completion-20261010/release-current-ui-r7/runtime-cleanup.json'
$owned=@(Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%' OR Name='ssok.exe'" | Where-Object { $_.ExecutablePath -like 'C:\Users\Hojun\Projects\ssok-ai-loop\build\*' } | Select-Object -ExpandProperty ProcessId)
$listeners=@(Get-NetTCPConnection -LocalPort 8127 -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess)
$uninstall=Test-Path -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ssok'
$location=Test-Path -LiteralPath 'HKCU:\Software\Bum-Boo\ssok'
$shortcut=Test-Path -LiteralPath (Join-Path $env:APPDATA 'Microsoft/Windows/Start Menu/Programs/ssok/ssok.lnk')
$result=@{owned_project_process_ids=$owned;port8127_listener_process_ids=$listeners;uninstall_registration_remaining=$uninstall;location_registration_remaining=$location;start_menu_shortcut_remaining=$shortcut;no_process_kill_performed=$true;registration_scope='Actual installer keys, including HKCU Software Bum-Boo ssok; older r6 location-only check used a wrong key.'}
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $out -Encoding utf8
if($owned.Count -or $listeners.Count -or $uninstall -or $location -or $shortcut){throw 'Task runtime residue exists; investigate recorded IDs without killing unrelated processes'}
