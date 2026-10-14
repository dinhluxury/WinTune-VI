#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Tools.Core.ps1"
$root=Join-Path $PSScriptRoot ('.test-runs/read-tools-'+[guid]::NewGuid().ToString('N').Substring(0,8))
Initialize-Tools $root $false ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
# Hard stop guards: this audit must never mutate the OS, even after edits.
function Set-PowerState {throw 'Read audit: native power writes forbidden.'}
function Remove-TempHandle {throw 'Read audit: native deletion forbidden.'}
function Clear-RecycleBin {throw 'Read audit: recycle deletion forbidden.'}
function Checkpoint-Computer {throw 'Read audit: Restore Point forbidden.'}
$base=$env:WINDIR
$before=Invoke-ToolNative (Join-Path $base 'System32/powercfg.exe') @('/getactivescheme')
$overview=Get-SystemOverview
$version=try {Invoke-ToolNative (Get-WinGetPath) @('--version')} catch {[pscustomobject]@{Error=$_.Exception.Message}}
$plans=Get-PowerList
$after=Invoke-ToolNative (Join-Path $base 'System32/powercfg.exe') @('/getactivescheme')
$summary=[pscustomobject]@{Mode='Native read-only';Hardware=$overview;WinGetVersion=$version;PowerPlanCount=@($plans.Plans).Count;ActivePowerPlanUnchanged=$before.Output -ceq $after.Output;NativeMutationTested=$false;NoPowerBackupCreated=@(Get-ChildItem $root -Filter 'power-*.dat').Count -eq 0}
$summary | ConvertTo-Json -Depth 12 | Set-Content "$PSScriptRoot/evidence/tools-read-only.json" -Encoding UTF8
if (-not $summary.ActivePowerPlanUnchanged -or -not $summary.NoPowerBackupCreated) {throw 'Read audit changed state.'}
Write-Output 'TOOLS READ AUDIT PASSED: Windows hardware/security data, WinGet version, power plan list; no native mutations.'
