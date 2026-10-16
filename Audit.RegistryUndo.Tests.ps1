#Requires -Version 5.1
# Production registry readers/writers are exercised only through fake RegistryKey APIs.
$ErrorActionPreference='Stop'
. "$PSScriptRoot/FullTweaks.Core.ps1"
. "$PSScriptRoot/FullTweaks.Native.ps1"
$script:RegistryFixture=@{};$script:RegistryDeletes=@();$script:RegistryKeyDeletes=@();$script:RegistryTreeDeletes=0;$script:Pass=0
$root=Join-Path $PSScriptRoot ('.test-runs/registry-undo-'+[guid]::NewGuid().ToString('N').Substring(0,8))
function Check([bool]$Ok,[string]$Name) {if (-not $Ok) {throw ('REGISTRY UNDO FAILED: '+$Name)};$script:Pass++;Write-Output ('PASS REGISTRY UNDO: '+$Name)}
function Reject([scriptblock]$Work) {try {& $Work | Out-Null;return $false} catch {return $true}}
function New-FixtureRegistryKey([string]$Path) {
    $key=[pscustomobject]@{Path=$Path}
    $key|Add-Member ScriptProperty ValueCount {$script:RegistryFixture[$this.Path].Values.Count}
    $key|Add-Member ScriptProperty SubKeyCount {$script:RegistryFixture[$this.Path].Children}
    $key|Add-Member ScriptMethod GetValueNames {return @($script:RegistryFixture[$this.Path].Values.Keys)}
    $key|Add-Member ScriptMethod GetSubKeyNames {if($script:RegistryFixture[$this.Path].PSObject.Properties['ChildNames']){return @($script:RegistryFixture[$this.Path].ChildNames)};return @()}
    $key|Add-Member ScriptMethod GetAccessControl {$acl=[Security.AccessControl.RegistrySecurity]::new();$acl.SetSecurityDescriptorSddlForm('D:(A;;KA;;;BA)',[Security.AccessControl.AccessControlSections]::Access);return $acl}
    $key|Add-Member ScriptMethod GetValueKind {param($name) return [Microsoft.Win32.RegistryValueKind]$script:RegistryFixture[$this.Path].Values[$name].Type}
    $key|Add-Member ScriptMethod GetValue {param($name,$default,$options) return $script:RegistryFixture[$this.Path].Values[$name].Value}
    $key|Add-Member ScriptMethod SetValue {param($name,$value,$kind) $script:RegistryFixture[$this.Path].Values[$name]=[pscustomobject]@{Type=[string]$kind;Value=$value}}
    $key|Add-Member ScriptMethod DeleteValue {param($name,$missing) $script:RegistryDeletes+=@($name);$script:RegistryFixture[$this.Path].Values.Remove($name)}
    $key|Add-Member ScriptMethod Dispose {}
    return $key
}
function Get-FullBase([string]$Hive) {
    if ($Hive -notin @('HKLM','HKCU')) {throw 'Unlisted hive in registry fixture'}
    $base=[pscustomobject]@{Hive=$Hive}
    $base|Add-Member ScriptMethod OpenSubKey {param($path,$write) $id=$this.Hive+'|'+$path;if($script:RegistryFixture.ContainsKey($id)){return New-FixtureRegistryKey $id};return $null}
    $base|Add-Member ScriptMethod CreateSubKey {param($path) $id=$this.Hive+'|'+$path;if(-not $script:RegistryFixture.ContainsKey($id)){$script:RegistryFixture[$id]=[pscustomobject]@{Values=@{};Children=0}};return New-FixtureRegistryKey $id}
    $base|Add-Member ScriptMethod DeleteSubKey {param($path,$missing) $id=$this.Hive+'|'+$path;if($script:RegistryFixture[$id].Values.Count -or $script:RegistryFixture[$id].Children){throw 'Fixture refuses nonempty key deletion'};$script:RegistryKeyDeletes+=@($id);$script:RegistryFixture.Remove($id)}
    $base|Add-Member ScriptMethod DeleteSubKeyTree {param($path,$missing) $script:RegistryTreeDeletes++;throw 'Tree deletion is forbidden in this fixture'}
    return $base
}
function New-RegistryUndoFixture([bool]$Existing=$false) {
    $script:RegistryFixture=@{};$script:RegistryDeletes=@();$script:RegistryKeyDeletes=@()
    Initialize-FullTweaks (Join-Path $root ([guid]::NewGuid().ToString('N').Substring(0,8))) $false 26300
    $feature=Get-FullFeature WPFTweaksActivity
    $script:FixturePath=$feature.Changes[0].Hive+'|'+$feature.Changes[0].Path
    if ($Existing) {$script:RegistryFixture[$FixturePath]=[pscustomobject]@{Values=@{foreign=[pscustomobject]@{Type='String';Value='keep'}};Children=0}}
    $rows=@(New-FullPlan @($feature.Id) @{})
    foreach ($row in $rows) {Write-FullResource $row $row.Target;$row.After=$row.Target;$row.State='Applied'}
    $journal=[pscustomobject]@{Version=1;User=$FullUser;Mode='Native';Created=(Get-Date).ToString('o');Status='Applied';Rows=$rows}
    Write-FullData $journal (Join-Path $FullRoot 'batch-fixture.dat')
    return $rows
}
$rows=@(New-RegistryUndoFixture)
Check ($rows.Count -eq 3 -and @($rows | Where-Object {$_.Before.KeyExisted -or $_.Before.Exists}).Count -eq 0) 'All three policy values share an originally absent key'
$null=Undo-FullSelection @('WPFTweaksActivity') $true
Check (-not $RegistryFixture.ContainsKey($FixturePath) -and $RegistryDeletes.Count -eq 3 -and $RegistryKeyDeletes.Count -eq 1) 'Undo removes each exact owned value and deletes the key only after the final sibling'
Check ((Get-FullJournals)[0].Data.Status -eq 'Undone') 'Production undo completes the multi-value journal'

