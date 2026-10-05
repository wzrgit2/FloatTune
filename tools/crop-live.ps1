
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$hits = New-Object System.Collections.ArrayList
$cb = [W+EnumProc]{ param($h,$p)
  $t = [W]::Title($h)
  if ($t -eq 'Media Widget') {
    $r = New-Object W+RECT
    [void][W]::GetWindowRect($h, [ref]$r)
    [void]$hits.Add(@{ h=$h; r=$r; vis=[W]::IsWindowVisible($h) })
  }
  return $true
}
[void][W]::EnumWindows($cb, [IntPtr]::Zero)
if ($hits.Count -eq 0) { Write-Output 'NO WIDGET WINDOW'; exit 1 }
$w = $hits[0]
Write-Output ("widget visible=" + $w.vis + " rect=" + $w.r.Left + "," + $w.r.Top + " " + ($w.r.Right-$w.r.Left) + "x" + ($w.r.Bottom-$w.r.Top))
$bmp = New-Object System.Drawing.Bitmap $vs.Width, $vs.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vs.Left, $vs.Top, 0, 0, $bmp.Size)
$g.Dispose()
$m = 24
$bx = $w.r.Left - $vs.Left - $m; $by = $w.r.Top - $vs.Top - $m
$rw = ($w.r.Right-$w.r.Left) + 2*$m; $rh = ($w.r.Bottom-$w.r.Top) + 2*$m
if ($bx -lt 0) { $bx = 0 }; if ($by -lt 0) { $by = 0 }
if ($bmp.Width -lt $bx+$rw) { $rw = $bmp.Width - $bx }
if ($bmp.Height -lt $by+$rh) { $rh = $bmp.Height - $by }
$rect = New-Object System.Drawing.Rectangle $bx, $by, $rw, $rh
$crop = New-Object System.Drawing.Bitmap $rw, $rh
$g2 = [System.Drawing.Graphics]::FromImage($crop)
$g2.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0,0,$rw,$rh), $rect, [System.Drawing.GraphicsUnit]::Pixel)
$g2.Dispose()
# scale x2 for readability
$big = New-Object System.Drawing.Bitmap ($rw*2), ($rh*2)
$g3 = [System.Drawing.Graphics]::FromImage($big)
$g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g3.DrawImage($crop, 0, 0, $rw*2, $rh*2)
$g3.Dispose()
$big.Save('C:\Users\SuperWan\.openclaw\workspace\widget-live.png', [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose(); $big.Dispose(); $bmp.Dispose()
Write-Output 'saved widget-live.png'
