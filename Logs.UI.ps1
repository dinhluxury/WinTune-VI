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
  $w.FindName('LogsStatus').Text=if ($r.Mode -eq 'Simulation') {'MÔ PHỎNG — chưa đọc nhật ký Windows thật.'} elseif (-not $r.Rows.Count) {'Không có lỗi trong phạm vi đã đọc. Đây không phải đánh giá toàn bộ sức khỏe máy.'} else {"$($r.Records) bản ghi → $($r.Rows.Count) nhóm trong 3 ngày. Số bản ghi không phải số sự cố riêng biệt hoặc lỗi còn tồn tại."}
  if ($r.Issues.Count) {$w.FindName('LogsStatus').Text+=' Chỉ đọc được một phần: '+($r.Issues -join ' ')}
  if ($r.Limited) {$w.FindName('LogsStatus').Text+=' Đã chạm giới hạn 200 sự kiện mỗi nhật ký.'}
  if ($r.Rows.Count) {$w.FindName('LogRows').SelectedIndex=0} else {foreach ($name in @('LogDetail','LogMeaning','LogAdvice','LogCurrent')) {$w.FindName($name).Text=''}}
 } catch {$w.FindName('LogsStatus').Text='Không đọc được nhật ký: '+$_.Exception.Message}
 $w.FindName('ReadLogs').IsEnabled=$true
}
function New-WindowsLogsWindow {
 [xml]$xml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="WinTune VI — Lỗi Windows và ứng dụng" Width="1160" Height="740" MinWidth="820" MinHeight="540" Background="{DynamicResource Theme.WindowBrush}" Foreground="{DynamicResource Theme.TextBrush}" FontFamily="Segoe UI" FontSize="14" WindowStartupLocation="CenterOwner">
 <Grid Margin="22"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <StackPanel><TextBlock Text="Windows đã ghi nhận sự cố gì?" FontSize="26" FontWeight="SemiBold"/><TextBlock Text="Chọn tên ứng dụng hoặc dịch vụ để xem điều đã xảy ra và việc nên làm. Các bản ghi giống nhau được gộp lại; lỗi cũ có thể đã hết." Foreground="{DynamicResource Theme.MutedBrush}" TextWrapping="Wrap" Margin="0,8,0,14"/></StackPanel>
 <Grid Grid.Row="1"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="16"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
 <ListView x:Name="LogRows" Background="{DynamicResource Theme.SurfaceBrush}" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Auto"><ListView.View><GridView><GridViewColumn Header="Ứng dụng / dịch vụ" Width="270" DisplayMemberBinding="{Binding Target}"/><GridViewColumn Header="Gần nhất" Width="110" DisplayMemberBinding="{Binding Time}"/><GridViewColumn Header="Bản ghi" Width="65" DisplayMemberBinding="{Binding Count}"/></GridView></ListView.View></ListView>
 <Border Grid.Column="2" Padding="16" CornerRadius="8" Background="{DynamicResource Theme.SurfaceBrush}"><ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel>
 <TextBlock x:Name="LogSubject" Text="Chọn một mục ở bên trái" FontSize="21" FontWeight="SemiBold" TextWrapping="Wrap"/>
 <TextBlock Text="Điều đã xảy ra" Foreground="{DynamicResource Theme.AccentBrush}" FontWeight="SemiBold" Margin="0,16,0,6"/><TextBlock x:Name="LogMeaning" TextWrapping="Wrap"/>
 <TextBlock x:Name="LogCurrent" Foreground="{DynamicResource Theme.AccentBrush}" TextWrapping="Wrap" Margin="0,12,0,0"/>
 <TextBlock Text="Bạn nên làm gì?" Foreground="{DynamicResource Theme.AccentBrush}" FontWeight="SemiBold" Margin="0,16,0,6"/><TextBlock x:Name="LogAdvice" TextWrapping="Wrap"/>
 <Expander Foreground="{DynamicResource Theme.TextBrush}" Header="Nội dung gốc và mã sự kiện" Margin="0,16,0,0"><Expander.HeaderTemplate><DataTemplate><TextBlock Text="{Binding}" Foreground="{DynamicResource Theme.TextBrush}"/></DataTemplate></Expander.HeaderTemplate><TextBox x:Name="LogDetail" IsReadOnly="True" TextWrapping="Wrap" MinHeight="80" MaxHeight="260" VerticalScrollBarVisibility="Auto" Background="{DynamicResource Theme.InputBrush}" Foreground="{DynamicResource Theme.TextBrush}" BorderThickness="0" Padding="10"/></Expander>
 </StackPanel></ScrollViewer></Border></Grid>
 <StackPanel Grid.Row="2" Margin="0,12,0,0"><TextBlock x:Name="LogsStatus" TextWrapping="Wrap"/><TextBlock x:Name="LogsSource" Margin="0,8,0,8"/><WrapPanel><Button x:Name="ReadLogs" Content="Đọc lại"/><Button x:Name="NativeLogs" Content="Mở nhật ký gốc (nâng cao)"/><Button x:Name="CloseLogs" Content="Đóng"/></WrapPanel></StackPanel>
 </Grid>
</Window>
'@
 $reader=New-Object Xml.XmlNodeReader $xml;$w=[Windows.Markup.XamlReader]::Load($reader);$reader.Close();$w.Resources=$script:Window.Resources;Register-ThemeWindow $w;if ($script:Window.IsVisible) {$w.Owner=$script:Window}
 $work=[Windows.SystemParameters]::WorkArea;$w.Width=[Math]::Min($w.Width,$work.Width);$w.Height=[Math]::Min($w.Height,$work.Height)
 $script:LogsWindow=$w;$script:LogsState=[pscustomobject]@{Job=$null;Timer=$null}
 $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(300);$timer.Add_Tick({Poll-WindowsLogSummary});$script:LogsState.Timer=$timer
 Set-SourceLink ($w.FindName('LogsSource')) 'https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-application-service-crashing-behavior'
 $w.FindName('LogRows').Add_SelectionChanged({param($sender,$eventArgs) if ($null -ne $sender.SelectedItem) {$r=$sender.SelectedItem;$w=$script:LogsWindow;$w.FindName('LogSubject').Text=$r.Target+' • '+$r.Count+' bản ghi';$w.FindName('LogMeaning').Text=$r.Meaning;$w.FindName('LogAdvice').Text=$r.Advice;$w.FindName('LogCurrent').Text=$r.Current;$w.FindName('LogDetail').Text=$r.Detail}})
 $w.FindName('ReadLogs').Add_Click({Read-WindowsLogSummary});$w.FindName('NativeLogs').Add_Click({if ($script:IsSimulation -or $script:WriteBlocked) {Message 'Mô phỏng/chỉ đọc: không mở nhật ký gốc.'} else {Start-Process -FilePath (Join-Path $env:WINDIR 'System32/eventvwr.msc')}})
 $w.FindName('CloseLogs').Add_Click({param($sender,$eventArgs) [Windows.Window]::GetWindow($sender).Close()});$w.Add_Closed({$script:LogsState.Timer.Stop()})
 return $w
}
function Open-WindowsLogs {
 try {$w=New-WindowsLogsWindow;Read-WindowsLogSummary;$null=$w.ShowDialog()} catch {Message $_.Exception.Message}
 finally {if ($null -ne $script:LogsWindow) {$script:LogsState.Timer.Stop();$job=$script:LogsState.Job;if ($null -ne $job) {try {$job.PowerShell.Stop()} catch {};$job.PowerShell.Dispose()}};$script:LogsWindow=$null}
}

