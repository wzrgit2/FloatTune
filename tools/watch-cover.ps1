$ErrorActionPreference = 'Continue'
$log = Join-Path $env:TEMP 'smtcart-watch.log'
Remove-Item $log -Force -ErrorAction SilentlyContinue
$env:SMTCART_DEBUG = '1'
$helper = 'C:\Users\SuperWan\.openclaw\workspace\music-widget\native\SmtcArt.exe'
Add-Content $log ("watch started " + (Get-Date -Format 'HH:mm:ss'))
for ($i = 0; $i -lt 240; $i++) {
  $o = & $helper 2>&1
  $txt = ($o | ForEach-Object { $_.ToString() }) -join ' | '
  if ($txt -notmatch 'no current session' -and $txt -notmatch 'no session manager') {
    Add-Content $log ((Get-Date -Format 'HH:mm:ss') + '  ' + $txt)
  }
  Start-Sleep -Seconds 15
}
Add-Content $log 'watch ended'
