# LOLON BUAH (PC) — perbarui alamat tetap https://aziz-anwar17.github.io/lolon (repo Aziz-Anwar17/lolon, kunci deploy khusus) + kabari Telegram.
param([string]$Url)
$Root = 'C:\LolonBuah'; $Git = "$Root\git\cmd\git.exe"; $Repo = "$Root\penunjuk"
$old = (Get-Content "$Root\ALAMAT.txt" -ErrorAction SilentlyContinue | Select-Object -First 1)
Set-Content "$Root\ALAMAT.txt" $Url
Add-Content "$Root\logs\alamat.log" "$(Get-Date -Format s) alamat: $Url"
$ssh = 'C:/Windows/System32/OpenSSH/ssh.exe -i C:/LolonBuah/kunci/penunjuk -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=C:/LolonBuah/kunci/known_hosts'
$g = @('-c', "core.sshCommand=$ssh", '-c', 'safe.directory=*', '-c', 'user.name=PC LOLON BUAH', '-c', 'user.email=pc@lolonbuah.local')
for ($t = 0; $t -lt 6; $t++) {
  try {
    if (-not (Test-Path "$Repo\.git")) { Remove-Item $Repo -Recurse -Force -ErrorAction SilentlyContinue; & $Git @g clone --depth 1 git@github.com:Aziz-Anwar17/lolon.git $Repo 2>&1 | Out-Null }
    else { & $Git @g -C $Repo fetch --depth 1 origin main 2>&1 | Out-Null; & $Git @g -C $Repo reset --hard origin/main 2>&1 | Out-Null }
    $json = '{"url":"' + $Url + '","updated":"' + (Get-Date).ToUniversalTime().ToString('s') + 'Z","sumber":"PC"}'
    [IO.File]::WriteAllText("$Repo\server.json", $json + "`n")
    & $Git @g -C $Repo add server.json 2>&1 | Out-Null
    & $Git @g -C $Repo commit -m "Alamat server PC $(Get-Date -Format s)" 2>&1 | Out-Null
    & $Git @g -C $Repo push origin HEAD:main 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Add-Content "$Root\logs\alamat.log" "$(Get-Date -Format s) github diperbarui: $Url"; break }
  } catch { }
  Start-Sleep 15
}
if ($Url -ne $old -and (Test-Path "$Root\kunci\telegram.env")) {
  $env = @{}; Get-Content "$Root\kunci\telegram.env" | ForEach-Object { if ($_ -match '^([A-Z_]+)=(.*)$') { $env[$matches[1]] = $matches[2].Trim('"') } }
  try {
    Invoke-RestMethod -Method Post -Uri "https://api.telegram.org/bot$($env.TELEGRAM_BOT_TOKEN)/sendMessage" -Body @{ chat_id = $env.TELEGRAM_CHAT_ID; text = "🍹 LOLON BUAH (server PC) — alamat baru:`n$Url`n`nAlamat tetap https://aziz-anwar17.github.io/lolon sudah diperbarui otomatis." } | Out-Null
    Add-Content "$Root\logs\alamat.log" "$(Get-Date -Format s) telegram terkirim"
  } catch { }
}
