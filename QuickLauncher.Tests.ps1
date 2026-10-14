#Requires -Version 5.1
# Execute only our trusted local template and harmless child fixtures.
# Both HTTP stages are mocked; no remote code, app, registry or PATH changes.
$ErrorActionPreference='Stop';$pass=0
function Check($Ok,$Name){if(-not $Ok){throw "QUICK LAUNCHER FAILED: $Name"};$script:pass++;Write-Output "PASS QUICK: $Name"}
$test=Join-Path $PSScriptRoot ('.test-runs/Lệnh online '+[guid]::NewGuid().ToString('N').Substring(0,8));$null=New-Item -ItemType Directory -Path $test
$child=Join-Path $test 'child.ps1';$marker=Join-Path $test 'child.json';$parentMarker=Join-Path $test 'parent.json'
$childText=@'
param([switch]$CheckOnly,[switch]$Confirmed,[switch]$Setup,[switch]$RegisterCommand)
[pscustomobject]@{CheckOnly=[bool]$CheckOnly;Confirmed=[bool]$Confirmed;Setup=[bool]$Setup;RegisterCommand=[bool]$RegisterCommand;Policy=[string](Get-ExecutionPolicy);Apartment=[string][Threading.Thread]::CurrentThread.ApartmentState}|ConvertTo-Json|Set-Content -LiteralPath $env:WINTUNE_QUICK_MARKER -Encoding UTF8
exit ([int]$env:WINTUNE_QUICK_EXIT)
'@
[IO.File]::WriteAllText($child,$childText,[Text.UTF8Encoding]::new($true))
$template=[IO.File]::ReadAllText("$PSScriptRoot/QuickLauncher.template.ps1")
$url='https://github.com/fixture/WinTune/releases/download/v0.15.2/WinTune-Online.ps1';$hash=(Get-FileHash $child).Hash
$quick=Join-Path $test 'get.ps1'
function Render-Quick([string]$Expected){[IO.File]::WriteAllText($quick,$template.Replace('__BOOTSTRAP_URL__',$url).Replace('__BOOTSTRAP_SHA256__',$Expected),[Text.UTF8Encoding]::new($true))}
Render-Quick $hash
$ts=$null;$es=$null;[Management.Automation.Language.Parser]::ParseFile($quick,[ref]$ts,[ref]$es)|Out-Null
Check (@($es).Count -eq 0) 'Standalone entry parses in Windows PowerShell 5.1'
$setup=@'
$ErrorActionPreference='Stop'
$env:TEMP='__TEMP__'
$env:WINTUNE_QUICK_MARKER='__MARKER__'
$env:WINTUNE_QUICK_EXIT='__EXIT__'
$script:QuickSource='__QUICK__'
$script:ChildSource='__CHILD__'
$script:MockFail=__FAIL__
function Invoke-RestMethod {param($Uri);if($Uri -cne 'https://raw.githubusercontent.com/fixture/WinTune/main/get.ps1'){throw 'wrong entry URL'};return [IO.File]::ReadAllText($script:QuickSource)}
function Invoke-WebRequest { [CmdletBinding()]param($Uri,$OutFile,[switch]$UseBasicParsing,$TimeoutSec);if($Uri -cne '__URL__' -or -not $UseBasicParsing -or $TimeoutSec -ne 30){throw 'wrong bootstrap request'};if($script:MockFail){throw 'mock network failure'};[IO.File]::Copy($script:ChildSource,$OutFile,$false)}
'@
$ps=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
function Run-Quick([switch]$OnlyCheck,[switch]$Fail,[int]$ExitCode=0){
    if([IO.File]::Exists($marker)){[IO.File]::Delete($marker)}
    $prelude=$setup.Replace('__TEMP__',$test.Replace("'","''")).Replace('__MARKER__',$marker.Replace("'","''")).Replace('__QUICK__',$quick.Replace("'","''")).Replace('__CHILD__',$child.Replace("'","''")).Replace('__URL__',$url).Replace('__FAIL__',$(if($Fail){'$true'}else{'$false'})).Replace('__EXIT__',[string]$ExitCode)
    $call=$(if($OnlyCheck){'& ([scriptblock]::Create((irm https://raw.githubusercontent.com/fixture/WinTune/main/get.ps1))) -CheckOnly'}else{'irm https://raw.githubusercontent.com/fixture/WinTune/main/get.ps1 | iex'})
    $tail=@'
$before=[string](Get-ExecutionPolicy);$pref=$ErrorActionPreference;$taskCode=0
try { __CALL__ } catch {$taskCode=1;Write-Output $_.Exception.Message}
[pscustomobject]@{Before=$before;After=[string](Get-ExecutionPolicy);PreferencePreserved=($ErrorActionPreference -eq $pref)}|ConvertTo-Json|Set-Content -LiteralPath '__PARENT__' -Encoding UTF8
exit $taskCode
'@
    $code=$prelude+"`r`n"+$tail.Replace('__CALL__',$call).Replace('__PARENT__',$parentMarker.Replace("'","''"))
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code));$ErrorActionPreference='Continue'
    $output=& $ps -NoProfile -STA -ExecutionPolicy Restricted -EncodedCommand $encoded 2>&1
    return [pscustomobject]@{Code=$LASTEXITCODE;Text=($output|Out-String)}
}
$run=Run-Quick;if($run.Code -ne 0){throw $run.Text};$record=Get-Content $marker -Raw -Encoding UTF8|ConvertFrom-Json
Check ($record.Confirmed -and -not $record.CheckOnly -and -not $record.Setup -and -not $record.RegisterCommand) 'Actual irm/iex syntax opens directly, without setup/PATH flags or repeated consent'
Check ($record.Policy -eq 'Bypass' -and $record.Apartment -eq 'STA') 'Verified child starts in the fixed Microsoft PowerShell STA host'
$parent=Get-Content $parentMarker -Raw -Encoding UTF8|ConvertFrom-Json
Check ($parent.Before -eq 'Restricted' -and $parent.After -eq 'Restricted' -and $parent.PreferencePreserved) 'Interactive parent policy and error preference remain unchanged'
Check (@(Get-ChildItem -LiteralPath $test -Filter 'WinTune-*.ps1').Count -eq 0) 'Successful launch removes only its own temporary bootstrap file'
$run=Run-Quick -OnlyCheck;if($run.Code -ne 0){throw $run.Text};$record=Get-Content $marker -Raw -Encoding UTF8|ConvertFrom-Json
Check ($record.CheckOnly -and -not $record.Confirmed -and -not $record.Setup) 'CheckOnly reaches only the metadata check in the child'
Render-Quick ('0'*64);$run=Run-Quick
Check ($run.Code -ne 0 -and -not [IO.File]::Exists($marker)) 'Wrong bootstrap checksum prevents child execution'
Check (@(Get-ChildItem -LiteralPath $test -Filter 'WinTune-*.ps1').Count -eq 0) 'Checksum refusal also cleans the temporary file'
Render-Quick $hash;$run=Run-Quick -Fail
Check ($run.Code -ne 0 -and -not [IO.File]::Exists($marker)) 'Connection failure starts no child'
$run=Run-Quick -ExitCode 7
Check ($run.Code -ne 0 -and $run.Text.Contains('7')) 'Child failure is reported instead of claiming the app opened'
Write-Output "QUICK LAUNCHER TESTS PASSED: $pass; local trusted IEX template, mocked HTTP and harmless Microsoft-host child, zero native changes."
