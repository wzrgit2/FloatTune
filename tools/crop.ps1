
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile('C:\Users\SuperWan\.openclaw\workspace\shot.png')
$rect = New-Object System.Drawing.Rectangle 1600, 30, 460, 180
$crop = New-Object System.Drawing.Bitmap $rect.Width, $rect.Height
$g = [System.Drawing.Graphics]::FromImage($crop)
$g.DrawImage($src, (New-Object System.Drawing.Rectangle 0,0,$rect.Width,$rect.Height), $rect, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$crop.Save('C:\Users\SuperWan\.openclaw\workspace\widget-crop.png', [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose(); $src.Dispose()
Write-Output 'cropped'
