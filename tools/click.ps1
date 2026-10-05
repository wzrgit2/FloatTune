
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DpiX { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
public class Wk {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@
[void][DpiX]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$pids = @{}
Get-Process electron,MusicController -ErrorAction SilentlyContinue | ForEach-Object { $pids[[uint32]$_.Id] = $true }
$found = @()
$cb = [Wk+EnumProc]{ param($h,$p)
  $id = 0
  [void][Wk]::GetWindowThreadProcessId($h, [ref]$id)
  if ($pids.ContainsKey([uint32]$id)) {
    $r = New-Object Wk+RECT
    [void][Wk]::GetWindowRect($h, [ref]$r)
    $w = $r.Right-$r.Left; $ht = $r.Bottom-$r.Top
    if ($w -gt 120 -and $ht -gt 30) { $script:found += ,@{ h=$h; t=[Wk]::Title($h); r=$r; w=$w; ht=$ht } }
  }
  return $true
}
[void][Wk]::EnumWindows($cb, [IntPtr]::Zero)
$main = $null
foreach ($f in $script:found) { Write-Output ("win '" + $f.t + "' " + $f.r.Left + "," + $f.r.Top + " " + $f.w + "x" + $f.ht); if ($f.ht -lt 200) { $main = $f } }
if ($null -eq $main) { Write-Output 'no main window'; exit 0 }
[void][Wk]::ShowWindow($main.h, 5)
Start-Sleep -Milliseconds 700
$r = New-Object Wk+RECT
[void][Wk]::GetWindowRect($main.h, [ref]$r)
$w = $r.Right-$r.Left; $h2 = $r.Bottom-$r.Top
# gear sits at right:42px top:3px size 16 -> centre in window ratio
$gx = [int]($r.Left + $w - ($w * 50.0 / 380.0))
$gy = [int]($r.Top + ($h2 * 11.0 / 110.0))
Write-Output ("click gear at " + $gx + "," + $gy)
[void][Wk]::SetCursorPos($gx, $gy)
Start-Sleep -Milliseconds 250
[Wk]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero)
[Wk]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 2500
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap ([int]$vs.Width), ([int]$vs.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen([int]$vs.Left, [int]$vs.Top, 0, 0, $bmp.Size)
$g.Dispose()
$sw = [int]($vs.Width/2); $sh = [int]($vs.Height/2)
$small = New-Object System.Drawing.Bitmap $sw, $sh
$g4 = [System.Drawing.Graphics]::FromImage($small)
$g4.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g4.DrawImage($bmp, 0, 0, $sw, $sh)
$g4.Dispose()
$small.Save('C:\Users\SuperWan\.openclaw\workspace\settings-shot.png', [System.Drawing.Imaging.ImageFormat]::Png)
$small.Dispose(); $bmp.Dispose()
Write-Output 'saved settings-shot.png'
