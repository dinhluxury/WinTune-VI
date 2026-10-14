#Requires -Version 5.1
param([switch]$Confirmed,[switch]$CheckOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Distribution.Core.ps1"
. "$PSScriptRoot/CommandRegistration.ps1"
. "$PSScriptRoot/SourceCommandRegistration.ps1"
. "$PSScriptRoot/Setup.Core.ps1"
try {
    $version=Get-WinTuneVersion $PSScriptRoot
    if ([IntPtr]::Size -ne 8 -or (Get-DistributionBuild) -lt $version.MinimumBuild) {throw 'Cần Windows 11 x64 với build được hỗ trợ.'}
    Test-PortableIntegrity $PSScriptRoot $version.Version
    $root=Get-WinTuneInstallRoot
    $text=Get-WinTuneSetupText $version.Version $root
    Write-Output $text
    if ($CheckOnly) {return}
    if (-not $Confirmed) {
        Add-Type -AssemblyName PresentationFramework
        $answer=[Windows.MessageBox]::Show($text,'Thiết lập WinTune',[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Question,[Windows.MessageBoxResult]::No)
        if ($answer -ne [Windows.MessageBoxResult]::Yes) {return}
    }
    $result=Invoke-WinTuneLocalSetup $PSScriptRoot $root $true
    Write-Output $result.Message
} catch {
    if ($CheckOnly) {Write-Error $_;exit 1}
    Add-Type -AssemblyName PresentationFramework
    [Windows.MessageBox]::Show(('Không thiết lập được WinTune. '+$_.Exception.Message),'WinTune',[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)|Out-Null
    exit 1
}
