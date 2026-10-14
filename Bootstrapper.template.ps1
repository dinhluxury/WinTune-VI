#Requires -Version 5.1
param([switch]$CheckOnly,[switch]$RegisterCommand,[switch]$Confirmed)
$ErrorActionPreference='Stop'
# Replaced only by the local build, never by Internet input.
$script:BootstrapTrust=ConvertFrom-Json ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__TRUST_BASE64__')))
__DISTRIBUTION_CORE__
__COMMAND_REGISTRATION__
try {
    Assert-ReleaseTrust $script:BootstrapTrust
    $root=Get-WinTuneInstallRoot
    $current='0.0.0'
    if (Test-Path -LiteralPath (Join-Path $root 'current.txt')) {
        $path=(Get-Content -LiteralPath (Join-Path $root 'current.txt') -Raw).Trim()
        $path=Assert-DistributionPath $path (Join-Path $root 'apps');$current=(Get-WinTuneVersion $path).Version
    }
    Write-Host 'Đang kiểm tra GitHub Releases và chữ ký manifest…'
    $info=Get-DistributionUpdate $script:BootstrapTrust $current
    Write-Host ("Đã cài: $current; bản stable đã xác minh: "+$info.Manifest.Version)
    if ($CheckOnly) {return}
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
    if ($RegisterCommand) {Register-WinTuneCommand $path $root $true | Write-Host}
    # Confirmation above explicitly covers launching. Updater inside WPF never launches.
    Start-Process -FilePath (Join-Path $path 'WinTune-VI.exe') -WorkingDirectory $path
} catch {Write-Error ('Không khởi chạy WinTune: '+$_.Exception.Message);exit 1}
