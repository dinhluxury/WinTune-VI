@echo off
setlocal DisableDelayedExpansion
rem WinTune CMD entry: download a file, verify its pinned hash, then run it.
rem No IEX, encoded command, security exclusions, PATH setup or hidden retry.
set "wt_mode=-Confirmed"
if not "%~2"=="" goto bad_arguments
if "%~1"=="" goto initialise
if /i not "%~1"=="--check-only" goto bad_arguments
set "wt_mode=-CheckOnly"
:initialise
if not defined TEMP goto temp_error
set "wt_ps=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "wt_curl=%SystemRoot%\System32\curl.exe"
rem Choose the native Windows binaries before execution, including 32-bit CMD.
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "wt_ps=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\curl.exe" set "wt_curl=%SystemRoot%\Sysnative\curl.exe"
if not exist "%wt_ps%" goto missing_tools
if not exist "%wt_curl%" goto missing_tools
set "wt_attempt=0"
:new_directory
set /a wt_attempt+=1 >nul
if %wt_attempt% GTR 20 goto temp_error
set "wt_directory=%TEMP%\WinTuneVI-%RANDOM%-%RANDOM%"
if exist "%wt_directory%" goto new_directory
mkdir "%wt_directory%" >nul 2>&1
if errorlevel 1 goto temp_error
set "WINTUNE_BOOTSTRAP_FILE=%wt_directory%\WinTune-Online.ps1"
echo WinTune VI - dang tai va kiem tra launcher...
"%wt_curl%" --disable --fail --location --silent --show-error --proto =https --proto-redir =https --connect-timeout 10 --max-time 60 --max-filesize 1048576 --output "%WINTUNE_BOOTSTRAP_FILE%" "https://github.com/dinhluxury/WinTune-VI/releases/download/v0.16.0/WinTune-Online.ps1"
if errorlevel 1 goto download_error
"%wt_ps%" -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; if ((Get-FileHash -LiteralPath $env:WINTUNE_BOOTSTRAP_FILE -Algorithm SHA256 -ErrorAction Stop).Hash -cne '8C63F1439F5415A5AB361754F1B79F647CC6F2DFA09C115D0840CD68388288E4') {Write-Error 'Checksum WinTune khong khop. Chua chay launcher.'; exit 1}"
if errorlevel 1 goto verification_error
"%wt_ps%" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%WINTUNE_BOOTSTRAP_FILE%" %wt_mode%
set "wt_exit=%ERRORLEVEL%"
if not "%wt_exit%"=="0" echo Khong mo duoc WinTune. Neu Windows chan, dung lai; khong tat Defender hoac them ngoai le.
goto cleanup
:download_error
echo Khong tai duoc launcher. Kiem tra ket noi hoac ban phat hanh. Chua chay WinTune.
set "wt_exit=2"
goto cleanup
:verification_error
echo Khong xac minh duoc launcher. Chua chay WinTune.
set "wt_exit=3"
:cleanup
rem Delete only this invocation's exact file; remove the directory only if empty.
if exist "%WINTUNE_BOOTSTRAP_FILE%" del /q "%WINTUNE_BOOTSTRAP_FILE%" >nul 2>&1
rmdir "%wt_directory%" >nul 2>&1
endlocal & exit /b %wt_exit%
:bad_arguments
echo Su dung: run.cmd [--check-only]
endlocal & exit /b 64
:temp_error
echo Khong tao duoc thu muc tam. Chua tai hoac chay WinTune.
endlocal & exit /b 4
:missing_tools
echo Can Windows 11 voi curl.exe va Windows PowerShell co san. Khong tu cai them.
endlocal & exit /b 5
