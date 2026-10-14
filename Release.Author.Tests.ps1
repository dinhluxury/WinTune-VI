#Requires -Version 5.1
# Real cryptography with throwaway fixture keys. No network, registry or PATH writes.
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Distribution.Core.ps1"
Add-Type -AssemblyName System.IO.Compression.FileSystem,System.Security
$test=Join-Path $PSScriptRoot ('.test-runs/author-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$builder=Join-Path $test 'builder';$keys=Join-Path $test 'fixture-keys';$pass=0
$null=New-Item -ItemType Directory -Path $builder
$ps=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
function Check($Ok,$Name) {if (-not $Ok) {throw "RELEASE AUTHOR FAILED: $Name"};$script:pass++;Write-Output "PASS AUTHOR: $Name"}
function Run-Author([string]$File,[string[]]$Arguments=@()) {
    $out=& $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $builder $File) @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {throw ($out|Out-String)}
}
function Reject-Author([string]$File,[string[]]$Arguments,[string]$Name) {
    $failed=$false;try {Run-Author $File $Arguments} catch {$failed=$true};Check $failed $Name
}
foreach ($name in @('New-ReleaseSigningKey.ps1','Configure-Release.ps1','Sign-Release.ps1','Build-Distribution.ps1','Prepare-GitHub.ps1','Bootstrapper.template.ps1','Distribution.Core.ps1','CommandRegistration.ps1','.gitignore','.gitattributes')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $builder}
Reject-Author New-ReleaseSigningKey.ps1 @('-Directory',(Join-Path $builder 'keys')) 'Private keys inside the author project are refused'
Check (-not (Test-Path (Join-Path $builder 'keys'))) 'Refused generation creates no key directory'
Run-Author New-ReleaseSigningKey.ps1 @('-Directory',$keys)
$public=Get-Content (Join-Path $keys 'public.xml') -Raw
Check ($public.Contains('<RSAKeyValue>') -and $public -notmatch '<(D|P|Q|DP|DQ|InverseQ)>') 'PowerShell 5.1 author tool exports only RSA public components'
$keyHash=(Get-FileHash (Join-Path $keys 'private.dpapi')).Hash
Check (-not [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $keys 'private.dpapi'))).Contains('<RSAKeyValue>')) 'Private key bytes are encrypted with current-user DPAPI'
Reject-Author New-ReleaseSigningKey.ps1 @('-Directory',$keys) 'Existing signing directories cannot be overwritten'
Check ((Get-FileHash (Join-Path $keys 'private.dpapi')).Hash -ceq $keyHash) 'Refused regeneration preserves the existing key'
Run-Author Configure-Release.ps1 @('-Repository','fixture/WinTune','-PublicKeyFile',(Join-Path $keys 'public.xml'))
$cfg=Get-ReleaseConfig $builder
Check ($cfg.Repository -ceq 'fixture/WinTune' -and $cfg.PublicKeyXml -ceq $public) 'Publisher configuration pins the exact public key locally'
$package=Join-Path $test 'WinTune-VI-v0.15.0';$null=New-Item -ItemType Directory -Path $package
foreach ($name in @('WinTune-VI.exe','WinTune-Demo.exe','WinTune.ps1','MainWindow.xaml','features.json','Core.ps1','Tools.Core.ps1','Tools.Worker.ps1','Theme.UI.ps1','Monitor.UI.ps1','Wintune.Command.exe')) {[IO.File]::WriteAllText((Join-Path $package $name),'fixture; never executed')}
[IO.File]::WriteAllText((Join-Path $package 'version.json'),'{"Schema":1,"Version":"0.15.0","MinimumBuild":22621,"Architecture":"x64"}')
Copy-Item -LiteralPath (Join-Path $builder 'release-config.json') -Destination $package
function Checksums {
    @(Get-ChildItem -LiteralPath $package -File | Where-Object Name -ne 'SHA256.txt' | ForEach-Object {(Get-FileHash -LiteralPath $_.FullName).Hash+'  '+$_.Name}) | Set-Content (Join-Path $package 'SHA256.txt') -Encoding UTF8
}
Checksums
$zip=Join-Path $test 'WinTune-VI-v0.15.0-portable.zip';[IO.Compression.ZipFile]::CreateFromDirectory($package,$zip,[IO.Compression.CompressionLevel]::Optimal,$true)
Run-Author Build-Distribution.ps1 @('-Package',$package,'-Zip',$zip)
$assets=(Get-Content (Join-Path $builder 'release-assets/LATEST.txt') -Raw).Trim();$manifest=Join-Path $assets 'release.json'
Run-Author Sign-Release.ps1 @('-Manifest',$manifest,'-PrivateKey',(Join-Path $keys 'private.dpapi'))
$signature=Join-Path $assets 'release.sig'
$m=Read-SignedRelease ([IO.File]::ReadAllBytes($manifest)) ([IO.File]::ReadAllBytes($signature)) $cfg 'v0.15.0'
Check ($m.MinimumBuild -eq 22621 -and $m.SHA256 -ceq (Get-FileHash $zip).Hash) 'Release uses package build requirements and the exact ZIP checksum'
Check ((Get-Item $signature).Length -eq 384) 'Generated RSA3072 signature verifies with the pinned public key'
$online=Join-Path $assets 'WinTune-Online.ps1';$tokens=$null;$parseErrors=$null
$null=[Management.Automation.Language.Parser]::ParseFile($online,[ref]$tokens,[ref]$parseErrors)
Check (@($parseErrors).Count -eq 0) 'Generated standalone bootstrapper parses in PowerShell 5.1'
$command=Get-Content (Join-Path $assets 'ONLINE-COMMAND.txt') -Raw
Check ($command.Contains((Get-FileHash $online).Hash) -and $command.Contains('/fixture/WinTune/releases/download/v0.15.0/') -and -not $command.Contains('irm | iex')) 'Online command pins version, repository and bootstrapper checksum'
$null=New-Item -ItemType Directory -Path (Join-Path $package 'simulation-data')
[IO.File]::WriteAllText((Join-Path $package 'simulation-data/private-history.json'),'{"fixture":"not for public source"}')
Run-Author Prepare-GitHub.ps1 @('-Package',$package,'-Assets',$assets)
$ready=(Get-Content (Join-Path $builder 'github-ready/LATEST.txt') -Raw).Trim()
Check ((Get-Content (Join-Path $ready 'PREPARED.json') -Raw|ConvertFrom-Json).SignatureVerified) 'Preparation re-verifies the signed release and archive'
Check (@(Get-ChildItem (Join-Path $ready 'Source') -Recurse -File | Where-Object {$_.Extension -in @('.exe','.dpapi','.zip')}).Count -eq 0) 'Public source folder contains no binaries, archives or private key'
Check (-not (Test-Path (Join-Path $ready 'Source/simulation-data'))) 'Source preparation excludes unlisted mutable data even after running the portable app'
Check ((Get-ChildItem (Join-Path $ready 'Release') -File).Count -eq 6 -and (Test-Path (Join-Path $ready 'Source/.gitattributes'))) 'Release assets are separated from source and preserve byte-exact hashes in Git'
$bytes=[IO.File]::ReadAllBytes($manifest);$bytes[$bytes.Length-2]=$bytes[$bytes.Length-2] -bxor 1
$failed=$false;try {Read-SignedRelease $bytes ([IO.File]::ReadAllBytes($signature)) $cfg 'v0.15.0' | Out-Null} catch {$failed=$true}
Check $failed 'Modified production-format metadata cannot pass the author verification'
$assetZip=Join-Path $assets $m.Asset;$zipBytes=[IO.File]::ReadAllBytes($assetZip);[IO.File]::WriteAllBytes($assetZip,($zipBytes+[byte]0))
$before=(Get-FileHash $signature).Hash
Reject-Author Sign-Release.ps1 @('-Manifest',$manifest,'-PrivateKey',(Join-Path $keys 'private.dpapi')) 'Signer refuses an archive changed after manifest creation'
Check ((Get-FileHash $signature).Hash -ceq $before) 'Rejected signing leaves the previous signature untouched'
Reject-Author Prepare-GitHub.ps1 @('-Package',$package,'-Assets',$assets) 'GitHub preparation refuses an altered release archive'
$newCfg=$cfg.PSObject.Copy();$newCfg.Repository='other/Repo';[IO.File]::WriteAllText((Join-Path $builder 'release-config.json'),($newCfg|ConvertTo-Json))
Reject-Author Build-Distribution.ps1 @('-Package',$package,'-Zip',$zip) 'Publisher configuration must match the packaged repository and key'
# Clear only the two explicitly named throwaway key files; keep other evidence.
[IO.File]::Delete((Join-Path $keys 'private.dpapi'));[IO.File]::Delete((Join-Path $keys 'public.xml'))
Write-Output "RELEASE AUTHOR TESTS PASSED: $pass; real fixture RSA/DPAPI, zero network or native Windows changes."
