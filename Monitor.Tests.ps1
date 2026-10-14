#Requires -Version 5.1
# Pure calculations and mocked providers. No real hardware/system changes.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Monitor.Core.ps1"
$script:Pass=0
function Assert-Monitor([bool]$Ok,[string]$Name) {if (-not $Ok) {throw "MONITOR FAILED: $Name"};$script:Pass++;Write-Output "PASS: $Name"}
$a=[pscustomobject]@{Idle=100;Kernel=200;User=100}
$b=[pscustomobject]@{Idle=140;Kernel=270;User=130}
Assert-Monitor ((Get-MonitorCpuPercent $a $b) -eq 60) 'Kernel includes idle; total CPU is calculated from deltas'
Assert-Monitor ($null -eq (Get-MonitorCpuPercent $null $b)) 'First CPU sample is unavailable, not zero'
Assert-Monitor ($null -eq (Get-MonitorCpuPercent $a $a)) 'Zero interval is not a fabricated load'
Assert-Monitor ($null -eq (Get-MonitorCpuPercent $b $a)) 'Counter reset rejects invalid delta'
Assert-Monitor ($null -eq (Get-MonitorCpuPercent $a ([pscustomobject]@{Idle=900;Kernel=270;User=130}))) 'Inconsistent idle count rejected'
Assert-Monitor ((Get-MonitorCpuPercent $a ([pscustomobject]@{Idle=100;Kernel=300;User=100})) -eq 100) 'Fully busy CPU reports 100 percent'
Assert-Monitor ((Get-MonitorCpuPercent $a ([pscustomobject]@{Idle=200;Kernel=300;User=100})) -eq 0) 'Measured idle CPU can report zero'
Assert-Monitor ((Get-MonitorRate 100 1100 2) -eq 500) 'Rates use actual elapsed seconds'
Assert-Monitor ($null -eq (Get-MonitorRate 100 0 2)) 'Reset network counters are unavailable'
Assert-Monitor ($null -eq (Get-MonitorRate 100 1100 0)) 'No divide by zero'
Assert-Monitor ((Format-MonitorSize (8GB)).Contains('8') -and (Format-MonitorSize (8GB)).Contains('GB')) '64-bit VRAM capacity above four GB is preserved'
Assert-Monitor ((Format-MonitorSize $null) -eq 'Chưa đọc được') 'Unknown capacity remains unknown'
$luid='luid_0x00000000_0x12345678'
$rows=@([pscustomobject]@{Name="pid_1_${luid}_phys_0_eng_0_engtype_3D";UtilizationPercentage=30},[pscustomobject]@{Name="pid_2_${luid}_phys_0_eng_0_engtype_3D";UtilizationPercentage=20},[pscustomobject]@{Name="pid_1_${luid}_phys_0_eng_1_engtype_Copy";UtilizationPercentage=40})
Assert-Monitor ((Get-MonitorGpuPercent $rows $luid) -eq 50) 'GPU aggregates processes per engine and chooses busiest engine'
Assert-Monitor ($null -eq (Get-MonitorGpuPercent $rows 'luid_0x00000000_0x99999999')) 'Other GPUs do not leak into selected GPU measurement'
$rows[0].UtilizationPercentage=95
Assert-Monitor ((Get-MonitorGpuPercent $rows $luid) -eq 100) 'Concurrent GPU counter rounding is bounded'
Assert-Monitor ($null -eq (Get-MonitorGpuPercent @() $luid)) 'Missing GPU counters are not zero'
$t=[DateTime]::UtcNow
$previous=[pscustomobject]@{NetworkTimestamp=$t;Network=@{a=[pscustomobject]@{Received=10;Sent=20}}}
$next=[pscustomobject]@{NetworkTimestamp=$t.AddSeconds(2);Network=@{a=[pscustomobject]@{Received=1010;Sent=620};b=[pscustomobject]@{Received=9000;Sent=9000}}}
$rates=Get-MonitorNetworkRates $previous $next
Assert-Monitor ($rates.Received -eq 500 -and $rates.Sent -eq 300) 'New interfaces ignored until there is a baseline'
Assert-Monitor ($null -eq (Get-MonitorNetworkRates $null $next).Received) 'Network first sample remains unavailable'
function Initialize-MonitorNative { }
function Get-CimInstance {throw 'Mocked WMI unavailable'}
function Get-PhysicalDisk {throw 'Mocked storage provider unavailable'}
# Native methods may be unavailable as well; Get-MonitorHardware must preserve
# individual errors instead of claiming success or crashing the page.
$info=Get-MonitorHardware
Assert-Monitor ($info.CpuName -eq 'Chưa đọc được bộ xử lý' -and $info.Disks.Count -eq 0) 'CIM failure still returns partial hardware details'
Assert-Monitor ($info.Issues.Count -ge 6 -and $info.GpuBytes -eq $null) 'Unavailable hardware providers have explicit reasons'
$script:Disposed=0;$script:ProcessReads=0
function New-TestProcess([int]$Id,[double]$Bytes) {
    $p=[pscustomobject]@{ProcessName="Fixture-$Id";Id=$Id;WorkingSet64=$Bytes}
    $p | Add-Member ScriptMethod Dispose {$script:Disposed++};return $p
}
$script:TestProcesses=@(foreach ($n in 1..12) {New-TestProcess $n ($n*1MB)})
$exited=New-TestProcess 99 0;$exited.PSObject.Properties.Remove('WorkingSet64');$exited | Add-Member ScriptProperty WorkingSet64 {throw 'Process exited'};$script:TestProcesses+=$exited
function Read-MonitorProcesses {$script:ProcessReads++;$script:TestProcesses}
$p=Get-MonitorProcesses
Assert-Monitor ($p.ProcessCount -eq 13 -and $p.Processes.Count -eq 10 -and $p.Processes[0].Id -eq 12 -and $p.Processes[9].Id -eq 3) 'Process sample takes ten highest working sets from actual enumerated fixtures'
Assert-Monitor ($Disposed -eq 13 -and $p.Issues.Count -eq 1) 'Exited/inaccessible process is skipped, reported and all handles are disposed'
$script:TestProcesses=@();$p=Get-MonitorProcesses
Assert-Monitor ($p.ProcessCount -eq 0 -and $p.Processes.Count -eq 0 -and $p.Issues.Count -eq 0) 'Successful empty process enumeration differs from failure'
function Read-MonitorProcesses {throw 'Mocked process enumeration access failure'}
$p=Get-MonitorProcesses
Assert-Monitor ($null -eq $p.ProcessCount -and $p.Issues[0].Contains('access failure')) 'Failed process reader reports unknown instead of fabricated zero processes'
function Read-MonitorProcesses {throw 'Process reader must not be called by slow sensor sampling'}
$p=Get-MonitorSample -SkipProcesses
Assert-Monitor ($null -eq $p.ProcessCount -and $p.Processes.Count -eq 0 -and -not (($p.Issues -join ' ').Contains('must not be called'))) 'Sensor-only sampling does not duplicate the independent process read'
Write-Output "MONITOR TESTS PASSED: $script:Pass; calculation and failure providers only, no system mutations."
