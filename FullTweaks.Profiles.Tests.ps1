#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/FullTweaks.Core.ps1"
. "$PSScriptRoot/FullTweaks.Native.ps1"
. "$PSScriptRoot/FullTweaks.Profiles.ps1"
$script:Pass=0
$base=Join-Path $PSScriptRoot ('.test-runs/profiles-'+[guid]::NewGuid().ToString('N'))
function Check([bool]$Ok,[string]$Name){if(-not $Ok){throw ('PRESET TEST FAILED: '+$Name)};$script:Pass++}
$profiles=@(Get-FullProfiles)
Check ($profiles.Count -eq 4 -and $profiles[0].Id -ceq 'custom') 'One custom selection and three presets'
Initialize-FullTweaks (Join-Path $base 'legacy-coverage') $true 26300
$targets=@{}
foreach($feature in $FullCatalog){$all=@($feature.Changes);if($feature.PSObject.Properties['Choices']){foreach($choice in $feature.Choices){$all+=@($choice.Changes)}};foreach($change in $all){$targets[($change.Hive+'|'+$change.Path+'|'+$change.Name).ToLowerInvariant()]=$true}}
$originalFeatures=Get-Content "$PSScriptRoot/features.json" -Raw -Encoding UTF8|ConvertFrom-Json
foreach($feature in @($originalFeatures|Where-Object Kind -eq Registry)) {
 $missing=@($feature.Changes|Where-Object {$h=if($_.PSObject.Properties['Hive']){$_.Hive}else{'HKCU'};-not $targets.ContainsKey(($h+'|'+$_.Path+'|'+$_.Name).ToLowerInvariant())})
 Check ($missing.Count -eq 0) ('All original registry targets remain accessible: '+$feature.Id)
}
foreach($buildNumber in @(22000,22621,22631,26100,26300)) {
 $previous=@()
 foreach($profile in $profiles | Where-Object Id -ne custom) {
  Initialize-FullTweaks (Join-Path $base ([guid]::NewGuid().ToString('N'))) $true $buildNumber
  $members=@(Get-FullPresetRows $profile.Id);$ids=@($members.Id);$choices=@{}
  foreach($member in $members){if($member.Option -cne 'Apply'){$choices[$member.Id]=$member.Option}}
  Check (@($previous | Where-Object {$_ -cnotin $ids}).Count -eq 0) ($profile.Id+' includes the preceding preset on '+$buildNumber)
  Check ($ids.Count -eq @($ids | Select-Object -Unique).Count) 'No duplicate selections'
  Check (@($ids | ForEach-Object {Get-FullFeature $_} | Where-Object {$_.Risk -or $_.Handler -notin @('Registry','Telemetry') -or $_.MinBuild -gt $buildNumber}).Count -eq 0) 'Only reviewed, compatible settings are selected'
  $plan=@(New-FullPlan $ids @{Choices=$choices})
  Check ($plan.Count -gt 0 -and $FullMockWrites -eq 0) ($profile.Id+' previews without conflicts or writes on '+$buildNumber)
  $null=Invoke-FullPlan $plan $true
  Check ((Get-FullJournals)[0].Data.Status -eq 'Applied') 'Simulated preset applies every planned change'
  $null=Undo-FullSelection $ids $true
  $notRestored=@($plan | Where-Object {-not (Test-FullSame (Read-FullResource $_) $_.Before)})
  Check ((Get-FullJournals)[0].Data.Status -eq 'Undone' -and $notRestored.Count -eq 0) 'Undo restores every original state for the entire preset'
  $previous=$ids
 }
}
Initialize-FullTweaks (Join-Path $base 'counts') $true 26300
Check (@(Get-FullPresetRows minimal).Count -eq 8 -and @(Get-FullPresetRows standard).Count -eq 19 -and @(Get-FullPresetRows advanced).Count -eq 31) 'Current Windows builds get the reviewed 8, 19 and 31 settings'
Write-Output "FULL PRESET TESTS PASSED: $Pass; all changes simulated."
