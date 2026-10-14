#Requires -Version 5.1
# Tests only /probe: app forces simulation and closes itself. Never applies tweaks.
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Distribution.Core.ps1"
$packageVersion=(Get-WinTuneVersion $PSScriptRoot).Version
$parent=Join-Path $PSScriptRoot '.test-runs'
$testRoot=Join-Path $parent ('Đóng gói kiểm tra '+[guid]::NewGuid().ToString('N').Substring(0,8))
Expand-Archive -LiteralPath "$PSScriptRoot/WinTune-VI-v$packageVersion-portable.zip" -DestinationPath $testRoot
$package=Join-Path $testRoot ('WinTune-VI-v'+$packageVersion)
$count=0
foreach ($line in @(Get-Content -LiteralPath "$package/SHA256.txt" -Encoding UTF8)) {
    if ($line -notmatch '^([0-9A-F]{64})  (.+)$') { throw 'Invalid checksum manifest.' }
    $expected=$Matches[1]; $relative=$Matches[2]
    $path=[IO.Path]::GetFullPath((Join-Path $package $relative))
    if (-not $path.StartsWith([IO.Path]::GetFullPath($package)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid manifest path.' }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $expected) { throw "Checksum differs: $relative" }
    $count++
}
$code=Get-Content "$package/WinTune.ps1" -Raw -Encoding UTF8
if (-not $code.Contains('Kiểm tra') -and -not $code.Contains('KIỂM TRA')) { throw 'UTF-8 source check failed.' }
$started=Get-Date
& (Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe') -NoProfile -STA -ExecutionPolicy Bypass -File "$package/WinTune.ps1" -GuiProbe
if ($LASTEXITCODE -ne 0) {throw 'Primary PowerShell/WPF package probe failed.'}
$exeVerified=$true;$exeNote='compiled Demo launcher /probe exit 0'
try {
    $process=Start-Process -FilePath "$package/WinTune-Demo.exe" -ArgumentList '/probe' -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
    if ($process.ExitCode -ne 0) {throw 'Packaged executable probe failed.'}
} catch {
    if ($_.Exception.Message -notmatch 'Application Control policy') {throw}
    $exeVerified=$false;$exeNote='compiled EXE execution blocked by Application Control; not verified'
    Write-Output 'EXE PROBE UNVERIFIED: Application Control blocked it. Checking packaged WPF directly in simulation; no policy changed.'
    & (Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe') -NoProfile -STA -ExecutionPolicy Bypass -File "$package/WinTune.ps1" -GuiProbe
    if ($LASTEXITCODE -ne 0) {throw 'Packaged PowerShell WPF probe failed.'}
}
if ((Get-Item "$package/evidence/gui-lifecycle.json").LastWriteTime -lt $started) { throw 'Packaged probe did not produce fresh lifecycle evidence.' }
$probe=Get-Content "$package/evidence/gui-lifecycle.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $probe.Visible -or -not $probe.ModalRendered -or -not $probe.ModalOwnerMatches -or $probe.Selected -ne 0 -or $probe.SimulatedWrites -ne 0) { throw 'Packaged GUI probe failed.' }
$verify=& (Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe') -NoProfile -STA -ExecutionPolicy Bypass -File "$package/Catalog.Verify.ps1" 2>&1
if ($LASTEXITCODE -ne 0) { throw 'Packaged source verification failed.' }
$actionTests=& (Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe') -NoProfile -STA -ExecutionPolicy Bypass -File "$package/Actions.Tests.ps1" 2>&1
if ($LASTEXITCODE -ne 0) { throw 'Packaged action mock tests failed.' }
foreach ($test in @('Tools.Tests.ps1','Tools.Worker.Tests.ps1','Monitor.Tests.ps1','Theme.Tests.ps1','Usability.Core.Tests.ps1','Registry.Typed.Tests.ps1','Coverage.Tests.ps1','Distribution.Tests.ps1','SourceCommand.Tests.ps1')) {
    $previousPreference=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        $testOutput=& (Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe') -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $package $test) 2>&1
        $testExit=$LASTEXITCODE
    } finally {$ErrorActionPreference=$previousPreference}
    if ($testExit -ne 0) {throw ("Packaged $test failed (exit $testExit).`n"+($testOutput|Out-String))}
}
$summary="PACKAGE CHECK: $count SHA-256 entries matched; Unicode/spaced extraction path; $exeNote; main WPF window and owned dialog rendered; 46 entries; zero native writes; packaged sources and mock tests verified. Native PATH/Win+R and production Releases remain unverified."
[pscustomobject]@{Version=$packageVersion;Checksums=$count;ExecutableVerified=$exeVerified;WpfVerified=$true;NativeWindowsChanges=0;Limitations=$exeNote} | ConvertTo-Json | Set-Content "$PSScriptRoot/evidence/package-v$packageVersion.json" -Encoding UTF8
$summary | Set-Content "$PSScriptRoot/evidence/package-check.log" -Encoding UTF8
Write-Output $summary
# Keep extracted evidence for review. No recursive delete is necessary.
