#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Tools.Core.ps1";. "$PSScriptRoot/Tools.UI.ps1";. "$PSScriptRoot/WizTree.Core.ps1"
$pass=0
function Check([bool]$Ok,[string]$Name) {if (-not $Ok) {throw "WIZTREE FAILED: $Name"};$script:pass++;Write-Output "PASS WIZTREE: $Name"}
function Reject([scriptblock]$Work,[string]$Name) {$failed=$false;try {& $Work | Out-Null} catch {$failed=$true};Check $failed $Name}
$root=Join-Path $PSScriptRoot ('.test-runs/wiztree-'+[guid]::NewGuid().ToString('N'));$user=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
Initialize-Tools $root $true $user;$script:ToolJob=$null;$script:IsSimulation=$true;$script:WriteBlocked=$false
Check (-not (Get-WizTreeInstallation).Installed) 'Initial simulated detection does not install anything'
Reject {Install-WizTree $false} 'Installation needs an authorized disk-usage action'
$args=@(Get-WizTreeInstallArguments)
Check (($args -join ' ') -match '--id AntibodySoftware.WizTree --exact --source winget' -and '--no-upgrade' -in $args -and '--allow-reboot' -notin $args -and '--ignore-security-hash' -notin $args -and '--override' -notin $args -and '--force' -notin $args) 'Installer uses the fixed exact package with normal hash checks and no reboot or upgrade'
function Run([string]$Id,[bool]$Confirmed) {$job=Start-ToolJob $Id ([pscustomobject]@{}) $Confirmed;if (-not $job.Process.WaitForExit(15000)) {throw 'Simulation worker timeout'};$result=Get-ToolJobResult $job;Complete-ToolJob $job;return $result}
$r=Run 'wiztreecheck' $false;Check ($r.Status -eq 'Completed' -and -not $r.Result.Installed) 'Detection worker only reads simulated installation state'
$r=Run 'wiztreeinstall' $false;Check ($r.Status -eq 'Failed') 'Unconfirmed worker cannot install'
$r=Run 'wiztreeinstall' $true;Check ($r.Status -eq 'Completed' -and $r.Mode -eq 'Simulation' -and $r.Result.Installed) 'Confirmed simulated installation returns a verified candidate to open'
Check (-not (Start-WizTreeApplication $r.Result.Path)) 'Simulation cannot launch an actual third-party executable'
$r=Run 'wiztreecheck' $false;Check ($r.Result.Installed) 'Next invocation detects the existing installation instead of reinstalling'
# Verify native trust and failure handling with fake metadata and native-call seams.
$exe=Join-Path $root 'WizTree64.exe';[IO.File]::WriteAllText($exe,'fixture, not executable')
function Read-WizTreeExecutableMetadata($Path) {return [pscustomobject]@{Signature=[pscustomobject]@{Status='Valid';SignerCertificate=[pscustomobject]@{Subject='CN=Antibody Software Limited, O=Antibody Software Limited, C=NZ'}};Product='WizTree';Version='fixture'}}
Check ((Assert-WizTreeExecutable $exe).Path -eq $exe) 'Verified Antibody publisher and product are accepted'
function Read-WizTreeExecutableMetadata($Path) {return [pscustomobject]@{Signature=[pscustomobject]@{Status='Valid';SignerCertificate=[pscustomobject]@{Subject='CN=Unrelated vendor, O=Unrelated vendor'}};Product='WizTree';Version='fixture'}}
Reject {Assert-WizTreeExecutable $exe} 'A valid signature belonging to another publisher is refused'
Reject {Assert-WizTreeExecutable '\\server\share\WizTree64.exe'} 'Network executable paths are refused'
$script:ToolSimulation=$false;$script:InstallCalls=0
function Get-WizTreeInstallation {return [pscustomobject]@{Installed=$false;Path='';Version=''}}
function Get-WizTreeWinGet {return 'mock-winget'}
function Invoke-ToolNative($Exe,$Arguments) {$script:InstallCalls++;return [pscustomobject]@{ExitCode=5;Output='fixture: access denied';Error='fixture only'}}
Reject {Install-WizTree $true} 'Failed installer never proceeds to a launch'
function Invoke-ToolNative($Exe,$Arguments) {$script:InstallCalls++;return [pscustomobject]@{ExitCode=0;Output='fixture';Error=''}}
Reject {Install-WizTree $true} 'Successful exit without a verified installed executable is not claimed as success'
Check ($InstallCalls -eq 2) 'Native command tests use mocked seams only'
Write-Output "WIZTREE TESTS PASSED: $pass; simulated workers and mocked native calls, no installation or executable launch."
