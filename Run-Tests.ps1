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
foreach ($name in @('Environment.Check.ps1','Core.Tests.ps1','Core.ExtendedTests.ps1','Catalog.Verify.ps1','Actions.Tests.ps1','Tools.Tests.ps1','Tools.Worker.Tests.ps1','Monitor.Tests.ps1','Theme.Tests.ps1','Usability.Core.Tests.ps1','Registry.Typed.Tests.ps1','Coverage.Tests.ps1','Distribution.Tests.ps1','Release.Author.Tests.ps1','SourceCommand.Tests.ps1','Setup.Tests.ps1','QuickLauncher.Tests.ps1','Launcher.Tests.ps1')) {
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
