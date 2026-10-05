$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$opName = 'IAsyncOperation' + [char]96 + '1'
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq $opName
})[0]
function Await($op, $type) { $t = $asTaskGeneric.MakeGenericMethod($type); $nt = $t.Invoke($null, @($op)); $nt.Wait(-1) | Out-Null; $nt.Result }
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime]
[void][Windows.Storage.Streams.IRandomAccessStreamWithContentType,Windows.Storage.Streams,ContentType=WindowsRuntime]
[void][Windows.Storage.Streams.IInputStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
[void][Windows.Storage.Streams.DataReader,Windows.Storage.Streams,ContentType=WindowsRuntime]
$MgrType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$PropsType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]
$StreamType = [Windows.Storage.Streams.IRandomAccessStreamWithContentType]
$mgr = Await ($MgrType::RequestAsync()) $MgrType
$s = $mgr.GetCurrentSession()
if ($null -eq $s) { Write-Output 'NO SESSION'; exit 0 }
$props = Await ($s.TryGetMediaPropertiesAsync()) $PropsType
Write-Output ('title: ' + $props.Title)
if ($null -eq $props.Thumbnail) { Write-Output 'NO THUMBNAIL'; exit 0 }
$stream = Await ($props.Thumbnail.OpenReadAsync()) $StreamType
Write-Output ('stream: ' + $stream.GetType().FullName)
try {
  $is = [Windows.Storage.Streams.IInputStream]$stream
  $net = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($is)
  $ms = New-Object System.IO.MemoryStream
  $net.CopyTo($ms)
  $b = $ms.ToArray()
  Write-Output ('A (cast+AsStreamForRead) bytes=' + $b.Length)
} catch { Write-Output ('A FAILED: ' + $_.Exception.Message) }
try {
  $dr = [Windows.Storage.Streams.DataReader]::new($stream.GetInputStreamAt(0))
  $ms2 = New-Object System.IO.MemoryStream
  $total = 0
  while ($true) {
    $n = Await ($dr.LoadAsync([uint32]65536)) ([uint32])
    if ($n -eq 0) { break }
    $buf = New-Object byte[] $n
    $dr.ReadBytes($buf)
    $ms2.Write($buf, 0, $n)
    $total += $n
  }
  Write-Output ('B (DataReader chunked) bytes=' + $total)
} catch { Write-Output ('B FAILED: ' + $_.Exception.Message) }
try {
  $b2 = New-Object byte[] 0
  $s2 = Await ($props.Thumbnail.OpenReadAsync()) $StreamType
  $dr2 = [Windows.Storage.Streams.DataReader]::new($s2)
  $n2 = Await ($dr2.LoadAsync([uint32]262144)) ([uint32])
  $buf2 = New-Object byte[] $n2
  $dr2.ReadBytes($buf2)
  Write-Output ('C (DataReader on stream) bytes=' + $n2)
} catch { Write-Output ('C FAILED: ' + $_.Exception.Message) }
