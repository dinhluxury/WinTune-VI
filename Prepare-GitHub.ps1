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

Bản vá độ ổn định sau kiểm tra logic tính năng, hoàn tác và bộ tải.

- Sửa hoàn tác Registry/Explorer và phục hồi những đợt bị ngắt; giữ dữ liệu được phần mềm khác thay đổi.
- Đọc danh sách ứng dụng và chuẩn bị xem trước bằng tác vụ nền; xử lý đóng cửa sổ, hủy tác vụ đọc và kết quả bị thiếu/hỏng.
- Xác minh lại cache đã cài bằng manifest có chữ ký và inventory từ ZIP đã ký. Giữ khóa công khai và URL chính thức.
- Giữ 111 mục tùy chỉnh, WizTree mở ổ C:, công cụ sửa Windows và các tính năng hiện có. Không tự áp dụng tinh chỉnh.
- Bổ sung kiểm thử hồi quy và báo cáo audit, bảo mật, hiệu năng cùng phạm vi chưa kiểm chứng.

Mở PowerShell/Windows Terminal và chạy:

```powershell
irm __PAGES_URL__ | iex
```

Hoặc tải **WinTune-VI-v0.15.0-portable.zip**, giải nén toàn bộ, mở **Mo-WinTune.cmd**.
Thử mô phỏng bằng **Mo-Ban-Mo-Phong.cmd**. App chính vẫn là PowerShell 5.1/WPF.

Các kiểm thử thay đổi Registry, gỡ/cài ứng dụng và sửa Windows dùng mock/mô phỏng.
Không khẳng định hiệu lực trên mọi build Windows hay không có lỗi tuyệt đối.
Xem **CHANGELOG-v0.15.0.md**, **KIEM-THU-v0.15.0.md** và **TEST_REPORT.md**.

Entry Pages đầu tiên vẫn là nguồn tin cậy mutable; các bước sau ghim SHA256 launcher,
chữ ký RSA manifest/ZIP và checksum tài nguyên. Không thay chính sách bảo mật Windows.
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
