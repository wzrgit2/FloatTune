
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DpiB { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[void][DpiB]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$bx = [int]2684
$by = [int]284
$rw = [int]531
$rh = [int]182
Write-Output ("crop " + $bx + "," + $by + " " + $rw + "x" + $rh)
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap ([int]$vs.Width), ([int]$vs.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen([int]$vs.Left, [int]$vs.Top, 0, 0, $bmp.Size)
$g.Dispose()
$rect = [System.Drawing.Rectangle]::new($bx, $by, $rw, $rh)
$crop = New-Object System.Drawing.Bitmap ([int]$rw), ([int]$rh)
$g2 = [System.Drawing.Graphics]::FromImage($crop)
$g2.DrawImage($bmp, [System.Drawing.Rectangle]::new(0,0,[int]$rw,[int]$rh), $rect, [System.Drawing.GraphicsUnit]::Pixel)
$g2.Dispose()
$big = New-Object System.Drawing.Bitmap ([int]($rw*2)), ([int]($rh*2))
$g3 = [System.Drawing.Graphics]::FromImage($big)
$g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g3.DrawImage($crop, 0, 0, [int]($rw*2), [int]($rh*2))
$g3.Dispose()
$big.Save('C:\Users\SuperWan\.openclaw\workspace\w-acrylic.png', [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose(); $big.Dispose(); $bmp.Dispose()
Write-Output 'saved'
