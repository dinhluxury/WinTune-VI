#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/FullTweaks.Core.ps1"
. "$PSScriptRoot/FullTweaks.Native.ps1"
$script:Pass=0;$script:Base=Join-Path $PSScriptRoot ('.test-runs/full-tests-'+[guid]::NewGuid().ToString('N'))
function Check([bool]$Ok,[string]$Name) {if (-not $Ok) {throw ('FULL TEST FAILED: '+$Name)};$script:Pass++;Write-Output ('PASS: '+$Name)}
function Fresh {Initialize-FullTweaks (Join-Path $script:Base ([guid]::NewGuid().ToString('N'))) $true 26300}
function Rejected([scriptblock]$Action) {try {& $Action | Out-Null;return $false} catch {return $true}}
Fresh
$source=Get-Content "$PSScriptRoot/sources/review-20261014/winutil/config__tweaks.json.txt" -Raw -Encoding UTF8 | ConvertFrom-Json
Check (@($FullCatalog | Where-Object {$_.Id -cin $source.PSObject.Properties.Name}).Count -eq 67) 'All 67 WinUtil screenshot configuration IDs remain present'
Check (@($FullCatalog | Where-Object {-not $_.Title -or -not $_.Explanation -or -not $_.Impact -or -not $_.Undo}).Count -eq 0) 'Every feature explains purpose, impact and undo in Vietnamese'
foreach ($id in @($FullCatalog.Id)) {
    Fresh;$f=Get-FullFeature $id
    if ($f.Handler -eq 'Route') {Check ($f.Route -eq 'Restore') ('Explicit route: '+$id);continue}
    for($i=0;$i -lt $f.Changes.Count;$i++){if(-not $f.Changes[$i].Exists){$row=[pscustomobject]@{Id=$id;Index=$i;Kind='Registry';Option='Apply'};$script:FullMemory[(Get-FullMemoryKey $row)]=[pscustomobject]@{Exists=$true;KeyExisted=$true;Type=$f.Changes[$i].Type;Value='Simulation original'}}}
    $rows=@(New-FullPlan @($id) @{});Check ($rows.Count -gt 0 -and $FullMockWrites -eq 0) ('Preview performs no writes: '+$id)
    $journal=Invoke-FullPlan $rows $true
    Check ($journal.Status -eq 'Applied' -and @($journal.Rows | Where-Object State -ne Applied).Count -eq 0) ('Simulation executes every registered resource: '+$id)
    $result=Undo-FullSelection @($id) $true
    $undoable=$f.Handler -notin @('Widgets','Copilot','Edge','OneDrive','WindowsAI','BitLocker','OOSU','UltimateRemove','Temp','DiskCleanup')
    if ($undoable) {Check (@((Get-FullJournals)[0].Data.Rows | Where-Object State -ne Restored).Count -eq 0) ('Restores each original state: '+$id)} else {Check ($result.Notes.Count -gt 0) ('Irreversible work never promises automatic recovery: '+$id)}
}
Fresh;$rows=@(New-FullPlan @('WPFToggleLongPaths') @{})
Check (Rejected {Invoke-FullPlan $rows $false}) 'Unconfirmed plan cannot write'
Check ($FullMockWrites -eq 0) 'Confirmation failure writes nothing'
$rows[0].Target.Value=999
Check (Rejected {Invoke-FullPlan $rows $true}) 'Tampered target rejected before backup/write'
Check ($FullMockWrites -eq 0) 'Unlisted value cannot reach Windows adapter'
Fresh
Check (Rejected {New-FullPlan @('WPFTweaksIPv46','WPFTweaksDisableIPv6') @{}}) 'Conflicting IPv4/IPv6 policies cannot be applied together'
Check (Rejected {Get-FullFeature 'unknown'}) 'Unknown native handler rejected'
Fresh;$rows=@(New-FullPlan @('WPFToggleNumLock') @{});$script:FullMemory[(Get-FullMemoryKey $rows[0])]=[pscustomobject]@{Exists=$true;Type='String';Value='2147483650'}
Check (Rejected {Invoke-FullPlan $rows $true}) 'Changed state after preview blocks the entire batch'
Fresh;$rows=@(New-FullPlan @('WPFToggleNumLock') @{});$script:FullFailAfter=1
Check (Rejected {Invoke-FullPlan $rows $true}) 'Mid-batch failure retains a pending recovery journal'
Check ((Get-FullJournals)[0].Data.Status -eq 'Pending') 'Partial change is never labelled fully applied'
$script:FullFailAfter=-1;$result=Undo-FullSelection @('WPFToggleNumLock') $true
Check ((Get-FullJournals)[0].Data.Status -eq 'Undone') 'Recovery handles an interrupted batch in reverse order'
Fresh;$rows=@(New-FullPlan @('WPFToggleLongPaths') @{});$null=Invoke-FullPlan $rows $true
$script:FullMemory[(Get-FullMemoryKey $rows[0])]=[pscustomobject]@{Exists=$true;Type='DWord';Value=7}
Check (Rejected {Undo-FullSelection @('WPFToggleLongPaths') $true}) 'Undo preserves later changes outside WinTune'
Fresh;$rows=@(New-FullPlan @('WPFToggleNumLock') @{});$null=Invoke-FullPlan $rows $true;$memory=$FullMemory;$root=$FullRoot
Initialize-FullTweaks $root $true 26300;$script:FullMemory=$memory;$null=Undo-FullSelection @('WPFToggleNumLock') $true
Check ((Get-FullJournals)[0].Data.Status -eq 'Undone') 'Original string types and HKU scope survive journal reload'
Fresh;$rows=@(New-FullPlan @('WPFToggleDarkMode') @{});$null=Invoke-FullPlan $rows $true
Check ('WPFToggleDarkMode' -cin @(Get-FullAppliedIds)) 'Select applied uses real value matches, not a selection flag'
Fresh;$path=Join-Path $FullRoot 'payload.dat';Write-FullData ([pscustomobject]@{Value=1}) $path;$bytes=[IO.File]::ReadAllBytes($path);$bytes[$bytes.Length-1]=$bytes[$bytes.Length-1] -bxor 1;[IO.File]::WriteAllBytes($path,$bytes)
Check (Rejected {Read-FullData $path}) 'Corrupt encrypted requests are rejected'
Check (Rejected {Write-FullData @{} (Join-Path $script:Base 'outside.dat')}) 'Journal path cannot escape its owned root'
$native=[IO.File]::ReadAllText("$PSScriptRoot/FullTweaks.Native.ps1")
Check (-not $native.Contains('Set-MpPreference') -and -not $native.Contains('Add-MpPreference') -and -not $native.Contains('--force-uninstall') -and -not $native.Contains('/ResetBase') -and -not $native.Contains('Remove-AppxPackage -AllUsers')) 'No Defender weakening, forced Edge deletion, ResetBase or cross-user app removal'
Check ((Get-FullFeature WPFTweaksUTC).Changes[0].Type -eq 'QWord' -and (Get-FullFeature WPFToggleStickyKeys).Changes[0].Type -eq 'String') 'UTC and accessibility values use the proper registry types'
Check (@((Get-FullFeature WPFToggleMouseAcceleration).Changes | Where-Object Type -ne String).Count -eq 0) 'Mouse settings preserve REG_SZ types rather than copying incorrect DWORD examples'
Check (@(Get-FullDnsProviders).Count -eq 10) 'All screenshot DNS provider categories are available'
Write-Output "FULL TWEAKS TESTS PASSED: $Pass; all Windows-changing actions simulated."
