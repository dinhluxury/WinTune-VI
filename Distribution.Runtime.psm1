# Lazy UI bridge. Workers and isolated tests use the same underlying local files.
. "$PSScriptRoot/Distribution.Core.ps1"
. "$PSScriptRoot/CommandRegistration.ps1"
Export-ModuleMember -Function Get-WinTuneVersion,Get-ReleaseConfig,Get-WinTuneInstallRoot
