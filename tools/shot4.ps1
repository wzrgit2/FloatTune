
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Dpi5 { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[void][Dpi5]::SetProcessDPIAware()
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
  if ($scale -ne 1) {
    $big = New-Object System.Drawing.Bitmap ([int]($w*$scale)), ([int]($h*$scale))
    $g3 = [System.Drawing.Graphics]::FromImage($big)
    $g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g3.DrawImage($c, 0, 0, [int]($w*$scale), [int]($h*$scale))
    $g3.Dispose(); $c.Dispose(); $big.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $big.Dispose()
  } else { $c.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $c.Dispose() }
  Write-Output ("saved " + $out)
}
Crop 2006 55 540 190 'C:\Users\SuperWan\.openclaw\workspace\w-widget.png' 2
Crop 1800 1355 800 85 'C:\Users\SuperWan\.openclaw\workspace\w-taskbar.png' 2
$bmp.Dispose()
