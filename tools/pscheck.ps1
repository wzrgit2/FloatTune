$errs = $null
$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw 'C:\Users\SuperWan\.openclaw\workspace\music-widget\bridge\smtc.ps1'), [ref]$errs)
if ($errs.Count -eq 0) { 'PS-OK' } else { $errs | ForEach-Object { $_.Message } }