# First setup uses the existing verified installer and conditional User PATH receipt.
# Callers must obtain one explicit confirmation covering installation and command setup.
function Get-WinTuneSetupText([string]$Version,[string]$Root) {
    return "Thiết lập WinTune $Version cho tài khoản Windows này.`n`nỨng dụng được lưu tại $Root.`nTạo lệnh wintune để mở từ CMD, PowerShell hoặc Win + R.`nSau lần này bạn chỉ cần gõ wintune; không phải đăng ký trong app.`n`nChỉ thêm thư mục lệnh vào PATH của tài khoản này. Giữ các bản cũ và lịch sử. Không áp dụng tinh chỉnh Windows."
}
function Start-VerifiedWinTuneApp([string]$Package,[string]$Version) {
    Test-PortableIntegrity $Package $Version
    $entry=Join-Path $Package 'WinTune.ps1'
    if ($entry.Contains('"')) {throw 'Đường dẫn khởi chạy không hợp lệ.'}
    $hostExe=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    Start-Process -FilePath $hostExe -ArgumentList ('-NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$entry+'"') -WorkingDirectory $Package -ErrorAction Stop
}
function Invoke-WinTuneLocalSetup([string]$Package,[string]$Root,[bool]$Confirmed) {
    if (-not $Confirmed) {throw 'Chưa xác nhận thiết lập WinTune; không cài hoặc đăng ký lệnh.'}
    # Refuse a foreign/legacy registration before changing the active package pointer.
    $existing=Get-UserCommandRegistration
    if ($existing.AppExists) {throw 'Có lệnh wintune kiểu cũ hoặc của ứng dụng khác. Bỏ đăng ký cũ trong WinTune trước; không ghi đè.'}
    $installed=Install-LocalDistribution $Package $Root $true
    $registration=Register-WinTuneCommand $installed.Path $Root $true
    if ($registration.Status -notin @('Registered','NoOp')) {throw 'Chưa xác minh được lệnh wintune; chưa mở app.'}
    $version=(Get-WinTuneVersion $installed.Path).Version
    Start-VerifiedWinTuneApp $installed.Path $version
    return [pscustomobject]@{Status='Ready';Version=$version;Path=$installed.Path;Message='Đã thiết lập và mở WinTune. Từ lần sau chỉ cần gõ wintune. Nếu Terminal đang mở, đóng toàn bộ cửa sổ Terminal rồi mở lại từ Start.'}
}
