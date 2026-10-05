#requires -Version 5.1
param(
  [switch]$Once,
  [string]$Command
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

Add-Type -AssemblyName System.Runtime.WindowsRuntime

# ---- WinRT async helper ----
$opName = 'IAsyncOperation' + [char]96 + '1'
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq $opName
})[0]
function Await($op, $type, $timeoutMs = 4000) {
  $t = $asTaskGeneric.MakeGenericMethod($type)
  $nt = $t.Invoke($null, @($op))
  # hard timeout: a wedged WinRT/SMTC broker must never freeze this loop
  if (-not $nt.Wait($timeoutMs)) { throw ('WinRT call timed out after ' + $timeoutMs + 'ms') }
  $nt.Result
}

[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime]
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionPlaybackInfo,Windows.Media.Control,ContentType=WindowsRuntime]
[void][Windows.Storage.Streams.DataReader,Windows.Storage.Streams,ContentType=WindowsRuntime]
[void][Windows.Storage.Streams.IRandomAccessStreamWithContentType,Windows.Storage.Streams,ContentType=WindowsRuntime]

$MgrType    = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$PropsType  = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]
$StreamType = [Windows.Storage.Streams.IRandomAccessStreamWithContentType]
$U32        = [uint32]
$BoolType   = [bool]

