#Requires -Version 5.1
# Reads only the existing Windows application preference; never changes it.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Theme.Core.ps1"
$key='HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$before=[Microsoft.Win32.Registry]::GetValue($key,'AppsUseLightTheme',$null)
$reading=Get-WindowsAppTheme
$after=[Microsoft.Win32.Registry]::GetValue($key,'AppsUseLightTheme',$null)
if ($before -ne $after -or $reading.Error) {throw 'System appearance read audit failed or changed externally.'}
$record=[pscustomobject]@{Mode='ReadOnly';Before=$before;After=$after;Resolved=$reading.Mode;Default=$reading.Default;WindowsThemeWrites=0;Time=[DateTime]::UtcNow;Limit='Read check only. Native Windows theme switching is not performed.'}
$record | ConvertTo-Json | Set-Content -LiteralPath "$PSScriptRoot/evidence/theme-system-read-only.json" -Encoding UTF8
Write-Output "READ ONLY THEME PASSED: Windows application preference $before, resolved $($reading.Mode); unchanged; no Windows theme writes."
