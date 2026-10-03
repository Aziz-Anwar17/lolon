# LOLON BUAH (PC) — ambil versi aplikasi terbaru dari repo PRIVAT Aziz-Anwar17/lolon-app dan pasang bila berbeda.
$Root = 'C:\LolonBuah'; $Git = "$Root\git\cmd\git.exe"; $Kode = "$Root\kode"
New-Item -ItemType Directory -Force "$Root\logs" | Out-Null
$ssh = 'C:/Windows/System32/OpenSSH/ssh.exe -i C:/LolonBuah/kunci/aplikasi -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=C:/LolonBuah/kunci/known_hosts'
$g = @('-c', "core.sshCommand=$ssh", '-c', 'safe.directory=*')
if (-not (Test-Path "$Kode\.git")) { Remove-Item $Kode -Recurse -Force -ErrorAction SilentlyContinue; & $Git @g clone --depth 1 git@github.com:Aziz-Anwar17/lolon-app.git $Kode 2>&1 | Out-Null }
else { & $Git @g -C $Kode fetch --depth 1 origin main 2>&1 | Out-Null; & $Git @g -C $Kode reset --hard origin/main 2>&1 | Out-Null }
if (-not (Test-Path "$Kode\versi.txt")) { Add-Content "$Root\logs\pembaruan.log" "$(Get-Date -Format s) gagal mengambil kode"; exit 1 }
$new = (Get-Content "$Kode\versi.txt" | Select-Object -First 1).Trim()
$cur = (Get-Content "$Root\app\VERSI" -ErrorAction SilentlyContinue | Select-Object -First 1)
if ($new -and $new -ne $cur) {
  Remove-Item "$Root\tmp-app" -Recurse -Force -ErrorAction SilentlyContinue
  Expand-Archive "$Kode\app.zip" "$Root\tmp-app" -Force
  robocopy "$Root\tmp-app\app" "$Root\app" /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
  Remove-Item "$Root\tmp-app" -Recurse -Force -ErrorAction SilentlyContinue
  # Hentikan node; tugas "LOLON BUAH Server" (putaran cmd) menyalakannya lagi dalam 5 detik dengan kode baru.
  Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -like '*LolonBuah*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  Add-Content "$Root\logs\pembaruan.log" "$(Get-Date -Format s) dipasang versi $new (sebelumnya $cur)"
}
