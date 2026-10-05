
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Dpi4 { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[void][Dpi4]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap $vs.Width, $vs.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vs.Left, $vs.Top, 0, 0, $bmp.Size)
$g.Dispose()
$y = $bmp.Height - 80
$w = [Math]::Min(2600, $bmp.Width)
$rect = [System.Drawing.Rectangle]::new(0, $y, $w, 80)
$tc = New-Object System.Drawing.Bitmap $w, 80
$g4 = [System.Drawing.Graphics]::FromImage($tc)
$g4.DrawImage($bmp, [System.Drawing.Rectangle]::new(0,0,$w,80), $rect, [System.Drawing.GraphicsUnit]::Pixel)
$g4.Dispose()
$tc.Save('C:\Users\SuperWan\.openclaw\workspace\w-taskbar.png', [System.Drawing.Imaging.ImageFormat]::Png)
$tc.Dispose(); $bmp.Dispose()
Write-Output ("taskbar strip: " + $w + "x80 from y=" + $y)
