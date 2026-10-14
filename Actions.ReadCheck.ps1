#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Core.ps1"
. "$PSScriptRoot/Actions.Core.ps1"
function Remove-ActionItem { throw 'Read-only audit blocks removals.' }
function Invoke-ActionPlan { throw 'Read-only audit blocks applying.' }
function Undo-StartupAction { throw 'Read-only audit blocks startup edits.' }
function Set-RegistryValue { throw 'Read-only audit blocks registry writes.' }
function Startup-Fingerprint {
    $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
    try {
        $rows=if ($null -eq $key) {@()} else {@($key.GetValueNames() | Sort-Object | ForEach-Object { [pscustomobject]@{Name=$_;Type=[string]$key.GetValueKind($_);Data=$key.GetValue($_,'',[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)} })}
        $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject @($rows) -Depth 6))
        $hash=[Security.Cryptography.SHA256]::Create()
        try {return [Convert]::ToBase64String($hash.ComputeHash($bytes))} finally {$hash.Dispose()}
    } finally {if ($null -ne $key) {$key.Dispose()}}
}
$root=Join-Path $PSScriptRoot ('.test-runs/actions-read-'+[guid]::NewGuid().ToString('N'))
Initialize-Actions $root $false ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
$before=Startup-Fingerprint
$apps=@(Get-ActionInventory Appx); $startup=@(Get-ActionInventory Startup)
if ((Startup-Fingerprint) -ne $before) {throw 'Startup changed externally during audit; investigate.'}
if (@(Get-ActionJournals).Count -ne 0) {throw 'Read-only inventory unexpectedly created a journal.'}
$result=[pscustomobject]@{AppCount=$apps.Count;AppNames=@($apps | ForEach-Object Name);StartupCount=$startup.Count;StartupNames=@($startup | ForEach-Object Name);StartupHashUnchanged=$true;MutationFunctionsBlocked=$true;NativeAppRemovalTested=$false;NativeStartupEditTested=$false}
$result | ConvertTo-Json -Depth 6 | Set-Content "$PSScriptRoot/evidence/actions-read-only.json" -Encoding UTF8
Write-Output "ACTIONS READ-ONLY CHECK PASSED: $($apps.Count) supported installed apps, $($startup.Count) supported Run entries; no removal, no edits, no journals."
