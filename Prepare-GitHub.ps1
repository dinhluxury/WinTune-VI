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
$quick=Join-Path $Assets 'get.ps1'
$quickUrl='https://github.com/'+$cfg.Repository+'/releases/download/v'+$v+'/WinTune-Online.ps1'
$expectedQuick=[IO.File]::ReadAllText("$PSScriptRoot/QuickLauncher.template.ps1").Replace('__BOOTSTRAP_URL__',$quickUrl).Replace('__BOOTSTRAP_SHA256__',$onlineHash)
if ([IO.File]::ReadAllText($quick) -cne $expectedQuick) {throw 'get.ps1 không khớp template hoặc hash của launcher; không chuẩn bị Source.'}
$quickBytes=[IO.File]::ReadAllBytes($quick)
if ($quickBytes.Length -ge 3 -and $quickBytes[0] -eq 239 -and $quickBytes[1] -eq 187 -and $quickBytes[2] -eq 191) {throw 'Entry HTTP phải là UTF-8 không BOM để chạy qua IEX.'}
$pages=Join-Path $Assets 'Pages'
if ((Get-FileHash -LiteralPath (Join-Path $pages 'index.html')).Hash -cne (Get-FileHash -LiteralPath $quick).Hash -or (Get-Item -LiteralPath (Join-Path $pages '.nojekyll')).Length -ne 0) {throw 'Bộ GitHub Pages không khớp entry đã xác minh.'}
$output=Join-Path $PSScriptRoot ('github-ready/v'+$v+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$source=Join-Path $output 'Source';$release=Join-Path $output 'Release'
$null=New-Item -ItemType Directory -Path $source,$release
$textExtensions=@('.ps1','.psm1','.cs','.xaml','.json','.md','.txt','.cmd')
$listed=@(Get-Content (Join-Path $Package 'SHA256.txt') -Encoding UTF8 | ForEach-Object {
    if ($_ -match '^[0-9A-Fa-f]{64}  (.+)$') {$Matches[1]}
})
foreach ($file in @(Get-ChildItem -LiteralPath $Package -Recurse -File)) {
    $relative=$file.FullName.Substring($Package.Length+1)
    $isStartTemplate=$relative -ceq 'sources\full-tweaks\start2.bin'
    if ($listed -notcontains $relative -or ($file.Extension -notin $textExtensions -and -not $isStartTemplate) -or $relative -eq 'SHA256.txt') {continue}
    $dest=Join-Path $source $relative;$null=New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($dest)) -Force
    Copy-Item -LiteralPath $file.FullName -Destination $dest
}
foreach ($name in @('.gitignore','.gitattributes')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $source}
# The online entry is generated after the ZIP; it belongs on main, not in runtime resources.
Copy-Item -LiteralPath $quick -Destination (Join-Path $source 'get.ps1')
$docs=Join-Path $source 'docs';$null=New-Item -ItemType Directory -Path $docs
foreach ($name in @('index.html','.nojekyll')) {Copy-Item -LiteralPath (Join-Path $pages $name) -Destination (Join-Path $docs $name)}
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
- PowerShell/WPF là lối mở chính; đăng ký wintune.cmd theo tài khoản khi xác nhận.
- Mở online bằng một dòng PowerShell/CMD; không cần đăng ký lệnh trên máy mới.
- Kiểm tra GitHub Releases khi bấm; RSA-SHA256 manifest và SHA256 ZIP.

Tải **WinTune-VI-v0.15.0-portable.zip**, giải nén toàn bộ và mở
**Mo-WinTune.cmd**. Thử mô phỏng bằng **Mo-Ban-Mo-Phong.cmd**.
Tùy chọn mở offline bằng tên wintune: chạy **Cai-WinTune.cmd** một lần;
đóng/mở lại Terminal từ Start, sau đó gõ **wintune**.
EXE có sẵn là lựa chọn riêng khi chính sách Windows cho phép; chưa ký Authenticode.
Không dùng gói Source code tự tạo bởi GitHub để chạy EXE.

Online Launcher: dùng lệnh ngắn trong **ONLINE-COMMAND.txt**, dạng
`irm __PAGES_URL__ | iex`.
Lệnh ngắn tin cậy get.ps1 đầu tiên qua HTTPS của repository chính thức;
get.ps1 kiểm SHA256 launcher, rồi chữ ký manifest/ZIP và tài nguyên.
Cũng giữ lệnh dài ghim hash trước khi chạy để tự chọn. Chỉ hoạt động
sau khi docs đã lên main, GitHub Pages được bật từ main /docs và bản stable
này được phát hành. URL raw get.ps1 vẫn được giữ trong ONLINE-COMMAND.txt.
Khởi chạy bằng host PowerShell Microsoft và script WPF đã xác minh; không
phụ thuộc EXE tự biên dịch, không tự đổi hoặc né chính sách Application Control.

EXE không có chữ ký Authenticode; chữ ký release.sig dùng cho WinTune xác minh
bản phát hành. Không bỏ qua chính sách bảo mật Windows.
Các kiểm tra sửa/xóa/gỡ/cài/đổi PATH dùng mock; hiệu lực trên Windows thật,
PATH/Win+R thật và chuỗi tải từ Release sản xuất còn cần kiểm chứng riêng.
Đọc README.md, DISTRIBUTION.md và FEATURE_MATRIX.md để biết phạm vi/giới hạn.
'@
$note=$note.Replace('0.15.0',$v)
$note=$note.Replace('OWNER/REPOSITORY',$cfg.Repository)
$parts=$cfg.Repository.Split('/');$pagesUrl='https://'+$parts[0].ToLowerInvariant()+'.github.io/'+$parts[1]
$note=$note.Replace('__PAGES_URL__',$pagesUrl)
[IO.File]::WriteAllText((Join-Path $output 'RELEASE-NOTES.md'),$note,[Text.UTF8Encoding]::new($true))
$fileList=@(Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {$_.FullName.Substring($source.Length+1)})
[IO.File]::WriteAllText((Join-Path $output 'SOURCE-FILES.txt'),($fileList -join "`r`n"),[Text.UTF8Encoding]::new($true))
$summary=[pscustomobject]@{Repository=$cfg.Repository;Version=$v;SourceFiles=$fileList.Count;ReleaseAsset=$m.Asset;SHA256=$m.SHA256;BootstrapperSHA256=$onlineHash;QuickLauncherSHA256=(Get-FileHash $quick).Hash;SignatureVerified=$true;Published=$false}
[IO.File]::WriteAllText((Join-Path $output 'PREPARED.json'),($summary|ConvertTo-Json),[Text.UTF8Encoding]::new($true))
$output | Set-Content "$PSScriptRoot/github-ready/LATEST.txt" -Encoding UTF8
Write-Output "Prepared local GitHub folders: $output. Nothing uploaded/published."
