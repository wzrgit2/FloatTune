
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DpiC { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[void][DpiC]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap ([int]$vs.Width), ([int]$vs.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen([int]$vs.Left, [int]$vs.Top, 0, 0, $bmp.Size)
$g.Dispose()
# where is the widget?
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Wz {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@
$pids = @{}
Get-Process electron,MusicController -ErrorAction SilentlyContinue | ForEach-Object { $pids[[uint32]$_.Id] = $true }
$found = $null
$cb = [Wz+EnumProc]{ param($h,$p)
  $id = 0
  [void][Wz]::GetWindowThreadProcessId($h, [ref]$id)
  if ($pids.ContainsKey([uint32]$id)) {
    $r = New-Object Wz+RECT
    [void][Wz]::GetWindowRect($h, [ref]$r)
    if (([Wz]::Title($h) -ne '') -and ($r.Right-$r.Left) -gt 150) { $script:found = $r }
  }
  return $true
}
[void][Wz]::EnumWindows($cb, [IntPtr]::Zero)
if ($found -ne $null) {
  Write-Output ("widget at " + $found.Left + "," + $found.Top + " " + ($found.Right-$found.Left) + "x" + ($found.Bottom-$found.Top))
  # sample inside the card (60% across, mid height) and just outside it (left of the window)
  $cx = [int]($found.Left + ($found.Right-$found.Left)*0.6)
  $cy = [int]($found.Top + ($found.Bottom-$found.Top)*0.75)
  $ox = [int]($found.Left - 40)
  $oy = $cy
  $inPix = $bmp.GetPixel($cx, $cy)
  $outPix = $bmp.GetPixel($ox, $oy)
  Write-Output ("inside card pixel:  R=" + $inPix.R + " G=" + $inPix.G + " B=" + $inPix.B)
  Write-Output ("outside (backdrop): R=" + $outPix.R + " G=" + $outPix.G + " B=" + $outPix.B)
}
# half-scale full desktop
$hw = [int]($vs.Width/2); $hh = [int]($vs.Height/2)
$small = New-Object System.Drawing.Bitmap $hw, $hh
$g4 = [System.Drawing.Graphics]::FromImage($small)
$g4.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g4.DrawImage($bmp, 0, 0, $hw, $hh)
$g4.Dispose()
$small.Save('C:\Users\SuperWan\.openclaw\workspace\desk-half.png', [System.Drawing.Imaging.ImageFormat]::Png)
$small.Dispose(); $bmp.Dispose()
Write-Output 'saved desk-half.png'
