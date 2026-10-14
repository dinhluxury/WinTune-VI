#Requires -Version 5.1
# Read-only audit. Never invokes the production writer.
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Core.ps1"
$cv=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Initialize-WinTune "$PSScriptRoot/features.json" "$PSScriptRoot/.test-runs/real-read" 'read-only-audit' ([int]$cv.CurrentBuild)
function Set-RegistryValue { throw 'Writes are forbidden in the read-only audit.' }
$states=@()
foreach ($f in @($Features | Where-Object Kind -eq Registry)) {
    $status=Get-FeatureState $f
    foreach ($c in $f.Changes) {
        $v=Read-RegistryValue $c
        $states+=[pscustomobject]@{Feature=$f.Id;Path=$c.Path;Name=$c.Name;Exists=$v.Exists;Value=$v.Value;Status=$status}
    }
}
$before=$states | ConvertTo-Json -Depth 6
$plan=@(New-ChangePlan @($Features | Where-Object Kind -eq Registry | ForEach-Object Id))
$after=@()
foreach ($f in @($Features | Where-Object Kind -eq Registry)) {
    $status=Get-FeatureState $f
    foreach ($c in $f.Changes) {
        $v=Read-RegistryValue $c
        $after+=[pscustomobject]@{Feature=$f.Id;Path=$c.Path;Name=$c.Name;Exists=$v.Exists;Value=$v.Value;Status=$status}
    }
}
if (($after | ConvertTo-Json -Depth 6) -cne $before) { throw 'External state changed during read-only audit; investigate.' }
if (@(Get-Journals).Count -ne 0) { throw 'Read-only preview created history unexpectedly.' }
$states | ConvertTo-Json -Depth 6 | Set-Content "$PSScriptRoot/evidence/real-read-snapshot.json" -Encoding UTF8
Write-Output "REAL READ CHECK PASSED: $($states.Count) registry values read, $($plan.Count) proposed changes, zero writes, zero journals. Not an apply/undo integration test."
