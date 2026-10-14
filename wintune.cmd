@echo off
setlocal
if "%~1"=="" goto app
if /I "%~1"=="demo" goto demo
if /I "%~1"=="test" goto test
if /I "%~1"=="probe" goto probe
if /I "%~1"=="help" goto help
if /I "%~1"=="update" goto update
if /I "%~1"=="register" goto register
if /I "%~1"=="unregister" goto unregister
echo Tham so khong hop le. Go: wintune help
exit /b 2
:app
if not exist "%~dp0WinTune.ps1" goto missing
start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0WinTune.ps1"
exit /b %errorlevel%
:demo
if not exist "%~dp0WinTune.ps1" goto missing
start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0WinTune.ps1" -Simulation
exit /b %errorlevel%
:test
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Run-Tests.ps1"
exit /b %errorlevel%
:probe
if not exist "%~dp0WinTune.ps1" goto missing
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0WinTune.ps1" -GuiProbe
exit /b %errorlevel%
:update
if not exist "%~dp0WinTune.ps1" goto missing
start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0WinTune.ps1" -Updates
exit /b %errorlevel%
:register
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Register-WinTune.ps1"
exit /b %errorlevel%
:unregister
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Register-WinTune.ps1" -Remove
exit /b %errorlevel%
:missing
echo Thieu WinTune.ps1. Hay giai nen toan bo goi portable vao cung thu muc.
exit /b 1
:help
echo wintune       : Mo ung dung; khong tu ap dung thay doi.
echo wintune demo  : Mo ban mo phong, khong ghi Windows.
echo wintune test  : Chay kiem thu tu dong voi registry mo phong.
echo wintune update: Mo trang cap nhat, khong tu tai/chay.
echo wintune register / unregister: Dang ky / bo dang ky lenh cho user.
echo wintune probe : Mo/dong WPF Demo tu dong de kiem tra launcher.
exit /b 0
