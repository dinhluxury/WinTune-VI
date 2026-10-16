#Requires -Version 5.1
# All Windows mutations are replaced by in-memory adapters.
$ErrorActionPreference='Stop'
. "$PSScriptRoot/FullTweaks.Core.ps1"
. "$PSScriptRoot/FullTweaks.Native.ps1"
$pass=0;$fail=0
function Check([bool]$Ok,[string]$Name) {if($Ok){$script:pass++;"PASS AUDIT: $Name"}else{$script:fail++;"FAIL AUDIT: $Name"}}
function Reject([scriptblock]$Code) {try{& $Code|Out-Null;return $false}catch{return $true}}
$base=Join-Path $PSScriptRoot ('.test-runs/audit-'+[guid]::NewGuid().ToString('N').Substring(0,8))
Initialize-FullTweaks $base $true 26300
$rows=@(New-FullPlan @('WPFToggleNumLock') @{})
$script:FullFailAfter=1
Check (Reject {Invoke-FullPlan $rows $true}) 'Injected failure leaves recovery journal'
$entry=@(Get-FullJournals)[0];$originalHash=(Get-FileHash $entry.Path).Hash
$null=Undo-FullSelection @('WPFToggleLongPaths') $true
Check ((Get-FileHash $entry.Path).Hash -ceq $originalHash) 'Unrelated undo does not rewrite pending journal'
Check ((Get-FullJournals)[0].Data.Status -eq 'Pending') 'Unrelated undo cannot unlock interrupted batch'
$script:FullFailAfter=-1
Check (Reject {Invoke-FullPlan @(New-FullPlan @('WPFToggleLongPaths') @{}) $true}) 'New apply remains blocked until recovery'
$null=Undo-FullSelection @('WPFToggleNumLock') $true
Check ((Get-FullJournals)[0].Data.Status -eq 'Undone') 'Correct recovery still succeeds'

# A failure before an irreversible native write still has an unchanged Before
# snapshot. It must be recoverable without ever executing an uninstall/undo.
Initialize-FullTweaks (Join-Path $base 'native-unchanged') $true 26300
$copilotId=@($FullCatalog | Where-Object Handler -eq 'Copilot')[0].Id
$nativeRows=@(New-FullPlan @($copilotId) @{})
$script:FullFailAfter=@($nativeRows | Where-Object Kind -ne 'Native').Count
Check (Reject {Invoke-FullPlan $nativeRows $true}) 'Irreversible native failure before write is recorded'
$script:FullFailAfter=-1
$null=Undo-FullSelection @($copilotId) $true
Check ((Get-FullJournals)[0].Data.Status -eq 'Undone') 'Unchanged irreversible resource can recover its interrupted batch'
Check (-not (Reject {Invoke-FullPlan @(New-FullPlan @('WPFToggleLongPaths') @{}) $true})) 'Recovered native pre-write failure no longer blocks unrelated apply'

# A changed irreversible resource is not reported as restored. Keep the batch
# locked when completion cannot be independently established.
Initialize-FullTweaks (Join-Path $base 'native-partial') $true 26300
$nativeRows=@(New-FullPlan @($copilotId) @{})
$script:FullFailAfter=@($nativeRows | Where-Object Kind -ne 'Native').Count
$null=Reject {Invoke-FullPlan $nativeRows $true}
$script:FullFailAfter=-1
$script:FullMemory['Native:'+$copilotId]=[pscustomobject]@{Handler='Copilot';PartiallyChanged=$true}
$null=Undo-FullSelection @($copilotId) $true
$nativeJournal=@(Get-FullJournals)[0].Data
Check ($nativeJournal.Status -eq 'Pending' -and @($nativeJournal.Rows | Where-Object { $_.Kind -eq 'Native' -and $_.State -eq 'Failed' }).Count -eq 1) 'Changed irreversible failure remains unresolved instead of falsely restored'
Check (Reject {Invoke-FullPlan @(New-FullPlan @('WPFToggleLongPaths') @{}) $true}) 'Unknown irreversible partial failure still blocks further apply'

