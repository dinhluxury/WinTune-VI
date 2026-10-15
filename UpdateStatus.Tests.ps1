#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/UpdateStatus.Core.ps1"
$pass=0
function Check([bool]$Ok,[string]$Name) {if (-not $Ok) {throw "UPDATE STATUS FAILED: $Name"};$script:pass++;Write-Output "PASS UPDATE STATUS: $Name"}
function Info([string]$Latest,[string]$Prepared) {return [pscustomobject]@{Status=$(if ([version]$Latest -gt [version]$Prepared) {'Available'} else {'Current'});Manifest=[pscustomobject]@{Version=$Latest};CurrentVersion=$Prepared}}
$r=Get-WinTuneUpdateStatus (Info '0.16.0' '0.16.0') '0.16.0'
Check ($r.State -eq 'Latest' -and -not $r.CanDownload -and $r.Title.Contains('mới nhất')) 'Latest requires the running version to match the published stable'
$r=Get-WinTuneUpdateStatus (Info '0.17.0' '0.16.0') '0.16.0'
Check ($r.State -eq 'Available' -and $r.CanDownload -and $r.Title.Contains('0.17.0')) 'A newer release exposes the update action'
$r=Get-WinTuneUpdateStatus (Info '0.17.0' '0.17.0') '0.16.0'
Check ($r.State -eq 'Ready' -and -not $r.CanDownload -and -not $r.Title.Contains('mới nhất') -and $r.Detail.Contains('Đang chạy 0.16.0')) 'An older running app is never labeled latest just because a newer package is prepared'
$r=Get-WinTuneUpdateStatus (Info '0.15.2' '0.16.0') '0.16.0'
Check ($r.State -eq 'Ahead' -and -not $r.CanDownload -and $r.Detail.Contains('Không cần tải bản cũ')) 'A newer local build never offers a downgrade'
$r=Get-WinTuneUpdateStatus (Info '0.16.10' '0.16.9') '0.16.9'
Check ($r.CanDownload) 'Version comparison is numeric, not lexical'
$r=Get-WinTuneUpdateStatus (Info '0.17.0' '0.18.0') '0.16.0'
Check ($r.State -eq 'Ready' -and $r.Detail.Contains('0.18.0')) 'A prepared newer version is distinguished from the running version'
$failed=$false;try {$bad=Info '0.17.0' '0.16.0';$bad.Status='Simulation';Get-WinTuneUpdateStatus $bad '0.16.0'} catch {$failed=$true}
Check $failed 'A simulation or failed lookup cannot claim latest status'
$failed=$false;try {$bad=Info '0.17.0' '0.16.0';$bad.Manifest.Version='untrusted';Get-WinTuneUpdateStatus $bad '0.16.0'} catch {$failed=$true}
Check $failed 'Malformed version metadata is rejected'
Write-Output "UPDATE STATUS TESTS PASSED: $pass; version fixtures only, no network or Windows changes."
