#Requires -Version 5.1
param([switch]$Remove,[switch]$Recover,[switch]$Confirmed)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Distribution.Core.ps1"
. "$PSScriptRoot/CommandRegistration.ps1"
. "$PSScriptRoot/SourceCommandRegistration.ps1"
$root=Get-WinTuneInstallRoot
if ($Remove -and $Recover) {throw 'Chọn riêng bỏ đăng ký hoặc phục hồi đăng ký lỗi.'}
if (-not $Confirmed) {
    Write-Host "Thư mục: $root. Lệnh PowerShell/WPF qua User PATH; không đổi Machine PATH hoặc App Paths (ngoại trừ khi bỏ đăng ký EXE cũ)."
    $answer=Read-Host $(if ($Recover) {'Phục hồi đăng ký dang dở nếu chưa đổi bên ngoài? Gõ DONG Y'} elseif ($Remove) {'Bỏ đăng ký wintune? Gõ DONG Y để xác nhận'} else {'Chép bản portable vào thư mục của tài khoản và đăng ký wintune? Gõ DONG Y để xác nhận'})
    if ($answer -cne 'DONG Y') {Write-Host 'Đã hủy; không thay đổi.';return}
}
if ($Recover) {Repair-WinTuneCommandRegistration $root $true}
elseif ($Remove) {Unregister-WinTuneCommand $root $true} else {
    $installed=Install-LocalDistribution $PSScriptRoot $root $true
    Register-WinTuneCommand $installed.Path $root $true
}
