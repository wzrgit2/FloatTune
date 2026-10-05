
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Dpi7 { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[void][Dpi7]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap $vs.Width, $vs.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vs.Left, $vs.Top, 0, 0, $bmp.Size)
$g.Dispose()
function Crop($x,$y,$w,$h,$out,$scale){
  $rect = [System.Drawing.Rectangle]::new($x,$y,$w,$h)
  $c = New-Object System.Drawing.Bitmap $w, $h
  $gg = [System.Drawing.Graphics]::FromImage($c)
  $gg.DrawImage($bmp, [System.Drawing.Rectangle]::new(0,0,$w,$h), $rect, [System.Drawing.GraphicsUnit]::Pixel)
  $gg.Dispose()
  $big = New-Object System.Drawing.Bitmap ([int]($w*$scale)), ([int]($h*$scale))
  $g3 = [System.Drawing.Graphics]::FromImage($big)
  $g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g3.DrawImage($c, 0, 0, [int]($w*$scale), [int]($h*$scale))
  $g3.Dispose(); $c.Dispose(); $big.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $big.Dispose()
  Write-Output ("saved " + $out)
}
Crop 1820 1352 110 88 'C:\Users\SuperWan\.openclaw\workspace\w-btn.png' 7
$bmp.Dispose()
