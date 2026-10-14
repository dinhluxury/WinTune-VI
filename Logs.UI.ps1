function Read-WindowsLogSummary {
 if ($null -ne $script:LogsState.Job) {return}
 $script:LogsWindow.FindName('ReadLogs').IsEnabled=$false;$script:LogsWindow.FindName('LogsStatus').Text='Đang đọc nhật ký 3 ngày gần nhất…'
 try {$script:LogsState.Job=New-MonitorJob WindowsLogs;$script:LogsState.Timer.Start()} catch {$script:LogsWindow.FindName('ReadLogs').IsEnabled=$true;$script:LogsWindow.FindName('LogsStatus').Text='Không bắt đầu đọc được: '+$_.Exception.Message}
}
function Poll-WindowsLogSummary {
 $job=$script:LogsState.Job;if ($null -eq $job -or -not $job.Handle.IsCompleted) {return}
 $script:LogsState.Job=$null;$script:LogsState.Timer.Stop();$w=$script:LogsWindow
 try {
  $r=Receive-MonitorJob $job;$w.FindName('LogRows').ItemsSource=@($r.Rows)
  $w.FindName('LogsStatus').Text=if ($r.Mode -eq 'Simulation') {'MÔ PHỎNG — chưa đọc nhật ký Windows thật.'} elseif ($r.Issues.Count) {'Chỉ đọc được một phần. '+($r.Issues -join ' ')} elseif (-not $r.Rows.Count) {'Không có sự kiện nghiêm trọng/lỗi trong phạm vi đã đọc. Không phải đánh giá toàn bộ sức khỏe máy.'} else {"Có $($r.Rows.Count) sự kiện trong 3 ngày gần nhất. Nhật ký không tự xác định nguyên nhân sự cố."}
  if ($r.Limited) {$w.FindName('LogsStatus').Text+=' Giới hạn 200 sự kiện mỗi nhật ký; có thể còn sự kiện chưa hiển thị.'}
  if ($r.Rows.Count) {$w.FindName('LogRows').SelectedIndex=0} else {$w.FindName('LogDetail').Text=''}
 } catch {$w.FindName('LogsStatus').Text='Không đọc được nhật ký: '+$_.Exception.Message}
 $w.FindName('ReadLogs').IsEnabled=$true
}
function New-WindowsLogsWindow {
 [xml]$xml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="WinTune VI — Nhật ký Windows dễ hiểu" Width="1100" Height="720" MinWidth="760" MinHeight="520" Background="{DynamicResource Theme.WindowBrush}" Foreground="{DynamicResource Theme.TextBrush}" FontFamily="Segoe UI" FontSize="14" WindowStartupLocation="CenterOwner">
 <Grid Margin="24"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <StackPanel><TextBlock Text="Nhật ký Windows dễ hiểu" FontSize="26" FontWeight="SemiBold"/><TextBlock Text="Các sự kiện nghiêm trọng và lỗi của Windows/ứng dụng trong 3 ngày gần nhất. Nhật ký cũ không có nghĩa máy đang hỏng; WinTune chỉ giải thích một số sự kiện đã biết, không đoán nguyên nhân." Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,12,0,14"/></StackPanel>
  <ListView x:Name="LogRows" Grid.Row="1" Background="{DynamicResource Theme.SurfaceBrush}" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Auto"><ListView.View><GridView><GridViewColumn Header="Thời điểm" Width="110" DisplayMemberBinding="{Binding Time}"/><GridViewColumn Header="Mức độ" Width="100" DisplayMemberBinding="{Binding Level}"/><GridViewColumn Header="Điều đã ghi nhận" Width="270"><GridViewColumn.CellTemplate><DataTemplate><TextBlock Text="{Binding Meaning}" TextWrapping="Wrap"/></DataTemplate></GridViewColumn.CellTemplate></GridViewColumn><GridViewColumn Header="Nên làm gì" Width="420"><GridViewColumn.CellTemplate><DataTemplate><TextBlock Text="{Binding Advice}" TextWrapping="Wrap"/></DataTemplate></GridViewColumn.CellTemplate></GridViewColumn></GridView></ListView.View></ListView>
  <Expander Grid.Row="2" Header="Chi tiết sự kiện đã chọn" Margin="0,14,0,12" Foreground="{DynamicResource Theme.MutedBrush}"><TextBox x:Name="LogDetail" IsReadOnly="True" TextWrapping="Wrap" MaxHeight="180" VerticalScrollBarVisibility="Auto" Background="{DynamicResource Theme.InputBrush}" Foreground="{DynamicResource Theme.TextBrush}" BorderThickness="0" Padding="12"/></Expander>
  <StackPanel Grid.Row="3"><TextBlock x:Name="LogsStatus"/><TextBlock x:Name="LogsSource" Margin="0,8,0,8"/><WrapPanel><Button x:Name="ReadLogs" Content="Đọc lại"/><Button x:Name="NativeLogs" Content="Mở nhật ký gốc (nâng cao)"/><Button x:Name="CloseLogs" Content="Đóng"/></WrapPanel></StackPanel>
 </Grid>
</Window>
'@
 $reader=New-Object Xml.XmlNodeReader $xml;$w=[Windows.Markup.XamlReader]::Load($reader);$reader.Close();$w.Resources=$script:Window.Resources;Register-ThemeWindow $w;if ($script:Window.IsVisible) {$w.Owner=$script:Window}
 $work=[Windows.SystemParameters]::WorkArea;$w.Width=[Math]::Min($w.Width,$work.Width);$w.Height=[Math]::Min($w.Height,$work.Height)
 $script:LogsWindow=$w;$script:LogsState=[pscustomobject]@{Job=$null;Timer=$null}
 $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(300);$timer.Add_Tick({Poll-WindowsLogSummary});$script:LogsState.Timer=$timer
 Set-SourceLink ($w.FindName('LogsSource')) 'https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/event-id-41-restart'
 $w.FindName('LogRows').Add_SelectionChanged({param($sender,$eventArgs) if ($null -ne $sender.SelectedItem) {$r=$sender.SelectedItem;$script:LogsWindow.FindName('LogDetail').Text="$($r.Log) • $($r.Provider) • Mã $($r.Id)`n`n$($r.Detail)"}})
 $w.FindName('ReadLogs').Add_Click({Read-WindowsLogSummary});$w.FindName('NativeLogs').Add_Click({if ($script:IsSimulation -or $script:WriteBlocked) {Message 'Mô phỏng/chỉ đọc: không mở nhật ký gốc.'} else {Start-Process -FilePath (Join-Path $env:WINDIR 'System32/eventvwr.msc')}})
 $w.FindName('CloseLogs').Add_Click({param($sender,$eventArgs) [Windows.Window]::GetWindow($sender).Close()});$w.Add_Closed({$script:LogsState.Timer.Stop()})
 return $w
}
function Open-WindowsLogs {
 try {$w=New-WindowsLogsWindow;Read-WindowsLogSummary;$null=$w.ShowDialog()} catch {Message $_.Exception.Message}
 finally {if ($null -ne $script:LogsWindow) {$script:LogsState.Timer.Stop();$job=$script:LogsState.Job;if ($null -ne $job) {try {$job.PowerShell.Stop()} catch {};$job.PowerShell.Dispose()}};$script:LogsWindow=$null}
}
