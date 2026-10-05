
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class W2 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@
$cb = [W2+EnumProc]{ param($h,$p)
  $t = [W2]::Title($h)
  if ($t -eq 'Media Widget') {
    $r = New-Object W2+RECT
    [void][W2]::GetWindowRect($h, [ref]$r)
    Write-Output ("WIDGET visible=" + [W2]::IsWindowVisible($h) + " minimized=" + [W2]::IsIconic($h) + " rect=" + $r.Left + "," + $r.Top + " " + ($r.Right-$r.Left) + "x" + ($r.Bottom-$r.Top))
  }
  return $true
}
[void][W2]::EnumWindows($cb, [IntPtr]::Zero)
Write-Output "--- sessions bridge says ---"
& powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\SuperWan\.openclaw\workspace\music-widget\bridge\smtc.ps1 -Once
