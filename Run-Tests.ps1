#Requires -Version 5.1
$ErrorActionPreference='Stop'
$hostExe=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$evidence=Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$errors=@()
foreach ($file in @(Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object Extension -in @('.ps1','.psm1'))) {
    $tokens=$null; $parseErrors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$parseErrors)
    $errors+=@($parseErrors)
}
if ($errors.Count -gt 0) { throw ($errors | Out-String) }
'PASS: All project PowerShell scripts parsed by Windows PowerShell 5.1' | Set-Content "$evidence/parser.log" -Encoding UTF8
$fullOutput=& $hostExe -NoProfile -STA -ExecutionPolicy Bypass -File "$PSScriptRoot/FullTweaks.Tests.ps1" 2>&1
$fullCode=$LASTEXITCODE;$fullOutput | Set-Content "$evidence/FullTweaks.Tests.ps1.log" -Encoding UTF8
if ($fullCode -ne 0) {throw 'Failed full-tweaks simulation tests. See evidence/FullTweaks.Tests.ps1.log.'}
Write-Output ($fullOutput | Select-Object -Last 1)
$nativeFullOutput=& $hostExe -NoProfile -STA -ExecutionPolicy Bypass -File "$PSScriptRoot/FullTweaks.Native.Tests.ps1" 2>&1
$nativeFullCode=$LASTEXITCODE;$nativeFullOutput | Set-Content "$evidence/FullTweaks.Native.Tests.ps1.log" -Encoding UTF8
if ($nativeFullCode -ne 0) {throw 'Failed full-tweaks native adapter fixtures. See evidence/FullTweaks.Native.Tests.ps1.log.'}
Write-Output ($nativeFullOutput | Select-Object -Last 1)
$debloatOutput=& $hostExe -NoProfile -STA -ExecutionPolicy Bypass -File "$PSScriptRoot/FullTweaks.Debloat.Tests.ps1" 2>&1
$debloatCode=$LASTEXITCODE;$debloatOutput | Set-Content "$evidence/FullTweaks.Debloat.Tests.ps1.log" -Encoding UTF8
if ($debloatCode -ne 0) {throw 'Failed Win11Debloat mapping, choice or adapter tests. See evidence/FullTweaks.Debloat.Tests.ps1.log.'}
Write-Output ($debloatOutput | Select-Object -Last 1)
$uxOutput=& $hostExe -NoProfile -STA -ExecutionPolicy RemoteSigned -File "$PSScriptRoot/UX.Core.Tests.ps1" 2>&1
$uxCode=$LASTEXITCODE;$uxOutput | Set-Content "$evidence/UX.Core.Tests.ps1.log" -Encoding UTF8
if ($uxCode -ne 0) {throw 'Failed usability reader/action fixtures. See evidence/UX.Core.Tests.ps1.log.'}
Write-Output ($uxOutput | Select-Object -Last 1)
$wizOutput=& $hostExe -NoProfile -STA -ExecutionPolicy RemoteSigned -File "$PSScriptRoot/WizTree.Tests.ps1" 2>&1
$wizCode=$LASTEXITCODE;$wizOutput | Set-Content "$evidence/WizTree.Tests.ps1.log" -Encoding UTF8
if ($wizCode -ne 0) {throw 'Failed WizTree integration fixtures. See evidence/WizTree.Tests.ps1.log.'}
Write-Output ($wizOutput | Select-Object -Last 1)
$scanOutput=& $hostExe -NoProfile -STA -ExecutionPolicy RemoteSigned -File "$PSScriptRoot/WizTree.Launch.Tests.ps1" 2>&1
$scanCode=$LASTEXITCODE;$scanOutput | Set-Content "$evidence/WizTree.Launch.Tests.ps1.log" -Encoding UTF8
if ($scanCode -ne 0) {throw 'Failed WizTree direct-drive launch fixtures. See evidence/WizTree.Launch.Tests.ps1.log.'}
Write-Output ($scanOutput | Select-Object -Last 1)
$statusOutput=& $hostExe -NoProfile -STA -ExecutionPolicy RemoteSigned -File "$PSScriptRoot/UpdateStatus.Tests.ps1" 2>&1
$statusCode=$LASTEXITCODE;$statusOutput | Set-Content "$evidence/UpdateStatus.Tests.ps1.log" -Encoding UTF8
if ($statusCode -ne 0) {throw 'Failed update status fixtures. See evidence/UpdateStatus.Tests.ps1.log.'}
Write-Output ($statusOutput | Select-Object -Last 1)
foreach ($name in @('Care.Core.Tests.ps1','FullTweaks.Profiles.Tests.ps1','Environment.Check.ps1','Core.Tests.ps1','Core.ExtendedTests.ps1','Catalog.Verify.ps1','Actions.Tests.ps1','Tools.Tests.ps1','Tools.Worker.Tests.ps1','Monitor.Tests.ps1','Theme.Tests.ps1','Usability.Core.Tests.ps1','Registry.Typed.Tests.ps1','Coverage.Tests.ps1','Distribution.Tests.ps1','Release.Author.Tests.ps1','SourceCommand.Tests.ps1','Setup.Tests.ps1','QuickLauncher.Tests.ps1','Launcher.Tests.ps1')) {
    $output=& $hostExe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $name) 2>&1
    $code=$LASTEXITCODE
    $output | Set-Content (Join-Path $evidence ($name+'.log')) -Encoding UTF8
    if ($code -ne 0) { throw "Failed: $name. See evidence logs." }
    if ($name -eq 'Environment.Check.ps1') { Write-Output 'ENVIRONMENT CHECK PASSED: Windows PowerShell 5.1 STA, WPF available.' }
    else { Write-Output ($output | Select-Object -Last 1) }
}
$output=& $hostExe -NoProfile -STA -ExecutionPolicy Bypass -File "$PSScriptRoot/WinTune.ps1" -SelfTest 2>&1
$code=$LASTEXITCODE
$output | Set-Content "$evidence/UI.SelfTests.log" -Encoding UTF8
if ($code -ne 0) { throw 'Failed WPF self-tests. See evidence/UI.SelfTests.log.' }
Write-Output ($output | Select-Object -Last 1)
if ((Get-Content "$evidence/Launcher.Tests.ps1.log" -Raw) -match 'UNVERIFIED') {Write-Output 'All runnable PowerShell/WPF/mock checks passed; compiled fixture execution remains unverified due to Application Control. See launcher log.'} else {Write-Output 'All automated checks passed. Registry/environment writes were simulated; native PATH/Win+R and production Releases are unverified.'}
