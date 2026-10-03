# LOLON BUAH (PC) — Cloudflare Quick Tunnel abadi. Dijalankan Scheduled Task "LOLON BUAH Tunnel" sebagai SYSTEM.
$Root = 'C:\LolonBuah'; $Cf = "$Root\cloudflared\cloudflared.exe"; $Log = "$Root\logs\tunnel.log"
New-Item -ItemType Directory -Force "$Root\logs" | Out-Null
while ($true) {
  Remove-Item $Log -ErrorAction SilentlyContinue
  $p = Start-Process -FilePath $Cf -ArgumentList "tunnel --no-autoupdate --url http://127.0.0.1:4700 --logfile `"$Log`"" -PassThru -WindowStyle Hidden
  $url = $null
  for ($i = 0; $i -lt 90 -and -not $url; $i++) {
    Start-Sleep 2
    if (Test-Path $Log) { $m = Select-String -Path $Log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' | Select-Object -Last 1; if ($m) { $url = $m.Matches[0].Value } }
  }
  if ($url) { & powershell -NoProfile -ExecutionPolicy Bypass -File "$Root\terbitkan-alamat.ps1" -Url $url }
  $p.WaitForExit()
  Start-Sleep 5
}
