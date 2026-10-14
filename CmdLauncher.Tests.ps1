#Requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$Prepared,[switch]$LiveCheckOnly)
$ErrorActionPreference='Stop'
$count=0
$testStarted=Get-Date
$defenderBefore=$null;$defenderAfter=$null
if ($LiveCheckOnly) {$defenderBefore=Get-MpComputerStatus -ErrorAction Stop}
function Check([bool]$Condition,[string]$Message) {if (-not $Condition) {throw $Message};$script:count++}
$prepared=(Resolve-Path -LiteralPath $Prepared).Path
$info=Get-Content -LiteralPath (Join-Path $Prepared 'PREPARED.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$entry=Join-Path $Prepared 'Source/docs/run.cmd'
$code=[IO.File]::ReadAllText($entry)
$body=@($code -split '\r?\n' | Where-Object {$_ -notmatch '^rem\b'}) -join "`n"
$bytes=[IO.File]::ReadAllBytes($entry)
Check (($bytes | Where-Object {$_ -gt 127} | Measure-Object).Count -eq 0) 'Native batch entry must be ASCII without BOM.'
Check ($code.Contains($info.BootstrapperURL) -and $code.Contains($info.BootstrapperSHA256)) 'The batch must pin the prepared versioned bootstrapper.'
Check ($body -notmatch '(?i)\biex\b|Invoke-Expression|EncodedCommand|Set-MpPreference|Add-MpPreference|Set-ExecutionPolicy|RegisterCommand') 'Batch must not evaluate remote text or change security/PATH.'
Check ($code.IndexOf('Get-FileHash') -lt $code.IndexOf('-File "%WINTUNE_BOOTSTRAP_FILE%"')) 'Hash must be checked before executing the file.'
Check ($code.Contains('if errorlevel 1 goto verification_error')) 'Hash errors must prevent execution.'
Check ($code.Contains('--fail') -and $code.Contains('--proto =https') -and $code.Contains('--proto-redir =https') -and $code.Contains('--max-filesize 1048576')) 'Download must fail on HTTP errors and enforce HTTPS/size limits.'
Check ($body -notmatch '(?i)rmdir\s+/s|\brd\s+/s|del\s+.*\*') 'Cleanup must not recursively remove directories or use wildcards.'
Check ($code.Contains('setlocal DisableDelayedExpansion')) 'Temporary paths containing ! must not be expanded.'
$test=Join-Path $PSScriptRoot ('.test-runs/cmd52-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$temp=Join-Path $test 'Temp có dấu & !'
$null=New-Item -ItemType Directory -Path $temp -Force
$cmd=Join-Path $env:WINDIR 'System32/cmd.exe'
$ps=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
$previousTemp=$env:TEMP
$previousMarker=$env:WINTUNE_CMD_TEST_MARKER
$previousFixture=$env:WINTUNE_CMD_TEST_FIXTURE
function Run-Batch([string]$Path,[string]$Arguments='') {
    $prior=$ErrorActionPreference
    try {$ErrorActionPreference='Continue';$output=& $cmd /d /s /c ('""'+$Path+'" '+$Arguments+'"') 2>&1;$exit=$LASTEXITCODE} finally {$ErrorActionPreference=$prior}
    return [pscustomobject]@{ExitCode=$exit;Output=($output|Out-String).Trim()}
}
try {
    $env:TEMP=$temp
    $badArgs=Run-Batch $entry '--unexpected'
    Check ($badArgs.ExitCode -eq 64) 'Unknown arguments must stop before downloading/executing.'
    Check (@(Get-ChildItem -LiteralPath $temp -Force).Count -eq 0) 'Cancelled/invalid invocation must leave no work directory.'
    # A harmless fixture verifies native CMD/PS behavior; no Windows/app action.
    $fixture=Join-Path $test 'child.ps1'
    $env:WINTUNE_CMD_TEST_FIXTURE=$fixture
    $env:WINTUNE_CMD_TEST_MARKER=Join-Path $test 'marker.json'
    $fixtureText='param([switch]$Confirmed,[switch]$CheckOnly) [pscustomobject]@{Confirmed=[bool]$Confirmed;CheckOnly=[bool]$CheckOnly;Apartment=[Threading.Thread]::CurrentThread.ApartmentState.ToString()}|ConvertTo-Json|Set-Content -LiteralPath $env:WINTUNE_CMD_TEST_MARKER -Encoding UTF8'
    [IO.File]::WriteAllText($fixture,$fixtureText,[Text.UTF8Encoding]::new($true))
    $fixtureHash=(Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
    $fixtureBatch=$code.Replace($info.BootstrapperSHA256,$fixtureHash)
    $downloadLine=@($fixtureBatch -split '\r?\n' | Where-Object {$_ -like '"%wt_curl%"*'})[0]
    $copyLine='"%wt_ps%" -NoProfile -Command "Copy-Item -LiteralPath $env:WINTUNE_CMD_TEST_FIXTURE -Destination $env:WINTUNE_BOOTSTRAP_FILE -ErrorAction Stop"'
    $fixtureBatch=$fixtureBatch.Replace($downloadLine,$copyLine)
    $fixturePath=Join-Path $test 'fixture.cmd'
    [IO.File]::WriteAllText($fixturePath,$fixtureBatch,[Text.Encoding]::ASCII)
    $run=Run-Batch $fixturePath '--check-only'
    Check ($run.ExitCode -eq 0) ('Native CMD fixture failed: '+$run.Output)
    $marker=Get-Content -LiteralPath $env:WINTUNE_CMD_TEST_MARKER -Raw | ConvertFrom-Json
    Check ($marker.CheckOnly -and -not $marker.Confirmed -and $marker.Apartment -eq 'STA') 'Check-only must reach a fixed STA child without confirming setup/app launch.'
    Check (@(Get-ChildItem -LiteralPath $temp -Force).Count -eq 0) 'Only this invocation temporary file/directory must be cleaned.'
    Remove-Item -LiteralPath $env:WINTUNE_CMD_TEST_MARKER
    $run=Run-Batch $fixturePath
    Check ($run.ExitCode -eq 0) ('Native confirmed fixture failed: '+$run.Output)
    $marker=Get-Content -LiteralPath $env:WINTUNE_CMD_TEST_MARKER -Raw | ConvertFrom-Json
    Check ($marker.Confirmed -and -not $marker.CheckOnly) 'Default mode must confirm the requested app opening without registering a command.'
    Remove-Item -LiteralPath $env:WINTUNE_CMD_TEST_MARKER
    $badHashPath=Join-Path $test 'bad-hash.cmd'
    [IO.File]::WriteAllText($badHashPath,$fixtureBatch.Replace($fixtureHash,('0'*64)),[Text.Encoding]::ASCII)
    $run=Run-Batch $badHashPath '--check-only'
    Check ($run.ExitCode -eq 3 -and -not (Test-Path -LiteralPath $env:WINTUNE_CMD_TEST_MARKER)) 'Mismatched hash must stop before child execution.'
    Check (@(Get-ChildItem -LiteralPath $temp -Force).Count -eq 0) 'Checksum failure cleanup must stay inside its invocation directory.'
    if ($LiveCheckOnly) {
        $nativeRoot=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'WinTuneVI'
        $pointer=Join-Path $nativeRoot 'current.txt'
        $before=if ([IO.File]::Exists($pointer)) {[IO.File]::ReadAllText($pointer)} else {''}
        $beforePath=[Environment]::GetEnvironmentVariable('PATH','User')
        $live=Run-Batch $entry '--check-only'
        $live.Output | Set-Content -LiteralPath (Join-Path $test 'live-cmd.log') -Encoding UTF8
        Check ($live.ExitCode -eq 0) ('Live metadata check failed; stop instead of changing security: '+$live.Output)
        $after=if ([IO.File]::Exists($pointer)) {[IO.File]::ReadAllText($pointer)} else {''}
        Check ($before -ceq $after -and $beforePath -ceq [Environment]::GetEnvironmentVariable('PATH','User')) 'Metadata-only CMD must not change app pointer or User PATH.'
        Check (@(Get-ChildItem -LiteralPath $temp -Force).Count -eq 0) 'Live invocation temporary file/directory must be cleaned.'
        $newAlerts=@(Get-MpThreatDetection -ErrorAction Stop | Where-Object {$_.InitialDetectionTime -ge $testStarted})
        Check ($newAlerts.Count -eq 0) 'Defender reported a new detection during the test; stop and investigate.'
        $defenderAfter=Get-MpComputerStatus -ErrorAction Stop
        Check ($defenderBefore.AntivirusEnabled -and $defenderBefore.RealTimeProtectionEnabled -and $defenderAfter.AntivirusEnabled -and $defenderAfter.RealTimeProtectionEnabled) 'Defender and real-time protection must remain enabled before and after the tests.'
    }
    $record=[ordered]@{Assertions=$count;NativeCmdTested=$true;HashMismatchBlockedExecution=$true;UnicodeSpaceAmpersandExclamationTempTested=$true;LiveMetadataOnlyPassed=[bool]$LiveCheckOnly;DefenderAndRealTimeProtectionVerified=[bool]$LiveCheckOnly;AppExecuted=$false;WindowsSettingsChanged=$false;UserPathChanged=$false;NativePointerChanged=$false;DefenderExclusionsAdded=$false;UntrustedTextEvaluated=$false;EntrySHA256=(Get-FileHash -LiteralPath $entry).Hash;Scope='Native CMD, harmless fixture and optional public bootstrapper CheckOnly; not a fresh-PC full app launch'}
    $record | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'evidence/cmd-launcher-v0152.json') -Encoding UTF8
    $record | ConvertTo-Json
} finally {$env:TEMP=$previousTemp;$env:WINTUNE_CMD_TEST_MARKER=$previousMarker;$env:WINTUNE_CMD_TEST_FIXTURE=$previousFixture}
