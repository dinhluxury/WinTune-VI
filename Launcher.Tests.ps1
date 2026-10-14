#Requires -Version 5.1
# Compiled executables against workspace fixtures; no UI/system modifications.
$ErrorActionPreference='Stop';$pass=0
function Check($Ok,$Name) {if (-not $Ok) {throw "LAUNCHER FAILED: $Name"};$script:pass++;Write-Output "PASS LAUNCHER: $Name"}
$root=Join-Path $PSScriptRoot ('.test-runs/launcher-'+[guid]::NewGuid().ToString('N').Substring(0,6));$old=Join-Path $root 'old';$new=Join-Path $root 'new';$null=New-Item -ItemType Directory -Path $old,$new
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (-not (Test-Path -LiteralPath "$PSScriptRoot/baseline-v0.14/Launcher.cs")) {Write-Output 'LAUNCHER TESTS: baseline unavailable in portable; use packaged /probe check.';return}
foreach ($entry in @(@($old,"$PSScriptRoot/baseline-v0.14/Launcher.cs"),@($new,"$PSScriptRoot/Launcher.cs"))) {
 $sourceFile=[IO.Path]::GetFullPath($entry[1]);$outputFile=Join-Path $entry[0] 'WinTune-Demo.exe'
 & $compiler /nologo /target:winexe /platform:x64 /reference:System.Windows.Forms.dll ("/out:"+$outputFile) $sourceFile
 if ($LASTEXITCODE -ne 0) {throw 'Cannot compile launcher fixture.'}
 $scriptText=@'
param([switch]$Simulation,[switch]$GuiProbe,[switch]$Updates)
if($GuiProbe) {exit 0}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'child-started.txt'),'started')
$deadline=[DateTime]::UtcNow.AddSeconds(12)
while(-not [IO.File]::Exists((Join-Path $PSScriptRoot 'release.flag')) -and [DateTime]::UtcNow -lt $deadline) {Start-Sleep -Milliseconds 50}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'child-finished.txt'),'fixture child completed')
'@
 [IO.File]::WriteAllText((Join-Path $entry[0] 'WinTune.ps1'),$scriptText,(New-Object Text.UTF8Encoding($true)))
}
$oldProcess=$null;$oldPeak=$null;$baselineLimitation=''
try {$oldProcess=Start-Process -FilePath (Join-Path $old 'WinTune-Demo.exe') -WindowStyle Hidden -PassThru -ErrorAction Stop}
catch {
 if ($_.Exception.Message -notmatch 'Application Control policy') {throw}
 $baselineLimitation='Application Control blocked the newly compiled baseline fixture. No policy changed.'
 Write-Output ('BASELINE COMPARISON UNVERIFIED: '+$baselineLimitation)
}
$watch=[Diagnostics.Stopwatch]::StartNew()
try {$newProcess=Start-Process -FilePath (Join-Path $new 'WinTune-Demo.exe') -WindowStyle Hidden -PassThru -ErrorAction Stop}
catch {
 if ($_.Exception.Message -notmatch 'Application Control policy') {throw}
 [IO.File]::WriteAllText((Join-Path $old 'release.flag'),'release')
 if ($null -ne $oldProcess) {$oldProcess.WaitForExit();$oldProcess.Dispose()}
 [pscustomobject]@{Scope='Compiled fixture execution blocked';Compiled=$true;ExecutionVerified=$false;Limitation=$_.Exception.Message;WindowsChanges=0} | ConvertTo-Json | Set-Content "$PSScriptRoot/evidence/launcher-lifecycle-v015.json" -Encoding UTF8
 Write-Output 'LAUNCHER EXECUTION UNVERIFIED: Application Control blocked the compiled fixture; no policy bypass/change. Direct WPF and package probe checks are separate.'
 return
}
$newExited=$newProcess.WaitForExit(1000);$watch.Stop()
if ($null -ne $oldProcess) {for ($i=0;$i -lt 40 -and -not (Test-Path (Join-Path $old 'child-started.txt'));$i++) {Start-Sleep -Milliseconds 100}}
Check $newExited 'Default launcher releases its wrapper while the child remains running'
if ($null -ne $oldProcess) {Check (-not $oldProcess.HasExited) 'Baseline wrapper remains waiting for its fixture child';$oldPeak=$oldProcess.PeakWorkingSet64}
[IO.File]::WriteAllText((Join-Path $old 'release.flag'),'release');[IO.File]::WriteAllText((Join-Path $new 'release.flag'),'release')
if ($null -ne $oldProcess) {$oldProcess.WaitForExit()}
Check ($newProcess.ExitCode -eq 0) 'Current default wrapper launches the controlled PowerShell fixture'
for ($i=0;$i -lt 30 -and -not (Test-Path (Join-Path $new 'child-finished.txt'));$i++) {Start-Sleep -Milliseconds 100}
Check (Test-Path (Join-Path $new 'child-finished.txt')) 'Releasing Process objects does not kill the PowerShell child'
$probe=Start-Process -FilePath (Join-Path $new 'WinTune-Demo.exe') -ArgumentList /probe -WindowStyle Hidden -Wait -PassThru
Check ($probe.ExitCode -eq 0) 'Probe mode continues waiting and propagates its result'
[IO.File]::WriteAllText((Join-Path $new 'WinTune.ps1'),'param([switch]$Simulation,[switch]$GuiProbe) exit 7')
$failed=Start-Process -FilePath (Join-Path $new 'WinTune-Demo.exe') -ArgumentList /probe -WindowStyle Hidden -Wait -PassThru
Check ($failed.ExitCode -eq 7 -and (Test-Path (Join-Path $new 'launcher-error.log'))) 'Failed probe returns an error and log without a blocking dialog'
$install=Join-Path $root 'install';$folder=Join-Path $install 'launcher';$app=Join-Path $install 'apps/v0.15-fixture';$null=New-Item -ItemType Directory -Path $folder,$app
[IO.File]::WriteAllText((Join-Path $app 'WinTune.ps1'),'fixture; never executed')
[IO.File]::WriteAllText((Join-Path $install 'current.txt'),$app)
& $compiler /nologo /target:winexe /platform:x64 /reference:System.Windows.Forms.dll ("/out:"+$folder+'\wintune.exe') (Join-Path $PSScriptRoot 'CommandRouter.cs')
if ($LASTEXITCODE -ne 0) {throw 'Cannot compile command resolver.'}
$info=New-Object Diagnostics.ProcessStartInfo (Join-Path $folder 'wintune.exe'),'/resolve';$info.UseShellExecute=$false;$info.RedirectStandardOutput=$true;$info.CreateNoWindow=$true
$p=[Diagnostics.Process]::Start($info);$resolved=$p.StandardOutput.ReadToEnd().Trim();$p.WaitForExit()
Check ($p.ExitCode -eq 0 -and $resolved -ceq $app) 'Compiled command resolver reads the stable per-user current pointer'
$p.Dispose();$newProcess.Dispose();if ($null -ne $oldProcess) {$oldProcess.Dispose()};$probe.Dispose();$failed.Dispose()
[pscustomobject]@{Scope='Controlled child fixture; not a WPF startup/FPS/RAM benchmark';NewWrapperExitMs=$watch.ElapsedMilliseconds;OldWrapperPeakBytes=$oldPeak;BaselineLimitation=$baselineLimitation;DefaultWrapperStaysAlive=$false;WindowsChanges=0} | ConvertTo-Json | Set-Content "$PSScriptRoot/evidence/launcher-lifecycle-v015.json" -Encoding UTF8
Write-Output "LAUNCHER TESTS PASSED: $pass; compiled wrappers/resolver; no PATH registration or Windows changes."
