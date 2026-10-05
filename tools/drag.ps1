
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DpiE { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
public class Wdrag2 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, IntPtr e);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@
[void][DpiE]::SetProcessDPIAware()
$pids = @{}
Get-Process electron,MusicController -ErrorAction SilentlyContinue | ForEach-Object { $pids[[uint32]$_.Id] = $true }
$main = [IntPtr]::Zero
$cb = [Wdrag2+EnumProc]{ param($h,$p)
  $id = 0
  [void][Wdrag2]::GetWindowThreadProcessId($h, [ref]$id)
  if ($pids.ContainsKey([uint32]$id)) {
    $r = New-Object Wdrag2+RECT
    [void][Wdrag2]::GetWindowRect($h, [ref]$r)
    if ((([Wdrag2]::Title($h)) -ne '') -and ($r.Right-$r.Left) -gt 120 -and ($r.Bottom-$r.Top) -lt 200) { $script:main = $h }
  }
  return $true
}
[void][Wdrag2]::EnumWindows($cb, [IntPtr]::Zero)
if ($main -eq [IntPtr]::Zero) { Write-Output 'no window'; exit 0 }
[void][Wdrag2]::SetWindowPos($main, [IntPtr]::Zero, 900, 200, 499, 150, 0x0014)
Start-Sleep -Milliseconds 900
$r = New-Object Wdrag2+RECT
[void][Wdrag2]::GetWindowRect($main, [ref]$r)
$startTop = [int]$r.Top
Write-Output ("start: " + ($r.Right-$r.Left) + "x" + ($r.Bottom-$r.Top) + " at " + $r.Left + "," + $r.Top)
$sx = [int]($r.Left + ($r.Right-$r.Left)*0.45)
$sy = [int]($r.Top + ($r.Bottom-$r.Top)*0.45)
[void][Wdrag2]::SetCursorPos($sx, $sy)
Start-Sleep -Milliseconds 400
[Wdrag2]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 350
for ($i = 1; $i -le 25; $i++) {
  $ty = [int]($sy + (1425 - $sy) * $i / 25.0)
  [void][Wdrag2]::SetCursorPos($sx, $ty)
  Start-Sleep -Milliseconds 30
}
[Wdrag2]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 2000
[void][Wdrag2]::GetWindowRect($main, [ref]$r)
$miniTop = [int]$r.Top
Write-Output ("after drag onto taskbar: " + ($r.Right-$r.Left) + "x" + ($r.Bottom-$r.Top) + " at " + $r.Left + "," + $r.Top)
$cx = [int]($r.Left + ($r.Right-$r.Left)*0.5)
$cy = [int]($r.Top + ($r.Bottom-$r.Top)*0.5)
[void][Wdrag2]::SetCursorPos($cx, $cy)
Start-Sleep -Milliseconds 350
[Wdrag2]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 300
for ($i = 1; $i -le 22; $i++) {
  $ty = [int]($miniTop + (300 - $miniTop) * $i / 22.0)
  [void][Wdrag2]::SetCursorPos($cx, $ty)
  Start-Sleep -Milliseconds 30
}
[Wdrag2]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 2000
[void][Wdrag2]::GetWindowRect($main, [ref]$r)
Write-Output ("after drag away: " + ($r.Right-$r.Left) + "x" + ($r.Bottom-$r.Top) + " at " + $r.Left + "," + $r.Top)
