#Requires -Version 5.1
param([switch]$CheckOnly,[switch]$RegisterCommand,[switch]$Confirmed,[switch]$Setup)
$ErrorActionPreference='Stop'
# Replaced only by the local build, never by Internet input.
$script:BootstrapTrust=ConvertFrom-Json ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__TRUST_BASE64__')))
__DISTRIBUTION_CORE__
__COMMAND_REGISTRATION__
__SOURCE_COMMAND_REGISTRATION__
__SETUP_CORE__
try {
    Assert-ReleaseTrust $script:BootstrapTrust
    $root=Get-WinTuneInstallRoot
    $current='0.0.0'
    if (Test-Path -LiteralPath (Join-Path $root 'current.txt')) {
        $path=(Get-Content -LiteralPath (Join-Path $root 'current.txt') -Raw -Encoding UTF8).Trim()
        $path=Assert-DistributionPath $path (Join-Path $root 'apps');$current=(Get-WinTuneVersion $path).Version
    }
    Write-Host 'Đang kiểm tra GitHub Releases và chữ ký manifest…'
    $info=Get-DistributionUpdate $script:BootstrapTrust $current
    Write-Host ("Đã cài: $current; bản stable đã xác minh: "+$info.Manifest.Version)
    if ($CheckOnly) {return}
    if ($Setup) {
        Write-Host (Get-WinTuneSetupText $info.Manifest.Version $root)
        if (-not $Confirmed -and (Read-Host 'Thiết lập lệnh wintune và mở ứng dụng? Gõ DONG Y') -cne 'DONG Y') {Write-Host 'Đã hủy trước khi tải hoặc đăng ký.';return}
        $Confirmed=$true
        $RegisterCommand=$true
        if ((Get-UserCommandRegistration).AppExists) {throw 'Có lệnh wintune kiểu cũ hoặc của ứng dụng khác. Bỏ đăng ký cũ trước; không ghi đè.'}
    }
    if ($info.Status -eq 'Available') {
        if (-not $Confirmed) {
            Write-Host ("Sẽ tải "+$info.Manifest.Size+" byte từ "+$info.ReleaseUrl)
            if ((Read-Host 'Tải, xác minh và khởi chạy bản này? Gõ DONG Y') -cne 'DONG Y') {Write-Host 'Đã hủy trước khi tải ZIP.';return}
        }
        $installed=Install-DistributionUpdate $info $root $true $null $script:BootstrapTrust
        $path=$installed.Path
    } else {
        if (-not $Confirmed -and (Read-Host 'Mở bản đã cài? Gõ DONG Y') -cne 'DONG Y') {return}
        Test-PortableIntegrity $path $current
    }
    if ($RegisterCommand) {
        $registration=Register-WinTuneCommand $path $root $true
        if ($registration.Status -notin @('Registered','NoOp')) {throw 'Chưa xác minh được lệnh wintune; chưa mở app.'}
        Write-Host 'Đã thiết lập lệnh wintune. Từ lần sau chỉ cần gõ wintune trong CMD hoặc PowerShell.'
    }
    # PowerShell/WPF is the primary online entry, never a fallback after a denial.
    # Windows still enforces policy on this host, scripts and dependent assemblies.
    Start-VerifiedWinTuneApp $path (Get-WinTuneVersion $path).Version
} catch {
    $reason=$_.Exception.Message
    if ($reason -match 'Application Control|code integrity|digital signature') {
        Write-Error ('Windows Application Control chặn file khởi chạy. Chữ ký manifest xác minh gói tải không phải chữ ký Authenticode của EXE. Không tự đổi chính sách bảo mật hoặc thử cách mở khác. Gói đã chuẩn bị vẫn được giữ; xem DISTRIBUTION.md, mục lỗi khởi chạy, về lối PowerShell/WPF có sẵn nếu chính sách cho phép. Chi tiết: '+$reason)
    } else {Write-Error ('Không khởi chạy WinTune: '+$reason)}
    exit 1
}
