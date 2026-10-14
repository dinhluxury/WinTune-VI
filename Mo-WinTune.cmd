@echo off
cd /d "%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0WinTune.ps1"
if errorlevel 1 (
 echo Khong mo duoc app. Xem HUONG-DAN.txt.
 pause
)
