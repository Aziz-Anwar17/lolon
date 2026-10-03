# ============================================================================
#  LOLON BUAH — pindahkan server ke PC Windows (selalu menyala).
#  Dijalankan oleh PASANG-LOLON-BUAH.bat (klik dua kali, izinkan "Ya" pada UAC).
#  Aman diulang. Database yang sudah ada di PC TIDAK ditimpa kecuali proses serah terima belum pernah selesai.
# ============================================================================
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
$Root = 'C:\LolonBuah'; $Src = $env:LOLON_SOURCE; $Sec = $env:LOLON_SERAH; $Kode = $env:LOLON_KODE
$DataDir = "$Root\data\production"
function Step($m) { Write-Host "`n==> $m" -ForegroundColor Green }
function Fail($m) { Write-Host "`nGAGAL: $m" -ForegroundColor Red; Write-Host 'Kirim tangkapan layar jendela ini ke Claude.' -ForegroundColor Yellow; throw $m }
function Get($u, $out) { Invoke-WebRequest $u -OutFile $out -UseBasicParsing }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Fail 'Perlu hak Administrator.' }
if (-not $Src -or -not $Sec -or -not $Kode) { Fail 'Alamat sumber atau kode pemasangan tidak diketahui.' }
foreach ($d in 'app', 'node', 'cloudflared', 'git', 'kunci', 'logs', 'data\production') { New-Item -ItemType Directory -Force -Path "$Root\$d" | Out-Null }

# ---------- 1. Node.js resmi (SHA-256 diverifikasi) ----------
Step '1/8 Node.js'
if (-not (Test-Path "$Root\node\node.exe")) {
  $base = 'https://nodejs.org/dist/latest-v24.x'
  $line = ((Invoke-WebRequest "$base/SHASUMS256.txt" -UseBasicParsing).Content -split "`n") | Where-Object { $_ -match 'node-v[\d.]+-win-x64\.zip\s*$' } | Select-Object -First 1
  $hash, $zipName = ($line.Trim() -split '\s+')
  Get "$base/$zipName" "$env:TEMP\$zipName"
  if ((Get-FileHash "$env:TEMP\$zipName" -Algorithm SHA256).Hash.ToLower() -ne $hash.ToLower()) { Fail 'Checksum Node.js tidak cocok.' }
  Expand-Archive "$env:TEMP\$zipName" "$env:TEMP\nodex" -Force
  Copy-Item "$env:TEMP\nodex\$($zipName -replace '\.zip$','')\*" "$Root\node" -Recurse -Force
}
& "$Root\node\node.exe" -v

