#Requires -Version 5.1
# Read-only integration audit. Does not change registry, apps, policies or services.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Monitor.Core.ps1"
Initialize-MonitorNative
$watch=[Diagnostics.Stopwatch]::StartNew()
$hardware=Get-MonitorHardware
$samples=@()
foreach ($n in 1..3) {$samples+=Get-MonitorSample $hardware.GpuLuid;if ($n -lt 3) {Start-Sleep -Seconds 2}}
$cpu=Get-MonitorCpuPercent $samples[1].Times $samples[2].Times
$network=Get-MonitorNetworkRates $samples[1] $samples[2]
if ($hardware.CpuName -eq 'Chưa đọc được bộ xử lý' -or $null -eq $samples[2].Memory) {throw 'Native CPU/RAM reader unavailable; see individual hardware errors.'}
if ($null -eq $cpu -or $cpu -lt 0 -or $cpu -gt 100) {throw 'CPU delta audit failed.'}
if ($samples[2].Memory.Available -gt $samples[2].Memory.Total) {throw 'Invalid native memory capacity.'}
if ($samples[2].Timestamp -le $samples[1].Timestamp) {throw 'Samples are not advancing.'}
$report=[pscustomobject]@{Mode='ReadOnly';Hardware=$hardware;Samples=$samples;CpuPercent=$cpu;Network=$network;ElapsedSeconds=$watch.Elapsed.TotalSeconds;Checked=[DateTime]::UtcNow;SystemMutations=0;Limit='Native monitoring readers only; no optimization or system-changing test is executed.'}
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath "$PSScriptRoot/evidence/monitor-read-only.json" -Encoding UTF8
Write-Output "READ ONLY MONITOR PASSED: $($hardware.CpuName); RAM $(Format-MonitorSize $hardware.InstalledBytes); GPU $($hardware.GpuName) / $(Format-MonitorSize $hardware.GpuBytes); CPU sample $cpu%; $($samples[2].ProcessCount) processes; no system mutations."
