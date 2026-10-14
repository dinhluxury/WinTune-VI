#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Theme.Core.ps1"
$script:Pass=0
function Assert-Theme([bool]$Ok,[string]$Name) {if (-not $Ok) {throw "THEME FAILED: $Name"};$script:Pass++;Write-Output "PASS: $Name"}
Assert-Theme ((Resolve-AppTheme Dark Light) -eq 'Dark') 'Explicit dark ignores Windows light setting'
Assert-Theme ((Resolve-AppTheme Light Dark) -eq 'Light') 'Explicit light ignores Windows dark setting'
Assert-Theme ((Resolve-AppTheme System Dark) -eq 'Dark') 'System follows dark app preference'
Assert-Theme ((Resolve-AppTheme System Light) -eq 'Light') 'System follows light app preference'
$bad=$false;try {Resolve-AppTheme Unknown Light | Out-Null} catch {$bad=$true};Assert-Theme $bad 'Unknown theme ID rejected'
$root=Join-Path $PSScriptRoot ('.test-runs/theme-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $root | Out-Null
$path=Join-Path $root 'ui-settings.json'
Assert-Theme ((Read-ThemePreference $path).Mode -eq 'System') 'First launch defaults to system'
foreach ($mode in @('Dark','Light','System')) {Save-ThemePreference $path $mode;$read=Read-ThemePreference $path;Assert-Theme ($read.Mode -eq $mode -and -not $read.Error) "Saved $mode reloads on next launch"}
Save-ThemePreference $path 'light';Assert-Theme ((Read-ThemePreference $path).Mode -eq 'Light') 'Case-insensitive API input is saved with canonical ID'
Assert-Theme (@(Get-ChildItem -LiteralPath $root -Filter '*.tmp').Count -eq 0) 'Atomic saves leave no temporary files'
$hash=(Get-FileHash -LiteralPath $path).Hash;$bad=$false
try {Save-ThemePreference $path 'Extreme'} catch {$bad=$true}
Assert-Theme ($bad -and (Get-FileHash -LiteralPath $path).Hash -eq $hash) 'Invalid save cannot overwrite working preference'
foreach ($json in @('{','{"Version":1,"Theme":"Unknown"}','{"Version":1,"Theme":["Dark"]}','{"Version":2,"Theme":"Dark"}')) {
    [IO.File]::WriteAllText($path,$json);$read=Read-ThemePreference $path
    Assert-Theme ($read.Mode -eq 'System' -and $read.Error.Length -gt 0 -and [IO.File]::ReadAllText($path) -eq $json) 'Corrupt preference reported and preserved, never executed'
}
Save-ThemePreference $path Dark;$hash=(Get-FileHash -LiteralPath $path).Hash
$lock=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None);$bad=$false
try {try {Save-ThemePreference $path Light} catch {$bad=$true}} finally {$lock.Dispose()}
Assert-Theme ($bad -and (Get-FileHash -LiteralPath $path).Hash -eq $hash -and @(Get-ChildItem -LiteralPath $root -Filter '*.tmp').Count -eq 0) 'Save access failure keeps last preference and cleans only its own temp file'
# Pure contrast calculations for text/surfaces, independent of Windows settings.
function Get-Luminance([string]$Color) {
    $v=@(1,3,5 | ForEach-Object {[Convert]::ToInt32($Color.Substring($_,2),16)/255.0} | ForEach-Object {if ($_ -le 0.04045) {$_/12.92} else {[Math]::Pow(($_+0.055)/1.055,2.4)}})
    return 0.2126*$v[0]+0.7152*$v[1]+0.0722*$v[2]
}
foreach ($mode in @('Dark','Light')) {
    $palette=Get-ThemePalette $mode
    Assert-Theme ($palette.Count -eq 16 -and @($palette.Values | Where-Object {$_ -notmatch '^#[0-9A-F]{6}$'}).Count -eq 0) "$mode palette declares all semantic brushes"
    foreach ($pair in @(@('Text','Surface'),@('Muted','Surface'),@('Accent','Surface'),@('Warning','Surface'),@('OnAccent','AccentButton'))) {
        $a=Get-Luminance $palette[$pair[0]];$b=Get-Luminance $palette[$pair[1]]
        Assert-Theme (([Math]::Max($a,$b)+0.05)/([Math]::Min($a,$b)+0.05) -ge 4.5) "$mode $($pair[0]) contrast remains legible"
    }
}
Write-Output "THEME TESTS PASSED: $script:Pass; isolated preference files and pure palettes only, no Windows theme writes."