# ---- system volume (CoreAudio COM interop) ----
$volCode = @'
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
  [PreserveSig] int RegisterControlChangeNotify(IntPtr p);
  [PreserveSig] int UnregisterControlChangeNotify(IntPtr p);
  [PreserveSig] int GetChannelCount(out uint count);
  [PreserveSig] int SetMasterVolumeLevel(float level, ref Guid ctx);
  [PreserveSig] int SetMasterVolumeLevelScalar(float level, ref Guid ctx);
  [PreserveSig] int GetMasterVolumeLevel(out float level);
  [PreserveSig] int GetMasterVolumeLevelScalar(out float level);
}
[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
  [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
  [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
}
[ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
  [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
}
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorComObject { }

public static class SysVolume {
  static IAudioEndpointVolume _cached;
  static IAudioEndpointVolume Get() {
    if (_cached != null) return _cached;
    var enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
    IMMDevice dev;
    enumerator.GetDefaultAudioEndpoint(0, 1, out dev);
    Guid iid = typeof(IAudioEndpointVolume).GUID;
    object o;
    dev.Activate(ref iid, 23, IntPtr.Zero, out o);
    _cached = (IAudioEndpointVolume)o;
    return _cached;
  }
  public static float GetVolume() { float v; Get().GetMasterVolumeLevelScalar(out v); return v; }
  public static void SetVolume(float v) { Guid g = Guid.Empty; Get().SetMasterVolumeLevelScalar(v, ref g); }
}
'@
Add-Type -TypeDefinition $volCode

# ---- state ----
$script:Manager = $null
function Get-Manager {
  if ($null -eq $script:Manager) {
    $script:Manager = Await ($MgrType::RequestAsync()) $MgrType 5000
    Write-Dbg 'session manager acquired'
  }
  return $script:Manager
}
$script:SW = [System.Diagnostics.Stopwatch]::StartNew()   # Environment.TickCount64 does not exist on .NET Framework (PS 5.1)
$script:CoverKey = ''
$script:CoverPath = $null
$script:CoverStamp = $null   # when the detached cover fetch was started
$script:CoverNote = ''
$script:LogFile = Join-Path $env:TEMP 'MusicController-bridge.log'
function Write-Dbg([string]$m) {
  try { Add-Content -Path $script:LogFile -Value ((Get-Date -Format 'HH:mm:ss') + ' ' + $m) -Encoding UTF8 } catch { }
}
$script:Props = $null
$script:PropsApp = ''
$script:PropsAt = 0

function Get-NowPlaying {
  $vol = 0
  try { $vol = [SysVolume]::GetVolume() } catch { }
  try { $mgr = Get-Manager }
  catch {
    Write-Dbg ('manager unavailable: ' + $_.Exception.Message)
    $script:Manager = $null   # retry fresh on the next tick
    return [ordered]@{ ok = $true; playing = $false; volume = [math]::Round($vol, 3) }
  }
  $s = $mgr.GetCurrentSession()
  if ($null -eq $s) {
    return [ordered]@{ ok = $true; playing = $false; volume = [math]::Round($vol, 3) }
  }
  $pi    = $s.GetPlaybackInfo()
  $tl    = $s.GetTimelineProperties()
  $appId = $s.SourceAppUserModelId
  $now   = $script:SW.ElapsedMilliseconds
  # media properties are comparatively expensive: refresh on app change or every 2s only
  if ($null -eq $script:Props -or $appId -ne $script:PropsApp -or ($now - $script:PropsAt) -gt 1000) {
    try {
      $script:Props    = Await ($s.TryGetMediaPropertiesAsync()) $PropsType 4000
      $script:PropsApp = $appId
      $script:PropsAt  = $now
    } catch {
      Write-Dbg ('media properties failed: ' + $_.Exception.Message)
      $script:PropsAt = $now
    }
  }
  $props = $script:Props
  if ($null -eq $props) {
    return [ordered]@{ ok = $true; playing = $false; volume = [math]::Round($vol, 3) }
  }

  $key = '' + $props.Title + '|' + $props.Artist
  if ($key -ne $script:CoverKey) {
    $script:CoverPath = $null
    if ($null -ne $props.Thumbnail) {
      # PowerShell 5.1 cannot read WinRT streams, so a small native helper decodes the cover.
      # It is launched DETACHED on purpose: it must never be able to block this state loop.
      try {
        # the helper may live next to the app, one or two levels up, depending on how
        # the build was unpacked (installer vs portable extraction)
        $helperCandidates = @(
          (Join-Path $PSScriptRoot '..\native\SmtcArt.exe'),
          (Join-Path $PSScriptRoot '..\..\native\SmtcArt.exe'),
          (Join-Path $PSScriptRoot '..\..\..\native\SmtcArt.exe'),
          (Join-Path $PSScriptRoot 'native\SmtcArt.exe')
        )
        $helper = $helperCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($helper) {
          Get-Process SmtcArt -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
          $script:CoverStamp = Get-Date
          Start-Process -FilePath $helper -WindowStyle Hidden -ErrorAction Stop | Out-Null
        } else {
          Write-Dbg ('native helper missing; tried: ' + ($helperCandidates -join ' | '))
        }
      } catch { Write-Dbg ('native cover spawn error: ' + $_.Exception.Message) }
    }
    $script:CoverKey = $key
    if ($null -ne $props.Thumbnail -and $null -eq $script:CoverPath) { Write-Dbg ('thumbnail present but could not be decoded (PowerShell 5.1 cannot read WinRT streams)') }
  }

  # pick up a freshly written cover file (never blocks on the helper process)
  if ($null -ne $script:CoverStamp -and $null -eq $script:CoverPath) {
    foreach ($e in @('png','jpg')) {
      $cp = Join-Path $env:TEMP ('media-widget-cover.' + $e)
      if (Test-Path $cp) {
        $fi = Get-Item $cp -ErrorAction SilentlyContinue
        if ($fi -and $fi.LastWriteTime -ge $script:CoverStamp) {
          $script:CoverPath = $cp
          $script:CoverStamp = $null
          Write-Dbg ('cover picked up: ' + $cp + ' (' + $fi.Length + ' bytes)')
          break
        }
      }
    }
    if ($null -ne $script:CoverStamp -and ((Get-Date) - $script:CoverStamp).TotalSeconds -gt 12) {
      $script:CoverStamp = $null
      Write-Dbg 'cover fetch gave up'
    }
  }

  return [ordered]@{
    ok       = $true
    playing  = $true
    appId    = $appId
    title    = [string]$props.Title
    artist   = [string]$props.Artist
    album    = [string]$props.AlbumTitle
    status   = $pi.PlaybackStatus.ToString()
    position = [math]::Round($tl.Position.TotalSeconds, 2)
    duration = [math]::Round($tl.EndTime.TotalSeconds, 2)
    cover    = $script:CoverPath
    volume   = [math]::Round($vol, 3)
  }
}

function Invoke-Cmd([string]$cmd) {
  $cmd = $cmd.Trim()
  if ($cmd -match '^volume:([0-9]*\.?[0-9]+)$') {
    [SysVolume]::SetVolume([float][math]::Max(0, [math]::Min(1, [double]$Matches[1])))
    return
  }
  $mgr = Get-Manager
  $s = $mgr.GetCurrentSession()
  if ($null -eq $s) { return }
  switch -Regex ($cmd) {
    '^(playpause|toggle)$'     { [void](Await ($s.TryTogglePlayPauseAsync()) $BoolType) }
    '^play$'                   { [void](Await ($s.TryPlayAsync()) $BoolType) }
    '^pause$'                  { [void](Await ($s.TryPauseAsync()) $BoolType) }
    '^next$'                   { [void](Await ($s.TrySkipNextAsync()) $BoolType) }
    '^prev$'                   { [void](Await ($s.TrySkipPreviousAsync()) $BoolType) }
    '^seek:([0-9]*\.?[0-9]+)$' { [void](Await ($s.TryChangePlaybackPositionAsync([long]([double]$Matches[1] * 10000000))) $BoolType) }
  }
}

if ($Once)    { (Get-NowPlaying) | ConvertTo-Json -Compress -Depth 5; exit 0 }
if ($Command) { Invoke-Cmd $Command; exit 0 }

# ---- streaming mode: JSON lines on stdout, commands on stdin ----
Write-Dbg 'bridge starting loop'
$stdin = [System.IO.StreamReader]::new([Console]::OpenStandardInput())
$readTask = $stdin.ReadLineAsync()
$lastPoll = 0
$iter = 0
while ($true) {
  $iter++
  try {
    if ($readTask -ne $null -and $readTask.IsCompleted) {
      $line = $null
      try { $line = $readTask.Result } catch { Write-Dbg ('stdin read error: ' + $_.Exception.Message) }
      if ($null -ne $line -and $line.Trim().Length -gt 0) {
        try { Invoke-Cmd $line } catch { Write-Dbg ('cmd error: ' + $_.Exception.Message) }
        $lastPoll = 0
      }
      if ($null -eq $line) { Start-Sleep -Milliseconds 250 }
      $readTask = $stdin.ReadLineAsync()
    }
  } catch { Write-Dbg ('loop error: ' + $_.Exception.Message) }
  $now = $script:SW.ElapsedMilliseconds
  if (($now - $lastPoll) -ge 600) {
    $lastPoll = $now
    $json = $null
    try { $json = (Get-NowPlaying) | ConvertTo-Json -Compress -Depth 5 }
    catch { $json = '{"ok":false,"error":"' + (($_.Exception.Message) -replace '\"','') + '"}' }
    if ($null -eq $json) { $json = '{"ok":false,"error":"empty"}' }
    try { [Console]::Out.WriteLine($json); [Console]::Out.Flush() }
    catch { Write-Dbg ('stdout error: ' + $_.Exception.Message) }
  }
  Start-Sleep -Milliseconds 45
}
