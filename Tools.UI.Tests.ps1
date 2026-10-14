# In-process WPF events plus a separate, strictly simulated worker.
$profilesWrites=$SimWriteCount
$Window.FindName('Profile').SelectedIndex=1
Assert-UI ($Selected.Count -eq 5 -and $Selected.ContainsKey('ads') -and $SimWriteCount -eq $profilesWrites) 'Profile prepares selections without executing changes'
$Window.FindName('Profile').SelectedIndex=2
Assert-UI ($Selected.Count -eq 10 -and $SimWriteCount -eq $profilesWrites) 'Balanced profile adds disclosed privacy selections without applying'
$Window.FindName('Profile').SelectedIndex=0
Assert-UI ($Selected.Count -eq 0) 'Custom profile starts with no selections'
$tw=New-ToolsWindow 'Phần mềm'
$tw.Show();$ownedDialog=New-TextDialog 'Kiểm tra chủ hộp thoại công cụ' 'Mô phỏng; không chạy công cụ.'
Assert-UI ($ownedDialog.Owner -eq $tw) 'Tool preview is owned by the visible tool window and cannot hide behind the main window'
$ownedDialog.Close();$tw.Hide()
Assert-UI ($ToolsState.Packages.Count -eq 0 -and $ToolJob -eq $null -and $tw.FindName('SoftwareSuggestions').Children.Count -eq 17) 'Software manager opens with seventeen curated apps and no background install'
$tw.FindName('PackageConsent').IsChecked=$true;$tw.FindName('SilentConsent').IsChecked=$true;$tw.FindName('ToolInput').Text='7zip.7zip'
Assert-UI (-not $tw.FindName('PackageConsent').IsChecked -and -not $tw.FindName('SilentConsent').IsChecked) 'Changing package input clears previous package/silent consent'
$tw.FindName('ToolInput').Text=''
$ToolsWindow.FindName('ToolGroup').SelectedItem='Dọn dẹp'
($ToolsWindow.FindName('ToolList').Items | Where-Object {$_.Tag.Id -eq 'tempdelete'}).IsSelected=$true
$script:DialogResponse=$false
$ToolsState.TempInventory=@($ToolMockFiles);$ToolsState.TempSelection[$ToolMockFiles[0].Path]=$true
Invoke-ToolsSelection
Assert-UI ($null -eq $ToolJob -and $LastDialogText -match 'Không (hoàn tác|khôi phục)' -and $ToolMockWrites -eq 0) 'Cancel cleanup preview starts no worker and deletes nothing'
$script:ToolsState.TempInventory=@(1..401 | ForEach-Object {[pscustomobject]@{Path=('C:\Demo\'+$_+'.tmp');Bytes=1;Modified='2026-01-01'}})
Render-TempPage
$first=$tw.FindName('TempFiles').Items[0];$first.IsChecked=$true;$first.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
$tw.FindName('TempNext').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($tw.FindName('TempFiles').Items.Count -eq 200 -and $ToolsState.TempPage -eq 1 -and $ToolsState.TempSelection.ContainsKey('C:\Demo\1.tmp')) 'Large cleanup scan is paged and changing pages preserves selected files'
$script:ToolsState.TempInventory=@();$script:ToolsState.TempSelection.Clear();$script:ToolsState.TempPage=0;Render-TempPage
# Render the new view, not a claim of desktop mouse testing.
Save-ManagerRendering $tw 'tools-manager-render'
$p=[pscustomobject]@{MockDelayMs=2200;SourceAgreed=$false}
$null=Start-ToolJob wingetcheck $p $false
$clock=New-Object Windows.Threading.DispatcherTimer;$clock.Interval=[TimeSpan]::FromMilliseconds(100);$script:ResponsiveTicks=0
$clock.Add_Tick({$script:ResponsiveTicks++});$clock.Start()
$deadline=(Get-Date).AddSeconds(15)
while (-not $ToolJob.Process.HasExited -and (Get-Date) -lt $deadline) {
 $frame=New-Object Windows.Threading.DispatcherFrame
 $pump=New-Object Windows.Threading.DispatcherTimer;$pump.Interval=[TimeSpan]::FromMilliseconds(50);$pump.Tag=$frame
 $pump.Add_Tick({param($sender,$args) $sender.Stop();$sender.Tag.Continue=$false});$pump.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
}
$clock.Stop()
$result=Get-ToolJobResult $ToolJob
Assert-UI ($null -ne $result -and $result.Status -eq 'Completed' -and $result.Mode -eq 'Simulation' -and $ResponsiveTicks -gt 5) 'Long simulated worker completes while the WPF dispatcher remains responsive'
Assert-UI ($result.Result.Mode -eq 'MÔ PHỎNG') 'Worker never labels fake hardware as real Windows measurements'
$ToolJob.Handled=$false;Poll-ToolsJob
Assert-UI ($ToolJob.Handled -and $tw.FindName('RunTool').IsEnabled -and $tw.FindName('ToolOutput').Text.Contains('MÔ PHỎNG')) 'Completed job updates result and reenables controls'
$tw.Close();$script:ToolsWindow=$null;$script:ToolJob=$null
