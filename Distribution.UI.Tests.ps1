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
Assert-UI ($null -eq $dw.FindName('DistributionRegister') -and $null -eq $dw.FindName('DistributionUnregister') -and $null -eq $dw.FindName('DistributionRecover') -and $null -eq $dw.FindName('DistributionFolder')) 'Update page has no command registration or PATH controls'
Assert-UI ($dw.FindName('DistributionState').Text -eq 'Chưa kiểm tra cập nhật' -and $dw.Height -le 500) 'Update page starts with an honest unchecked status and compact layout'
$running=$script:DistributionRunningVersion
$latest=[pscustomobject]@{Status='Current';Manifest=[pscustomobject]@{Version=$running};CurrentVersion=$running}
Set-DistributionCheckResult $latest
Assert-UI ($dw.FindName('DistributionState').Text.Contains('mới nhất') -and -not $dw.FindName('DistributionInstall').IsEnabled -and $dw.FindName('DistributionChecked').Text.Contains('Đã kiểm tra')) 'Verified matching running version shows latest with a check time'
foreach ($mode in @('Dark','Light')) {Set-AppThemeMode $mode $false;Save-SoftwareRendering $dw ('update-latest-'+$mode.ToLowerInvariant())}
$next=([version]$running).Major.ToString()+'.'+(([version]$running).Minor+1).ToString()+'.0'
$available=[pscustomobject]@{Status='Available';Manifest=[pscustomobject]@{Version=$next;Size=1};CurrentVersion=$running;ReleaseUrl='https://github.com/fixture/WinTune/releases/tag/v'+$next}
Set-DistributionCheckResult $available
$script:DialogResponse=$false;$dw.FindName('DistributionInstall').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($dw.FindName('DistributionInstall').IsEnabled -and $LastDialogText.Contains($next) -and $null -eq $DistributionJob) 'Canceling an available update starts no download or install'
$prepared=[pscustomobject]@{Status='Current';Manifest=[pscustomobject]@{Version=$next};CurrentVersion=$next;PreparedPath='C:\Fixture\Prepared'}
Set-DistributionCheckResult $prepared
Assert-UI ($dw.FindName('DistributionState').Text -eq 'Bản cập nhật đã sẵn sàng' -and -not $dw.FindName('DistributionInstall').IsEnabled -and $dw.FindName('DistributionOpenFolder').Visibility -eq 'Visible') 'Prepared newer app is presented as ready, not as the currently running version'
Set-DistributionCheckResult $latest
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
