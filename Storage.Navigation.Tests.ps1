# Sidebar click -> automatic simulated install/scan/import, without another action.
function Has-CollapsibleAncestor($Control) {for ($p=$Control.Parent;$null -ne $p;$p=$p.Parent) {if ($p -is [Windows.Controls.Expander]) {return $true}};return $false}
foreach ($name in @('BackupTools','RestoreWindows','DeviceManager','EventViewer')) {Assert-UI (-not (Has-CollapsibleAncestor $Window.FindName($name))) "$name stays outside a collapsible sidebar section"}
Assert-UI ($Window.FindName('Distribution').Parent -eq $Window.FindName('ThemeChoice').Parent) 'WinTune information and update entry lives with appearance settings in the footer'
Assert-UI ($null -eq (Get-Command New-StorageWindow -ErrorAction SilentlyContinue)) 'Basic storage viewer is no longer loaded by the app'
$savedToolRoot=$ToolRoot;$savedDataRoot=$DataRoot
$script:DataRoot=Join-Path $savedDataRoot 'automatic-wiztree';$null=New-Item -ItemType Directory -Path $DataRoot -Force
$script:ToolJob=$null;$script:StorageFixtureCompleted=$false;$script:StorageFixtureDeadline=(Get-Date).AddSeconds(25)
$script:StorageFixtureTimer=New-Object Windows.Threading.DispatcherTimer;$StorageFixtureTimer.Interval=[TimeSpan]::FromMilliseconds(100)
$StorageFixtureTimer.Add_Tick({
 if ($script:WizTreeWindow -and $script:WizTreeState.Preparation -and -not $script:WizTreeState.Job) {
  $script:StorageFixtureCompleted=$true;$script:StorageFixtureTimer.Stop()
  foreach ($mode in @('Dark','Light')) {Set-AppThemeMode $mode $false;Save-SoftwareRendering $script:WizTreeWindow ('wiztree-automatic-'+$mode.ToLowerInvariant())}
  $script:WizTreeWindow.Close()
 } elseif ((Get-Date) -gt $script:StorageFixtureDeadline) {$script:StorageFixtureTimer.Stop();if ($script:WizTreeWindow) {$script:WizTreeWindow.Close()}}
})
$StorageFixtureTimer.Start()
$Window.FindName('Cleanup').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($StorageFixtureCompleted -and $WizTreeState.Preparation.Installed -and $null -eq $WizTreeState.Job) 'One sidebar click prepares direct drive scanning with no second install or Scan click'
Assert-UI ($WizTreeState.Preparation.Drive -eq 'C:' -and $WizTreeState.Preparation.ScanMode -eq 'DirectDrive' -and -not $WizTreeState.Preparation.Launched -and -not $WizTreeState.Preparation.PSObject.Properties['ReportPath']) 'Automatic flow hands the real C drive to WizTree and never a CSV report'
$hub=New-WizTreeWindow;$hub.Show();$hub.UpdateLayout()
Assert-UI ($null -eq $hub.FindName('WizTreeBasic') -and $null -eq $hub.FindName('WizTreeRun')) 'WizTree progress page has no basic viewer or separate install action'
$script:WizTreeState.Job=Start-ToolJob 'wiztreeopen' ([pscustomobject]@{MockDelayMs=1200}) $true $true
Set-WizTreeBusy $true;$WizTreeState.Timer.Start()
$hub.FindName('WizTreeStop').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ([IO.File]::Exists((Join-Path $WizTreeState.Job.Path 'cancel.open')) -and -not $hub.FindName('WizTreeStop').IsEnabled) 'Cancel signals the preparation worker and disables repeated requests'
$deadline=(Get-Date).AddSeconds(20)
while ($WizTreeState.Job -and (Get-Date) -lt $deadline) {Start-Sleep -Milliseconds 30;Poll-WizTreeTask}
Assert-UI ($null -eq $WizTreeState.Job -and $hub.FindName('WizTreeStatus').Text.Contains('Đã hủy') -and $hub.FindName('WizTreeRetry').Visibility -eq 'Visible') 'Canceled preparation reports cancellation and offers retry'
$hub.Close();$script:WizTreeWindow=$null;$script:DataRoot=$savedDataRoot;Initialize-Tools $savedToolRoot $true $UserId;$script:ToolJob=$null;Set-AppThemeMode Dark $false
