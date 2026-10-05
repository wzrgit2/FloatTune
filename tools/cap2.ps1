
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DpiA { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
public class Wm {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@
[void][DpiA]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$pids = @{}
Get-Process electron,MusicController -ErrorAction SilentlyContinue | ForEach-Object { $pids[[uint32]$_.Id] = $true }
$target = [IntPtr]::Zero
$cb = [Wm+EnumProc]{ param($h,$p)
  $id = 0
  [void][Wm]::GetWindowThreadProcessId($h, [ref]$id)
  if ($pids.ContainsKey([uint32]$id)) {
    $r = New-Object Wm+RECT
    [void][Wm]::GetWindowRect($h, [ref]$r)
    if (([Wm]::Title($h) -ne '') -and ($r.Right-$r.Left) -gt 150 -and ($r.Bottom-$r.Top) -gt 50) { $script:target = $h }
  }
  return $true
}
[void][Wm]::EnumWindows($cb, [IntPtr]::Zero)
if ($target -eq [IntPtr]::Zero) { Write-Output 'no window'; exit 0 }
$r = New-Object Wm+RECT
[void][Wm]::GetWindowRect($target, [ref]$r)
$w = $r.Right-$r.Left; $h2 = $r.Bottom-$r.Top
# move onto the bright wallpaper on the second monitor
[void][Wm]::SetWindowPos($target, [IntPtr]::Zero, 2700, 300, $w, $h2, 0x0014)
Start-Sleep -Milliseconds 1200
[void][Wm]::GetWindowRect($target, [ref]$r)
Write-Output ("moved to " + $r.Left + "," + $r.Top + " " + ($r.Right-$r.Left) + "x" + ($r.Bottom-$r.Top))
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap $vs.Width, $vs.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vs.Left, $vs.Top, 0, 0, $bmp.Size)
$g.Dispose()
$m = 16
$bx = [Math]::Max(0, $r.Left - $vs.Left - $m); $by = [Math]::Max(0, $r.Top - $vs.Top - $m)
$rw = [Math]::Min($bmp.Width - $bx, ($r.Right-$r.Left) + 2*$m); $rh = [Math]::Min($bmp.Height - $by, ($r.Bottom-$r.Top) + 2*$m)
$rect = [System.Drawing.Rectangle]::new($bx,$by,$rw,$rh)
$crop = New-Object System.Drawing.Bitmap $rw, $rh
$g2 = [System.Drawing.Graphics]::FromImage($crop)
$g2.DrawImage($bmp, [System.Drawing.Rectangle]::new(0,0,$rw,$rh), $rect, [System.Drawing.GraphicsUnit]::Pixel)
$g2.Dispose()
$big = New-Object System.Drawing.Bitmap ([int]($rw*2)), ([int]($rh*2))
$g3 = [System.Drawing.Graphics]::FromImage($big)
$g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g3.DrawImage($crop, 0, 0, [int]($rw*2), [int]($rh*2))
$g3.Dispose()
$big.Save('C:\Users\SuperWan\.openclaw\workspace\w-acrylic.png', [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose(); $big.Dispose(); $bmp.Dispose()
Write-Output 'saved w-acrylic.png'
