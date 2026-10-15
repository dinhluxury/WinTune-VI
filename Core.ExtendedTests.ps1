#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Core.ps1"
. "$PSScriptRoot/Simulation.ps1"
. "$PSScriptRoot/Theme.Core.ps1"
$parent=Join-Path $PSScriptRoot '.test-runs'
$root=Join-Path $parent ('extended-'+[guid]::NewGuid().ToString('N'))
$script:Pass=0
function Assert([bool]$ok,[string]$text) { if (-not $ok) { throw "FAILED: $text" }; $script:Pass++; Write-Output "PASS: $text" }
function Reject([scriptblock]$action,[string]$text) { $failed=$false; try { & $action | Out-Null } catch { $failed=$true }; Assert $failed $text }
function Fresh {
    $dir=Join-Path $root ([guid]::NewGuid().ToString('N'))
    Initialize-WinTune "$PSScriptRoot/features.json" $dir 'test' 26300
    $script:Memory=@{}; $script:SimWriteCount=0
    $script:WriteCalls=0; $script:FailAt=0; $script:Mode='normal'; $script:ExternalChange=$null
}
function Set-RegistryValue($Change,[bool]$Exists,$Value) {
    $script:WriteCalls++
    if ($script:WriteCalls -eq $script:FailAt -and $script:Mode -ne 'after') { throw 'Injected failure before write' }
    if ($script:Mode -eq 'drop') { return }
    $k=Get-SimKey $Change
    if ($Exists) { $script:Memory[$k]=$Value } else { $script:Memory.Remove($k) }
    if ($script:WriteCalls -eq $script:FailAt -and $script:Mode -eq 'after') { throw 'Injected failure after write' }
    if ($null -ne $script:ExternalChange) { $script:Memory[(Get-SimKey $script:ExternalChange)]=9; $script:ExternalChange=$null }
}
# Fresh must not replace the instrumented writer with Simulation's normal writer.
$writer=${function:Set-RegistryValue}
$journalWriter=${function:Save-Journal}
try {
    Fresh; Set-Item Function:Set-RegistryValue $writer
    $preference=Join-Path $DataRoot 'ui-settings.json'
    Save-ThemePreference $preference Dark
    Assert (@(Get-Journals).Count -eq 0 -and @(New-ChangePlan @('ads')).Count -eq 1) 'Saved appearance is not misread as a Windows backup'
    $null=Invoke-ChangePlan @(New-ChangePlan @('ads'))
    Save-ThemePreference $preference Light
    Assert (@(Get-Journals).Count -eq 1 -and (Get-LatestJournal).Journal.Status -eq 'Applied') 'Appearance and real format backup coexist without deleting either'
    Initialize-WinTune "$PSScriptRoot/features.json" $DataRoot 'test' 26300
    Assert ((Get-LatestJournal).Journal.Rows[0].Feature -eq 'ads' -and (Read-ThemePreference $preference).Mode -eq 'Light') 'Restart retains backup and appearance independently'
    $null=Undo-LatestJournal
    Assert ($Memory.Count -eq 0 -and (Get-Journals)[0].Journal.Status -eq 'Undone') 'Undo works with saved appearance in the same directory'
    [IO.File]::WriteAllText($preference,'{')
    Assert (@(Get-Journals).Count -eq 1 -and [IO.File]::ReadAllText($preference) -eq '{') 'Damaged appearance is kept for theme error handling and is not a damaged backup'
    $unknown=Join-Path $DataRoot 'unknown.json';[IO.File]::WriteAllText($unknown,'{')
    Reject {Get-Journals} 'Unknown corrupt JSON still locks backup reading'
    Reject {New-ChangePlan @('dvr')} 'Corrupt backup still blocks new changes'
    Assert ([IO.File]::ReadAllText($unknown) -eq '{') 'Invalid backup is preserved for recovery'
    Fresh; Set-Item Function:Set-RegistryValue $writer
    Assert ($Features.Count -eq 44) 'PowerShell 5.1 catalog has 44 entries after redundant Settings shortcuts were removed'
    Assert ((Get-Feature 'ads').Title -is [string]) 'Get-Feature returns one feature'
    Assert ((Get-FeatureState (Get-Feature 'ads')) -like 'Chưa đặt giá trị*') 'Missing value is distinct from disabled'
    Reject { New-ChangePlan @('startupsettings') } 'Removed Settings shortcut cannot be queued'
    Assert (@(New-ChangePlan @('ads','ads')).Count -eq 1) 'Duplicate selected IDs produce one change'
    Reject { Invoke-ChangePlan @() } 'Empty plan rejected'
    Assert (@(Get-Journals).Count -eq 0) 'Empty plan never creates a batch'
    $rows=@(New-ChangePlan @('ads')); $rows[0].Target=8
    Reject { Invoke-ChangePlan $rows } 'Tampered target rejected before writing'
    Assert ($WriteCalls -eq 0) 'Invalid plan never writes'
    $rows=@(New-ChangePlan @('ads')); $rows[0].Index=0.5
    Reject { Invoke-ChangePlan $rows } 'Fractional registry index rejected'
    $rows=@(New-ChangePlan @('ads')); $rows[0].Path='Software\Other'
    Reject { Invoke-ChangePlan $rows } 'Changed path rejected'

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $all=@($Features | Where-Object Kind -eq Registry | ForEach-Object Id)
    $rows=@(New-ChangePlan $all)
    Assert ($rows.Count -gt 20 -and $WriteCalls -eq 0) 'Preview all registry features is read-only'
    $null=Invoke-ChangePlan $rows
    Assert (@(Get-Journals).Count -eq 1 -and (Get-LatestJournal).Journal.Version -eq 3) 'Full simulated batch persists version 3 history'
    foreach ($f in @($Features | Where-Object Kind -eq Registry)) { Assert ((Get-FeatureState $f) -eq 'Đã đặt giá trị yêu cầu') "Verified simulated state: $($f.Id)" }
    $dir=$DataRoot; Initialize-WinTune "$PSScriptRoot/features.json" $dir 'test' 26300
    Assert ((Get-LatestJournal).Journal.Status -eq 'Applied') 'History survives engine reinitialization'
    Assert (@(New-ChangePlan $all).Count -eq 0) 'All applied items produce no-op'
    $null=Undo-LatestJournal
    Assert ($Memory.Count -eq 0 -and @((Get-Journals)[0].Journal.Rows | Where-Object UndoState -ne Restored).Count -eq 0) 'Full undo removes only previously missing values and verifies each row'

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $script:FailAt=2
    Reject { Invoke-ChangePlan @(New-ChangePlan @('dvr','ads')) } 'Failure stops partial batch'
    $j=(Get-LatestJournal).Journal
    Assert ($j.Rows[0].State -eq 'Applied' -and $j.Rows[1].State -eq 'Failed' -and $j.Rows[2].State -eq 'Skipped') 'History distinguishes success, attempted failure, and not attempted'
    $script:Memory[(Get-SimKey (Get-Feature 'ads').Changes[0])]=9
    $script:FailAt=0; $null=Undo-LatestJournal
    Assert ($Memory[(Get-SimKey (Get-Feature 'ads').Changes[0])] -eq 9) 'Undo does not touch skipped values changed by another program'

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $script:FailAt=1; $script:Mode='after'
    Reject { Invoke-ChangePlan @(New-ChangePlan @('ads')) } 'Failure after physical write retains recovery record'
    Assert ($Memory.Count -eq 1) 'Injected error actually occurs after simulated write'
    $script:FailAt=0; $script:Mode='normal'; $null=Undo-LatestJournal
    Assert ($Memory.Count -eq 0) 'Undo recovers a write that threw after mutation'

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $script:Mode='drop'
    Reject { Invoke-ChangePlan @(New-ChangePlan @('ads')) } 'Silent write failure detected by read-back'
    Assert ((Get-LatestJournal).Journal.Status -eq 'Pending') 'Read-back mismatch is not success'
    $script:Mode='normal'; $null=Undo-LatestJournal
    Assert ($WriteCalls -eq 1) 'Undo already-original value does not write or create keys'

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $null=Invoke-ChangePlan @(New-ChangePlan @('dvr'))
    $script:FailAt=$WriteCalls+2
    Reject { Undo-LatestJournal } 'Mid-undo failure retains retryable history'
    Assert ((Get-LatestJournal).Journal.Rows[0].UndoState -eq 'Restored') 'Successful undo row checkpoint persists'
    $script:FailAt=0; $null=Undo-LatestJournal
    Assert ($Memory.Count -eq 0) 'Retry completes partial undo'

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $null=Invoke-ChangePlan @(New-ChangePlan @('dvr'))
    $script:FailAt=$WriteCalls+2; Reject { Undo-LatestJournal } 'Prepare restored-row conflict scenario'
    $script:Memory[(Get-SimKey (Get-Feature 'dvr').Changes[0])]=0
    $script:FailAt=0
    Reject { Undo-LatestJournal } 'External edit to a restored row blocks retry even if it equals target'

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $script:ExternalChange=(Get-Feature 'ads').Changes[0]
    Reject { Invoke-ChangePlan @(New-ChangePlan @('dvr','ads')) } 'Changes between writes detected'
    Assert ((Get-LatestJournal).Journal.Rows[2].State -eq 'Skipped') 'Conflicting unattempted value is not recorded as applied'
    $null=Undo-LatestJournal
    Assert ($Memory[(Get-SimKey (Get-Feature 'ads').Changes[0])] -eq 9) 'Recovery preserves concurrent external modification'

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $null=Invoke-ChangePlan @(New-ChangePlan @('ads'))
    $latest=Get-LatestJournal; $latest.Journal.Rows[0].Exists='false'; Save-Journal $latest.Journal $latest.Path
    Reject { Get-Journals } 'String boolean in persisted backup rejected'

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $script:Build=19041; Reject { New-ChangePlan @('alttab') } 'Alt-Tab browser integration requires Windows 10 20H2 or later'
    $script:Build=19045; Reject { New-ChangePlan @('align') } 'Windows 10 cannot apply Windows 11 alignment'
    Reject { New-ChangePlan @('widgets') } 'Windows 10 cannot apply the Windows 11 Widgets button setting'
    $script:Build=22621; Reject { New-ChangePlan @('endtask') } 'End task requires supported Windows build'

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $rows=@(New-ChangePlan @('ads'))
    function Save-Journal { throw 'Injected backup failure before writing' }
    Reject { Invoke-ChangePlan $rows } 'Backup failure prevents applying settings'
    Assert ($WriteCalls -eq 0 -and $Memory.Count -eq 0) 'No simulated writes happen without a saved backup'
    Set-Item Function:Save-Journal $journalWriter

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $null=Invoke-ChangePlan @(New-ChangePlan @('ads'))
    $legacy=Get-LatestJournal; $legacy.Journal.Version=2
    $legacy.Journal.Rows=@($legacy.Journal.Rows | Select-Object Feature,Index,Exists,Value,Target)
    Save-Journal $legacy.Journal $legacy.Path
    $null=Undo-LatestJournal
    Assert ($Memory.Count -eq 0) 'Legacy v0.2 backup can still be undone'

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $widgets=(Get-Feature 'widgets').Changes[0]
    $Memory[(Get-SimKey $widgets)]=1
    $widgetRows=@(New-ChangePlan @('widgets'))
    Assert ($widgetRows.Count -eq 1 -and $widgetRows[0].Value -eq 1 -and $widgetRows[0].Target -eq 0) 'Widgets preview preserves the visible original value'
    $null=Invoke-ChangePlan $widgetRows
    Assert ($Memory[(Get-SimKey $widgets)] -eq 0) 'Widgets applies only the taskbar visibility value'
    $null=Undo-LatestJournal
    Assert ($Memory[(Get-SimKey $widgets)] -eq 1) 'Widgets undo restores the visible original value'

    Fresh; Set-Item Function:Set-RegistryValue $writer
    $accessCheck=${function:Test-RegistryWriteAccess}
    function Test-RegistryWriteAccess($Change) { return [pscustomobject]@{Allowed=($Change.Name -ne 'GameDVR_Enabled');Reason='Injected access denied'} }
    Reject { Invoke-ChangePlan @(New-ChangePlan @('ads','dvr')) } 'Denied later target blocks the entire batch before first write'
    Assert ($WriteCalls -eq 0 -and $Memory.Count -eq 0) 'Permission preflight leaves all earlier targets unchanged'
    Assert (@(Get-Journals).Count -eq 0) 'Permission refusal does not create a fake or pending batch'
    Set-Item Function:Test-RegistryWriteAccess $accessCheck

    Fresh
    # Use the actual isolated writer with its optional persistence mechanism.
    . "$PSScriptRoot/Simulation.ps1"
    Enable-SimulationStorage
    $null=Invoke-ChangePlan @(New-ChangePlan @('ads'))
    $script:Memory=@{}; Enable-SimulationStorage
    Assert ((Read-RegistryValue (Get-Feature 'ads').Changes[0]).Value -eq 0 -and $Memory.Count -eq 1) 'Demo virtual registry survives reopening'
    $null=Undo-LatestJournal
    $script:Memory=@{}; Enable-SimulationStorage
    Assert ($Memory.Count -eq 0) 'Persisted demo registry also records undo'
    Write-Output "EXTENDED TESTS PASSED: $script:Pass (simulated registry only)."
} finally {
    $absolute=[IO.Path]::GetFullPath($root)
    if (-not $absolute.StartsWith([IO.Path]::GetFullPath($parent)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup path.' }
    if (Test-Path -LiteralPath $absolute) { Remove-Item -LiteralPath $absolute -Recurse -Force }
}
