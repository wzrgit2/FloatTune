$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$opName = 'IAsyncOperation' + [char]96 + '1'
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq $opName
})[0]
function Await($op, $type, $t = 5000) { $tt = $asTaskGeneric.MakeGenericMethod($type); $nt = $tt.Invoke($null, @($op)); if (-not $nt.Wait($t)) { throw 'timeout' }; $nt.Result }
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime]
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionPlaybackInfo,Windows.Media.Control,ContentType=WindowsRuntime]
$MgrType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$PropsType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]
$mgr = Await ($MgrType::RequestAsync()) $MgrType
$sessions = $mgr.GetSessions()
Write-Output ('sessions: ' + $sessions.Count)
foreach ($s in $sessions) {
  $info = $s.GetPlaybackInfo()
  $c = $info.Controls
  Write-Output ('--- ' + $s.SourceAppUserModelId + ' status=' + $info.PlaybackStatus)
  Write-Output ('    position-enabled=' + $c.IsPlaybackPositionEnabled + '  play=' + $c.IsPlayEnabled + ' pause=' + $c.IsPauseEnabled + ' next=' + $c.IsNextEnabled + ' prev=' + $c.IsPreviousEnabled + ' rate=' + $c.IsPlaybackRateEnabled)
  $timeline = $s.GetTimelineProperties()
  Write-Output ('    pos=' + [math]::Round($timeline.Position.TotalSeconds,2) + ' dur=' + [math]::Round($timeline.EndTime.TotalSeconds,2))
}
$cur = $mgr.GetCurrentSession()
if ($null -ne $cur) { Write-Output ('current: ' + $cur.SourceAppUserModelId) } else { Write-Output 'no current session' }
