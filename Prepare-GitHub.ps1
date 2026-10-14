#Requires -Version 5.1
# Produces reviewable local folders. Does not initialize Git, upload or publish.
param([string]$Package='',[string]$Assets='')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Distribution.Core.ps1"
if (-not $Package) {$Package=(Get-Content "$PSScriptRoot/release/LATEST.txt" -Raw).Trim()}
if (-not $Assets) {$Assets=(Get-Content "$PSScriptRoot/release-assets/LATEST.txt" -Raw).Trim()}
$v=(Get-WinTuneVersion $Package).Version;$cfg=Get-ReleaseConfig $Package
Test-PortableIntegrity $Package $v
if (Test-Path -LiteralPath (Join-Path $Package 'evidence')) {throw 'Dùng Build-Package.ps1 -PublicRelease trước: bộ public không chứa dữ liệu kiểm thử của máy.'}
$manifestPath=Join-Path $Assets 'release.json';$signaturePath=Join-Path $Assets 'release.sig'
$m=Read-SignedRelease ([IO.File]::ReadAllBytes($manifestPath)) ([IO.File]::ReadAllBytes($signaturePath)) $cfg ('v'+$v)
$zip=Join-Path $Assets $m.Asset
if ((Get-FileHash -LiteralPath $zip).Hash -ine $m.SHA256 -or (Get-Item -LiteralPath $zip).Length -ne $m.Size) {throw 'ZIP phát hành không khớp chữ ký.'}
$online=Join-Path $Assets 'WinTune-Online.ps1';$onlineHash=(Get-FileHash -LiteralPath $online).Hash
if ((Get-Content (Join-Path $Assets 'WinTune-Online.ps1.sha256') -Raw).Trim() -cne $onlineHash) {throw 'Checksum bootstrapper không khớp.'}
$output=Join-Path $PSScriptRoot ('github-ready/v'+$v+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$source=Join-Path $output 'Source';$release=Join-Path $output 'Release'
$null=New-Item -ItemType Directory -Path $source,$release
$textExtensions=@('.ps1','.psm1','.cs','.xaml','.json','.md','.txt','.cmd')
$listed=@(Get-Content (Join-Path $Package 'SHA256.txt') -Encoding UTF8 | ForEach-Object {
    if ($_ -match '^[0-9A-Fa-f]{64}  (.+)$') {$Matches[1]}
})
foreach ($file in @(Get-ChildItem -LiteralPath $Package -Recurse -File)) {
    $relative=$file.FullName.Substring($Package.Length+1)
    if ($listed -notcontains $relative -or $file.Extension -notin $textExtensions -or $relative -eq 'SHA256.txt') {continue}
    $dest=Join-Path $source $relative;$null=New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($dest)) -Force
    Copy-Item -LiteralPath $file.FullName -Destination $dest
}
foreach ($name in @('.gitignore','.gitattributes')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $source}
# The public progress file is a short generated summary, never the private history.
$ignorePath=Join-Path $source '.gitignore'
$ignore=[IO.File]::ReadAllText($ignorePath) -replace '(?m)^/TIEN-DO\.md\r?\n',''
[IO.File]::WriteAllText($ignorePath,$ignore,[Text.UTF8Encoding]::new($false))
foreach ($name in @($m.Asset,'WinTune-Online.ps1','WinTune-Online.ps1.sha256','release.json','release.sig','ONLINE-COMMAND.txt')) {Copy-Item -LiteralPath (Join-Path $Assets $name) -Destination $release}
$note=@'
# WinTune VI 0.15.0

Ứng dụng Windows 11 x64 bằng tiếng Việt, PowerShell + WPF.

- Tùy chỉnh Windows, quyền riêng tư và giao diện có xem trước/hoàn tác.
- Gỡ ứng dụng theo tài khoản, bảo vệ thành phần thiết yếu; không gỡ sẵn.
- Cài 17 phần mềm thông dụng khi tự chọn và xác nhận.
- Tổng quan máy tính, tiến trình cập nhật theo chu kỳ mục tiêu 2 giây.
- Portable EXE, đăng ký lệnh wintune theo tài khoản khi có xác nhận.
- Kiểm tra GitHub Releases khi bấm; RSA-SHA256 manifest và SHA256 ZIP.

Tải **WinTune-VI-v0.15.0-portable.zip**, giải nén toàn bộ và mở
**WinTune-VI.exe**. Thử mô phỏng bằng **WinTune-Demo.exe**.
Không dùng gói Source code tự tạo bởi GitHub để chạy EXE.

Online Launcher: lệnh trong **ONLINE-COMMAND.txt** tải bootstrapper ra file,
kiểm tra SHA256 ghim rồi khởi chạy. Không dùng irm | iex.
Đọc lệnh từ kênh tin cậy của tác giả; bootstrapper tiếp tục xác minh chữ ký
manifest và ZIP. Chỉ hoạt động sau khi bản stable này được phát hành.

EXE không có chữ ký Authenticode; chữ ký release.sig dùng cho WinTune xác minh
bản phát hành. Không bỏ qua chính sách bảo mật Windows.
Các kiểm tra sửa/xóa/gỡ/cài/đổi PATH dùng mock; hiệu lực trên Windows thật,
PATH/Win+R thật và chuỗi tải từ Release sản xuất còn cần kiểm chứng riêng.
Đọc README.md, DISTRIBUTION.md và FEATURE_MATRIX.md để biết phạm vi/giới hạn.
'@
$note=$note.Replace('0.15.0',$v)
[IO.File]::WriteAllText((Join-Path $output 'RELEASE-NOTES.md'),$note,[Text.UTF8Encoding]::new($true))
$fileList=@(Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {$_.FullName.Substring($source.Length+1)})
[IO.File]::WriteAllText((Join-Path $output 'SOURCE-FILES.txt'),($fileList -join "`r`n"),[Text.UTF8Encoding]::new($true))
$summary=[pscustomobject]@{Repository=$cfg.Repository;Version=$v;SourceFiles=$fileList.Count;ReleaseAsset=$m.Asset;SHA256=$m.SHA256;BootstrapperSHA256=$onlineHash;SignatureVerified=$true;Published=$false}
[IO.File]::WriteAllText((Join-Path $output 'PREPARED.json'),($summary|ConvertTo-Json),[Text.UTF8Encoding]::new($true))
$output | Set-Content "$PSScriptRoot/github-ready/LATEST.txt" -Encoding UTF8
Write-Output "Prepared local GitHub folders: $output. Nothing uploaded/published."
