
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DpiM2 { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
public class Wmin2 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@
[void][DpiM2]::SetProcessDPIAware()
$pids = @{}
Get-Process electron,MusicController -ErrorAction SilentlyContinue | ForEach-Object { $pids[[uint32]$_.Id] = $true }
$main = [IntPtr]::Zero
$cb = [Wmin2+EnumProc]{ param($h,$p)
  $id = 0
  [void][Wmin2]::GetWindowThreadProcessId($h, [ref]$id)
  if ($pids.ContainsKey([uint32]$id)) {
    $r = New-Object Wmin2+RECT
    [void][Wmin2]::GetWindowRect($h, [ref]$r)
    if ((([Wmin2]::Title($h)) -ne '') -and ($r.Right-$r.Left) -gt 120 -and ($r.Bottom-$r.Top) -lt 200) { $script:main = $h }
  }
  return $true
}
[void][Wmin2]::EnumWindows($cb, [IntPtr]::Zero)
if ($main -eq [IntPtr]::Zero) { Write-Output 'no window'; exit 0 }
$r = New-Object Wmin2+RECT
[void][Wmin2]::GetWindowRect($main, [ref]$r)
Write-Output ("before: " + ($r.Right-$r.Left) + "x" + ($r.Bottom-$r.Top) + " at " + $r.Left + "," + $r.Top)
[void][Wmin2]::SetWindowPos($main, [IntPtr]::Zero, 900, 1420, ($r.Right-$r.Left), ($r.Bottom-$r.Top), 0x0014)
Start-Sleep -Milliseconds 1500
[void][Wmin2]::GetWindowRect($main, [ref]$r)
Write-Output ("after drag-to-taskbar: " + ($r.Right-$r.Left) + "x" + ($r.Bottom-$r.Top) + " at " + $r.Left + "," + $r.Top)
[void][Wmin2]::SetWindowPos($main, [IntPtr]::Zero, 900, 300, ($r.Right-$r.Left), ($r.Bottom-$r.Top), 0x0014)
Start-Sleep -Milliseconds 1500
[void][Wmin2]::GetWindowRect($main, [ref]$r)
Write-Output ("after drag-away: " + ($r.Right-$r.Left) + "x" + ($r.Bottom-$r.Top) + " at " + $r.Left + "," + $r.Top)
