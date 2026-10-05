
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Dpi3 { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
public class W9 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@
[void][Dpi3]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$targets = @{}
Get-Process electron -ErrorAction SilentlyContinue | ForEach-Object { $targets[[uint32]$_.Id] = $true }
$found = @()
$cb = [W9+EnumProc]{ param($h,$p)
  $pid2 = 0
  [void][W9]::GetWindowThreadProcessId($h, [ref]$pid2)
  $t = [W9]::Title($h)
  if ($targets.ContainsKey([uint32]$pid2) -and $t -ne '') {
    $r = New-Object W9+RECT
    [void][W9]::GetWindowRect($h, [ref]$r)
    $script:found += ,@{ t=$t; r=$r; min=[W9]::IsIconic($h) }
  }
  return $true
}
[void][W9]::EnumWindows($cb, [IntPtr]::Zero)
foreach ($f in $script:found) {
  Write-Output ("WINDOW '" + $f.t + "' minimized=" + $f.min + " rect=" + $f.r.Left + "," + $f.r.Top + " " + ($f.r.Right-$f.r.Left) + "x" + ($f.r.Bottom-$f.r.Top))
}
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap $vs.Width, $vs.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vs.Left, $vs.Top, 0, 0, $bmp.Size)
$g.Dispose()
# widget crop
foreach ($f in $script:found) {
  if ($f.t -eq 'Media Widget' -or $f.t -match '测试') {
    $m = 16
    $bx = [Math]::Max(0, $f.r.Left - $vs.Left - $m); $by = [Math]::Max(0, $f.r.Top - $vs.Top - $m)
    $rw = [Math]::Min($bmp.Width - $bx, ($f.r.Right-$f.r.Left) + 2*$m); $rh = [Math]::Min($bmp.Height - $by, ($f.r.Bottom-$f.r.Top) + 2*$m)
    $rect = New-Object System.Drawing.Rectangle $bx, $by, $rw, $rh
    $crop = New-Object System.Drawing.Bitmap $rw, $rh
    $g2 = [System.Drawing.Graphics]::FromImage($crop)
    $g2.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0,0,$rw,$rh), $rect, [System.Drawing.GraphicsUnit]::Pixel)
    $g2.Dispose()
    $crop.Save('C:\Users\SuperWan\.openclaw\workspace\w-widget.png', [System.Drawing.Imaging.ImageFormat]::Png)
    $crop.Dispose()
    Write-Output ("widget crop saved " + $rw + "x" + $rh)
  }
}
# taskbar strip (bottom of primary monitor)
$tb = New-Object System.Drawing.Rectangle 0, ($bmp.Height - 90), [Math]::Min(2560, $bmp.Width), 90
$tc = New-Object System.Drawing.Bitmap $tb.Width, $tb.Height
$g4 = [System.Drawing.Graphics]::FromImage($tc)
$g4.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0,0,$tb.Width,$tb.Height), $tb, [System.Drawing.GraphicsUnit]::Pixel)
$g4.Dispose()
$tc.Save('C:\Users\SuperWan\.openclaw\workspace\w-taskbar.png', [System.Drawing.Imaging.ImageFormat]::Png)
$tc.Dispose()
$bmp.Dispose()
Write-Output 'taskbar strip saved'
