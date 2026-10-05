
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
Write-Output ("virtual screen: Left=" + $vs.Left + " Top=" + $vs.Top + " " + $vs.Width + "x" + $vs.Height)
$src = [System.Drawing.Image]::FromFile('C:\Users\SuperWan\.openclaw\workspace\shot.png')
Write-Output ("bitmap: " + $src.Width + "x" + $src.Height)
# widget window rect in desktop coords
$wx = 1628; $wy = 60; $ww = 383; $wh = 112
$bx = $wx - $vs.Left - 20
$by = $wy - $vs.Top - 20
$rw = $ww + 40; $rh = $wh + 40
if ($bx -lt 0) { $bx = 0 }; if ($by -lt 0) { $by = 0 }
Write-Output ("crop at bitmap " + $bx + "," + $by + " " + $rw + "x" + $rh)
$rect = New-Object System.Drawing.Rectangle $bx, $by, $rw, $rh
$crop = New-Object System.Drawing.Bitmap $rw, $rh
$g = [System.Drawing.Graphics]::FromImage($crop)
$g.DrawImage($src, (New-Object System.Drawing.Rectangle 0,0,$rw,$rh), $rect, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$crop.Save('C:\Users\SuperWan\.openclaw\workspace\widget-crop2.png', [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose(); $src.Dispose()
Write-Output 'saved widget-crop2.png'
