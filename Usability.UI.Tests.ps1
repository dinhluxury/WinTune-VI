# In-process UI events, fixture readers and simulated worker only.
$usabilityWrites=$SimWriteCount
function Pump-UsabilityUI {
 $frame=New-Object Windows.Threading.DispatcherFrame;$pump=New-Object Windows.Threading.DispatcherTimer;$pump.Interval=[TimeSpan]::FromMilliseconds(50);$pump.Tag=$frame
 $pump.Add_Tick({param($sender,$args) $sender.Stop();$sender.Tag.Continue=$false});$pump.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
}
Set-MainPage Dashboard
$Window.FindName('DashboardDiagnostics').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($null -ne $MonitorState.DiagnosticsJob -and -not $Window.FindName('DashboardDiagnostics').IsEnabled -and $null -eq $ToolsWindow) 'Security button starts its reader immediately without another tool window or preview'
$deadline=[DateTime]::UtcNow.AddSeconds(12)
while ($null -ne $MonitorState.DiagnosticsJob -and [DateTime]::UtcNow -lt $deadline) {Pump-UsabilityUI;Poll-DashboardDiagnostics}
Assert-UI ($Window.FindName('DashboardDiagnostics').IsEnabled -and $Window.FindName('DiagnosticsStatus').Text.Contains('MÔ PHỎNG')) 'Security completion reenables the button and never labels demo as a native scan'
Assert-UI ((Format-DiagnosticSwitch $null) -eq 'Chưa đọc được' -and (Format-DiagnosticSwitch 2) -eq 'Chưa đọc được' -and (Format-DiagnosticSwitch $false) -eq 'Tắt') 'Missing or unconfigured security state differs from a measured disabled state'
$data=[pscustomobject]@{Time=(Get-Date).ToString('o');Mode='fixture';TPM='Chưa đọc được (mô phỏng)';'Secure Boot'=$false;Defender=[pscustomobject]@{AntivirusEnabled=$true;RealTimeProtectionEnabled=$true};Firewall=@([pscustomobject]@{Name='Public';Enabled=$false});'Lỗi thiết bị'=@()}
Show-DashboardDiagnostics $data
Assert-UI ($Window.FindName('DiagnosticsBoot').Text -eq 'Tắt' -and $Window.FindName('DiagnosticsDevices').Text.Contains('không báo thiết bị lỗi')) 'Security cards distinguish successful empty device query from unknown data'
$data.'Lỗi thiết bị'='Không đọc được (mô phỏng)';Show-DashboardDiagnostics $data
Assert-UI ($Window.FindName('DiagnosticsDevices').Text.Contains('Không đọc được')) 'Failed device query is not reported as no driver errors'
$Window.Width=900;$Window.Height=560;$outer=$Window.FindName('DashboardPage')
$Window.Content.Measure([Windows.Size]::new(884,520));$Window.Content.Arrange([Windows.Rect]::new(0,0,884,520));$Window.Content.UpdateLayout();$outer.ScrollToVerticalOffset(200);$Window.Content.UpdateLayout();$offset=$outer.VerticalOffset
$wheel=[Windows.Input.MouseWheelEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice,0,-120);$wheel.RoutedEvent=[Windows.UIElement]::PreviewMouseWheelEvent
$Window.FindName('ProcessList').RaiseEvent($wheel);$Window.Content.UpdateLayout()
Assert-UI ($wheel.Handled -and $outer.VerticalOffset -gt $offset) 'Mouse wheel over process rows scrolls the outer overview page'
$outer.ScrollToBottom();$Window.Content.UpdateLayout()
foreach ($mode in @('Dark','Light')) {Set-AppThemeMode $mode $false;$Window.Content.UpdateLayout();$bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap 884,520,96,96,([Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($Window.Content);$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create((Join-Path $PSScriptRoot "evidence/security-$($mode.ToLowerInvariant()).png"));try {$encoder.Save($stream)} finally {$stream.Dispose()}}
$rw=New-RestoreWindow Create
Assert-UI ($rw.FindName('CreateRestore').Content -eq 'Tạo mốc bây giờ' -and $null -eq $rw.FindName('ToolGroup') -and $rw.FindName('ProtectionSettings').Content -eq 'Mở cài đặt bảo vệ') 'Restore surface explains three steps and has no power-plan selector'
$rw.Show();$owned=New-TextDialog 'Thử chủ hộp thoại khôi phục' 'Mô phỏng'
Assert-UI ($owned.Owner -eq $rw) 'Restore confirmation stays above the restore window'
$owned.Close();$rw.Hide();$script:DialogResponse=$false
$rw.FindName('CreateRestore').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI (-not $RestoreState.Busy -and $null -eq $RestoreState.Job) 'Cancelling restore-point confirmation starts no worker'
$script:DialogResponse=$true;Create-RestorePointFromUI;$deadline=[DateTime]::UtcNow.AddSeconds(12)
while ($RestoreState.Busy -and [DateTime]::UtcNow -lt $deadline) {Pump-UsabilityUI;Poll-RestoreCenter}
Assert-UI (-not $RestoreState.Busy -and $rw.FindName('RestoreOperation').Text.StartsWith('MÔ PHỎNG')) 'Restore creation uses the existing simulated worker and reports actual completion honestly'
while ($null -ne $RestoreState.ReadJob -and [DateTime]::UtcNow -lt $deadline) {Pump-UsabilityUI;Poll-RestoreCenter}
Assert-UI (-not $RestoreState.PointsKnown -and $rw.FindName('RestoreStatus').Text.Contains('MÔ PHỎNG')) 'Demo restore list does not claim native restore points exist'
Save-ManagerRendering $rw 'restore-guide';$rw.Close();$script:RestoreWindow=$null;$script:ToolJob=$null
$lw=New-WindowsLogsWindow;Read-WindowsLogSummary;$deadline=[DateTime]::UtcNow.AddSeconds(12)
while ($null -ne $LogsState.Job -and [DateTime]::UtcNow -lt $deadline) {Pump-UsabilityUI;Poll-WindowsLogSummary}
Assert-UI ($lw.FindName('LogRows').Items.Count -eq 0 -and $lw.FindName('LogsStatus').Text.Contains('MÔ PHỎNG')) 'Simple Windows log table uses a read-only reader and explicitly empty demo results'
Save-ManagerRendering $lw 'logs-summary';$lw.Close();$script:LogsWindow=$null
$sw=New-ToolsWindow 'Phần mềm'
Assert-UI ($sw.FindName('ToolList').Items.Count -eq 1 -and $ToolsState.Current.Id -eq 'wingetinstall' -and $sw.FindName('ToolGroup').Visibility -eq 'Collapsed') 'Software opens directly to installation without WinGet/update menus'
Assert-UI (-not $sw.FindName('SourceConsent').IsChecked -and -not $sw.FindName('PackageConsent').IsChecked -and $sw.FindName('SilentConsent').Visibility -eq 'Collapsed') 'Simplified installation accepts no terms or silent installation by default'
Assert-UI ($sw.FindName('ToolSource').Inlines.LastInline -is [Windows.Documents.Hyperlink] -and $Window.FindName('Source').Inlines.LastInline -is [Windows.Documents.Hyperlink]) 'Source references are named text links instead of raw URLs'
Save-ManagerRendering $sw 'software-simple';$sw.Close();$script:ToolsWindow=$null
Assert-UI (@($Profiles | Where-Object Id -eq 'safe').Count -eq 0 -and @(Get-ProfileSelection advanced).Count -eq 13 -and 'recall' -notin @(Get-ProfileSelection advanced) -and 'notepadai' -notin @(Get-ProfileSelection advanced)) 'CTT-style profiles stay selective and never select snapshot-deleting or machine AI changes automatically'
Assert-UI ($SimWriteCount -eq $usabilityWrites -and $ActionWrites -eq 0) 'All new browsing/readers/dialog tests perform no registry writes or app removals'
Set-AppThemeMode Dark $false;$Window.FindName('DiagnosticsResults').Visibility='Collapsed';$outer.ScrollToTop();Set-MainPage Features;$Selected.Clear();Render-List
