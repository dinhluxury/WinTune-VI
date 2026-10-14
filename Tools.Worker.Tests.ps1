#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Tools.Core.ps1"
. "$PSScriptRoot/Tools.UI.ps1"
. "$PSScriptRoot/Actions.Core.ps1"
$root=Join-Path $PSScriptRoot ('.test-runs/worker-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$user=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
Initialize-Tools $root $true $user
$script:ToolJob=$null;$pass=0
function Check([bool]$Ok,[string]$Text) {if (-not $Ok) {throw "WORKER FAILED: $Text"};$script:pass++;Write-Output "PASS WORKER: $Text"}
function Run([string]$Id,$P,[bool]$Confirmed) {
 $job=Start-ToolJob $Id $P $Confirmed
 if (-not $job.Process.WaitForExit(15000)) {throw 'Simulated worker timed out; do not terminate a real operation.'}
 return (Get-ToolJobResult $job)
}
$p=[pscustomobject]@{Query='7zip';PackageId='7zip.7zip';PackageIds=@('7zip.7zip','VideoLAN.VLC');SourceAgreed=$false;PackageAgreed=$false;SilentAgreed=$false;Files=@($ToolMockFiles);Guid='';Before=''}
foreach ($id in @('sfc','dismcheck','dismscan','dismrestore','diskcheck','wingetinstall','tempscan','tempdelete','restorepoint')) {
 $r=Run $id $p $true
 Check ($r.Status -eq 'Completed' -and $r.Mode -eq 'Simulation') "Separate worker $id completes using a simulated handler"
}
$r=Run sfc $p $false;Check ($r.Status -eq 'Failed') 'Unconfirmed repair worker executes no command'
$r=Run 'unknown-handler' $p $true;Check ($r.Status -eq 'Failed') 'Worker rejects unregistered handler'
$actionRoot=Join-Path $root 'actions';Initialize-Actions $actionRoot $true $user
$selected=@(Get-ActionInventory Appx)[0]
$plan=@(New-ActionPlan Appx @($selected.Id))
$r=Run actionsapply ([pscustomobject]@{ActionRoot=$actionRoot;Rows=$plan}) $true
Initialize-Actions $actionRoot $true $user
Check ($r.Status -eq 'Completed' -and @(Get-ActionInventory Appx).Count -eq 29 -and (Get-ActionJournals).Journal.Status -eq 'Completed') 'Appx worker persists exact simulated package removal and history'
$r=Run actionsapply ([pscustomobject]@{ActionRoot=$actionRoot;Rows=@(New-ActionPlan Startup @('Discord'))}) $true
$r=Run startupundo ([pscustomobject]@{ActionRoot=$actionRoot}) $true
Initialize-Actions $actionRoot $true $user
Check ($r.Status -eq 'Completed' -and @(Get-ActionInventory Startup).Count -eq 1) 'Startup worker undo reloads its persistent backup'
$savedStart=${function:Start-Process}
function Start-Process {throw 'Mocked UAC refusal — no process started'}
$script:ToolSimulation=$false;$rejected=$false
try {$null=Start-ToolJob sfc $p $true $true} catch {$rejected=$true}
Check $rejected 'Declined elevation/start failure never starts an operation'
$cancel=@(Get-ChildItem $ToolRoot -Recurse -Filter result.json | ForEach-Object {Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json} | Where-Object Status -EQ Cancelled)
Check ($cancel.Count -eq 1) 'Cancelled UAC/start request has a persistent honest result'
if ($null -ne $savedStart) {Set-Item Function:Start-Process $savedStart} else {Remove-Item Function:Start-Process}
$script:ToolSimulation=$true
Set-Content -LiteralPath (Join-Path $script:ToolJob.Path 'result.json') -Value '{broken' -Encoding UTF8
Check ((Get-ToolJobResult $script:ToolJob).Status -eq 'Failed') 'Corrupt result is reported as a failure instead of crashing UI or claiming success'
Write-Output "WORKER TESTS PASSED: $pass; executing requests Simulation; elevation refusal mocked; no native mutations."
