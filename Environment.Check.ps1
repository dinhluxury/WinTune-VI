#Requires -Version 5.1
$ErrorActionPreference='Stop'
$cv=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
[pscustomobject]@{
    PowerShell=$PSVersionTable.PSVersion.ToString()
    Platform=[Environment]::OSVersion.Platform.ToString()
    Build=$cv.CurrentBuild
    Revision=$cv.UBR
    DisplayVersion=$cv.DisplayVersion
    Edition=$cv.EditionID
    Apartment=[Threading.Thread]::CurrentThread.ApartmentState.ToString()
    WpfAssembly=[Windows.Window].Assembly.FullName
    Is64Bit=[Environment]::Is64BitProcess
} | ConvertTo-Json
