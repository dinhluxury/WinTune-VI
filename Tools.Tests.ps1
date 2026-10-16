#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Tools.Core.ps1"
. "$PSScriptRoot/Core.ps1"
. "$PSScriptRoot/Simulation.ps1"
. "$PSScriptRoot/Profiles.ps1"
$base=Join-Path $PSScriptRoot ('.test-runs/tools-'+[guid]::NewGuid().ToString('N').Substring(0,8));$pass=0
function Check([bool]$Ok,[string]$Name) {if (-not $Ok) {throw "TOOLS FAILED: $Name"};$script:pass++;Write-Output "PASS TOOL: $Name"}
function Reject([scriptblock]$Work,[string]$Name) {$failed=$false;try {& $Work | Out-Null} catch {$failed=$true};Check $failed $Name}
$user=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
Initialize-Tools $base $true $user
$params=[pscustomobject]@{Query='7zip';PackageId='7zip.7zip';PackageIds=@('7zip.7zip');SourceAgreed=$false;PackageAgreed=$false;SilentAgreed=$false;Files=@($ToolMockFiles);Guid='8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c';Before=$ToolMockPlan}
Check ($ToolMockWrites -eq 0 -and @(Get-ToolDefinitions).Count -eq 19) 'Opening initializes tools without native writes'
Reject {Get-Tool 'arbitrary-command'} 'Unregistered JSON handler is refused'
Reject {Invoke-ToolHandler sfc $params $false} 'Repair requires specific confirmation'
Reject {Invoke-ToolHandler tempdelete $params $false} 'Deletion requires specific confirmation'
foreach ($id in @('wingetsearch','wingetlist','wingetupdates','wingetshow','wingetinstall','wingetupgrade')) {
 $args=@(New-WinGetArguments $id $params)
 Check ('--accept-source-agreements' -notin $args -and '--accept-package-agreements' -notin $args -and '--silent' -notin $args -and '--all' -notin $args) "WinGet $id never silently accepts agreements/installs all"
}
$params.SourceAgreed=$true;$params.PackageAgreed=$true;$params.SilentAgreed=$true
$args=@(New-WinGetArguments wingetinstall $params)
Check ('--exact' -in $args -and '--accept-source-agreements' -in $args -and '--accept-package-agreements' -in $args -and '--silent' -in $args) 'WinGet consent is explicit and command targets an exact ID'
$params.PackageId='x --all & del';Reject {New-WinGetArguments wingetinstall $params} 'Command injection in package ID is rejected'
$params.PackageId='Notepad++.Notepad++';Check (@(New-WinGetArguments wingetshow $params) -contains 'Notepad++.Notepad++') 'Verified Notepad++ ID is accepted'
$params.Query='a"; x';Reject {New-WinGetArguments wingetsearch $params} 'Search cannot inject shell text'
$params.Query='7zip';$params.PackageId='7zip.7zip'
Check ('--version' -notin @(New-WinGetArguments wingetinstall $params) -and '--architecture' -notin @(New-WinGetArguments wingetinstall $params)) 'Other curated apps keep normal WinGet version selection'
$params.PackageId='UniKey.UniKey'
$uniShow=@(New-WinGetArguments wingetshow $params);$uniInstall=@(New-WinGetArguments wingetinstall $params)
Check (($uniShow -join ' ').Contains('--version 4.6.230919 --architecture x64') -and ($uniInstall -join ' ').Contains('--version 4.6.230919 --architecture x64')) 'UniKey preview and installation target the reviewed x64 release'
Check ('--version' -notin @(New-WinGetArguments wingetlist $params)) 'Installed-package verification remains independent of version pin'
$params | Add-Member -NotePropertyName Version -NotePropertyValue '999 --override bad';$params | Add-Member -NotePropertyName Architecture -NotePropertyValue 'arm64'
Check ((@(New-WinGetArguments wingetinstall $params) -join ' ').Contains('--version 4.6.230919 --architecture x64')) 'Execution input cannot override the trusted UniKey version and architecture'
$params.PackageId='7zip.7zip'
Check ((Quote-ToolArgument 'C:\A B\') -eq '"C:\A B\\"') 'Windows argument quoting preserves trailing slash and spaces'
Check ((Convert-ToolOutput ([Text.Encoding]::Unicode.GetBytes('Kiểm tra Windows')) $false) -eq 'Kiểm tra Windows') 'UTF-16 redirected output is decoded without nul characters'
Check ((Convert-ToolOutput ([Text.Encoding]::UTF8.GetBytes('Tên gói')) $true) -eq 'Tên gói') 'WinGet UTF-8 output preserves Vietnamese'
foreach ($id in @('wingetcheck','wingetsearch','wingetlist','wingetupdates','wingetshow','wingetinstall','wingetupgrade','tempscan','tempdelete','recycle','sfc','dismcheck','dismscan','dismrestore','diskcheck','powerlist','restorepoint')) {
 $result=Invoke-ToolHandler $id $params $true
 Check ($null -ne $result) "Handler $id has a real implementation and isolated simulated result"
}
Check ((Get-SystemOverview).Mode -eq 'MÔ PHỎNG' -and @((Get-ToolDefinitions) | Where-Object Id -eq 'dashboard').Count -eq 0) 'Overview reader remains available; no duplicate overview tool in the catalog'
$script:ToolMockCimFail=$true;Reject {Get-SystemOverview} 'Unavailable CIM is an error, never a fabricated hardware result';$script:ToolMockCimFail=$false
Check ('/NoRestart' -in (Invoke-ToolHandler dismrestore $params $true).Arguments) 'DISM explicitly forbids automatic restart'
$tempRoot=Get-ToolTempRoot
Check (-not (Test-SafeTempPath (Join-Path $tempRoot '../personal.txt') $tempRoot)) 'Traversal out of TEMP is blocked'
Check (-not (Test-SafeTempPath ($tempRoot+'-other\file.tmp') $tempRoot)) 'Sibling prefix is not a permitted delete root'
Check (-not (Test-SafeTempPath ($tempRoot+'\file.tmp:stream') $tempRoot)) 'Alternate data streams are refused'
$bad=[pscustomobject]@{Files=@([pscustomobject]@{Path='C:\Windows\System32\file.tmp';Bytes=1;Modified='x'})}
Reject {Invoke-ToolHandler tempdelete $bad $true} 'System paths are never cleanup targets'
Reject {Remove-TempHandle 'C:\file.tmp' 0 0 'C:\'} 'Native handle deletion forbidden in simulated tests'
$before=Get-PowerState;$writes=$ToolMockWrites
$p=[pscustomobject]@{Before=$before;Guid=$before};$r=Invoke-PowerChange $p $false
Check ($r.Status -eq 'NoOp' -and $ToolMockWrites -eq $writes -and @(Get-ChildItem $ToolRoot -Filter 'power-*.dat').Count -eq 0) 'No-op power plan creates no fake batch'
$p.Guid='8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c';$p.Before='stale';Reject {Invoke-PowerChange $p $false} 'Power plan stale preview is refused';$p.Before=$before
$r=Invoke-PowerChange $p $false
Check ($r.Before -eq $before -and (Get-PowerState) -eq $p.Guid) 'Power plan saves and verifies actual state provider'
Reject {Invoke-PowerChange $p $false} 'Unresolved power history blocks another change'
$script:ToolMockPlan='11111111-1111-1111-1111-111111111111';Reject {Invoke-PowerChange $p $true} 'External power plan conflict blocks overwrite'
$script:ToolMockPlan=$p.Guid;$null=Invoke-PowerChange $p $true
Check ((Get-PowerState) -eq $before) 'Power undo restores original GUID'
$path=Join-Path $ToolRoot 'secret.dat';Protect-ToolData ([pscustomobject]@{Value='C:\Private command'}) $path
Check ((Read-ProtectedToolData $path).Value -eq 'C:\Private command') 'DPAPI request/history round trip'
$corrupt=Get-Content $path -Raw | ConvertFrom-Json;$corrupt.Protected='AA==';Write-ToolJson $corrupt $path;Reject {Read-ProtectedToolData $path} 'Tampered execution request cannot be read'
Initialize-WinTune "$PSScriptRoot/features.json" (Join-Path $base 'registry') $user 26300
Initialize-Profiles
$ids=@(Get-ProfileSelection minimal)
Check ($ids.Count -eq 5 -and 'ads' -in $ids -and $SimWriteCount -eq 0) 'Minimal profile prepares disclosed advertising settings without applying'
Check (@(Get-ProfileSelection standard).Count -eq 10 -and @(Get-ProfileSelection custom).Count -eq 0) 'Balanced/custom profiles prepare selections and never apply'
# Compile our deletion helper without invoking any Windows deletion API.
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/Tools.Core.ps1",[ref]$tokens,[ref]$errors)
$native=$ast.FindAll({param($a) $a -is [Management.Automation.Language.StringConstantExpressionAst] -and $a.Value.Contains('public static class WinTuneTempDelete')},$true) | Select-Object -First 1
if ($null -eq $native) {throw 'Missing native helper source.'}
Add-Type -TypeDefinition $native.Value
Check ($null -ne ('WinTuneTempDelete' -as [type])) 'Native path/handle deletion helper compiles; never called in tests'
# Exercise the production pre-delete checks with mocked filesystem/writer;
# no test creates or deletes a real TEMP file.
$savedItem=${function:Get-Item};$savedDelete=${function:Remove-TempHandle}
$script:FixturePath=Join-Path (Get-ToolTempRoot) ('WinTune-fixture-'+[guid]::NewGuid().ToString('N')+'.tmp')
$script:FixtureDate=[DateTime]::UtcNow.AddDays(-10);$script:FixtureSize=20L;$script:HandleCalls=0
function Get-Item {param($LiteralPath,[switch]$Force,$ErrorAction) return [pscustomobject]@{FullName=$script:FixturePath;PSIsContainer=$false;Length=$script:FixtureSize;LastWriteTimeUtc=$script:FixtureDate}}
function Remove-TempHandle {param($Path,$Bytes,$Ticks,$Root) $script:HandleCalls++}
$file=[pscustomobject]@{Path=$FixturePath;Bytes=20L;Modified=$FixtureDate.ToString('o')}
$script:ToolSimulation=$false
$script:FixtureSize=21L;$r=Remove-SelectedTemp @($file)
Check ($r.RemovedBytes -eq 0 -and $HandleCalls -eq 0) 'Changed file length is skipped before the mocked delete handle'
$script:FixtureSize=20L;$script:FixtureDate=[DateTime]::UtcNow;$r=Remove-SelectedTemp @($file)
Check ($r.RemovedBytes -eq 0 -and $HandleCalls -eq 0) 'Changed/new file timestamp is skipped before deletion'
$script:FixtureDate=[DateTime]::Parse($file.Modified).ToUniversalTime();$r=Remove-SelectedTemp @($file)
Check ($r.RemovedBytes -eq 20 -and $HandleCalls -eq 1) 'Verified file records only actual successful bytes through a mocked writer'
$script:ToolSimulation=$true
if ($null -ne $savedItem) {Set-Item Function:Get-Item $savedItem} else {Remove-Item Function:Get-Item}
Set-Item Function:Remove-TempHandle $savedDelete
Check (Test-ToolRestartRequired ([pscustomobject]@{ExitCode=3010})) 'Native exit 3010 preserves the reboot requirement'
Check (Test-ToolRestartRequired ([pscustomobject]@{ExitCode=0;RestartRequested=$true})) 'Aggregated install preserves a reboot request from an individual package'
Check (-not (Test-ToolRestartRequired ([pscustomobject]@{ExitCode=0;RestartRequested=$false}))) 'Successful operation without a reboot request stays false'
Write-Output "TOOLS TESTS PASSED: $pass; all system-changing handlers simulated, no native cleanup/repair/install/power writes."
