#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Tools.Core.ps1";. "$PSScriptRoot/Tools.UI.ps1";. "$PSScriptRoot/WizTree.Core.ps1";. "$PSScriptRoot/WizTree.Launch.ps1"
$pass=0
function Check([bool]$Ok,[string]$Name) {if (-not $Ok) {throw "WIZTREE LAUNCH FAILED: $Name"};$script:pass++;Write-Output "PASS WIZTREE LAUNCH: $Name"}
function Reject([scriptblock]$Work,[string]$Name) {$failed=$false;try {& $Work | Out-Null} catch {$failed=$true};Check $failed $Name}
$root=Join-Path $PSScriptRoot ('.test-runs/wiztree-direct-'+[guid]::NewGuid().ToString('N'));$user=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
Initialize-Tools $root $true $user;$script:ToolJob=$null;$script:IsSimulation=$true;$script:WriteBlocked=$false
function Run([bool]$Confirmed) {$job=Start-ToolJob 'wiztreeopen' ([pscustomobject]@{}) $Confirmed;if (-not $job.Process.WaitForExit(15000)) {throw 'Simulation worker timeout'};$result=Get-ToolJobResult $job;Complete-ToolJob $job;return $result}
$r=Run $false;Check ($r.Status -eq 'Failed' -and -not (Get-WizTreeInstallation).Installed) 'Unconfirmed job cannot install or open WizTree'
$r=Run $true
Check ($r.Status -eq 'Completed' -and $r.Mode -eq 'Simulation' -and $r.Result.Installed -and $r.Result.Drive -eq 'C:' -and $r.Result.ScanMode -eq 'DirectDrive') 'One confirmed job prepares the real C drive rather than a CSV import'
Check (-not $r.Result.Launched -and -not $r.Result.PSObject.Properties['ReportPath']) 'Simulation cannot start the app or report a fabricated completed scan'
Check (@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.csv').Count -eq 0) 'Automatic opening creates no disk report CSV'
$receipt=Get-Item -LiteralPath (Join-Path $ToolRoot 'simulation-wiztree.json');$installedWhen=$receipt.LastWriteTimeUtc
$r=Run $true
Check ($r.Status -eq 'Completed' -and (Get-Item -LiteralPath $receipt.FullName).LastWriteTimeUtc -eq $installedWhen) 'Subsequent opening reuses the installed WizTree'
$job=Start-ToolJob 'wiztreeopen' ([pscustomobject]@{MockDelayMs=1200}) $true
[IO.File]::WriteAllText((Join-Path $job.Path 'cancel.open'),'cancel');$null=$job.Process.WaitForExit(15000);$r=Get-ToolJobResult $job;Complete-ToolJob $job
Check ($r.Status -eq 'Failed' -and $r.Message.Contains('hủy')) 'Cancellation before handoff starts no WizTree process'
$arguments=@(Get-WizTreeLaunchArguments 'c:')
Check ($arguments.Count -eq 2 -and $arguments[0] -ceq 'C:' -and $arguments[1] -eq '/admin=1' -and -not (($arguments -join ' ') -match 'csv|export')) 'Launch arguments name the actual drive with native admin scanning and no export switch'
Reject {Get-WizTreeLaunchArguments 'C:\Data\latest.csv'} 'Regression: a CSV path cannot replace the drive argument'
Reject {Start-WizTreeApplication 'C:\Simulation\WizTree64.exe' 'C:\Data\latest.csv'} 'The actual launcher also refuses the old report handoff'
Reject {Get-WizTreeLaunchArguments 'C: /export=data.csv'} 'Extra arguments cannot be injected through a drive name'
Check ((Select-WizTreeInitialDrive @('A:','D:','C:') 'D:') -eq 'C:') 'C is preferred even when another drive appears first'
Check ((Select-WizTreeInitialDrive @('D:','E:') 'E:') -eq 'E:') 'A PC without C falls back to its ready Windows drive'
Check ((Select-WizTreeInitialDrive @('D:') 'E:') -eq 'D:') 'A remaining ready local drive can be used as fallback'
Reject {Select-WizTreeInitialDrive @() 'C:'} 'No ready drive is an error rather than a fictitious scan'
# Drive selection and opening seams only; no real app or installer is called.
function Install-WizTree([bool]$Confirmed) {return [pscustomobject]@{Installed=$true;Path='fixture';Version='fixture'}}
function Get-WizTreeReadyDrives {return @('C:','D:')}
function Start-WizTreeApplication([string]$Path,[string]$Drive) {$script:OpenedDrive=$Drive;return $true}
$script:ToolSimulation=$false;$jobFolder=Join-Path $root 'native-fixture';$null=New-Item -ItemType Directory -Path $jobFolder;$script:ToolStatusPath=Join-Path $jobFolder 'status.json'
$r=Invoke-WizTreeOpen $true
Check ($r.Launched -and $OpenedDrive -ceq 'C:' -and $r.ScanMode -eq 'DirectDrive') 'Native flow hands C directly to the GUI launcher without claiming the scan has completed'
Write-Output "WIZTREE LAUNCH TESTS PASSED: $pass; simulated workers and mocked native launch only."
