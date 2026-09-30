# Exercise the shipped app through Windows input; release templates reject --script.
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class SsokNativeUi {
 [StructLayout(LayoutKind.Sequential)] public struct Point { public int X,Y; }
 [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr w);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr w, out uint pid);
 [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a,uint b,bool attach);
 [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr w);
 [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr w, ref Point p);
 [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr w, out Rect r);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint x,uint y,int data,UIntPtr extra);
}
'@
[SsokNativeUi]::SetProcessDPIAware() | Out-Null
function UiFocus {
    $script:UiProcess.Refresh()
    if ($script:UiProcess.HasExited) { throw 'App exited during native interaction' }
    $script:UiHandle=$script:UiProcess.MainWindowHandle
    $foreground=[SsokNativeUi]::GetForegroundWindow()
    [uint32]$owner=0
    $foregroundThread=[SsokNativeUi]::GetWindowThreadProcessId($foreground,[ref]$owner)
    $currentThread=[SsokNativeUi]::GetCurrentThreadId()
    $attached=$foregroundThread -ne $currentThread -and [SsokNativeUi]::AttachThreadInput($currentThread,$foregroundThread,$true)
    try {
        [SsokNativeUi]::BringWindowToTop($script:UiHandle) | Out-Null
        [SsokNativeUi]::SetForegroundWindow($script:UiHandle) | Out-Null
    } finally { if ($attached) { [SsokNativeUi]::AttachThreadInput($currentThread,$foregroundThread,$false) | Out-Null } }
    Start-Sleep -Milliseconds 200
    [SsokNativeUi]::GetWindowThreadProcessId([SsokNativeUi]::GetForegroundWindow(),[ref]$owner) | Out-Null
    if ($owner -ne $script:UiProcess.Id) { throw "Task app cannot acquire foreground; refusing input (expected PID $($script:UiProcess.Id), foreground PID $owner)" }
}
function UiPoint([string]$Name) {
    UiFocus
    $p=New-Object SsokNativeUi+Point
    [SsokNativeUi]::ClientToScreen($script:UiHandle,[ref]$p) | Out-Null
    $a=$script:UiLayout.points.$Name
    if (-not $a) { throw "Missing layout anchor: $Name" }
    [SsokNativeUi]::SetCursorPos($p.X+[int]$a[0],$p.Y+[int]$a[1]) | Out-Null
}
function UiClick([string]$Name) {
    UiPoint $Name
    [SsokNativeUi]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 100
    [SsokNativeUi]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 700
}
function UiScroll([int]$Amount) {
    UiPoint 'stage_picker'
    [SsokNativeUi]::mouse_event(0x800,0,0,$Amount,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 700
}
function UiCapture([string]$Path) {
    UiFocus
    $r=New-Object SsokNativeUi+Rect
    [SsokNativeUi]::GetClientRect($script:UiHandle,[ref]$r) | Out-Null
    if ($r.Right -ne $script:UiLayout.viewport[0] -or $r.Bottom -ne $script:UiLayout.viewport[1]) { throw 'Native client size differs from verified layout' }
    $p=New-Object SsokNativeUi+Point
    [SsokNativeUi]::ClientToScreen($script:UiHandle,[ref]$p) | Out-Null
    $rect=New-Object Drawing.Rectangle($p.X,$p.Y,$r.Right,$r.Bottom)
    if (-not [Windows.Forms.SystemInformation]::VirtualScreen.Contains($rect)) { throw 'Task window extends outside the screen; refusing partial capture' }
    $bitmap=New-Object Drawing.Bitmap($r.Right,$r.Bottom)
    $graphics=[Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($p.X,$p.Y,0,0,$bitmap.Size)
        $bitmap.Save($Path,[Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function VerifyNativeUi([string]$App,[string]$Work,[string]$Layout) {
    $script:UiLayout=Get-Content $Layout -Raw | ConvertFrom-Json
    $clipboard=[Windows.Forms.Clipboard]::GetDataObject()
    $script:UiProcess=$null
    try {
        $script:UiProcess=Start-Process -FilePath $App -WorkingDirectory (Split-Path $App) -ArgumentList @('--rendering-driver','opengl3','--audio-driver','Dummy','--language','en','--single-window','--resolution','1400x950','--position','0,0','--max-fps','60') -PassThru -RedirectStandardOutput (Join-Path $Work 'native.stdout') -RedirectStandardError (Join-Path $Work 'native.stderr')
        for ($i=0; $i -lt 100; $i++) {
            $script:UiProcess.Refresh()
            if ($script:UiProcess.HasExited) { throw 'Native app exited before showing its window' }
            if ($script:UiProcess.MainWindowHandle -ne [IntPtr]::Zero) { break }
            Start-Sleep -Milliseconds 100
        }
        Start-Sleep -Seconds 3
        $ids=@('raise-flag','finish-line','wall-brake')
        for ($index=0; $index -lt 3; $index++) {
            UiClick 'stop'
            UiClick 'stages_tab'
            UiScroll 3600
            if ($index) {
                UiClick 'stage_picker'
                for ($down=0; $down -le $index; $down++) { [Windows.Forms.SendKeys]::SendWait('{DOWN}'); Start-Sleep -Milliseconds 100 }
                [Windows.Forms.SendKeys]::SendWait('{ENTER}')
                Start-Sleep -Milliseconds 700
            }
            UiClick 'stage_load'
            if ($index) { UiClick 'stage_confirm' }
            UiClick 'stage_answer'
            UiClick 'run_code'
            Start-Sleep -Seconds 12
            UiClick 'stages_tab'
            UiCapture (Join-Path $Work "stage-$($ids[$index]).png")
            UiScroll -3600
            [Windows.Forms.Clipboard]::SetText('ssok-verification-pending')
            UiClick 'stage_export'
            [Windows.Forms.SendKeys]::SendWait('^c')
            Start-Sleep -Milliseconds 500
            $text=[Windows.Forms.Clipboard]::GetText()
            $stage=$text | ConvertFrom-Json
            Check ($stage.format -eq 'ssok-stage' -and $stage.id -eq $ids[$index] -and $stage.author_solution.source.Length -gt 0) "Native UI clears and exports verified $($ids[$index]) solution"
            [IO.File]::WriteAllText((Join-Path $Work "stage-$($ids[$index]).json"),$text)
        }
        $script:UiProcess.CloseMainWindow() | Out-Null
        Check ($script:UiProcess.WaitForExit(10000)) 'Native app closes normally after interaction'
        $log=(Get-Content (Join-Path $Work 'native.stdout') -Raw)+(Get-Content (Join-Path $Work 'native.stderr') -Raw)
        Check ($log -notmatch '(?m)^(SCRIPT ERROR:|ERROR:)') 'Native graphics interaction has no engine or script errors'
    } finally {
        if ($script:UiProcess -and -not $script:UiProcess.HasExited) { $script:UiProcess.Kill(); $script:UiProcess.WaitForExit() }
        if ($clipboard) { [Windows.Forms.Clipboard]::SetDataObject($clipboard,$true) } else { [Windows.Forms.Clipboard]::Clear() }
    }
}
