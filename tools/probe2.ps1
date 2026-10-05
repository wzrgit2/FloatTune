$ErrorActionPreference = 'Continue'
function Log($m) { [Console]::Error.WriteLine((Get-Date -Format 'HH:mm:ss.fff') + ' ' + $m) }
Log 'start'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$opName = 'IAsyncOperation' + [char]96 + '1'
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq $opName
})[0]
function Await($op, $type) { $t = $asTaskGeneric.MakeGenericMethod($type); $nt = $t.Invoke($null, @($op)); $nt.Wait(-1) | Out-Null; $nt.Result }
Log 'types loading'
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime]
$MgrType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$PropsType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]
Log 'requesting manager...'
$mgr = Await ($MgrType::RequestAsync()) $MgrType
Log ('manager ok: ' + ($mgr -ne $null))
$s = $mgr.GetCurrentSession()
Log ('session: ' + $(if ($null -eq $s) { 'none' } else { $s.SourceAppUserModelId }))
if ($null -ne $s) {
  Log 'getting media properties...'
  $props = Await ($s.TryGetMediaPropertiesAsync()) $PropsType
  Log ('props ok, title=' + $props.Title)
  $tl = $s.GetTimelineProperties()
  Log ('timeline pos=' + $tl.Position.TotalSeconds + ' dur=' + $tl.EndTime.TotalSeconds)
  $pi = $s.GetPlaybackInfo()
  Log ('status=' + $pi.PlaybackStatus)
}
Log 'done'
