#Requires -Version 5.1
# Test the production reader/writer through a fake RegistryKey API, never Windows.
$ErrorActionPreference='Stop';. "$PSScriptRoot/Core.ps1"
$root=Join-Path $PSScriptRoot ('.test-runs/typed-'+[guid]::NewGuid().ToString('N'))
Initialize-WinTune "$PSScriptRoot/features.json" $root 'fixture' 26300
$c=(Get-Feature classicmenu).Changes[0];$pass=0
function Check([bool]$Ok,[string]$Name) {if (-not $Ok) {throw "TYPED API FAILED: $Name"};$script:pass++;Write-Output "PASS: $Name"}
$script:KeyPresent=$false;$script:KeyValues=@{};$script:LastKind=$null;$script:DeletedPath=''
$script:FakeKey=[pscustomobject]@{SubKeyCount=0}
$FakeKey | Add-Member ScriptMethod Dispose {}
$FakeKey | Add-Member ScriptMethod GetValueNames {return @($script:KeyValues.Keys)}
$FakeKey | Add-Member ScriptMethod GetValueKind {param($name) return $script:LastKind}
$FakeKey | Add-Member ScriptMethod GetValue {param($name) return $script:KeyValues[$name]}
$FakeKey | Add-Member ScriptMethod SetValue {param($name,$value,$kind) $script:KeyValues[$name]=$value;$script:LastKind=$kind}
$FakeKey | Add-Member ScriptMethod DeleteValue {param($name,$errorIfMissing) $script:KeyValues.Remove($name)}
$script:FakeBase=[pscustomobject]@{}
$FakeBase | Add-Member ScriptMethod OpenSubKey {param($path,$writable) if ($script:KeyPresent) {return $script:FakeKey};return $null}
$FakeBase | Add-Member ScriptMethod CreateSubKey {param($path) $script:KeyPresent=$true;return $script:FakeKey}
$FakeBase | Add-Member ScriptMethod DeleteSubKey {param($path,$throwMissing) if ($script:KeyValues.Count) {throw 'Foreign values remain'};$script:KeyPresent=$false;$script:DeletedPath=$path}
function Get-RegistryBase($Change) {return $script:FakeBase}
Check (-not (Read-RegistryValue $c).KeyExisted) 'Production reader records the absent original key'
Set-RegistryValue $c $true ''
Check ($LastKind -eq [Microsoft.Win32.RegistryValueKind]::String -and (Read-RegistryValue $c).Value -is [string]) 'Production writer sets REG_SZ instead of converting the empty value to zero'
Set-RegistryValue $c $false '' $true
Check (-not $KeyPresent -and $DeletedPath -ceq $c.Path) 'Undo removes only the empty leaf key created for this feature'
Set-RegistryValue $c $true ''; $KeyValues['other']='foreign';$failed=$false
try {Set-RegistryValue $c $false '' $true} catch {$failed=$true}
Check ($failed -and $KeyValues.ContainsKey('') -and $KeyValues.ContainsKey('other')) 'Foreign key content blocks removal before any value is deleted'
$KeyValues=@{' '=1;''='C:\foreign.dll'};$LastKind=[Microsoft.Win32.RegistryValueKind]::String;$failed=$false
try {Read-RegistryValue $c | Out-Null} catch {$failed=$true}
Check $failed 'Existing nonempty COM registration cannot be overwritten'
$mouse=(Get-Feature pointerprecision).Changes[0];$KeyPresent=$true;$KeyValues=@{'MouseSpeed'='1'};$LastKind=[Microsoft.Win32.RegistryValueKind]::String
Check ((Read-RegistryValue $mouse).Value -ceq '1') 'Production reader accepts original nonempty mouse REG_SZ without altering it'
Set-RegistryValue $mouse $true '0'
Check ($LastKind -eq [Microsoft.Win32.RegistryValueKind]::String -and $KeyValues['MouseSpeed'] -ceq '0') 'Mouse target is written as REG_SZ rather than incorrect DWORD'
Set-RegistryValue $mouse $true '1'
Check ((Read-RegistryValue $mouse).Value -ceq '1') 'Production writer restores original mouse string through mocked RegistryKey API'
Write-Output "TYPED REGISTRY API TESTS PASSED: $pass; all RegistryKey calls mocked, zero native writes."
