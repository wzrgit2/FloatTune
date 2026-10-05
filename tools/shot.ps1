
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string name);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@
$found = @()
$cb = [W+EnumProc]{ param($h,$p)
  $t = [W]::Title($h)
  if ($t -like '*Media Widget*' ) { $script:found += ,@($h, $t, [W]::IsWindowVisible($h), [W]::IsIconic($h)) }
  return $true
}
[void][W]::EnumWindows($cb, [IntPtr]::Zero)
foreach ($f in $found) {
  $r = New-Object W+RECT
  [void][W]::GetWindowRect($f[0], [ref]$r)
  Write-Output ("WINDOW title='" + $f[1] + "' visible=" + $f[2] + " minimized=" + $f[3] + " rect=" + $r.Left + "," + $r.Top + " " + ($r.Right-$r.Left) + "x" + ($r.Bottom-$r.Top))
}
if ($found.Count -eq 0) { Write-Output "no Media Widget window found" }
Write-Output "--- electron processes ---"
@(Get-Process electron -ErrorAction SilentlyContinue).Count
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
Write-Output ("screen: " + $vs.Width + "x" + $vs.Height)
$bmp = New-Object System.Drawing.Bitmap $vs.Width, $vs.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vs.Left, $vs.Top, 0, 0, $bmp.Size)
$out = 'C:\Users\SuperWan\.openclaw\workspace\shot.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output ("saved " + $out + " " + (Get-Item $out).Length)