$rows=@(New-RegistryUndoFixture)
$RegistryFixture[$FixturePath].Values.foreign=[pscustomobject]@{Type='String';Value='keep'}
Check (Reject {Undo-FullSelection @('WPFTweaksActivity') $true}) 'A foreign value rejects undo before any owned value is deleted'
Check ($RegistryDeletes.Count -eq 0 -and $RegistryFixture[$FixturePath].Values.Count -eq 4) 'Foreign and owned values all survive the rejected undo'

$rows=@(New-RegistryUndoFixture)
# Change a recorded sibling by its real catalog name, not a generated value name.
$name=(Get-FullChanges (Get-FullFeature $rows[0].Id) $rows[0].Option)[$rows[0].Index].Name
$RegistryFixture[$FixturePath].Values[$name]=[pscustomobject]@{Type='DWord';Value=99}
Check (Reject {Undo-FullSelection @('WPFTweaksActivity') $true}) 'A same-batch sibling changed after apply is never accepted merely by name'
Check ($RegistryDeletes.Count -eq 0 -and $RegistryFixture[$FixturePath].Values[$name].Value -eq 99) 'Changed sibling blocks the first undo write'

$rows=@(New-RegistryUndoFixture)
$RegistryFixture[$FixturePath].Children=1
Check (Reject {Undo-FullSelection @('WPFTweaksActivity') $true}) 'A child key still rejects new-key undo'
Check ($RegistryDeletes.Count -eq 0 -and $RegistryKeyDeletes.Count -eq 0) 'Child-key conflict performs no deletion'

$rows=@(New-RegistryUndoFixture)
$last=$rows[-1]
Check (Reject {Write-FullResource $last $last.Before $true @($last)}) 'Matching sibling values outside the supplied journal context are not trusted'
Check ($RegistryDeletes.Count -eq 0) 'Insufficient ownership context performs no deletion'

$rows=@(New-RegistryUndoFixture $true)
$null=Undo-FullSelection @('WPFTweaksActivity') $true
Check ($RegistryFixture[$FixturePath].Values.Count -eq 1 -and $RegistryFixture[$FixturePath].Values.foreign.Value -ceq 'keep' -and $RegistryKeyDeletes.Count -eq 0) 'Undo of values in a pre-existing key preserves its foreign contents and the key'

$script:RegistryFixture=@{};$script:RegistryDeletes=@();$script:RegistryKeyDeletes=@()
Initialize-FullTweaks (Join-Path $root 'unsupported-kind') $false 26300
$f=Get-FullFeature WPFToggleLongPaths;$c=$f.Changes[0];$id=$c.Hive+'|'+$c.Path
$RegistryFixture[$id]=[pscustomobject]@{Values=@{};Children=0}
$RegistryFixture[$id].Values[$c.Name]=[pscustomobject]@{Type='None';Value=[byte[]](1,2)}
Check (Reject {New-FullPlan @($f.Id) @{}}) 'Preview rejects an original REG_NONE value that the undo writer cannot restore'
Check ($RegistryDeletes.Count -eq 0 -and $RegistryFixture[$id].Values[$c.Name].Type -eq 'None') 'Unsupported original value remains byte-for-byte untouched'

$treeFeature=@($FullCatalog|Where-Object {@($_.Changes|Where-Object Type -eq 'Tree').Count})[0]
$treeChange=@($treeFeature.Changes|Where-Object Type -eq 'Tree')[0];$treeId=$treeChange.Hive+'|'+$treeChange.Path
$RegistryFixture[$treeId]=[pscustomobject]@{Values=@{};Children=1;ChildNames=@('child')}
$RegistryFixture[$treeId+'\child']=[pscustomobject]@{Values=@{original=[pscustomobject]@{Type='None';Value=[byte[]](3,4)}};Children=0}
$snapshot=Read-FullRegistryTree $treeChange.Hive $treeChange.Path
Check (Reject {New-FullPlan @($treeFeature.Id) @{}}) 'Preview recursively rejects a tree containing an unsupported child value kind'
Check (Reject {Set-FullRegistryTree $treeChange.Hive $treeChange.Path $snapshot}) 'A legacy tree snapshot is validated before the writer deletes its live root'
Check ($RegistryTreeDeletes -eq 0 -and $RegistryFixture[$treeId+'\child'].Values.original.Type -eq 'None') 'Rejected tree snapshots perform zero tree deletions and preserve child data'
$snapshot.Value.Children[0].Data.Value.Values[0].Data.Type='Binary'
$snapshot.Value.Children[0].Data.Value.Values[0].Data.Value=[Convert]::ToBase64String([byte[]](3,4))
Check (-not (Reject {Assert-FullRegistrySnapshot $snapshot})) 'Supported typed child values remain eligible for tree restoration'

Write-Output "REGISTRY UNDO TESTS PASSED: $Pass; real readers, writers and undo; every RegistryKey call mocked."
