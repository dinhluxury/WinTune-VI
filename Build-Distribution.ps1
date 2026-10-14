#Requires -Version 5.1
# Build artifacts only. No GitHub publication or signing key generation.
param([string]$Package='',[string]$Zip='')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Distribution.Core.ps1"
if (-not $Package) {$Package=(Get-Content "$PSScriptRoot/release/LATEST.txt" -Raw).Trim()}
$versionInfo=Get-WinTuneVersion $Package;$v=$versionInfo.Version
if (-not $Zip) {$Zip=Join-Path $PSScriptRoot ('WinTune-VI-v'+$v+'-portable.zip')}
$cfg=Get-Content "$PSScriptRoot/release-config.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if ($cfg.Repository -or $cfg.PublicKeyXml) {Assert-ReleaseTrust $cfg}
Test-PortableIntegrity $Package $v
$packageCfg=Get-Content (Join-Path $Package 'release-config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($packageCfg.Repository -cne $cfg.Repository -or $packageCfg.PublicKeyXml -cne $cfg.PublicKeyXml) {throw 'Cấu hình trong portable khác cấu hình tác giả. Build lại gói trước khi chuẩn bị Release.'}
# Validate the exact archive, not just the folder supplied beside it.
$audit=Join-Path $PSScriptRoot ('.test-runs/release-audit-'+[guid]::NewGuid().ToString('N'))
$zipRoot=Expand-VerifiedPackage $Zip $audit $v
$zipCfg=Get-Content (Join-Path $zipRoot 'release-config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$zipVersion=Get-WinTuneVersion $zipRoot
if ($zipCfg.Repository -cne $cfg.Repository -or $zipCfg.PublicKeyXml -cne $cfg.PublicKeyXml -or $zipVersion.MinimumBuild -ne $versionInfo.MinimumBuild) {throw 'ZIP không khớp nguồn tin cậy/phiên bản Windows đã chọn; không chuẩn bị Release.'}
$output=Join-Path $PSScriptRoot ('release-assets/v'+$v+'-'+[guid]::NewGuid().ToString('N').Substring(0,8));$null=New-Item -ItemType Directory -Path $output -Force
$trust=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($cfg|ConvertTo-Json -Compress)))
$template=[IO.File]::ReadAllText("$PSScriptRoot/Bootstrapper.template.ps1")
$code=$template.Replace('__TRUST_BASE64__',$trust).Replace('__DISTRIBUTION_CORE__',[IO.File]::ReadAllText("$PSScriptRoot/Distribution.Core.ps1")).Replace('__COMMAND_REGISTRATION__',[IO.File]::ReadAllText("$PSScriptRoot/CommandRegistration.ps1")).Replace('__SOURCE_COMMAND_REGISTRATION__',[IO.File]::ReadAllText("$PSScriptRoot/SourceCommandRegistration.ps1"))
$online=Join-Path $output 'WinTune-Online.ps1';[IO.File]::WriteAllText($online,$code,(New-Object Text.UTF8Encoding($true)))
Copy-Item -LiteralPath $Zip -Destination $output
$m=[pscustomobject]@{Schema=1;Repository=$cfg.Repository;Version=$v;Architecture='x64';MinimumBuild=$versionInfo.MinimumBuild;Asset=[IO.Path]::GetFileName($Zip);Size=(Get-Item -LiteralPath $Zip).Length;SHA256=(Get-FileHash -LiteralPath $Zip).Hash}
[IO.File]::WriteAllText((Join-Path $output 'release.json'),($m|ConvertTo-Json),(New-Object Text.UTF8Encoding($false)))
$hash=(Get-FileHash -LiteralPath $online).Hash
$url='https://github.com/'+$(if ($cfg.Repository) {$cfg.Repository} else {'OWNER/REPOSITORY'})+'/releases/download/v'+$v+'/WinTune-Online.ps1'
$command='$p=Join-Path $env:TEMP (''WinTune-''+[guid]::NewGuid().ToString(''N'')+''.ps1''); Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop -Uri '''+$url+''' -OutFile $p; if((Get-FileHash -LiteralPath $p -Algorithm SHA256 -ErrorAction Stop).Hash -cne '''+$hash+'''){throw ''Checksum bootstrapper sai''}; & (Join-Path $env:WINDIR ''System32\WindowsPowerShell\v1.0\powershell.exe'') -NoProfile -STA -ExecutionPolicy Bypass -File $p'
$notice="Mở WinTune VI bằng PowerShell. Lấy lệnh này từ kênh tin cậy của tác giả; SHA256 bootstrapper ghim trong lệnh. Tải ra file, xác minh rồi mở phiên PowerShell riêng; không đổi ExecutionPolicy của tài khoản hoặc toàn máy. Bootstrapper tiếp tục kiểm tra chữ ký manifest và ZIP, hỏi DONG Y trước khi tải/khởi chạy. Lệnh dùng được sau khi tác giả công khai bản stable với đủ asset đã ký. Không dùng irm | iex.`r`n`r`n"+$command
[IO.File]::WriteAllText((Join-Path $output 'ONLINE-COMMAND.txt'),$notice,(New-Object Text.UTF8Encoding($true)))
[IO.File]::WriteAllText((Join-Path $output 'WinTune-Online.ps1.sha256'),$hash,(New-Object Text.UTF8Encoding($true)))
$output | Set-Content "$PSScriptRoot/release-assets/LATEST.txt" -Encoding UTF8
Write-Output "Prepared release assets: $output. Not signed/published."
