#Requires -Version 5.1
# AUTHOR TOOL: local metadata only; no release publication.
param([Parameter(Mandatory=$true)][string]$Repository,[Parameter(Mandatory=$true)][string]$PublicKeyFile)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Distribution.Core.ps1"
$cfg=[pscustomobject]@{Schema=1;Repository=$Repository;PublicKeyXml=[IO.File]::ReadAllText($PublicKeyFile);Channel='stable'}
Assert-ReleaseTrust $cfg
[IO.File]::WriteAllText("$PSScriptRoot/release-config.json",($cfg|ConvertTo-Json),(New-Object Text.UTF8Encoding($true)))
Write-Output 'Đã cấu hình nguồn và khóa công khai. Build lại gói; không ký/phát hành tự động.'
