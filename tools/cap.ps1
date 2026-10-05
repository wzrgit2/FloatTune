
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Dpi9 { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
public class Wc {
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
[void][Dpi9]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$pids = @{}
Get-Process electron,MusicController -ErrorAction SilentlyContinue | ForEach-Object { $pids[[uint32]$_.Id] = $true }
$best = $null
$cb = [Wc+EnumProc]{ param($h,$p)
  $id = 0
  [void][Wc]::GetWindowThreadProcessId($h, [ref]$id)
  if ($pids.ContainsKey([uint32]$id)) {
    $t = [Wc]::Title($h)
    $r = New-Object Wc+RECT
    [void][Wc]::GetWindowRect($h, [ref]$r)
    $w = $r.Right-$r.Left; $ht = $r.Bottom-$r.Top
    if ($t -ne '' -and $w -gt 150 -and $ht -gt 50) {
      Write-Output ("WIN '" + $t + "' " + $r.Left + "," + $r.Top + " " + $w + "x" + $ht + " min=" + [Wc]::IsIconic($h))
      $script:best = @{ r=$r }
    }
  }
  return $true
}
[void][Wc]::EnumWindows($cb, [IntPtr]::Zero)
if ($null -eq $script:best) { Write-Output 'NO WINDOW'; exit 0 }
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap $vs.Width, $vs.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vs.Left, $vs.Top, 0, 0, $bmp.Size)
$g.Dispose()
$r = $script:best.r
$m = 14
$bx = [Math]::Max(0, $r.Left - $vs.Left - $m); $by = [Math]::Max(0, $r.Top - $vs.Top - $m)
$rw = [Math]::Min($bmp.Width - $bx, ($r.Right-$r.Left) + 2*$m); $rh = [Math]::Min($bmp.Height - $by, ($r.Bottom-$r.Top) + 2*$m)
$rect = [System.Drawing.Rectangle]::new($bx,$by,$rw,$rh)
$crop = New-Object System.Drawing.Bitmap $rw, $rh
$g2 = [System.Drawing.Graphics]::FromImage($crop)
$g2.DrawImage($bmp, [System.Drawing.Rectangle]::new(0,0,$rw,$rh), $rect, [System.Drawing.GraphicsUnit]::Pixel)
$g2.Dispose()
$sc = 2
$big = New-Object System.Drawing.Bitmap ([int]($rw*$sc)), ([int]($rh*$sc))
$g3 = [System.Drawing.Graphics]::FromImage($big)
$g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g3.DrawImage($crop, 0, 0, [int]($rw*$sc), [int]($rh*$sc))
$g3.Dispose()
$big.Save('C:\Users\SuperWan\.openclaw\workspace\w-now.png', [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose(); $big.Dispose(); $bmp.Dispose()
Write-Output 'saved w-now.png'
