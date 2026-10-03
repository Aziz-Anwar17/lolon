@echo off
rem LOLON BUAH - pindahkan server ke PC ini (lewat internet). Klik dua kali, pilih "Ya" bila Windows meminta izin.
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
title Pemasang LOLON BUAH
echo.
echo  ===== PEMASANG SERVER LOLON BUAH =====
echo.
set /p KODE=Ketik KODE PEMASANGAN dari Claude lalu tekan Enter: 
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $b='https://aziz-anwar17.github.io/lolon/pc'; $j=Invoke-RestMethod ('https://api.github.com/repos/Aziz-Anwar17/lolon/contents/pc/serah.json?t='+[DateTime]::Now.Ticks) -Headers @{Accept='application/vnd.github.raw+json';'User-Agent'='lolon'}; if ($j -is [string]) { $j=$j|ConvertFrom-Json }; $env:LOLON_SOURCE=$b; $env:LOLON_SERAH=$j.url; $env:LOLON_KODE='%KODE%'; $w=New-Object Net.WebClient; $w.Encoding=[Text.Encoding]::UTF8; iex ($w.DownloadString($b+'/pasang-pc.ps1?t='+[DateTime]::Now.Ticks).TrimStart([char]0xFEFF))"
echo.
pause
