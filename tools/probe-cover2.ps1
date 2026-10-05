$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime]
[void][Windows.Storage.Streams.IRandomAccessStreamWithContentType,Windows.Storage.Streams,ContentType=WindowsRuntime]
[void][Windows.Storage.Streams.IInputStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
[void][Windows.Storage.Streams.DataReader,Windows.Storage.Streams,ContentType=WindowsRuntime]
$MgrType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$PropsType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]
$mgrOp = $MgrType::RequestAsync()
while ($mgrOp.Status -eq 0) { Start-Sleep -Milliseconds 20 }
$mgr = $mgrOp.GetResults()
$s = $mgr.GetCurrentSession()
if ($null -eq $s) { Write-Output 'NO SESSION'; exit 0 }
$propOp = $s.TryGetMediaPropertiesAsync()
while ($propOp.Status -eq 0) { Start-Sleep -Milliseconds 20 }
$props = $propOp.GetResults()
Write-Output ('title: ' + $props.Title)
if ($null -eq $props.Thumbnail) { Write-Output 'NO THUMBNAIL'; exit 0 }
$thumbOp = $props.Thumbnail.OpenReadAsync()
while ($thumbOp.Status -eq 0) { Start-Sleep -Milliseconds 20 }
$stream = $thumbOp.GetResults()
Write-Output ('D stream type: ' + $stream.GetType().FullName)
try {
  $net = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
  $ms = New-Object System.IO.MemoryStream
  $net.CopyTo($ms)
  Write-Output ('D AsStreamForRead bytes=' + $ms.ToArray().Length)
} catch { Write-Output ('D FAILED: ' + $_.Exception.Message) }
try {
  $dr = [Windows.Storage.Streams.DataReader]::new($stream)
  $n = $dr.LoadAsync([uint32]262144).GetResults()
  $buf = New-Object byte[] $n
  $dr.ReadBytes($buf)
  Write-Output ('E DataReader bytes=' + $n)
} catch { Write-Output ('E FAILED: ' + $_.Exception.Message) }
try {
  $rt = $stream.GetType()
  Write-Output ('F interfaces: ' + (($rt.GetInterfaces() | ForEach-Object { $_.FullName }) -join ', '))
} catch { }
