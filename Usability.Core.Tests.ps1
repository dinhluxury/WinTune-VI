#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Core.ps1";. "$PSScriptRoot/Simulation.ps1";. "$PSScriptRoot/RepairSummary.Core.ps1";. "$PSScriptRoot/Logs.Core.ps1"
$pass=0
function Check([bool]$Ok,[string]$Name) {if (-not $Ok) {throw "USABILITY FAILED: $Name"};$script:pass++;Write-Output "PASS: $Name"}
function Reject([scriptblock]$Work,[string]$Name) {$failed=$false;try {& $Work | Out-Null} catch {$failed=$true};Check $failed $Name}
$root=Join-Path $PSScriptRoot ('.test-runs/usability-'+[guid]::NewGuid().ToString('N'))
Initialize-WinTune "$PSScriptRoot/features.json" $root 'mock-user' 26300
$c=(Get-Feature classicmenu).Changes[0];$rows=@(New-ChangePlan @('classicmenu'))
Check ($rows.Count -eq 1 -and $rows[0].Target -is [string] -and $rows[0].Target -ceq '' -and -not $rows[0].KeyExisted) 'Classic menu preserves empty REG_SZ and absent original key in preview'
$null=Invoke-ChangePlan $rows
Check ((Read-RegistryValue $c).Exists -and (Read-RegistryValue $c).Value -is [string]) 'String application stays a string in isolated provider'
$null=Undo-LatestJournal
Check (-not (Read-RegistryValue $c).Exists) 'String undo restores absence without a fabricated DWORD'
$rows=@(New-ChangePlan @('notepadai'))
Check ($rows[0].Hive -eq 'HKLM' -and $rows[0].Name -eq 'DisableAIFeatures') 'Notepad AI plan explicitly records machine scope'
$rows[0].Hive='HKCU';Reject {Invoke-ChangePlan $rows} 'Changed backup scope is rejected before writing'
$rows=@(New-ChangePlan @('classicmenu'));$rows[0].Value='C:\untrusted.dll';Reject {Invoke-ChangePlan $rows} 'String backup cannot inject a different COM registration'
Reject {New-ChangePlan @('copilotapp')} 'App removal cannot silently join registry profiles'
Check (-not (Test-SameState ([pscustomobject]@{Exists=$true;Value=''}) ([pscustomobject]@{Exists=$true;Value=0}))) 'Empty string and DWORD zero never compare as the same state'
Check (-not (Test-SameState ([pscustomobject]@{Exists=$false;Value='';KeyExisted=$true}) ([pscustomobject]@{Exists=$false;Value='';KeyExisted=$false}))) 'New external menu key between preview and apply is a conflict even without a default value'
function Result([string]$Id,[int]$Code,[string]$Output) {return [pscustomobject]@{Id=$Id;Mode='Native';Status='Completed';Message='fixture';Result=[pscustomobject]@{ExitCode=$Code;Output=$Output}}}
Check ((Get-RepairConclusion (Result sfc 0 'Windows Resource Protection did not find any integrity violations.')).StartsWith('Không phát hiện')) 'SFC clean conclusion requires the explicit Windows message'
Check ((Get-RepairConclusion (Result sfc 0 'Windows Resource Protection found corrupt files and successfully repaired them.')).Contains('đã sửa')) 'SFC repair conclusion reflects the Windows report'
Check ((Get-RepairConclusion (Result sfc 0 'unknown localized output')).Contains('chưa đủ')) 'Unknown localized successful exit never fabricates a clean SFC result'
Check ((Get-RepairConclusion (Result dismscan 0 'The component store is repairable.')).Contains('phát hiện lỗi')) 'DISM repairable is translated as needing repair'
Check ((Get-RepairConclusion (Result dismcheck 0 'No component store corruption detected.')).Contains('không phát hiện')) 'DISM clean report is recognized'
Check ((Get-RepairConclusion (Result dismrestore 5 'Access denied')).Contains('Chưa kiểm tra')) 'Failed repair never says the machine is healthy'
Check ((Get-RepairConclusion (Result diskcheck 0 'fixture')).Contains('không đánh giá toàn bộ')) 'Disk read result explains its practical limits'
$r=Result sfc 0 'clean';$r.Mode='Simulation';Check ((Get-RepairConclusion $r).StartsWith('MÔ PHỎNG')) 'Mock repair is not labeled as native success'
$event=[pscustomobject]@{ProviderName='Microsoft-Windows-Kernel-Power';Id=41;TimeCreated=(Get-Date);Level=1;LogName='System';Message='fixture'}
$summary=Convert-WindowsEventSummary $event
Check ($summary.Meaning.Contains('đột ngột') -and $summary.Advice.Contains('không xác định nguyên nhân')) 'Kernel Power 41 explains the observation without diagnosing PSU failure'
$event.ProviderName='Unknown vendor';$event.Id=987
Check ((Convert-WindowsEventSummary $event).Meaning.Contains('Unknown vendor')) 'Unknown events retain their actual source and conservative explanation'
Check ((Get-WindowsLogSummary $true).Rows.Count -eq 0) 'Demo log reader never fabricates native event entries'
. "$PSScriptRoot/Tools.Core.ps1"
$script:ToolSimulation=$false;$script:ReadClasses=@()
function Read-ToolCim($Class) {$script:ReadClasses+=$Class;return @()}
function Get-Tpm {throw 'mock permission denied'}
function Confirm-SecureBootUEFI {return $false}
function Get-MpComputerStatus {return [pscustomobject]@{AntivirusEnabled=$true;RealTimeProtectionEnabled=$true;AMServiceEnabled=$true}}
function Get-NetFirewallProfile {return [pscustomobject]@{Name='Public';Enabled=$true}}
$d=Get-SystemOverview -DiagnosticsOnly
Check ($ReadClasses.Count -eq 1 -and $ReadClasses[0] -eq 'Win32_PnPEntity') 'Security click only reads the requested data, not duplicate full hardware inventory'
Check ($d.TPM -is [string] -and $d.'Secure Boot' -eq $false -and $d.Defender.RealTimeProtectionEnabled) 'Permission error and measured disabled state remain distinct while other sections succeed'
Check ($SimWriteCount -eq 2) 'All added readers and conclusions use zero additional system mutations'
Write-Output "USABILITY CORE TESTS PASSED: $pass; isolated registry and mocked security/log/repair providers only."