# O&O and interactive Disk Cleanup expose only descriptive markers. Equality
# of those markers does not establish that the external tool changed nothing.
Initialize-FullTweaks (Join-Path $base 'native-opaque') $true 26300
$script:FullMemory['Native:WPFOOSUbutton']=[pscustomobject]@{External='constant descriptive marker'}
$opaqueRows=@(New-FullPlan @('WPFOOSUbutton') @{})
$script:FullFailAfter=0
$null=Reject {Invoke-FullPlan $opaqueRows $true}
$script:FullFailAfter=-1
$opaqueUndo=Undo-FullSelection @('WPFOOSUbutton') $true
$opaqueJournal=@(Get-FullJournals)[0].Data
Check ($opaqueJournal.Status -eq 'Pending' -and $opaqueJournal.Rows[0].State -eq 'Failed') 'Opaque external-tool markers never prove that changes were restored'
Check ($opaqueUndo.Notes.Count -gt 0 -and $FullMockWrites -eq 0) 'Opaque external-tool recovery explains its limit and performs zero writes'

$savedUser=$script:FullUser;$script:FullUser='Audit-'+[guid]::NewGuid().ToString('N')
$mutexName='Local\WinTuneVI-Full-'+$script:FullUser
$keepAlive=New-Object Threading.Mutex($false,$mutexName)
$abandon=Join-Path $base 'abandon.ps1'
[IO.File]::WriteAllText($abandon,('param($Name) $m=New-Object Threading.Mutex($false,$Name);$null=$m.WaitOne();exit 0'),[Text.UTF8Encoding]::new($true))
try {
    & (Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe') -NoProfile -ExecutionPolicy Bypass -File $abandon $mutexName
    $recovered=$null
    try {$recovered=Enter-FullOperationLock;Check ($null -ne $recovered) 'Worker can acquire mutex abandoned by a crashed fixture process'} finally {if ($recovered) {Exit-FullOperationLock $recovered}}
} finally {$keepAlive.Dispose();$script:FullUser=$savedUser}

# Never invoke the old native tree writer: it calls Windows directly.
$safe=(Get-Command Set-FullTree).ScriptBlock.ToString().Contains('Get-FullBase') -and (Get-Command Write-FullNative).ScriptBlock.ToString().Contains('(Get-FullBase ''HKCU'').DeleteSubKeyTree')
Check $safe 'Explorer tree uses mockable bounded registry adapter'
if($safe){
    $script:FakeTrees=@{};$script:Deletes=0
    $fake=[pscustomobject]@{}
    $fake|Add-Member ScriptMethod DeleteSubKeyTree {param($path,$missing) $script:Deletes++;foreach($k in @($script:FakeTrees.Keys)){if($k -eq $path -or $k.StartsWith($path+'\')){$script:FakeTrees.Remove($k)}}}
    $fake|Add-Member ScriptMethod CreateSubKey {param($path)
        if(-not $script:FakeTrees.ContainsKey($path)){$script:FakeTrees[$path]=@{}}
        $key=[pscustomobject]@{Path=$path}
        $key|Add-Member ScriptMethod Dispose {}
        $key|Add-Member ScriptMethod SetValue {param($name,$value,$type) $script:FakeTrees[$this.Path][$name]=[pscustomobject]@{Value=$value;Type=[string]$type}}
        return $key
    }
    function Get-FullBase([string]$Hive){if($Hive -cne 'HKCU'){throw 'Native hive forbidden in fixture'};return $fake}
    $shell='Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\'
    $f=@($FullCatalog|Where-Object Handler -eq FolderDiscovery)[0]
    $errorText=''
    try{Write-FullNative $f @{} @{} $false}catch{$errorText=$_.Exception.Message}
    Check (-not $errorText -and $FakeTrees.ContainsKey($shell+'Bags\AllFolders\Shell')) 'FolderDiscovery writes requested value without missing Type error'
    if(-not $errorText){Check ($FakeTrees[$shell+'Bags\AllFolders\Shell']['FolderType'].Type -eq 'String') 'FolderType is REG_SZ'}
    $tree=[pscustomobject]@{Exists=$true;Values=@([pscustomobject]@{Name='empty';Type='String';Value=''},[pscustomobject]@{Name='binary';Type='Binary';Value='AAH/'});Children=@([pscustomobject]@{Name='child';Data=[pscustomobject]@{Exists=$true;Values=@([pscustomobject]@{Name='n';Type='DWord';Value=42});Children=@()}})}
    $errorText='';try{Set-FullTree ($shell+'Bags') $tree}catch{$errorText=$_.Exception.Message}
    Check (-not $errorText) 'Restore Explorer tree preserves typed values and child keys'
    if(-not $errorText){Check ($FakeTrees[$shell+'Bags']['empty'].Value -ceq '' -and $FakeTrees[$shell+'Bags\child']['n'].Value -eq 42) 'Restored values match original fixture'}
    $count=$Deletes
    Check (Reject {Set-FullTree ($shell+'BagsOther') $tree}) 'Sibling prefix is outside allowed Explorer trees'
    $tree.Children[0].Name='bad\child'
    Check (Reject {Set-FullTree ($shell+'Bags') $tree}) 'Malformed child rejected before deleting original tree'
    Check ($Deletes -eq $count) 'Rejected trees perform zero deletions'
    $script:FullSimulation=$false
    $unsupported=[pscustomobject]@{Exists=$true;Values=@([pscustomobject]@{Name='unsupported';Type='None';Value=0});Children=@()}
    Check (Reject {Get-FullNativeTarget $f @{} ([pscustomobject]@{Bags=$unsupported;BagMRU=$unsupported})}) 'Explorer snapshot unsupported by undo is rejected before native apply'
    Check ($Deletes -eq $count) 'Unsupported snapshot does not delete live Explorer layout'
    $script:FullSimulation=$true
    $script:ForeignDeletes=0
    $foreignKey=[pscustomobject]@{ValueCount=2;SubKeyCount=0}
    $foreignKey|Add-Member ScriptMethod GetValueNames {return @('owned','external')}
    $foreignKey|Add-Member ScriptMethod DeleteValue {param($name,$missing) $script:ForeignDeletes++}
    $foreignKey|Add-Member ScriptMethod Dispose {}
    $foreignBase=[pscustomobject]@{}
    $foreignBase|Add-Member ScriptMethod OpenSubKey {param($path,$write) return $foreignKey}
    function Get-FullBase([string]$Hive){return $foreignBase}
    Check (Reject {Set-FullRegistry ([pscustomobject]@{Hive='HKCU';Path='fixture';Name='owned';Type='String'}) ([pscustomobject]@{Exists=$false;KeyExisted=$false;Type='String';Value=$null})}) 'Undo refuses a newly created key containing foreign values'
    Check ($ForeignDeletes -eq 0) 'Foreign key content is checked before deleting the owned value'
    $foreignKey|Add-Member ScriptMethod GetValueKind {param($name) return [Microsoft.Win32.RegistryValueKind]::DWord}
    $foreignKey|Add-Member ScriptMethod GetValue {param($name,$fallback,$options) return 7}
    $sameValue=Read-FullRegistry ([pscustomobject]@{Hive='HKCU';Path='fixture';Name='OWNED';Type='DWord'})
    Check ($sameValue.Exists -and $sameValue.Value -eq 7) 'Registry value names ignore casing so existing values are backed up instead of treated as absent'
}
"AUDIT REGRESSION: $pass passed; $fail failed; no native Windows writes."
if($fail){exit 1}
