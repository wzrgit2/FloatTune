$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$opName = 'IAsyncOperation' + [char]96 + '1'
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq $opName
})[0]
function Await($op, $type, $t = 6000) { $tt = $asTaskGeneric.MakeGenericMethod($type); $nt = $tt.Invoke($null, @($op)); if (-not $nt.Wait($t)) { throw 'timeout' }; $nt.Result }
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime]
$MgrType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$mgr = Await ($MgrType::RequestAsync()) $MgrType
$s = $mgr.GetCurrentSession()
if ($null -eq $s) { Write-Output 'no session'; exit 0 }
Write-Output ('app: ' + $s.SourceAppUserModelId)
$tl = $s.GetTimelineProperties()
$before = $tl.Position.TotalSeconds
Write-Output ('before pos = ' + [math]::Round($before,2))
$target = $before + 10
$ticks = [long]($target * 10000000)
Write-Output ('attempting seek to ' + [math]::Round($target,2) + ' ...')
$res = $false
try { $res = Await ($s.TryChangePlaybackPositionAsync($ticks)) ([bool]) } catch { Write-Output ('seek threw: ' + $_.Exception.Message) }
Write-Output ('TryChangePlaybackPositionAsync returned: ' + $res)
Start-Sleep -Milliseconds 1800
$tl2 = $s.GetTimelineProperties()
$after = $tl2.Position.TotalSeconds
Write-Output ('after  pos = ' + [math]::Round($after,2))
Write-Output ('VERDICT: ' + $(if ($after - $before -gt 5) { 'SEEK WORKED' } else { 'seek had NO effect' }))
