# Recorded-event fixtures and simulated removal.
$uxWrites=$SimWriteCount
. "$PSScriptRoot/Logs.Core.ps1"
$fixture=[pscustomobject]@{ProviderName='Application Error';Id=1000;Level=2;TimeCreated=Get-Date;LogName='Application';Message='DỮ LIỆU KIỂM THỬ';Xml='<Event><EventData><Data Name="AppName">ExampleEditor.exe</Data><Data Name="ModuleName">example.dll</Data><Data Name="ExceptionCode">c0000005</Data></EventData></Event>'}
$event=Convert-WindowsEventSummary $fixture;$rows=@(Group-WindowsEventSummaries @($event,$event))
$lw=New-WindowsLogsWindow;$lw.FindName('LogRows').ItemsSource=$rows;$lw.FindName('LogRows').SelectedIndex=0;$lw.FindName('LogsStatus').Text='DỮ LIỆU KIỂM THỬ — 2 bản ghi mẫu, không phải lỗi của máy';$lw.Show();$lw.UpdateLayout()
Assert-UI ($lw.FindName('LogMeaning').Text.Contains('ExampleEditor.exe') -and $lw.FindName('LogSubject').Text.Contains('2 bản ghi') -and $lw.FindName('LogAdvice').Parent -is [Windows.Controls.StackPanel]) 'Selected log immediately shows app, repeated records and advice without expanding details'
Save-SoftwareRendering $lw 'logs-actionable';$lw.Close();$script:LogsWindow=$null
$pw=New-ToolsWindow 'Tối ưu';$pw.Show();$pw.FindName('ToolOutput').Text=Format-PowerList (Get-PowerList);$pw.UpdateLayout()
Assert-UI ($pw.FindName('ToolsHeading').Text -eq 'Hiệu năng và pin' -and $pw.FindName('ToolOutput').Text.Contains('Cân bằng') -and $null -eq $ToolJob) 'Power explanation shows concrete effects before any mode change'
Save-SoftwareRendering $pw 'power-explained';$pw.Close();$script:ToolsWindow=$null
$sw=New-ToolsWindow 'Phần mềm';$sw.Show();$sw.UpdateLayout()
Assert-UI ($sw.FindName('ToolProgress').Visibility -eq 'Collapsed' -and $sw.FindName('ToolSetup').ActualHeight -gt 250) 'Empty progress area leaves room for the software catalog'
Show-SoftwareOutput;$sw.FindName('ToolOutput').Text='DỮ LIỆU KIỂM THỬ — tiến trình cài đặt';$sw.UpdateLayout();$expanded=$sw.FindName('ToolSetup').ActualHeight;$sw.FindName('ToolProgress').IsExpanded=$false;$sw.UpdateLayout()
Assert-UI ($sw.FindName('ToolSetup').ActualHeight -ge $expanded -and $sw.FindName('ToolProgress').ActualHeight -lt 40) 'Installation progress can collapse and return space to the catalog'
$sw.Close();$script:ToolsWindow=$null
# Exercise the actual main checkbox -> preview -> worker flow in isolated simulation.
$savedRoot=$DataRoot;$savedMemory=$Memory;$script:DataRoot=Join-Path $savedRoot 'direct-copilot';$null=New-Item -ItemType Directory -Path $DataRoot -Force;$script:Memory=@{}
Initialize-Tools (Join-Path $DataRoot 'tools') $true $UserId
Initialize-Actions (Join-Path $DataRoot 'actions') $true $UserId
$script:ToolJob=$null;$Selected.Clear();$Search.Text='';Render-List
$copilot=@($List.Items | Where-Object {$_.Tag.Id -ceq 'copilotapp'})[0].Content.Children[0]
Assert-UI ($copilot.IsEnabled) 'Copilot is a directly selectable tweak'
$copilot.IsChecked=$true;$copilot.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($Selected.ContainsKey('copilotapp') -and $null -eq $ManagementWindow) 'Checking Copilot queues it without opening the app manager'
function Wait-CopilotFixture {
 $deadline=(Get-Date).AddSeconds(25)
 while ($script:MainActionBusy -and (Get-Date) -lt $deadline) {Start-Sleep -Milliseconds 50;Poll-MainCopilot}
 if ($script:MainActionBusy) {throw 'Copilot fixture did not finish'}
}
$script:DialogResponse=$false;$Window.FindName('Preview').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));Wait-CopilotFixture
Assert-UI ($LastDialogText.Contains('Microsoft.Copilot') -and $Selected.ContainsKey('copilotapp') -and -not $MainActionBusy) 'Canceling direct preview keeps the selection and uninstalls nothing'
Initialize-Actions (Join-Path $DataRoot 'actions') $true $UserId
Assert-UI (@(Get-AllAppInventory).Count -eq 30) 'Canceled direct removal preserves all simulated apps'
$Selected['ads']=$true;$script:DialogResponse=$true;Update-Selection;$Window.FindName('Preview').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));Wait-CopilotFixture
Initialize-Actions (Join-Path $DataRoot 'actions') $true $UserId
Assert-UI (@(Get-AllAppInventory).Count -eq 29 -and -not $Selected.ContainsKey('copilotapp') -and $Memory.Count -gt 0 -and $LastDialogText.Contains('mã quảng cáo')) 'One confirmed preview applies selected settings and removes only Copilot through its worker'
$Selected['copilotapp']=$true;Update-Selection;$Window.FindName('Preview').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));Wait-CopilotFixture
Assert-UI ($Window.FindName('Status').Text.Contains('Không tìm thấy') -and -not $Window.FindName('Status').Text.Contains('Đã gỡ')) 'Absent Copilot reports no app instead of false removal success'
$script:DataRoot=$savedRoot;$script:Memory=$savedMemory;$Selected.Clear();$script:ToolJob=$null;Initialize-Tools (Join-Path $DataRoot 'tools') $true $UserId;Refresh-UI