# ---------- 2. Cloudflared ----------
Step '2/8 Cloudflare Tunnel'
if (-not (Test-Path "$Root\cloudflared\cloudflared.exe")) { Get 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' "$Root\cloudflared\cloudflared.exe" }
& "$Root\cloudflared\cloudflared.exe" --version

# ---------- 3. Git portabel (untuk alamat tetap & pembaruan) ----------
Step '3/8 Git portabel'
if (-not (Test-Path "$Root\git\cmd\git.exe")) {
  $rel = Invoke-RestMethod 'https://api.github.com/repos/git-for-windows/git/releases/latest' -Headers @{ 'User-Agent' = 'lolon-buah' }
  $asset = $rel.assets | Where-Object { $_.name -match '^MinGit-[\d.]+-64-bit\.zip$' } | Select-Object -First 1
  Get $asset.browser_download_url "$env:TEMP\mingit.zip"
  Expand-Archive "$env:TEMP\mingit.zip" "$Root\git" -Force
}
& "$Root\git\cmd\git.exe" --version
if (-not (Test-Path 'C:\Windows\System32\OpenSSH\ssh.exe')) {
  Write-Host 'Memasang OpenSSH Client bawaan Windows…'
  Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 | Out-Null
}

# ---------- 4. Kunci & skrip dari Mac ----------
Step '4/8 Kunci & skrip'
foreach ($f in 'penunjuk', 'aplikasi', 'telegram.env') { try { Get "$Sec/kunci/$f?kode=$Kode" "$Root\kunci\$f" } catch { Fail "Kode pemasangan salah/kedaluwarsa atau Mac tidak menyala ($f)." } }
foreach ($f in 'tunnel.ps1', 'terbitkan-alamat.ps1', 'perbarui.ps1') { Get "$Src/$f" "$Root\$f" }
icacls "$Root\kunci" /inheritance:r /grant:r 'SYSTEM:(OI)(CI)F' 'Administrators:(OI)(CI)F' /T | Out-Null

# ---------- 5. Kode aplikasi dari repo privat ----------
Step '5/8 Kode aplikasi'
& powershell -NoProfile -ExecutionPolicy Bypass -File "$Root\perbarui.ps1"
if (-not (Test-Path "$Root\app\src\server.js")) { Fail "Kode aplikasi tidak terambil. Lihat $Root\logs\pembaruan.log" }
Write-Host "Versi aplikasi: $(Get-Content "$Root\app\VERSI")"

# ---------- 6. Serah terima database dari Mac (Mac berhenti menerima transaksi) ----------
Step '6/8 Serah terima database'
if (Test-Path "$DataDir\SERAH-TERIMA-SELESAI.txt") {
  Write-Host 'Database sudah pernah diserahkan ke PC — tidak ditimpa.' -ForegroundColor Yellow
} else {
  Get "$Sec/serah-db?kode=$Kode" "$env:TEMP\lolon-db.zip"
  Remove-Item "$env:TEMP\lolon-db" -Recurse -Force -ErrorAction SilentlyContinue
  Expand-Archive "$env:TEMP\lolon-db.zip" "$env:TEMP\lolon-db" -Force
  if (-not (Test-Path "$env:TEMP\lolon-db\loloan-production.db")) { Fail 'Berkas database dari Mac tidak lengkap.' }
  Copy-Item "$env:TEMP\lolon-db\*" $DataDir -Recurse -Force
  Write-Host "Database diterima ($([math]::Round((Get-Item "$DataDir\loloan-production.db").Length/1KB)) KB)."
}

# ---------- 7. Tugas otomatis (menyala sendiri setiap PC hidup) ----------
Step '7/8 Layanan otomatis'
@"
@echo off
set APP_MODE=production
set PORT=4700
set HOST=0.0.0.0
set COOKIE_SECURE=auto
set TRUST_PROXY=1
set DATA_DIR=$DataDir
cd /d $Root\app
:loop
"$Root\node\node.exe" src\server.js >> "$Root\logs\server.log" 2>&1
timeout /t 5 /nobreak >nul
goto loop
"@ | Set-Content "$Root\jalankan-server.cmd" -Encoding ASCII
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
$boot = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName 'LOLON BUAH Server' -Action (New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$Root\jalankan-server.cmd`"") -Trigger $boot -Settings $set -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Register-ScheduledTask -TaskName 'LOLON BUAH Tunnel' -Action (New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Root\tunnel.ps1`"") -Trigger $boot -Settings $set -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
$every = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(15) -RepetitionInterval (New-TimeSpan -Minutes 15)
Register-ScheduledTask -TaskName 'LOLON BUAH Pembaruan' -Action (New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Root\perbarui.ps1`"") -Trigger $every -Settings $set -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
foreach ($t in 'LOLON BUAH Server', 'LOLON BUAH Tunnel') { Stop-ScheduledTask $t -ErrorAction SilentlyContinue }
Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'node.exe' -or $_.Name -eq 'cloudflared.exe') -and $_.CommandLine -like '*LolonBuah*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-ScheduledTask 'LOLON BUAH Server'
$ok = $false; for ($i = 0; $i -lt 20 -and -not $ok; $i++) { Start-Sleep 2; try { $ok = [bool](Invoke-RestMethod 'http://127.0.0.1:4700/api/health').ok } catch {} }
if (-not $ok) { Fail "Server tidak menyala. Lihat $Root\logs\server.log" }
Write-Host 'Server LOLON BUAH hidup di PC.'
Start-ScheduledTask 'LOLON BUAH Tunnel'
# PC tidak boleh tidur/hibernasi saat tersambung listrik; cadangan Wi-Fi toko boleh masuk.
powercfg /change standby-timeout-ac 0; powercfg /change hibernate-timeout-ac 0; powercfg /change disk-timeout-ac 0
if (-not (Get-NetFirewallRule -DisplayName 'LOLON BUAH LAN' -ErrorAction SilentlyContinue)) { New-NetFirewallRule -DisplayName 'LOLON BUAH LAN' -Direction Inbound -Protocol TCP -LocalPort 4700 -Profile Private -Action Allow | Out-Null }

# ---------- 8. Verifikasi dari internet + konfirmasi ke Mac ----------
Step '8/8 Menunggu alamat publik & alamat tetap'
$url = $null
for ($i = 0; $i -lt 60 -and -not $url; $i++) { Start-Sleep 3; $url = (Get-Content "$Root\ALAMAT.txt" -ErrorAction SilentlyContinue | Select-Object -First 1) }
if (-not $url) { Fail "Tunnel belum memberi alamat. Lihat $Root\logs\tunnel.log" }
$live = $false; for ($i = 0; $i -lt 30 -and -not $live; $i++) { Start-Sleep 4; try { $live = [bool](Invoke-RestMethod "$url/api/health").ok } catch {} }
$pointed = $false; for ($i = 0; $i -lt 30 -and -not $pointed; $i++) { Start-Sleep 4; try { $p = Invoke-RestMethod "https://api.github.com/repos/Aziz-Anwar17/lolon/contents/server.json" -Headers @{ Accept = 'application/vnd.github.raw+json'; 'User-Agent' = 'lolon' }; if ($p -is [string]) { $p = $p | ConvertFrom-Json }; $pointed = ($p.url -eq $url) } catch {} }
if ($live -and $pointed) {
  Set-Content "$DataDir\SERAH-TERIMA-SELESAI.txt" "Database dipindahkan dari Mac pada $(Get-Date -Format s)"
  try { Invoke-WebRequest "$Sec/selesai?kode=$Kode&url=$([uri]::EscapeDataString($url))" -UseBasicParsing | Out-Null } catch {}
  Write-Host "`nSELESAI — LOLON BUAH kini berjalan di PC ini." -ForegroundColor Green
  Write-Host "Alamat tetap (tidak berubah): https://aziz-anwar17.github.io/lolon" -ForegroundColor Cyan
  Write-Host "Alamat langsung saat ini:     $url"
  Write-Host 'Mac boleh dimatikan. Biarkan PC ini tetap menyala dan tersambung internet.'
} else {
  Fail "Server menyala tetapi belum bisa diakses dari internet (live=$live, alamat tetap=$pointed). Lihat $Root\logs\alamat.log"
}
