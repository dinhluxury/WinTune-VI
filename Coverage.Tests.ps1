#Requires -Version 5.1
# All writes use Simulation. Test chosen values, restart recovery and invalid data.
$ErrorActionPreference='Stop';. "$PSScriptRoot/Core.ps1";. "$PSScriptRoot/Simulation.ps1"
$testRoot=Join-Path $PSScriptRoot ('.test-runs/coverage-'+[guid]::NewGuid().ToString('N'));$pass=0
function Check([bool]$Ok,[string]$Name) {if (-not $Ok) {throw "COVERAGE FAILED: $Name"};$script:pass++;Write-Output "PASS: $Name"}
function Fresh {Initialize-WinTune "$PSScriptRoot/features.json" (Join-Path $testRoot ([guid]::NewGuid().ToString('N'))) 'fixture' 26300;$script:Memory=@{};$script:SimWriteCount=0}
Fresh;$choiceFeatures=@($Features | Where-Object {$_.PSObject.Properties['Choices']})
foreach ($f in $choiceFeatures) {foreach ($choice in $f.Choices) {
    Fresh;Set-FeatureChoice $f.Id $choice.Id;$plan=@(New-ChangePlan @($f.Id))
    Check ($plan.Count -eq @($f.Changes).Count -and $SimWriteCount -eq 0 -and @($plan | Where-Object Choice -CNE $choice.Id).Count -eq 0) "Preview retains the exact choice: $($f.Id)/$($choice.Id)"
    $null=Invoke-ChangePlan $plan
    Initialize-WinTune "$PSScriptRoot/features.json" $DataRoot 'fixture' 26300
    $null=Undo-LatestJournal
    Check ($Memory.Count -eq 0) "Restart undo uses stored targets independently of current choice: $($f.Id)/$($choice.Id)"
}}
Fresh;$mouse=Get-Feature pointerprecision
foreach ($c in $mouse.Changes) {$Memory[(Get-SimKey $c)]='6'}
$null=Invoke-ChangePlan @(New-ChangePlan @('pointerprecision'));$null=Undo-LatestJournal
Check (@($mouse.Changes | Where-Object {(Read-RegistryValue $_).Value -cne '6'}).Count -eq 0) 'Original nonempty REG_SZ mouse values are restored exactly'
Fresh;Set-FeatureChoice 'search' 'box';$plan=@(New-ChangePlan @('search'));$plan[0].Target=999;$bad=$false
try {Invoke-ChangePlan $plan | Out-Null} catch {$bad=$true}
Check ($bad -and $SimWriteCount -eq 0) 'Unlisted target cannot enter a backup or write'
Fresh;Set-FeatureChoice darkmode light;$plan=@(New-ChangePlan @('darkmode'));$plan[1].Choice='dark';$plan[1].Target=0;$bad=$false
try {Invoke-ChangePlan $plan | Out-Null} catch {$bad=$true}
Check ($bad -and $SimWriteCount -eq 0) 'Mixed choices within one feature are rejected before writes'
Fresh;$Build=22621
Check (-not (Test-FeatureSupported (Get-Feature dragtray))) 'Drag Tray is unavailable on builds before 26200'
$bad=$false;try {Set-FeatureChoice search 'unknown'} catch {$bad=$true};Check $bad 'Unknown choice ID cannot be selected'
. "$PSScriptRoot/Actions.Core.ps1";Initialize-Actions (Join-Path $testRoot 'actions') $true 'fixture'
$photo=@(Get-AllAppInventory | Where-Object Name -eq 'Microsoft.Windows.Photos')[0]
Check ((Get-AppProtection $photo).Category -eq 'Ứng dụng thông thường' -and $ActionWrites -eq 0) 'Useful photo app is identified without recommending or automatically removing it'
$runtime=$photo.PSObject.Copy();$runtime.Name='Microsoft.GamingServices';$runtime.Id='Microsoft.GamingServices_1.0.0.0_x64__8wekyb3d8bbwe'
Check ((Get-AppProtection $runtime).Protected) 'Expanded catalog does not unlock Gaming Services'
Write-Output "COVERAGE TESTS PASSED: $pass; all Windows-changing operations simulated."
