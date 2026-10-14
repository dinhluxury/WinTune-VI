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
foreach ($name in @('New-ReleaseSigningKey.ps1','Configure-Release.ps1','Sign-Release.ps1','Build-Distribution.ps1','Prepare-GitHub.ps1','Bootstrapper.template.ps1','Distribution.Core.ps1','CommandRegistration.ps1','SourceCommandRegistration.ps1','Setup.Core.ps1','QuickLauncher.template.ps1','.gitignore','.gitattributes')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $builder}
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
$line=@($command -split '\r?\n' | Where-Object {$_ -like '$p=*'})[0]
Check ($line.Contains((Get-FileHash $online).Hash) -and $line.Contains('/fixture/WinTune/releases/download/v0.15.0/') -and -not $line.Contains('irm | iex')) 'Online command pins version, repository and bootstrapper checksum'
Check ($command.Contains('-NoProfile -STA -ExecutionPolicy Bypass -File $p') -and $command.Contains('System32\WindowsPowerShell\v1.0\powershell.exe') -and -not $command.Contains('Set-ExecutionPolicy')) 'Generated launch command uses a fixed child host with process-only policy'
# Test the actual generated command from a Restricted parent. Network/hash
# adapters are mocked; the child is a harmless local fixture, never WinTune.
$child=Join-Path $test 'child.ps1';$marker=Join-Path $test 'child.json'
[IO.File]::WriteAllText($child,'param([switch]$CheckOnly,[switch]$Setup) [pscustomobject]@{Policy=[string](Get-ExecutionPolicy);Apartment=[Threading.Thread]::CurrentThread.ApartmentState.ToString();CheckOnly=[bool]$CheckOnly;Setup=[bool]$Setup}|ConvertTo-Json|Set-Content -LiteralPath $env:WINTUNE_FIXTURE_MARKER -Encoding UTF8',[Text.UTF8Encoding]::new($true))
function Run-CommandFixture([string]$Body,[string]$Hash,[bool]$FailDownload=$false) {
    $setup=@'
$ErrorActionPreference='Stop'
$env:TEMP='__TEMP__'
$env:WINTUNE_FIXTURE_MARKER='__MARKER__'
$script:ParentMarker='__PARENT__'
$script:FixtureSource='__CHILD__'
$script:FixtureHash='__HASH__'
$script:FixtureFail=__FAIL__
function Invoke-WebRequest { [CmdletBinding()]param($Uri,$OutFile,[switch]$UseBasicParsing,$TimeoutSec) if($script:FixtureFail){throw 'mock connection failure'};Copy-Item -LiteralPath $script:FixtureSource -Destination $OutFile }
function Get-FileHash { [CmdletBinding()]param($LiteralPath,$Algorithm) return [pscustomobject]@{Hash=$script:FixtureHash} }
'@
    $setup=$setup.Replace('__TEMP__',$test.Replace("'","''")).Replace('__MARKER__',$marker.Replace("'","''")).Replace('__PARENT__',(Join-Path $test 'parent-policy.txt').Replace("'","''")).Replace('__CHILD__',$child.Replace("'","''")).Replace('__HASH__',$Hash).Replace('__FAIL__',$(if ($FailDownload) {'$true'} else {'$false'}))
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($setup+"`r`n"+$Body+"`r`n[string](Get-ExecutionPolicy) | Set-Content -LiteralPath `$script:ParentMarker`r`nexit `$LASTEXITCODE"))
    $ErrorActionPreference='Continue' # Capture expected native stderr and exit code.
    $output=& $ps -NoProfile -ExecutionPolicy Restricted -EncodedCommand $encoded 2>&1
    return [pscustomobject]@{ExitCode=$LASTEXITCODE;Output=($output|Out-String)}
}
$publishedHash=(Get-FileHash $online).Hash
$run=Run-CommandFixture ($line+' -CheckOnly') $publishedHash
if ($run.ExitCode -ne 0) {throw $run.Output}
$result=Get-Content $marker -Raw | ConvertFrom-Json
Check ($result.Policy -eq 'Bypass' -and $result.Apartment -eq 'STA' -and $result.CheckOnly -and (Get-Content (Join-Path $test 'parent-policy.txt') -Raw).Trim() -eq 'Restricted') 'Restricted parent can launch verified fixture in a separate STA session without changing parent policy'
Check (-not $result.Setup) 'Default online command opens the app without registering PATH'
Check ($command.Contains('irm https://fixture.github.io/WinTune | iex') -and $command.Contains('curl.exe -q -fL --proto =https --proto-redir =https') -and $command.Contains('https://fixture.github.io/WinTune/run.cmd') -and $command.Contains('irm https://raw.githubusercontent.com/fixture/WinTune/main/get.ps1 | iex') -and -not $command.Contains('powershell -NoProfile -Command "irm')) 'PowerShell entry, file-based CMD entry and raw fallback use the configured publisher; blocked CMD-IEX wrapper is absent'
[IO.File]::Delete($marker)
$run=Run-CommandFixture ($line+' -CheckOnly') ('0'*64)
Check ($run.ExitCode -ne 0 -and -not (Test-Path $marker)) 'Checksum mismatch prevents the child from being launched'
$run=Run-CommandFixture ($line+' -CheckOnly') $publishedHash $true
Check ($run.ExitCode -ne 0 -and -not (Test-Path $marker)) 'Connection failure terminates before checksum or child execution'
$null=New-Item -ItemType Directory -Path (Join-Path $package 'simulation-data')
[IO.File]::WriteAllText((Join-Path $package 'simulation-data/private-history.json'),'{"fixture":"not for public source"}')
Run-Author Prepare-GitHub.ps1 @('-Package',$package,'-Assets',$assets)
$ready=(Get-Content (Join-Path $builder 'github-ready/LATEST.txt') -Raw).Trim()
Check ((Get-Content (Join-Path $ready 'PREPARED.json') -Raw|ConvertFrom-Json).SignatureVerified) 'Preparation re-verifies the signed release and archive'
Check (@(Get-ChildItem (Join-Path $ready 'Source') -Recurse -File | Where-Object {$_.Extension -in @('.exe','.dpapi','.zip')}).Count -eq 0) 'Public source folder contains no binaries, archives or private key'
Check (-not (Test-Path (Join-Path $ready 'Source/simulation-data'))) 'Source preparation excludes unlisted mutable data even after running the portable app'
Check ((Get-ChildItem (Join-Path $ready 'Release') -File).Count -eq 6 -and (Test-Path (Join-Path $ready 'Source/.gitattributes'))) 'Release assets are separated from source and preserve byte-exact hashes in Git'
Check ((Get-FileHash (Join-Path $ready 'Source/get.ps1')).Hash -ceq (Get-FileHash (Join-Path $assets 'get.ps1')).Hash) 'Generated get.ps1 enters Source while six release assets remain unchanged'
Check ((Get-FileHash (Join-Path $ready 'Source/docs/index.html')).Hash -ceq (Get-FileHash (Join-Path $assets 'get.ps1')).Hash -and (Get-Item (Join-Path $ready 'Source/docs/.nojekyll')).Length -eq 0) 'Pages index is byte-identical to the verified entry, with no Jekyll processing'
$indexPath=Join-Path $assets 'Pages/index.html';$indexBefore=[IO.File]::ReadAllBytes($indexPath)
[IO.File]::WriteAllText($indexPath,'changed page')
Reject-Author Prepare-GitHub.ps1 @('-Package',$package,'-Assets',$assets) 'Changed hosted entry is rejected before publishing source'
[IO.File]::WriteAllBytes($indexPath,$indexBefore)
$quickBefore=[IO.File]::ReadAllText((Join-Path $assets 'get.ps1'))
[IO.File]::WriteAllText((Join-Path $assets 'get.ps1'),$quickBefore+' changed')
Reject-Author Prepare-GitHub.ps1 @('-Package',$package,'-Assets',$assets) 'A modified first-stage entry is rejected during source preparation'
[IO.File]::WriteAllText((Join-Path $assets 'get.ps1'),$quickBefore,[Text.UTF8Encoding]::new($false))
$quickPath=Join-Path $assets 'get.ps1';$quickBytes=[IO.File]::ReadAllBytes($quickPath)
[IO.File]::WriteAllBytes($quickPath,([Text.UTF8Encoding]::new($true).GetPreamble()+$quickBytes))
Reject-Author Prepare-GitHub.ps1 @('-Package',$package,'-Assets',$assets) 'UTF-8 BOM is refused for the hosted IEX entry'
[IO.File]::WriteAllBytes($quickPath,$quickBytes)
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
