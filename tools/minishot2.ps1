
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DpiQ { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
public class Wq {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@
[void][DpiQ]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$pids = @{}
Get-Process electron,MusicController -ErrorAction SilentlyContinue | ForEach-Object { $pids[[uint32]$_.Id] = $true }
$main = [IntPtr]::Zero
$cb = [Wq+EnumProc]{ param($h,$p)
  $id = 0
  [void][Wq]::GetWindowThreadProcessId($h, [ref]$id)
  if ($pids.ContainsKey([uint32]$id)) {
    $r = New-Object Wq+RECT
    [void][Wq]::GetWindowRect($h, [ref]$r)
    if ((([Wq]::Title($h)) -ne '') -and ($r.Right-$r.Left) -gt 120 -and ($r.Bottom-$r.Top) -lt 200) { $script:main = $h }
  }
  return $true
}
[void][Wq]::EnumWindows($cb, [IntPtr]::Zero)
if ($main -eq [IntPtr]::Zero) { Write-Output 'no window'; exit 0 }
[void][Wq]::ShowWindow($main, 5)
$r = New-Object Wq+RECT
[void][Wq]::GetWindowRect($main, [ref]$r)
# 1) move up -> leave mini
[void][Wq]::SetWindowPos($main, [IntPtr]::Zero, 1200, 200, ($r.Right-$r.Left), ($r.Bottom-$r.Top), 0x0014)
Start-Sleep -Milliseconds 2200
[void][Wq]::GetWindowRect($main, [ref]$r)
Write-Output ("restored: " + ($r.Right-$r.Left) + "x" + ($r.Bottom-$r.Top) + " at " + $r.Left + "," + $r.Top)
# 2) move back down -> enter mini (docks itself above the taskbar)
[void][Wq]::SetWindowPos($main, [IntPtr]::Zero, 1200, 1425, ($r.Right-$r.Left), ($r.Bottom-$r.Top), 0x0014)
Start-Sleep -Milliseconds 2400
[void][Wq]::GetWindowRect($main, [ref]$r)
Write-Output ("mini: " + ($r.Right-$r.Left) + "x" + ($r.Bottom-$r.Top) + " at " + $r.Left + "," + $r.Top)
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap ([int]$vs.Width), ([int]$vs.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen([int]$vs.Left, [int]$vs.Top, 0, 0, $bmp.Size)
$g.Dispose()
$m = 16
$bx = [int][Math]::Max(0, $r.Left - $vs.Left - $m); $by = [int][Math]::Max(0, $r.Top - $vs.Top - $m)
$rw = [int][Math]::Min($bmp.Width - $bx, ($r.Right-$r.Left) + 2*$m); $rh = [int][Math]::Min($bmp.Height - $by, ($r.Bottom-$r.Top) + 2*$m)
Write-Output ("crop " + $bx + "," + $by + " " + $rw + "x" + $rh)
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
$big.Save('C:\Users\SuperWan\.openclaw\workspace\w-mini2.png', [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose(); $big.Dispose(); $bmp.Dispose()
Write-Output 'saved w-mini2.png'
