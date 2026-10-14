#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Actions.Core.ps1"
$root=Join-Path $PSScriptRoot ('.test-runs/actions-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$pass=0
function Check([bool]$OK,[string]$Text) { if (-not $OK) {throw "ACTION FAILED: $Text"}; $script:pass++; Write-Output "PASS ACTION: $Text" }
function Reject([scriptblock]$Work,[string]$Text) {$failed=$false; try { & $Work | Out-Null } catch {$failed=$true}; Check $failed $Text}
function Fresh { Initialize-Actions (Join-Path $root ([guid]::NewGuid().ToString('N').Substring(0,8))) $true 'simulation-user' }
Fresh
$apps=@(Get-ActionInventory Appx)
Check ($apps.Count -eq 30 -and $ActionWrites -eq 0) 'Opening inventories uses simulation with no writes'
$rows=@(New-ActionPlan Appx @($apps[0].Id,$apps[0].Id))
Check ($rows.Count -eq 1 -and $ActionWrites -eq 0 -and @(Get-ActionJournals).Count -eq 0) 'Preview deduplicates selection and creates no batch'
Reject {Invoke-ActionPlan @()} 'Empty plan refused without a fake batch'
$script:ActionBusyApps=@($apps[0].Id)
Reject {New-ActionPlan Appx @($apps[0].Id)} 'Running app is blocked before removal'
$script:ActionBusyApps=@()
$saved=$ActionMemoryApps[$apps[0].Id]
$ActionMemoryApps.Remove($apps[0].Id)
Reject {Invoke-ActionPlan $rows} 'Stale app removal plan refused before mutations'
Check ($ActionWrites -eq 0 -and @(Get-ActionJournals).Count -eq 0) 'Stale plan leaves no mutation/journal'
$ActionMemoryApps[$saved.Id]=$saved
$null=Invoke-ActionPlan @(New-ActionPlan Appx @($saved.Id))
Check (@(Get-ActionInventory Appx).Count -eq 29 -and (Get-ActionJournals).Journal.Status -eq 'Completed') 'Removal is verified against current inventory'
$data=$ActionRoot; Initialize-Actions $data $true 'simulation-user'
Check (@(Get-ActionInventory Appx).Count -eq 29 -and @(Get-ActionJournals).Count -eq 1) 'Removal state and journal survive reopening'
Check ((Get-ActionJournals).Journal.Rows[0].Item.StoreId -match '^[A-Z0-9]{12,14}$') 'Exact package and reinstall product preserved'
Reject {Undo-StartupAction} 'App removal does not advertise data undo as startup recovery'
Fresh
$apps=@(Get-ActionInventory Appx)
$rows=@(New-ActionPlan Appx @($apps[0].Id,$apps[1].Id,$apps[2].Id))
$script:ActionFailId=$apps[1].Id; $script:ActionFailAfter=$true
Reject {Invoke-ActionPlan $rows} 'Mid-batch app removal failure reported'
$j=(Get-ActionJournals).Journal
Check ($j.Rows[0].State -eq 'Applied' -and $j.Rows[1].State -eq 'Failed' -and $j.Rows[2].State -eq 'Skipped') 'History distinguishes applied, uncertain failure and skipped items'
Check (@(Get-ActionInventory Appx).Count -eq 28) 'Failure after mutation is not misreported as no changes'
Fresh
$s=@(Get-ActionInventory Startup)[0]
$s.ValueKind='ExpandString'; $s.Command='"%LOCALAPPDATA%\Discord\Discord.exe" --startup'
$null=Invoke-ActionPlan @(New-ActionPlan Startup @($s.Id))
Check (@(Get-ActionInventory Startup).Count -eq 0) 'Startup removal affects only selected Run entry'
Undo-StartupAction
$restored=Read-StartupExact $s.Id
Check ($restored.Command -ceq $s.Command -and $restored.ValueKind -eq 'ExpandString') 'Startup undo preserves unexpanded command and data type'
Check ((Get-ActionJournals).Journal.Status -eq 'Undone') 'Undo status persists'
Fresh
$s=@(Get-ActionInventory Startup)[0]
$null=Invoke-ActionPlan @(New-ActionPlan Startup @($s.Id))
$external=$s.PSObject.Copy(); $external.Command='C:\Demo\different.exe'
$ActionMemoryStartup[$s.Id]=$external
Reject {Undo-StartupAction} 'External startup changes block undo'
Check ((Read-StartupExact $s.Id).Command -eq 'C:\Demo\different.exe') 'Conflict never overwrites outside value'
$external.Command='C:\Demo\Defender.exe'
Reject {Undo-StartupAction} 'Even a command excluded from inventory is detected as a conflict'
Fresh
$second=$ActionMemoryStartup['Discord'].PSObject.Copy(); $second.Id='Spotify'; $second.Name='Spotify'; $second.Title='Spotify'; $second.Command='C:\Demo\Spotify.exe'
$ActionMemoryStartup['Spotify']=$second
$script:ActionFailId='Spotify'; $script:ActionFailAfter=$true
Reject {Invoke-ActionPlan @(New-ActionPlan Startup @('Discord','Spotify'))} 'Startup failure after mutation leaves a recovery journal'
Check ($ActionMemoryStartup.Count -eq 0 -and (Get-LatestStartupAction).Journal.Status -eq 'Partial') 'Partial startup failure is tracked even after physical removal'
Undo-StartupAction
Check ($ActionMemoryStartup.Count -eq 2 -and (Get-ActionJournals).Journal.Status -eq 'Undone') 'Partial startup recovery restores both affected commands'
Fresh
$null=Invoke-ActionPlan @(New-ActionPlan Startup @('Discord'))
$last=Get-LatestStartupAction
$last.Journal.Rows[0].UndoState='Restored'
$last.Journal.Status='Partial'
Save-ActionJournal $last.Journal $last.Path
Reject {Undo-StartupAction} 'Previously restored command deleted externally is not recreated'
Check ($ActionWrites -eq 1 -and $ActionMemoryStartup.Count -eq 0) 'Deleted restored command conflict causes zero additional writes'
Fresh
Check (-not (Test-StartupAllowed 'SecurityHealth' 'C:\Windows\SecurityHealthSystray.exe')) 'Windows security startup never offered'
Check (-not (Test-StartupAllowed 'Discord' 'C:\Defender.exe')) 'Security command blocked even under an allowed entry name'
Check (-not (Test-StartupAllowed 'UnknownApp' 'C:\Unknown.exe')) 'Unknown startup apps not automatically disabled'
$s=@(Get-ActionInventory Startup)[0]
$rows=@(New-ActionPlan Startup @($s.Id)); $rows[0].Item.Id='SecurityHealth'
Reject {Invoke-ActionPlan $rows} 'Forged startup target blocked'
Fresh
$apps=@(Get-ActionInventory Appx); $rows=@(New-ActionPlan Appx @($apps[0].Id))
$rows[0].Item.Name='Microsoft.WindowsStore'
Reject {Invoke-ActionPlan $rows} 'Store/framework/system app forgery blocked'
Fresh
$null=Invoke-ActionPlan @(New-ActionPlan Startup @('Discord'))
$last=Get-LatestStartupAction
$sealed=Get-Content -LiteralPath $last.Path -Raw | ConvertFrom-Json
$sealed.Protected='AA=='
$sealed | ConvertTo-Json | Set-Content -LiteralPath $last.Path -Encoding UTF8
Reject {Get-ActionJournals} 'Tampered encrypted journal refused'
Reject {New-ActionPlan Startup @('Discord')} 'Corrupted history blocks another plan'
Fresh
$originalSave=${function:Save-ActionJournal}
function Save-ActionJournal {throw 'Injected storage failure'}
Reject {Invoke-ActionPlan @(New-ActionPlan Startup @('Discord'))} 'Backup failure prevents startup mutation'
Check ($ActionWrites -eq 0 -and @(Get-ActionInventory Startup).Count -eq 1) 'No mutation without durable journal'
Set-Item Function:Save-ActionJournal $originalSave
Fresh
$regular=@(Get-ActionInventory Appx)[0].PSObject.Copy();$regular.Name='Example.Notes';$regular.PublisherId='abcdefghijklm';$regular.Id='Example.Notes_1.0.0.0_x64__abcdefghijklm';$regular.StoreId='';$regular.Title='Example Notes'
Check (-not (Get-AppProtection $regular).Protected) 'Ordinary third-party Appx is classified without a bloatware claim'
$ActionMemoryApps[$regular.Id]=$regular
$null=Invoke-ActionPlan @(New-ActionPlan Appx @($regular.Id))
Check (@(Get-ActionInventory Appx | Where-Object Id -EQ $regular.Id).Count -eq 0) 'Third-party exact selected package uses the same durable removal path'
foreach ($name in @('Microsoft.WindowsStore','Microsoft.MicrosoftEdge','Microsoft.GamingServices','Microsoft.Windows.ShellExperienceHost','Vendor.WebView2','NVIDIA.ControlPanel','Microsoft.VCLibs.140.00')) {
 $protected=$regular.PSObject.Copy();$protected.Name=$name
 Check (Get-AppProtection $protected).Protected "Protected package never offered: $name"
}
Write-Output "ACTION TESTS PASSED: $pass (in-memory app/startup providers only; no real app removals or startup edits)."
