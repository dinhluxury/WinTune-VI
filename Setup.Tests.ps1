#Requires -Version 5.1
# All installation, command registration and process launch adapters are mocked.
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Setup.Core.ps1"
$pass=0;$script:Calls=New-Object 'Collections.Generic.List[string]';$script:Foreign=$false;$script:Fail='';$script:RegStatus='Registered'
function Check($Ok,$Name){if(-not $Ok){throw "SETUP FAILED: $Name"};$script:pass++;Write-Output "PASS SETUP: $Name"}
function Reject([scriptblock]$Work,$Name){$failed=$false;try{& $Work|Out-Null}catch{$failed=$true};Check $failed $Name}
function Reset-Fixture {$script:Calls.Clear();$script:Foreign=$false;$script:Fail='';$script:RegStatus='Registered'}
function Get-UserCommandRegistration {$script:Calls.Add('ReadRegistration');[pscustomobject]@{AppExists=$script:Foreign}}
function Install-LocalDistribution($Package,$Root,$Confirmed){if(-not $Confirmed){throw 'not confirmed'};$script:Calls.Add('Install');if($script:Fail -eq 'Install'){throw 'mock access denied'};[pscustomobject]@{Path='C:\fixture\apps\WinTune';Status='Prepared'}}
function Register-WinTuneCommand($Package,$Root,$Confirmed){if(-not $Confirmed){throw 'not confirmed'};$script:Calls.Add('Register');if($script:Fail -eq 'Register'){throw 'mock PATH failure'};[pscustomobject]@{Status=$script:RegStatus}}
function Get-WinTuneVersion($Root){[pscustomobject]@{Version='0.15.2'}}
function Test-PortableIntegrity($Root,$Version){$script:Calls.Add('Integrity');if($script:Fail -eq 'Integrity'){throw 'mock changed file'}}
function Start-Process {param($FilePath,$ArgumentList,$WorkingDirectory,$ErrorAction);$script:Calls.Add('Launch');if($script:Fail -eq 'Launch'){throw 'mock Application Control refusal'};$script:Launch=[pscustomobject]@{FilePath=$FilePath;Arguments=$ArgumentList;Root=$WorkingDirectory}}
$text=Get-WinTuneSetupText '0.15.2' 'C:\fixture'
Check ($text.Contains('wintune') -and $text.Contains('PATH của tài khoản') -and $text.Contains('C:\fixture')) 'One confirmation explains installed location and command setup'
Reject {Invoke-WinTuneLocalSetup source install $false} 'No confirmation refuses setup'
Check ($script:Calls.Count -eq 0) 'Unconfirmed setup reads/writes/launches nothing'
$result=Invoke-WinTuneLocalSetup source install $true
Check ($result.Status -eq 'Ready' -and ($script:Calls -join ',') -eq 'ReadRegistration,Install,Register,Integrity,Launch') 'Confirmed setup registers before launching; no separate UI action'
Check ($script:Launch.FilePath -eq (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -and $script:Launch.Arguments.Contains('-STA') -and $script:Launch.Arguments.Contains('-File "C:\fixture\apps\WinTune\WinTune.ps1"')) 'Launch uses fixed Microsoft host and quoted source path'
Reset-Fixture;$script:RegStatus='NoOp';$result=Invoke-WinTuneLocalSetup source install $true
Check ($result.Status -eq 'Ready') 'Already registered setup can open the app through the existing idempotent handler'
Reset-Fixture;$script:Foreign=$true;Reject {Invoke-WinTuneLocalSetup source install $true} 'Foreign or legacy App Paths is refused'
Check (($script:Calls -join ',') -eq 'ReadRegistration') 'Foreign registration is refused before installation changes the pointer'
foreach($failure in @('Install','Register','Integrity','Launch')){
    Reset-Fixture;$script:Fail=$failure;Reject {Invoke-WinTuneLocalSetup source install $true} "Failure is reported: $failure"
    if($failure -ne 'Launch'){Check (-not $script:Calls.Contains('Launch')) "Failure starts no application: $failure"}
}
Reset-Fixture;$script:RegStatus='Pending';Reject {Invoke-WinTuneLocalSetup source install $true} 'Pending command registration is not claimed as success'
Check (-not $script:Calls.Contains('Launch')) 'Pending command registration starts no app'
Reject {Start-VerifiedWinTuneApp 'C:\fixture\bad"path' '0.15.2'} 'Unsafe quoted path is refused before launching'
# Test the real generated bootstrap control flow with a wholly mocked provider.
$test=Join-Path $PSScriptRoot ('.test-runs/setup-'+[guid]::NewGuid().ToString('N').Substring(0,8));$null=New-Item -ItemType Directory -Path $test
$prelude=@'
$script:Trace=New-Object 'Collections.Generic.List[string]'
function Assert-ReleaseTrust($Config){}
function Get-WinTuneInstallRoot{return 'C:\fixture'}
function Test-Path {param($LiteralPath) return [bool]$env:WINTUNE_TEST_CURRENT}
function Get-Content {param($LiteralPath,[switch]$Raw,$Encoding) return 'C:\fixture\apps\current'}
function Assert-DistributionPath($Path,$Root){return $Path}
function Get-WinTuneVersion($Path){[pscustomobject]@{Version=$(if($env:WINTUNE_TEST_CURRENT){'0.16.0'}else{'0.15.2'})}}
function Test-PortableIntegrity($Path,$Version){}
function Assert-InstalledRelease($Path,$Info,$Root,$Config){$script:Trace.Add('VerifySignedCache')}
function Get-DistributionUpdate($Config,$Current){$script:Trace.Add('Metadata');[pscustomobject]@{Status=$(if($env:WINTUNE_TEST_CURRENT){'Current'}else{'Available'});Manifest=[pscustomobject]@{Version='0.15.2';Size=123};ReleaseUrl='https://github.com/fixture/WinTune/releases/tag/v0.15.2'}}
function Read-Host {param($Prompt);$script:Trace.Add('Confirm');return $env:WINTUNE_TEST_ANSWER}
function Get-UserCommandRegistration {[pscustomobject]@{AppExists=$false}}
function Install-DistributionUpdate($Info,$Root,$Confirmed,$Cancellation,$Config){$script:Trace.Add('Install');return [pscustomobject]@{Path='C:\fixture\apps\current'}}
function Register-WinTuneCommand($Path,$Root,$Confirmed){$script:Trace.Add('Register');[pscustomobject]@{Status='Registered'}}
function Get-WinTuneSetupText($Version,$Root){return 'Set up wintune and User PATH'}
function Start-VerifiedWinTuneApp($Path,$Version){$script:Trace.Add($(if($env:WINTUNE_TEST_CURRENT){'Launch:'+$Version}else{'Launch'}))}
'@
$template=[IO.File]::ReadAllText("$PSScriptRoot/Bootstrapper.template.ps1")
$code=$template.Replace('__TRUST_BASE64__',[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{}'))).Replace('__DISTRIBUTION_CORE__',$prelude).Replace('__COMMAND_REGISTRATION__','').Replace('__SOURCE_COMMAND_REGISTRATION__','').Replace('__SETUP_CORE__','')
$bootstrap=Join-Path $test 'bootstrap.ps1';[IO.File]::WriteAllText($bootstrap,$code,[Text.UTF8Encoding]::new($true))
$savedAnswer=$env:WINTUNE_TEST_ANSWER
$savedCurrent=$env:WINTUNE_TEST_CURRENT
try{
    $env:WINTUNE_TEST_CURRENT=$null
    $env:WINTUNE_TEST_ANSWER='NO';. $bootstrap -Setup
    Check (($script:Trace -join ',') -eq 'Metadata,Confirm') 'Cancel first online setup stops before ZIP/registration/launch'
    $env:WINTUNE_TEST_ANSWER='DONG Y';. $bootstrap -Setup
    Check (($script:Trace -join ',') -eq 'Metadata,Confirm,Install,Register,Launch') 'Online setup confirms exactly once and registers before opening'
    . $bootstrap -Setup -CheckOnly
    Check (($script:Trace -join ',') -eq 'Metadata') 'CheckOnly with Setup remains metadata only, no confirmation or registration'
    $env:WINTUNE_TEST_CURRENT='1';. $bootstrap -Setup
    Check (($script:Trace -join ',') -eq 'Metadata,Confirm,VerifySignedCache,Register,Launch:0.16.0') 'Cached package must pass signed verification before registration or launch (verification mocked here)'
} finally {$env:WINTUNE_TEST_ANSWER=$savedAnswer;$env:WINTUNE_TEST_CURRENT=$savedCurrent}
Write-Output "SETUP TESTS PASSED: $pass; mocked install/PATH/process launch only, no real Windows changes."
