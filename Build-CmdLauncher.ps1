#Requires -Version 5.1
# Add a reviewable CMD Pages entry without rebuilding/replacing a published release.
param([Parameter(Mandatory=$true)][string]$Prepared)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Distribution.Core.ps1"
$preparedRoot=(Resolve-Path -LiteralPath $Prepared).Path
$source=Join-Path $preparedRoot 'Source'
$assets=Join-Path $preparedRoot 'Release'
$cfg=Get-ReleaseConfig $source
$version=(Get-WinTuneVersion $source).Version
$summary=Get-Content -LiteralPath (Join-Path $preparedRoot 'PREPARED.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$manifest=Read-SignedRelease ([IO.File]::ReadAllBytes((Join-Path $assets 'release.json'))) ([IO.File]::ReadAllBytes((Join-Path $assets 'release.sig'))) $cfg ('v'+$version)
if ($summary.Repository -cne $cfg.Repository -or $summary.Version -cne $version) {throw 'Prepared source identity mismatch.'}
$zip=Join-Path $assets $manifest.Asset
if ((Get-Item -LiteralPath $zip).Length -ne $manifest.Size -or (Get-FileHash -LiteralPath $zip).Hash -cne $manifest.SHA256) {throw 'Signed ZIP mismatch.'}
$hash=(Get-FileHash -LiteralPath (Join-Path $assets 'WinTune-Online.ps1')).Hash
if ($hash -cne $summary.BootstrapperSHA256 -or (Get-Content -LiteralPath (Join-Path $assets 'WinTune-Online.ps1.sha256') -Raw -Encoding UTF8).Trim() -cne $hash) {throw 'Prepared bootstrapper hash mismatch.'}
$url='https://github.com/'+$cfg.Repository+'/releases/download/v'+$version+'/WinTune-Online.ps1'
$cmdCode=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'CmdLauncher.template.cmd')).Replace('__BOOTSTRAP_URL__',$url).Replace('__BOOTSTRAP_SHA256__',$hash)
if ($cmdCode -match '__BOOTSTRAP_' -or $cmdCode -match '[^\x00-\x7f]') {throw 'CMD template has unresolved placeholders or non-ASCII content.'}
$cmdCode=($cmdCode -replace '\r?\n',"`r`n")
$output=Join-Path $PSScriptRoot ('github-ready/cmd-v'+$version+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$newSource=Join-Path $output 'Source'
$null=New-Item -ItemType Directory -Path $newSource
# A full source copy keeps the established GitHub Desktop handoff simple.
Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $newSource -Recurse
foreach ($name in @('CmdLauncher.template.cmd','Build-CmdLauncher.ps1','CmdLauncher.Tests.ps1','Build-Package.ps1','Build-Distribution.ps1','Release.Author.Tests.ps1','README.md','DISTRIBUTION.md','PUBLISHING.md')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $newSource -Force
}
$entry=Join-Path $newSource 'docs/run.cmd'
[IO.File]::WriteAllText($entry,$cmdCode,[Text.Encoding]::ASCII)
$parts=$cfg.Repository.Split('/')
$entryUrl='https://'+$parts[0].ToLowerInvariant()+'.github.io/'+$parts[1]+'/run.cmd'
$command='curl.exe -q -fL --proto =https --proto-redir =https -o "%TEMP%\wintune.cmd" '+$entryUrl+' && "%TEMP%\wintune.cmd"'
$notice=@"
# Bo sung launcher CMD cho WinTune VI $version

Chep NOI DUNG Source vao repository GitHub Desktop da clone, Commit -> Push origin.
Khong thay 6 asset Release $version, khong doi tag, khong tao Release moi.
GitHub Pages se cap nhat docs/run.cmd sau khi push. Kiem tra byte/hash URL truoc khi mo.

CMD tren may Windows 11 khac:
$command

Entry run.cmd dau tien tin cay HTTPS cua repository chinh thuc; khong duoc kiem hash
truoc khi batch nay chay. Batch tai launcher thanh file va kiem SHA256 ghim truoc -File.
Launcher giu nguyen RSA manifest/SHA256 ZIP/resource. Khong dung IEX hoac ma hoa lenh,
khong them PATH, dependency, ngoai le Defender hoac doi chinh sach bao mat.
ExecutionPolicy Bypass chi cho tien trinh PowerShell dang chay file da doi chieu;
khong thay Defender/App Control. Neu Defender chan, dung, khong tu thu host/lenh khac.

Test local --check-only chi doc metadata; khong tu tai ZIP, cai, dang ky lenh hoac mo app.
Khong coi test local la bao dam duoc chap nhan tren moi PC.
"@
[IO.File]::WriteAllText((Join-Path $output 'CMD-COMMAND.txt'),$command,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $output 'HUONG-DAN.md'),$notice,[Text.UTF8Encoding]::new($true))
$record=[ordered]@{Repository=$cfg.Repository;Version=$version;SourceFiles=@(Get-ChildItem -LiteralPath $newSource -File -Recurse -Force).Count;EntryUrl=$entryUrl;EntrySHA256=(Get-FileHash -LiteralPath $entry).Hash;BootstrapperURL=$url;BootstrapperSHA256=$hash;PublishedReleaseUnchanged=$true;AppCodeUnchanged=$true;Uploaded=$false;Command=$command}
[IO.File]::WriteAllText((Join-Path $output 'PREPARED.json'),($record|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($true))
$output | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'github-ready/CMD-LATEST.txt') -Encoding UTF8
Write-Output $output
