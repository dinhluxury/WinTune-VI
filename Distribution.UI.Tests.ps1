# Actual WPF and a simulated background worker; no network/install/PATH changes.
$distWrites=$SimWriteCount;$toolWrites=$ToolMockWrites;$distSelectedCount=$Selected.Count
$Window.FindName('Distribution').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
$dw=$script:DistributionWindow;$dw.UpdateLayout()
Assert-UI ($dw.IsVisible -and $null -eq $script:DistributionJob -and -not $script:DistributionTimer.IsEnabled) 'Opening distribution center starts no network reader, installer or persistent timer'
Assert-UI ($dw.FindName('DistributionVersion').Text.Contains('MÔ PHỎNG') -and $dw.FindName('DistributionVersion').Text.Contains((Get-WinTuneVersion $PSScriptRoot).Version)) 'Distribution center shows real local version and simulation label'
Assert-UI (-not $dw.FindName('DistributionInstall').IsEnabled) 'Download button requires a checked and signed newer release'
if ($null -eq $script:DistributionConfig) {
    Assert-UI (-not $dw.FindName('DistributionCheck').IsEnabled -and $dw.FindName('DistributionSource').Text.Contains('Chưa cấu hình')) 'Missing publisher trust is explained and cannot start a fake online check'
} else {
    Assert-UI ($dw.FindName('DistributionCheck').IsEnabled -and $dw.FindName('DistributionSource').Text.Contains($script:DistributionConfig.Repository) -and $null -eq $script:DistributionJob) 'Configured publisher enables an explicit check without starting a network task'
}
$script:DialogResponse=$false;$dw.FindName('DistributionUnregister').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($null -eq $script:DistributionJob -and $LastDialogText.Contains('Giữ ứng dụng')) 'Canceling command removal starts no action'
Start-DistributionJob Check
Assert-UI ($null -ne $script:DistributionJob -and $dw.FindName('DistributionCancel').IsEnabled) 'Distribution work runs in a separate PowerShell pipeline'
$frame=New-Object Windows.Threading.DispatcherFrame;$pulse=New-Object Windows.Threading.DispatcherTimer;$pulse.Interval=[TimeSpan]::FromMilliseconds(50);$script:DistPulse=0
$pulse.Add_Tick({$script:DistPulse++;if ($script:DistPulse -ge 2) {$pulse.Stop();$frame.Continue=$false}});$pulse.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
Assert-UI ($script:DistPulse -eq 2 -and $null -ne $script:DistributionJob) 'WPF dispatcher continues responding during a slow distribution task'
$dw.Close();Assert-UI ($dw.IsVisible) 'Closing distribution window cannot abandon an in-flight task'
$dw.FindName('DistributionCancel').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
for ($i=0;$i -lt 20 -and $null -ne $script:DistributionJob;$i++) {Pump-UsabilityUI;Receive-DistributionUIJob}
Assert-UI ($null -eq $script:DistributionJob -and -not $script:DistributionTimer.IsEnabled) 'Cancel releases the background pipeline and timer'
Assert-UI ($dw.FindName('DistributionStatus').Text.Contains('hủy') -and -not $dw.FindName('DistributionInstall').IsEnabled) 'Canceled task does not claim installation success'
foreach ($mode in @('Dark','Light')) {Set-AppThemeMode $mode $false;$dw.UpdateLayout();Save-SoftwareRendering $dw ('distribution-'+$mode.ToLowerInvariant())}
Assert-UI ($SimWriteCount -eq $distWrites -and $ToolMockWrites -eq $toolWrites -and $Selected.Count -eq $distSelectedCount) 'Distribution UI tests preserve Windows state and feature selections'
$dw.Close();Assert-UI ($null -eq $script:DistributionWindow) 'Distribution window closes after the canceled worker is disposed'
Set-AppThemeMode Dark $false
