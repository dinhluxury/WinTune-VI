#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Distribution.Core.ps1";. "$PSScriptRoot/CommandRegistration.ps1"
. "$PSScriptRoot/SourceCommandRegistration.ps1"
$test=Join-Path $PSScriptRoot ('.test-runs/Phân phối '+[guid]::NewGuid().ToString('N').Substring(0,6));$null=New-Item -ItemType Directory -Path $test;$pass=0
function Check($Ok,$Name) {if (-not $Ok) {throw "DISTRIBUTION FAILED: $Name"};$script:pass++;Write-Output "PASS DISTRIBUTION: $Name"}
function Reject([scriptblock]$Work,$Name) {$failed=$false;try {& $Work | Out-Null} catch {$failed=$true};Check $failed $Name}
function Bytes($Object) {return ,[Text.Encoding]::UTF8.GetBytes(($Object|ConvertTo-Json -Depth 6 -Compress))}
$rsa=New-Object Security.Cryptography.RSACryptoServiceProvider 2048;$rsa.PersistKeyInCsp=$false
$cfg=[pscustomobject]@{Schema=1;Repository='fixture/WinTune';PublicKeyXml=$rsa.ToXmlString($false);Channel='stable'}
$source=Join-Path $test 'WinTune-VI-v0.16.0';$null=New-Item -ItemType Directory -Path $source
foreach ($name in @('WinTune-VI.exe','WinTune-Demo.exe','WinTune.ps1','MainWindow.xaml','features.json','Core.ps1','Tools.Core.ps1','Tools.Worker.ps1','Theme.UI.ps1','Monitor.UI.ps1','Wintune.Command.exe')) {[IO.File]::WriteAllText((Join-Path $source $name),'fixture, never executed')}
foreach ($name in @('Wintune.Registered.cmd','CommandRouter.ps1')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $source}
[IO.File]::WriteAllText((Join-Path $source 'version.json'),'{"Schema":1,"Version":"0.16.0","MinimumBuild":22000,"Architecture":"x64"}')
[IO.File]::WriteAllText((Join-Path $source 'release-config.json'),($cfg|ConvertTo-Json))
function Write-FixtureChecksums {
 $lines=@(Get-ChildItem -LiteralPath $source -File | Where-Object Name -ne 'SHA256.txt' | ForEach-Object {(Get-FileHash -LiteralPath $_.FullName).Hash+'  '+$_.Name})
 $lines | Set-Content -LiteralPath (Join-Path $source 'SHA256.txt') -Encoding UTF8
}
Write-FixtureChecksums
Add-Type -AssemblyName System.IO.Compression.FileSystem,System.Net.Http
$zip=Join-Path $test 'package.zip';[IO.Compression.ZipFile]::CreateFromDirectory($source,$zip,[IO.Compression.CompressionLevel]::Optimal,$true)
$zipBytes=[IO.File]::ReadAllBytes($zip)
$m=[pscustomobject]@{Schema=1;Repository=$cfg.Repository;Version='0.16.0';Architecture='x64';MinimumBuild=22000;Asset='WinTune-VI-v0.16.0-portable.zip';SHA256=(Get-DistributionHash $zipBytes);Size=$zipBytes.Length}
$payload=Bytes $m;$signature=$rsa.SignData($payload,[Security.Cryptography.CryptoConfig]::MapNameToOID('SHA256'))
Check ((Read-SignedRelease $payload $signature $cfg 'v0.16.0').Version -eq '0.16.0') 'RSA-SHA256 signature uses the pinned public key'
$tampered=$payload.Clone();$tampered[15]=$tampered[15] -bxor 1;Reject {Read-SignedRelease $tampered $signature $cfg 'v0.16.0'} 'Modified manifest is rejected before JSON processing'
$wrong=New-Object Security.Cryptography.RSACryptoServiceProvider 2048;$wrong.PersistKeyInCsp=$false;$wrongCfg=$cfg.PSObject.Copy();$wrongCfg.PublicKeyXml=$wrong.ToXmlString($false)
Reject {Read-SignedRelease $payload $signature $wrongCfg 'v0.16.0'} 'A different signing key is not accepted';$wrong.Dispose()
Reject {Read-SignedRelease $payload $signature $cfg 'v0.17.0'} 'Release tag must match signed manifest'
$privateCfg=$cfg.PSObject.Copy();$privateCfg.PublicKeyXml=$rsa.ToXmlString($true);Reject {Assert-ReleaseTrust $privateCfg} 'Private keys cannot enter distributed trust metadata'
$emptyCfg=$cfg.PSObject.Copy();$emptyCfg.Repository='';Reject {Assert-ReleaseTrust $emptyCfg} 'Unconfigured production source fails closed without networking'
foreach ($url in @('http://github.com/fixture/WinTune','https://github.com.evil.example/test','https://127.0.0.1/test','https://user@github.com/test','https://github.com:444/test','https://github.com/test#fragment')) {Reject {Assert-DistributionUrl $url} "Unsafe download URL rejected: $url"}
foreach ($name in @('../outside','A/../outside','C:/Windows/a','/rooted','A/file.txt:stream','A/CON.txt','A/trailing.','A/trailing ','A//empty')) {Reject {Assert-PackageName $name} "Unsafe ZIP name rejected: $name"}
Check ((Assert-PackageName 'WinTune-VI-v0.16.0/sources/README.md') -eq 'WinTune-VI-v0.16.0/sources/README.md') 'Ordinary resource paths are allowed'
Test-PortableIntegrity $source '0.16.0';Check $true 'All resources and package version are checked against the file manifest'
[IO.File]::WriteAllText((Join-Path $source 'MainWindow.xaml'),'changed');Reject {Test-PortableIntegrity $source '0.16.0'} 'Modified XAML is rejected';[IO.File]::WriteAllText((Join-Path $source 'MainWindow.xaml'),'fixture, never executed')
[IO.File]::WriteAllText((Join-Path $source 'unexpected.ps1'),'do not execute');Reject {Test-PortableIntegrity $source '0.16.0'} 'Extra scripts outside the manifest are rejected';[IO.File]::Delete((Join-Path $source 'unexpected.ps1'))
$expanded=Expand-VerifiedPackage $zip (Join-Path $test 'expanded') '0.16.0';Check ([IO.File]::Exists((Join-Path $expanded 'MainWindow.xaml'))) 'ZIP resources are extracted and verified in new workspace staging'
function New-MaliciousZip([string]$Name,[string[]]$Entries) {
 $path=Join-Path $test $Name;$a=[IO.Compression.ZipFile]::Open($path,[IO.Compression.ZipArchiveMode]::Create)
 try {foreach ($e in $Entries) {$entry=$a.CreateEntry($e);$s=$entry.Open();try {$s.WriteByte(65)} finally {$s.Dispose()}}} finally {$a.Dispose()};return $path
}
$evil=New-MaliciousZip evil.zip @('WinTune-VI-v0.16.0/../../escaped.txt');Reject {Expand-VerifiedPackage $evil (Join-Path $test 'evil-stage') '0.16.0'} 'Zip Slip is refused before creating the stage'
Check (-not (Test-Path (Join-Path $test 'evil-stage')) -and -not (Test-Path (Join-Path $test 'escaped.txt'))) 'Traversal writes no files outside staging'
$duplicate=New-MaliciousZip duplicate.zip @('WinTune-VI-v0.16.0/A.txt','WinTune-VI-v0.16.0/a.txt');Reject {Expand-VerifiedPackage $duplicate (Join-Path $test 'dupe-stage') '0.16.0'} 'Case-insensitive duplicate ZIP entries are refused'
$cancel=New-Object Threading.CancellationTokenSource;$cancel.Cancel();Reject {Expand-VerifiedPackage $zip (Join-Path $test 'cancel-stage') '0.16.0' $cancel} 'Canceled extraction does not activate a version';$cancel.Dispose()
# Mock the actual HttpClient transport: no socket, DNS or Internet connection.
Add-Type -ReferencedAssemblies System.Net.Http @'
using System;using System.Net;using System.Net.Http;using System.Threading;using System.Threading.Tasks;using System.Collections.Generic;
public class WinTuneFakeHttp:HttpMessageHandler {
 public static Queue<HttpResponseMessage> Responses=new Queue<HttpResponseMessage>();public static List<string> URLs=new List<string>();
 protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage r,CancellationToken t){URLs.Add(r.RequestUri.AbsoluteUri);if(Responses.Count==0)throw new HttpRequestException("fixture disconnect");return Task.FromResult(Responses.Dequeue());}
}
'@
function New-DistributionHttpHandler {return New-Object WinTuneFakeHttp}
function Response([int]$Code,[byte[]]$Data,[string]$Location='') {$r=New-Object Net.Http.HttpResponseMessage ([Net.HttpStatusCode]$Code);$r.Content=New-Object Net.Http.ByteArrayContent (,$Data);if ($Location) {$r.Headers.Location=[uri]$Location};[WinTuneFakeHttp]::Responses.Enqueue($r)}
Response 500 (Bytes 'retry');Response 200 (Bytes 'success');$data=Get-DistributionBytes 'https://api.github.com/fixture' 2048
Check ([Text.Encoding]::UTF8.GetString($data).Contains('success') -and [WinTuneFakeHttp]::URLs.Count -eq 2) 'Transient HTTP failure retries and succeeds through a mocked transport'
Response 403 (Bytes 'denied');$count=[WinTuneFakeHttp]::URLs.Count;Reject {Get-DistributionBytes 'https://api.github.com/fixture' 2048} 'HTTP permission/rate error is reported';Check ([WinTuneFakeHttp]::URLs.Count -eq $count+1) 'Permanent HTTP errors do not retry indefinitely'
Response 200 (New-Object byte[] 2000);Reject {Get-DistributionBytes 'https://api.github.com/fixture' 100} 'Oversize download is rejected'
for ($i=0;$i -lt 3;$i++) {Response 302 @() 'https://127.0.0.1/internal'}
Reject {Get-DistributionBytes 'https://github.com/fixture/download' 2048} 'Redirect cannot leave the GitHub allowlist'
Check (@([WinTuneFakeHttp]::URLs | Where-Object {$_ -match '127.0.0.1'}).Count -eq 0) 'No request is sent to the redirected internal host'
$assetPrefix='https://github.com/fixture/WinTune/releases/download/v0.16.0/'
$release=[pscustomobject]@{draft=$false;prerelease=$false;tag_name='v0.16.0';assets=@('release.json','release.sig',$m.Asset) | ForEach-Object {[pscustomobject]@{name=$_;browser_download_url=$assetPrefix+$_;state='uploaded'}}}
Response 200 (Bytes $release);Response 200 $payload;Response 200 $signature
$info=Get-DistributionUpdate $cfg '0.15.0';Check ($info.Status -eq 'Available') 'Update check verifies signed metadata without downloading ZIP'
Check (-not ([WinTuneFakeHttp]::URLs -contains ($assetPrefix+$m.Asset))) 'Checking never fetches or executes application assets'
$install=Join-Path $test 'installed';$count=[WinTuneFakeHttp]::URLs.Count;Reject {Install-DistributionUpdate $info $install $false $null $cfg} 'Unconfirmed update cannot download/install';Check ([WinTuneFakeHttp]::URLs.Count -eq $count) 'Cancel before download makes no request'
Response 200 (Bytes 'wrong ZIP');Reject {Install-DistributionUpdate $info $install $true $null $cfg} 'Incorrect ZIP checksum/size never activates';Check (-not (Test-Path (Join-Path $install 'current.txt'))) 'Failed validation leaves active version untouched'
Response 200 $zipBytes;$installed=Install-DistributionUpdate $info $install $true $null $cfg
Check ($installed.Status -eq 'Prepared' -and (Get-Content (Join-Path $install 'current.txt') -Raw).Trim() -eq $installed.Path) 'Verified update prepares a side-by-side version, never starts an EXE'
[IO.File]::WriteAllText((Join-Path $install 'current.txt'),$installed.Path,[Text.UTF8Encoding]::new($false))
Check ((Get-PreparedDistributionVersion $install '0.15.0') -eq '0.16.0') 'UTF-8 pointer without BOM supports Vietnamese installation paths'
Write-DistributionAtomic (Join-Path $install 'current.txt') $installed.Path
$beforePointer=Get-Content (Join-Path $install 'current.txt') -Raw;$mutated=$info.PSObject.Copy();$mutated.Url='https://github.com/other/repo/release.zip';Reject {Install-DistributionUpdate $mutated $install $true $null $cfg} 'Edited plan URL cannot override signed release identity'
Check ((Get-Content (Join-Path $install 'current.txt') -Raw) -ceq $beforePointer) 'Invalid subsequent request preserves active pointer'
Check ((Install-LocalDistribution $source $install $true).Status -eq 'Existing') 'Local install reuses a verified same/newer version'
Check ((Get-PreparedDistributionVersion $install '0.15.0') -eq '0.16.0') 'Prepared version prevents repeated downloads from the older running app'
Reject {Activate-DistributionPackage $source $install '0.15.0' $m.SHA256} 'An older version cannot replace an already prepared newer version'
Check ((Get-Content (Join-Path $install 'current.txt') -Raw) -ceq $beforePointer) 'Downgrade refusal preserves the current pointer'
$altered=$info.PSObject.Copy();$altered.Manifest=$info.Manifest.PSObject.Copy();$altered.Manifest.SHA256='0'*64
Reject {Install-DistributionUpdate $altered $install $true $null $cfg} 'Modified preview cannot change signed checksum'
$null=New-Item -ItemType Directory -Path (Join-Path $installed.Path 'simulation-data');[IO.File]::WriteAllText((Join-Path $installed.Path 'simulation-data/demo.json'),'fixture output');Test-PortableIntegrity $installed.Path '0.16.0'
Check $true 'Known demo output does not invalidate immutable application resources'
# Native environment/registry writers are replaced; no User/Machine PATH changes.
$script:FakeReg=[pscustomobject]@{Path='C:\Fixture';PathKind='ExpandString';PathExists=$true;AppExists=$false;AppTarget='';AppPath='';AppNames=@()};$script:RegWrites=0;$script:Refreshed=0;$script:FailApp=$false;$script:FailPath=$false
function Get-UserCommandRegistration {return $script:FakeReg.PSObject.Copy()}
function Set-UserCommandPath($Value,$Kind,$Exists=$true) {if($script:FailPath){$script:FailPath=$false;throw 'fixture PATH failure'};$script:RegWrites++;$script:FakeReg.Path=$Value;$script:FakeReg.PathKind=$Kind;$script:FakeReg.PathExists=$Exists}
function Set-UserCommandAppPath($Target,$Folder,$Remove=$false) {if ($script:FailApp) {throw 'fixture app path failure'};$script:RegWrites++;$script:FakeReg.AppExists=-not $Remove;$script:FakeReg.AppTarget=$Target;$script:FakeReg.AppPath=$Folder;$script:FakeReg.AppNames=if ($Remove) {@()} else {@('','Path')}}
function Get-CommandRegistrationUser {return 'Fixture-SID'}
function Notify-UserCommandEnvironment {$script:Refreshed++}
Reject {Register-WinTuneCommand $installed.Path $install $false} 'Command registration also requires confirmation';Check ($RegWrites -eq 0) 'Opening/preparing command registration writes no registry'
$r=Register-WinTuneCommand $installed.Path $install $true;Check ($r.Status -eq 'Registered' -and $FakeReg.Path.Contains('command') -and -not $FakeReg.AppExists -and (Test-Path (Join-Path $install 'command/wintune.cmd'))) 'Confirmed source registration targets only mocked User PATH and copies CMD/PowerShell entries'
$writes=$RegWrites;Check ((Register-WinTuneCommand $installed.Path $install $true).Status -eq 'NoOp' -and $RegWrites -eq $writes) 'Repeated registration is idempotent'
$FakeReg.Path+=';C:\NewExternalTool';$null=Unregister-WinTuneCommand $install $true;Check ($FakeReg.Path -eq 'C:\Fixture;C:\NewExternalTool' -and -not $FakeReg.AppExists) 'Unregister retains unrelated PATH changes and removes only owned registration'
Check (Test-Path $installed.Path) 'Unregister keeps app versions and user journals'
$FakeReg.AppExists=$true;$FakeReg.AppTarget='C:\Other\wintune.exe';$FakeReg.AppPath='C:\Other';$FakeReg.AppNames=@('','Path');Reject {Register-WinTuneCommand $installed.Path $install $true} 'Existing foreign wintune registration is not overwritten'
$FakeReg.AppExists=$false;$FakeReg.AppTarget='';$FakeReg.AppPath='';$FakeReg.AppNames=@();$script:FailPath=$true;$old=$FakeReg.Path
Reject {Register-WinTuneCommand $installed.Path $install $true} 'Mid-registration access failure is reported'
Check ($FakeReg.Path -eq $old -and (Get-Content (Join-Path $install 'command-registration.json') -Raw|ConvertFrom-Json).Status -eq 'RolledBack') 'Failed registration conditionally rolls back its PATH change'
$script:FailApp=$false;$null=Register-WinTuneCommand $installed.Path $install $true;$FakeReg.AppExists=$true;$FakeReg.AppTarget='C:\External\wintune.exe';$FakeReg.AppPath='C:\External';$FakeReg.AppNames=@('','Path');$null=Unregister-WinTuneCommand $install $true
Check ($FakeReg.AppExists -and $FakeReg.AppTarget -eq 'C:\External\wintune.exe') 'Source unregister preserves unrelated external App Paths'
$FakeReg.AppExists=$false;$FakeReg.AppTarget='';$FakeReg.AppPath='';$FakeReg.AppNames=@();$null=Register-WinTuneCommand $installed.Path $install $true
$j=Get-Content (Join-Path $install 'command-registration.json') -Raw|ConvertFrom-Json;$j.Status='Pending';Write-DistributionAtomic (Join-Path $install 'command-registration.json') ($j|ConvertTo-Json -Depth 5)
$FakeReg.Path+=';C:\ExternalChange';Reject {Repair-WinTuneCommandRegistration $install $true} 'Recovery refuses externally changed command registration'
$FakeReg.Path=$j.After;Reject {Repair-WinTuneCommandRegistration $install $false} 'Recovery also requires confirmation'
Check ((Repair-WinTuneCommandRegistration $install $true).Status -eq 'RolledBack' -and $FakeReg.Path -eq $j.Before.Path -and -not $FakeReg.AppExists) 'Owned pending registration can be repaired with conditional mock rollback'
$null=Register-WinTuneCommand $installed.Path $install $true;$script:FailPath=$true
Reject {Unregister-WinTuneCommand $install $true} 'Partial command removal is reported and retains a recovery receipt'
Check ((Get-Content (Join-Path $install 'command-registration.json') -Raw|ConvertFrom-Json).Status -eq 'PendingRemoval') 'Interrupted removal remains recoverable instead of silently claiming completion'
$script:FailApp=$false;Check ((Repair-WinTuneCommandRegistration $install $true).Status -eq 'Removed' -and -not $FakeReg.AppExists) 'Conditional recovery completes owned partial removal without deleting app data'
$legacyRoot=Join-Path $test 'legacy-install';$null=Complete-LegacyWinTuneCommandRegistration $installed.Path $legacyRoot $true
Check ($FakeReg.AppExists -and (Get-Content (Join-Path $legacyRoot 'command-registration.json') -Raw|ConvertFrom-Json).Schema -eq 1) 'Legacy fixture preserves the original EXE registration receipt format'
Reject {Register-WinTuneCommand $installed.Path $legacyRoot $true} 'Registered legacy command must be removed explicitly before migration'
Check ((Unregister-WinTuneCommand $legacyRoot $true).Status -eq 'Removed' -and -not $FakeReg.AppExists) 'New release can conditionally unregister an owned schema1 EXE command'
$null=Complete-LegacyWinTuneCommandRegistration $installed.Path $legacyRoot $true
$legacy=Get-Content (Join-Path $legacyRoot 'command-registration.json') -Raw|ConvertFrom-Json;$legacy.Status='Pending';Write-DistributionAtomic (Join-Path $legacyRoot 'command-registration.json') ($legacy|ConvertTo-Json -Depth 5)
Check ((Repair-WinTuneCommandRegistration $legacyRoot $true).Status -eq 'RolledBack' -and -not $FakeReg.AppExists) 'New release can repair an interrupted schema1 EXE registration'
$null=Register-WinTuneCommand $installed.Path $install $true;$cmd=Join-Path $install 'command/wintune.cmd';$originalCmd=[IO.File]::ReadAllBytes($cmd);[IO.File]::WriteAllText($cmd,'tampered local command');$beforeWrites=$RegWrites
Reject {Register-WinTuneCommand $installed.Path $install $true} 'Source registration refuses a changed existing command helper'
Check ($RegWrites -eq $beforeWrites) 'Changed helper causes no native registration changes';[IO.File]::WriteAllBytes($cmd,$originalCmd)
$null=Unregister-WinTuneCommand $install $true
$rsa.Dispose()
Write-Output "DISTRIBUTION TESTS PASSED: $pass; Internet and registry/environment changes mocked; filesystem fixtures remain inside workspace."
