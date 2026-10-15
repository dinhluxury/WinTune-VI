#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Logs.Core.ps1";. "$PSScriptRoot/Power.Explanations.ps1"
$pass=0
function Check([bool]$Ok,[string]$Name) {if (-not $Ok) {throw "UX FAILED: $Name"};$script:pass++;Write-Output "PASS UX: $Name"}
function Reject([scriptblock]$Work,[string]$Name) {$failed=$false;try {& $Work | Out-Null} catch {$failed=$true};Check $failed $Name}
$root=Join-Path $PSScriptRoot ('.test-runs/ux-'+[guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $root -Force
function Event([string]$Provider,[int]$Id,[string]$Xml) {return [pscustomobject]@{ProviderName=$Provider;Id=$Id;TimeCreated=Get-Date;Level=2;LogName='fixture';Message='Test fixture only';Xml='<Event><EventData>'+$Xml+'</EventData></Event>'}}
$app=Convert-WindowsEventSummary (Event 'Application Error' 1000 '<Data Name="AppName">editor.exe</Data><Data Name="ModuleName">ntdll.dll</Data><Data Name="ExceptionCode">c0000005</Data>')
Check ($app.Target -eq 'editor.exe' -and $app.Meaning.Contains('ntdll.dll') -and $app.Meaning.Contains('c0000005') -and $app.Advice.Contains('chưa chắc')) 'Crash names the app and recorded module without inventing a cause'
$service=Convert-WindowsEventSummary (Event 'Service Control Manager' 7000 '<Data Name="param1">Example Service</Data><Data Name="param2">%%1068</Data>')
Check ($service.Target -eq 'Example Service' -and $service.Meaning.Contains('phụ thuộc')) 'Service failure includes the actual service and Windows reason'
$timeout=Convert-WindowsEventSummary (Event 'Service Control Manager' 7009 '<Data Name="param1">30000</Data><Data Name="param2">Example Service</Data>')
Check ($timeout.Target -eq 'Example Service') 'Timeout event uses the service field rather than the timeout number'
$grouped=@(Group-WindowsEventSummaries @($app,$app,$service) @([pscustomobject]@{Name='Example';DisplayName='Example Service';Status='Running'}))
Check ($grouped.Count -eq 2 -and @($grouped | Where-Object Kind -eq App)[0].Count -eq 2 -and @($grouped | Where-Object Kind -eq Service)[0].Current.Contains('đã chạy lại')) 'Repeated records group together and recovered service state stays distinct'
$unknown=Convert-WindowsEventSummary (Event 'Vendor source' 999 '')
Check ($unknown.Meaning.Contains('Vendor source') -and $unknown.Advice.Contains('Chưa có cách diễn giải')) 'Unknown events retain the evidence and admit limits'
$power=Format-PowerList ([pscustomobject]@{Plans=@([pscustomobject]@{Guid='381b4222-f694-41f0-9685-ff5bb260df2e';Title='Balanced'});Active='381b4222-f694-41f0-9685-ff5bb260df2e'})
Check ($power.Contains('ĐANG DÙNG: Cân bằng') -and -not $power.Contains('381b4222') -and $power.Contains('không làm thay đổi')) 'Power list shows current mode and useful effects without GUID clutter'
Check ((Get-PowerExplanation '11111111-1111-1111-1111-111111111111' 'Vendor custom').Name -eq 'Vendor custom') 'OEM power plans retain their name without guessed performance promises'
. "$PSScriptRoot/Actions.Core.ps1";. "$PSScriptRoot/Copilot.Core.ps1"
Initialize-Actions "$root/actions" $true 'ux-fixture'
$preview=New-CopilotRemovalPreview;$id=$preview.Rows[0].Item.Id
Check ($preview.Found -and $preview.Rows.Count -eq 1 -and $preview.Rows[0].Item.Name -ceq 'Microsoft.Copilot' -and $ActionWrites -eq 0) 'Copilot preview selects exactly the current-user Microsoft package without uninstalling'
$script:ActionBusyApps=@($id);Reject {New-CopilotRemovalPreview} 'Running Copilot is not forcibly closed or removed';$script:ActionBusyApps=@()
$saved=$ActionMemoryApps[$id];$saved.PublisherId='untrustedxxxx';Reject {New-CopilotRemovalPreview} 'Impersonating publisher is refused';$saved.PublisherId='8wekyb3d8bbwe'
$null=Invoke-ActionPlan $preview.Rows
Check (@(Get-AllAppInventory | Where-Object Name -CEQ 'Microsoft.Copilot').Count -eq 0 -and @(Get-AllAppInventory).Count -eq 29) 'Simulated direct removal verifies absence and preserves every other app'
$absent=New-CopilotRemovalPreview
Check (-not $absent.Found -and $absent.Rows.Count -eq 0 -and $absent.Message.Contains('Không tìm thấy')) 'Missing Copilot reports no matching app instead of claiming removal'
Write-Output "UX CORE TESTS PASSED: $pass; workspace files and simulated app providers only."
