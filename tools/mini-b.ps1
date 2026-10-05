$i = 0
while ($true) { $i++; [Console]::Out.WriteLine('{"i":' + $i + '}'); [Console]::Out.Flush(); Start-Sleep -Milliseconds 200; if ($i -ge 8) { break } }
