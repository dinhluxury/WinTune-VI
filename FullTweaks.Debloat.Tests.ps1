#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/FullTweaks.Core.ps1"
. "$PSScriptRoot/FullTweaks.Native.ps1"
$script:Pass=0;$base=Join-Path $PSScriptRoot ('.test-runs/d-'+[guid]::NewGuid().ToString('N').Substring(0,8))
function Check([bool]$Ok,[string]$Name) {if (-not $Ok) {throw ('DEBLOAT TEST FAILED: '+$Name)};$script:Pass++;Write-Output ('PASS: '+$Name)}
function Reject([scriptblock]$Work) {try {& $Work | Out-Null;return $false} catch {return $true}}
function Fresh {Initialize-FullTweaks (Join-Path $base ([guid]::NewGuid().ToString('N'))) $true 26300}
Fresh
$document=Get-Content "$PSScriptRoot/FullTweaks.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$source=Get-Content "$PSScriptRoot/sources/review-20261014/debloat/Config__Features.json.txt" -Raw -Encoding UTF8 | ConvertFrom-Json
$outsideImage=@('DisableChromeAI','HideChat','DisableModernStandbyNetworking','Hide3dObjects','HideMusic','HideIncludeInLibrary','HideGiveAccessTo','HideShare')
$expected=@($source.Features | Where-Object {$_.Category -and $_.FeatureId -cnotin $outsideImage})
Check ($document.Win11FeatureMap.Count -eq 88 -and $expected.Count -eq 88) 'All 88 checkbox and dropdown options represented by the two Win11Debloat images have mappings'
foreach ($f in $expected) {
    $mapping=@($document.Win11FeatureMap | Where-Object UpstreamId -CEQ $f.FeatureId)
    Check ($mapping.Count -eq 1) ('One mapping for '+$f.FeatureId)
    $target=Get-FullFeature $mapping[0].WinTuneId;$null=Get-FullChanges $target $mapping[0].Choice
    Check ($target.MinBuild -ge 22000 -and $target.Title -and $target.Explanation -and $target.Impact -and $target.Undo) ('Explained implementation for '+$f.FeatureId)
}
function Read-ReferenceReg([string]$File) {
    $hive='';$path='';$result=@{}
    foreach ($line in ([IO.File]::ReadAllText($File) -split '\r?\n')) {
        if (-not $line.Trim() -or $line.StartsWith(';') -or $line.StartsWith('Windows Registry')) {continue}
        if ($line -match '^\[(-?)(HKEY_CURRENT_USER|HKEY_LOCAL_MACHINE|HKEY_CLASSES_ROOT|HKEY_USERS)\\(.+)\]$') {
            $delete=$Matches[1] -eq '-';$hive=switch ($Matches[2]) {'HKEY_LOCAL_MACHINE' {'HKLM'} 'HKEY_USERS' {'HKU'} default {'HKCU'}};$path=if ($Matches[2] -eq 'HKEY_CLASSES_ROOT') {'Software\Classes\'+$Matches[3]} else {$Matches[3]}
            if ($delete) {$result[$hive+'\'+$path+'\']=[pscustomobject]@{Hive=$hive;Path=$path;Name='';Type='Tree';Exists=$false;Value=$null}};continue
        }
        if ($line -notmatch '^(@|"(?:[^"\\]|\\.)*")=(.*)$') {throw ('Reference syntax was not reviewed: '+$line)}
        $name=$Matches[1];$raw=$Matches[2];$name=if ($name -eq '@') {''} else {$name.Substring(1,$name.Length-2).Replace('\\','\').Replace('\"','"')}
        $exists=$true;$value=$null;$type='String'
        if ($raw -eq '-') {$exists=$false}
        elseif ($raw -match '^dword:([0-9a-fA-F]{8})$') {$type='DWord';$value=[Convert]::ToInt32($Matches[1],16)}
        elseif ($raw.StartsWith('"') -and $raw.EndsWith('"')) {$value=$raw.Substring(1,$raw.Length-2).Replace('\\','\').Replace('\"','"')}
        elseif ($raw -match '^hex:([0-9a-fA-F,]+)$') {$type='Binary';$value=[byte[]]@($Matches[1].Split(',') | ForEach-Object {[Convert]::ToByte($_,16)})}
        else {throw ('Reference value type was not reviewed: '+$raw)}
        $result[$hive+'\'+$path+'\'+$name]=[pscustomobject]@{Hive=$hive;Path=$path;Name=$name;Type=$type;Exists=$exists;Value=$value}
    };return @($result.Values)
}
foreach ($f in @($expected | Where-Object RegistryKey)) {
    $mapping=@($document.Win11FeatureMap | Where-Object UpstreamId -CEQ $f.FeatureId)[0];$target=Get-FullFeature $mapping.WinTuneId;$actual=@(Get-FullChanges $target $mapping.Choice)
    $reference=@(Read-ReferenceReg (Join-Path $PSScriptRoot ('sources/review-20261014/debloat/Regfiles__'+$f.RegistryKey+'.txt')))
    foreach ($r in $reference) {
        if ($f.FeatureId -eq 'DisableAISvcAutoStart') {Check ($target.Services[0].Name -ceq 'WSAIFabricSvc' -and $target.Services[0].StartupType -ceq 'Manual' -and $r.Value -eq 3) 'AI service uses SCM Manual instead of raw registry service editing';continue}
        $found=@($actual | Where-Object {$_.Hive -eq $r.Hive -and $_.Path -eq $r.Path -and $_.Name -ceq $r.Name})
        Check ($found.Count -eq 1 -and (Test-FullSame (Get-FullTarget $found[0]) (Get-FullTarget $r))) ('Pinned source registry target: '+$f.FeatureId+'/'+$r.Name)
    }
}
foreach ($feature in @($FullCatalog | Where-Object {$_.PSObject.Properties['Choices']})) {
    foreach ($choice in $feature.Choices) {
        Fresh;$parameters=@{Choices=@{}};$parameters.Choices[$feature.Id]=$choice.Id
        # Give deletions an original value so each choice has a meaningful state to restore.
        $changes=@(Get-FullChanges $feature $choice.Id)
        for ($i=0;$i -lt $changes.Count;$i++) {$row=[pscustomobject]@{Kind='Registry';Id=$feature.Id;Option=$choice.Id;Index=$i};$value=if ($changes[$i].Name -eq 'SettingsPageVisibility') {if ($choice.Id -eq 'On') {''} else {'hide:home'}} else {'fixture previous value'};$script:FullMemory[(Get-FullMemoryKey $row)]=[pscustomobject]@{Exists=$true;KeyExisted=$true;Type='String';Value=$value}}
        $rows=@(New-FullPlan @($feature.Id) $parameters)
        Check ($FullMockWrites -eq 0 -and $rows.Count -gt 0 -and @($rows | Where-Object Option -CNE $choice.Id).Count -eq 0) ('Exact queued choice, read-only preview: '+$feature.Id+'/'+$choice.Id)
        $null=Invoke-FullPlan $rows $true;$null=Undo-FullSelection @($feature.Id) $true
        Check ((Get-FullJournals)[0].Data.Status -eq 'Undone') ('Original value restored for '+$feature.Id+'/'+$choice.Id)
    }
}
Fresh
Check (Reject {New-FullPlan @('DBExplorerLocation') @{Choices=@{DBExplorerLocation='unknown'}}}) 'Unlisted choices cannot reach a writer'
Check (Reject {New-FullPlan @('WPFTweaksWindowsAI','DBDisableAISvcAutoStart') @{}}) 'Conflicting AI service startup modes rejected before writes'
$f=Get-FullFeature WPFToggleHideSettingsHome;$r=[pscustomobject]@{Kind='Registry';Id=$f.Id;Option='Apply';Index=0};$script:FullMemory[(Get-FullMemoryKey $r)]=[pscustomobject]@{Exists=$true;KeyExisted=$true;Type='String';Value='hide:bluetooth'}
Check (Reject {New-FullPlan @($f.Id) @{}}) 'Existing Settings page restrictions are never overwritten'
Fresh;$rows=@(New-FullPlan @('DBExplorerLocation') @{Choices=@{DBExplorerLocation='ExplorerToDownloads'}});$null=Invoke-FullPlan $rows $true
$detected=@(Get-FullAppliedSelections | Where-Object Id -CEQ DBExplorerLocation)
Check ($detected.Count -eq 1 -and $detected[0].Option -ceq 'ExplorerToDownloads') 'Applied detection preserves the actual dropdown choice'
$script:FullBuild=26100
Check (Reject {New-FullPlan @('DBStartAllAppsView') @{}}) 'New Start layout is blocked on Windows builds without the supported feature'
# Native adapters below are mocked, while Start binary writes are confined to a workspace fixture.
$script:OptionalCalls=@();$script:OptionalFixture=@([pscustomobject]@{FeatureName='Recall';State='Enabled'},[pscustomobject]@{FeatureName='VirtualMachinePlatform';State='Disabled'},[pscustomobject]@{FeatureName='Microsoft-Windows-Subsystem-Linux';State='Disabled'})
function Get-WindowsOptionalFeature {param([switch]$Online,$ErrorAction) return $script:OptionalFixture}
function Enable-WindowsOptionalFeature {param([switch]$Online,[string]$FeatureName,[switch]$All,[switch]$NoRestart,$ErrorAction) $script:OptionalCalls+=@{Name=$FeatureName;NoRestart=[bool]$NoRestart;All=[bool]$All};@($script:OptionalFixture|Where-Object FeatureName -CEQ $FeatureName)[0].State='EnablePending'}
function Disable-WindowsOptionalFeature {param([switch]$Online,[string]$FeatureName,[switch]$Remove,[switch]$NoRestart,$ErrorAction) $script:OptionalCalls+=@{Name=$FeatureName;NoRestart=[bool]$NoRestart;Remove=[bool]$Remove};@($script:OptionalFixture|Where-Object FeatureName -CEQ $FeatureName)[0].State='DisablePending'}
$f=Get-FullFeature DBEnableWindowsSubsystemForLinux;$before=Get-FullOptionalState $f;$after=Get-FullOptionalTarget $f $before;Set-FullOptionalState $f $after $false
Check ($OptionalCalls.Count -eq 2 -and @($OptionalCalls | Where-Object {-not $_.NoRestart -or $_.All}).Count -eq 0) 'WSL touches exactly two listed features without restart, distro install or automatic dependency changes'
Check (Test-FullOptionalResult (Get-FullOptionalState $f) $after) 'A requested component pending reboot is reported accurately'
Check (Reject {Get-FullOptionalTarget $f (Get-FullOptionalState $f)}) 'Pending component changes block another apply'
Check (Reject {Set-FullOptionalState $f $before $true}) 'Undo waits for the outstanding reboot'
$pending=Get-FullOptionalState $f;foreach ($item in $script:OptionalFixture) {if ($item.State -eq 'EnablePending') {$item.State='Enabled'}}
Check (Test-FullSame $pending (Get-FullOptionalState $f)) 'Reboot completing an expected change does not masquerade as external interference'
Set-FullOptionalState $f $before $true
Check (@($OptionalCalls|Where-Object {$_.ContainsKey('Remove') -and $_.Remove}).Count -eq 0) 'Component undo never deletes payloads or Linux data'
$f=Get-FullFeature DBEnableWindowsSandbox
Check (Reject {Get-FullOptionalState $f}) 'Absent unsupported Sandbox is not shown as enabled'
$f=Get-FullFeature DBDisableRecall;$script:OptionalFixture=@()
Check ((Get-FullOptionalState $f).Features[0].State -ceq 'Absent') 'Absent Recall is distinguished from a successful removal'
Check (-not (Test-FullOptionalResult ([pscustomobject]@{Features=@([pscustomobject]@{Name='Recall';State='Enabled'})}) ([pscustomobject]@{Features=@([pscustomobject]@{Name='Recall';State='Disabled'})}))) 'Unchanged Recall state cannot claim success'
$script:ProfileTest=Join-Path $base 'profile';$null=New-Item -ItemType Directory -Path $ProfileTest -Force
function Get-FullStartProfileRoots($Feature) {return @($script:ProfileTest)}
$f=Get-FullFeature DBClearStart;$old=Get-FullStartPins $f;$target=Get-FullStartTarget $old;Set-FullStartPins $f $target
Check (Test-FullSame (Get-FullStartPins $f) $target) 'Verified empty Start template is written only to the selected fixture profile'
Set-FullStartPins $f $old
Check (Test-FullSame (Get-FullStartPins $f) $old) 'Undo removes only the created Start file and empty fixture directories'
$entry=(Get-FullStartPaths $f)[0];$null=New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($entry.Path)) -Force;$original=[byte[]](1,2,3,4,5,0,255);[IO.File]::WriteAllBytes($entry.Path,$original)
$old=Get-FullStartPins $f;Set-FullStartPins $f (Get-FullStartTarget $old);Set-FullStartPins $f $old
Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes($entry.Path)) -ceq [Convert]::ToBase64String($original)) 'Existing Start layout restores byte for byte'
$bad=Get-FullStartTarget $old;$bad.Files[0].Path=Join-Path $base 'outside.bin'
Check (Reject {Set-FullStartPins $f $bad}) 'Start layout writer rejects paths outside enumerated profile targets'
Check (@(Get-FullTelemetryTasks).Count -eq 8) 'Telemetry list contains only eight reviewed diagnostic task names'
Write-Output "FULL DEBLOAT TESTS PASSED: $Pass; Windows APIs mocked, file writes only under workspace fixtures."
