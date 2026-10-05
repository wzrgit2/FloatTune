
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Dpi2 { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
public class W4 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@
[void][Dpi2]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$hwnd = [IntPtr]::Zero
$cb = [W4+EnumProc]{ param($h,$p) if ([W4]::Title($h) -eq 'Media Widget') { $script:hwnd = $h } return $true }
[void][W4]::EnumWindows($cb, [IntPtr]::Zero)
Write-Output ("hwnd " + $hwnd)
if ($hwnd -ne [IntPtr]::Zero) {
  [void][W4]::ShowWindow($hwnd, 9)   # SW_RESTORE
  Start-Sleep -Milliseconds 1200
  [void][W4]::SetForegroundWindow($hwnd)
  Start-Sleep -Milliseconds 800
  $r = New-Object W4+RECT
  [void][W4]::GetWindowRect($hwnd, [ref]$r)
  Write-Output ("after restore: minimized=" + [W4]::IsIconic($hwnd) + " rect=" + $r.Left + "," + $r.Top + " " + ($r.Right-$r.Left) + "x" + ($r.Bottom-$r.Top))
  $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
  $bmp = New-Object System.Drawing.Bitmap $vs.Width, $vs.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($vs.Left, $vs.Top, 0, 0, $bmp.Size)
  $g.Dispose()
  $m = 18
  $bx = $r.Left - $vs.Left - $m; $by = $r.Top - $vs.Top - $m
  $rw = ($r.Right-$r.Left) + 2*$m; $rh = ($r.Bottom-$r.Top) + 2*$m
  if ($bx -lt 0) { $bx = 0 }; if ($by -lt 0) { $by = 0 }
  if ($bx+$rw -gt $bmp.Width) { $rw = $bmp.Width-$bx }
  if ($by+$rh -gt $bmp.Height) { $rh = $bmp.Height-$by }
  $rect = New-Object System.Drawing.Rectangle $bx, $by, $rw, $rh
  $crop = New-Object System.Drawing.Bitmap $rw, $rh
  $g2 = [System.Drawing.Graphics]::FromImage($crop)
  $g2.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0,0,$rw,$rh), $rect, [System.Drawing.GraphicsUnit]::Pixel)
  $g2.Dispose()
  $big = New-Object System.Drawing.Bitmap ($rw*2), ($rh*2)
  $g3 = [System.Drawing.Graphics]::FromImage($big)
  $g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g3.DrawImage($crop, 0, 0, $rw*2, $rh*2)
  $g3.Dispose()
  $big.Save('C:\Users\SuperWan\.openclaw\workspace\final-check.png', [System.Drawing.Imaging.ImageFormat]::Png)
  $crop.Dispose(); $big.Dispose(); $bmp.Dispose()
  Write-Output 'saved final-check.png'
}
