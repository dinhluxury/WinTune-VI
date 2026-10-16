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
Assert-UI (@(Get-VisibleTools | Where-Object {$_.Id -in @('tempscan','tempdelete','recycle')}).Count -eq 0) 'Cleanup shortcuts are replaced by read-only storage analysis'
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
$tw.FindName('ToolList').SelectedIndex=-1;$tw.FindName('ToolList').SelectedIndex=0
Assert-UI ($tw.FindName('RunTool').IsEnabled) 'Changing tool details after completion does not access a disposed Process'
$savedToolResultReader=${function:Get-ToolJobResult}
$fakeCompleted=[pscustomobject]@{HasExited=$true};$fakeCompleted|Add-Member ScriptMethod Dispose {}
$script:ToolJob=[pscustomobject]@{Id='wingetinstall';Process=$fakeCompleted;Handled=$false;Started=Get-Date}
try {
 function Get-ToolJobResult($Job) {return [pscustomobject]@{Status='Completed';Id='wingetinstall';Mode='Simulation';Message='fixture';RestartRequired=$true;Result=[pscustomobject]@{ExitCode=0;Output='fixture';Rows=@([pscustomobject]@{Id='7zip.7zip';State='Completed'})}}}
 Poll-ToolsJob
 Assert-UI ($tw.FindName('ToolStatus').Text.Contains('yêu cầu khởi động lại') -and $ToolJob.Handled) 'Install summary preserves restart guidance instead of overwriting the worker warning'
} finally {Set-Item Function:Get-ToolJobResult $savedToolResultReader}
$tw.Close();$script:ToolsWindow=$null;$script:ToolJob=$null
