#Requires -Version 5.1
param([switch]$PublicRelease)
$ErrorActionPreference='Stop'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Không có trình biên dịch .NET Framework 64-bit.' }
& $compiler /nologo /target:winexe /platform:x64 /reference:System.Windows.Forms.dll "/out:$PSScriptRoot\WinTune-VI.exe" "$PSScriptRoot\Launcher.cs"
if ($LASTEXITCODE -ne 0) { throw 'Biên dịch launcher thất bại.' }
Copy-Item -LiteralPath "$PSScriptRoot/WinTune-VI.exe" -Destination "$PSScriptRoot/WinTune-Demo.exe" -Force
Write-Output 'Built real .NET Framework launcher; WPF application remains auditable PowerShell source.'
& $compiler /nologo /target:winexe /platform:x64 /reference:System.Windows.Forms.dll "/out:$PSScriptRoot\Wintune.Command.exe" "$PSScriptRoot\CommandRouter.cs"
if ($LASTEXITCODE -ne 0) {throw 'Biên dịch resolver lệnh wintune thất bại.'}
. "$PSScriptRoot/Distribution.Core.ps1"
$packageVersion=(Get-WinTuneVersion $PSScriptRoot).Version
$releaseRoot=Join-Path $PSScriptRoot 'release'
$buildRoot=Join-Path $releaseRoot ('build-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6))
$portable=Join-Path $buildRoot ('WinTune-VI-v'+$packageVersion)
New-Item -ItemType Directory -Path $portable -Force | Out-Null
$files=@('WinTune-VI.exe','WinTune-Demo.exe','WinTune.ps1','Core.ps1','Simulation.ps1','MainWindow.xaml','features.json','Mo-WinTune.cmd','Mo-Ban-Mo-Phong.cmd','wintune.cmd','HUONG-DAN.txt','THU-THUC-TE.txt','LICENSE-Win11Debloat.txt','TIEN-DO.md','KIEM-THU.md','UI.SelfTests.ps1','UI.GuiProbe.ps1','Core.Tests.ps1','Core.ExtendedTests.ps1','Run-Tests.ps1','Catalog.Verify.ps1','Environment.Check.ps1','RealRead.Check.ps1','Launcher.cs','Build-Package.ps1')
foreach ($file in $files) {
    if ($PublicRelease -and $file -in @('TIEN-DO.md','THU-THUC-TE.txt')) {continue}
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $portable $file) -Force
}
foreach ($file in @('Diagnostics.UI.ps1','Restore.UI.ps1','Logs.Core.ps1','Logs.UI.ps1','Links.UI.ps1','RepairSummary.Core.ps1','Usability.Core.Tests.ps1','Registry.Typed.Tests.ps1','Usability.UI.Tests.ps1','app-labels.json')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
foreach ($file in @('Monitor.Native.cs','Monitor.Core.ps1','Monitor.UI.ps1','Monitor.Tests.ps1','Monitor.UI.Tests.ps1','Monitor.ReadCheck.ps1','UI.MonitorReadProbe.ps1','CHANGELOG-v0.6.md')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
foreach ($file in @('Theme.Core.ps1','Theme.UI.ps1','Theme.Native.cs','Theme.Tests.ps1','Theme.UI.Tests.ps1','Theme.ReadCheck.ps1','CHANGELOG-v0.7.md')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
foreach ($file in @('FeatureBoard.UI.ps1','Board.UI.Tests.ps1','Hover.UI.Tests.ps1','CHANGELOG-v0.8.md','CHANGELOG-v0.9.md','CHANGELOG-v0.10.md')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
foreach ($file in @('Actions.Core.ps1','Actions.UI.ps1','Actions.Tests.ps1','Actions.UI.Tests.ps1','Actions.ReadCheck.ps1','app-catalog.json','GIAM-RAM-VA-GO-APP.txt','LICENSE-WinUtil.txt','Package.Check.ps1')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $portable $file) -Force }
foreach ($file in @('Tools.Core.ps1','Tools.UI.ps1','Tools.Worker.ps1','Tools.Tests.ps1','Tools.Worker.Tests.ps1','Tools.UI.Tests.ps1','Tools.ReadCheck.ps1','Profiles.ps1','profiles.json','software-catalog.json','Review-Matrix.ps1','FEATURE_MATRIX.md','README.md','CHANGELOG-v0.11.md','CHANGELOG-v0.12.md','CHANGELOG-v0.13.md','Software.UI.ps1','Coverage.Tests.ps1','Coverage.UI.Tests.ps1','feature-coverage.json')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
foreach ($file in @('Software.Layout.Tests.ps1','CHANGELOG-v0.14.md')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
if (-not $PublicRelease) {
    foreach ($file in @('VM.Check.ps1','VM.JournalReload.ps1','VM.Verify.ps1','Kiem-Thu-May-Ao.cmd','Phuc-Hoi-Kiem-Thu.cmd','KIEM-THU-TU-DONG.txt')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $portable $file) -Force }
}
Copy-Item -LiteralPath "$PSScriptRoot/LICENSE-Microsoft-winget-dsc.txt" -Destination $portable -Force
foreach ($file in @('Distribution.Core.ps1','Distribution.Runtime.psm1','Distribution.Tests.ps1','Launcher.Tests.ps1','CommandRegistration.ps1','CommandRouter.cs','Wintune.Command.exe','Register-WinTune.ps1','version.json','release-config.json','DISTRIBUTION.md','CHANGELOG-v0.15.md')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
foreach ($file in @('New-ReleaseSigningKey.ps1','Configure-Release.ps1','Sign-Release.ps1','Build-Distribution.ps1','Bootstrapper.template.ps1','Release.Author.Tests.ps1','Prepare-GitHub.ps1','PUBLISHING.md','.gitignore','.gitattributes')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force
}
foreach ($file in @('SourceCommandRegistration.ps1','CommandRouter.ps1','Wintune.Registered.cmd','SourceCommand.Tests.ps1','CHANGELOG-v0.15.1.md')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
foreach ($file in @('Setup.Core.ps1','Install-WinTune.ps1','Cai-WinTune.cmd','Setup.Tests.ps1','CHANGELOG-v0.15.2.md')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
foreach ($file in @('QuickLauncher.template.ps1','QuickLauncher.Tests.ps1')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
foreach ($file in @('CmdLauncher.template.cmd','Build-CmdLauncher.ps1','CmdLauncher.Tests.ps1')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Pages.Serving.Tests.ps1') -Destination $portable -Force
foreach ($file in @('Care.Core.ps1','Care.UI.ps1','Care.Core.Tests.ps1','Care.UI.Tests.ps1','CHANGELOG-v0.16.2.md','KIEM-THU-v0.16.2.md','FullTweaks.Profiles.ps1','FullTweaks.Profiles.Tests.ps1','UnifiedTweaks.UI.ps1','UnifiedTweaks.UI.Tests.ps1','CHANGELOG-v0.16.1.md','KIEM-THU-v0.16.1.md','FullTweaks.json','FullTweaks.Core.ps1','FullTweaks.Native.ps1','FullTweaks.UI.ps1','FullTweaks.Worker.ps1','FullTweaks.Tests.ps1','FullTweaks.UI.Tests.ps1','TINH-CHINH-DAY-DU.md','CHANGELOG-v0.16.0.md')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
Copy-Item -LiteralPath "$PSScriptRoot/FullTweaks.Native.Tests.ps1" -Destination $portable -Force
foreach ($file in @('FullTweaks.Debloat.ps1','FullTweaks.Debloat.Tests.ps1')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
Copy-Item -LiteralPath "$PSScriptRoot/KIEM-THU-v0.16.0.md" -Destination $portable -Force
foreach ($file in @('CompactGroupsPanel.cs','Copilot.Core.ps1','Copilot.UI.ps1','Power.Explanations.ps1','UX.Core.Tests.ps1','UX.UI.Tests.ps1','WizTree.Core.ps1','WizTree.Launch.ps1','WizTree.UI.ps1','WizTree.Tests.ps1','WizTree.Launch.Tests.ps1','Storage.Navigation.Tests.ps1','WIZTREE.md','UpdateStatus.Core.ps1','UpdateStatus.Tests.ps1')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $portable -Force}
if ($PublicRelease) {
    $publicProgress="# Tiến độ bản public`r`n`r`nWinTune VI $packageVersion. Mã nguồn và manifest ký đã được chuẩn bị local cho`r`nrepository dinhluxury/WinTune-VI. Không tự upload hoặc phát hành.`r`n`r`nXem CHANGELOG-v$packageVersion.md và KIEM-THU.md về kiểm thử/giới hạn;`r`nPUBLISHING.md hướng dẫn đưa mã và bộ tải lên GitHub.`r`nNhật ký/ảnh kiểm thử riêng của máy không được phân phối trong gói public.`r`n"
    [IO.File]::WriteAllText((Join-Path $portable 'TIEN-DO.md'),$publicProgress,[Text.UTF8Encoding]::new($true))
}
$sourceDest=Join-Path $portable 'sources'
New-Item -ItemType Directory -Path $sourceDest -Force | Out-Null
foreach ($source in @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'sources') -File | Where-Object { $_.Name -match '\.reg(\.txt)?$' })) {
    $sourceName=$source.Name
    if ($sourceName.EndsWith('.reg')) { $sourceName+='.txt' }
    Copy-Item -LiteralPath $source.FullName -Destination (Join-Path $sourceDest $sourceName) -Force
}
Copy-Item -LiteralPath "$PSScriptRoot/sources/README.md" -Destination "$sourceDest/README.md" -Force
foreach ($file in @('microsoft-taskbar-reference.psm1.txt','microsoft-taskbar-reference.json')) { Copy-Item -LiteralPath "$PSScriptRoot/sources/$file" -Destination (Join-Path $sourceDest $file) -Force }
Copy-Item -LiteralPath "$PSScriptRoot/sources/winutil" -Destination $sourceDest -Recurse -Force
Copy-Item -LiteralPath "$PSScriptRoot/sources/review-20261014" -Destination $sourceDest -Recurse -Force
Copy-Item -LiteralPath "$PSScriptRoot/sources/curated-v014" -Destination $sourceDest -Recurse -Force
Copy-Item -LiteralPath "$PSScriptRoot/sources/full-tweaks" -Destination $sourceDest -Recurse -Force
Copy-Item -LiteralPath "$PSScriptRoot/sources/winget-package-ids.json" -Destination $sourceDest -Force
if (-not $PublicRelease) {
$proof=Join-Path $portable 'evidence'
New-Item -ItemType Directory -Path $proof -Force | Out-Null
foreach ($name in @('parser.log','Environment.Check.ps1.log','Core.Tests.ps1.log','Core.ExtendedTests.ps1.log','Catalog.Verify.ps1.log','UI.SelfTests.log','gui-lifecycle.json','real-read-lifecycle.log')) {
    Copy-Item -LiteralPath (Join-Path "$PSScriptRoot/evidence" $name) -Destination (Join-Path $proof $name) -Force
}
foreach ($name in @('vm-runner-verification.log','vm-snapshot.json')) {
    $vmProofFile=Join-Path "$PSScriptRoot/evidence" $name
    if (Test-Path -LiteralPath $vmProofFile) { Copy-Item -LiteralPath $vmProofFile -Destination (Join-Path $proof $name) -Force }
}
foreach ($name in @('Actions.Tests.ps1.log','actions-read-only.json','app-manager-render.png','startup-manager-render.png')) {
    $actionProof=Join-Path "$PSScriptRoot/evidence" $name
    if (Test-Path -LiteralPath $actionProof) { Copy-Item -LiteralPath $actionProof -Destination (Join-Path $proof $name) -Force }
}
foreach ($name in @('Tools.Tests.ps1.log','Tools.Worker.Tests.ps1.log','tools-read-only.json','tools-manager-render.png')) {Copy-Item -LiteralPath (Join-Path "$PSScriptRoot/evidence" $name) -Destination $proof -Force}
foreach ($name in @('Monitor.Tests.ps1.log','monitor-read-only.json','monitor-ui-read-only.json','dashboard-process-live.png','monitor-live-check.log','dashboard-native.png','dashboard-900x560-100.png','dashboard-1280x860-150.png')) {Copy-Item -LiteralPath (Join-Path "$PSScriptRoot/evidence" $name) -Destination $proof -Force}
foreach ($name in @('Theme.Tests.ps1.log','theme-system-read-only.json','theme-light.png','theme-dark.png','theme-tools-light.png','theme-tools-dark.png')) {Copy-Item -LiteralPath (Join-Path "$PSScriptRoot/evidence" $name) -Destination $proof -Force}
foreach ($name in @('board-dark-1280.png','board-light-900.png','process-hover-dark.png','process-hover-light.png')) {Copy-Item -LiteralPath (Join-Path "$PSScriptRoot/evidence" $name) -Destination $proof -Force}
foreach ($name in @('security-dark.png','security-light.png','restore-guide.png','logs-summary.png','software-simple.png','usability-native-read.json','Usability.Core.Tests.ps1.log','Registry.Typed.Tests.ps1.log','Coverage.Tests.ps1.log','upstream-heads-v013.json','software-expanded.png')) {Copy-Item -LiteralPath (Join-Path "$PSScriptRoot/evidence" $name) -Destination $proof -Force}
foreach ($name in @('software-curated-dark.png','software-curated-light.png')) {Copy-Item -LiteralPath (Join-Path "$PSScriptRoot/evidence" $name) -Destination $proof -Force}
foreach ($name in @('Distribution.Tests.ps1.log','Launcher.Tests.ps1.log','launcher-lifecycle-v015.json','distribution-dark.png','distribution-light.png')) {Copy-Item -LiteralPath (Join-Path "$PSScriptRoot/evidence" $name) -Destination $proof -Force}
$vmUserProof=Join-Path "$PSScriptRoot/evidence" 'vm-user'
if (Test-Path -LiteralPath $vmUserProof) {
    $vmProofDest=Join-Path $proof 'vm-user'
    New-Item -ItemType Directory -Path $vmProofDest -Force | Out-Null
    foreach ($screenshot in @(Get-ChildItem -LiteralPath $vmUserProof -Filter '*.png' -File)) { Copy-Item -LiteralPath $screenshot.FullName -Destination $vmProofDest -Force }
}
}
$manifest=@(Get-ChildItem -LiteralPath $portable -Recurse -File | Where-Object { $_.Name -ne 'SHA256.txt' } | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash+'  '+$_.FullName.Substring($portable.Length+1)
})
$manifest | Set-Content (Join-Path $portable 'SHA256.txt') -Encoding UTF8
$archive=Join-Path $PSScriptRoot ('WinTune-VI-v'+$packageVersion+'-portable.zip')
Compress-Archive -LiteralPath $portable -DestinationPath $archive -Force
$portable | Set-Content (Join-Path $releaseRoot 'LATEST.txt') -Encoding UTF8
Write-Output "Portable folder: $portable"
Write-Output "ZIP: $archive"
