. "$PSScriptRoot/WizTree.Core.ps1"
. "$PSScriptRoot/WizTree.Launch.ps1"
function Set-WizTreeBusy([bool]$Busy) {
 $w=$script:WizTreeWindow
 $w.FindName('WizTreeProgress').Visibility=if ($Busy) {'Visible'} else {'Collapsed'}
 $w.FindName('WizTreeStop').Visibility=if ($Busy) {'Visible'} else {'Collapsed'}
 $w.FindName('WizTreeRetry').Visibility=if ($Busy) {'Collapsed'} else {'Visible'}
 $w.FindName('WizTreeStop').IsEnabled=$Busy
}
function Start-WizTreeTask {
 try {
  if ($script:WizTreeState.Job) {return}
  $script:WizTreeState.CloseRequested=$false;$script:WizTreeState.CancelRequested=$false
  $script:WizTreeState.Preparation=$null
  $script:WizTreeState.Job=Start-ToolJob 'wiztreeopen' ([pscustomobject]@{}) $true $true
  Set-WizTreeBusy $true;$script:WizTreeState.Timer.Start()
  $script:WizTreeWindow.FindName('WizTreeStatus').Text='Đang kiểm tra WizTree; nếu chưa có sẽ tự cài, rồi mở ổ C: để WizTree quét trực tiếp. Windows có thể hỏi quyền quản trị.'
 } catch {Set-WizTreeBusy $false;$script:WizTreeWindow.FindName('WizTreeStatus').Text='Chưa bắt đầu được. '+$_.Exception.Message}
}
function Stop-WizTreeTask {
 $s=$script:WizTreeState;if (-not $s.Job -or $s.CancelRequested) {return}
 [IO.File]::WriteAllText((Join-Path $s.Job.Path 'cancel.open'),'cancel')
 $s.CancelRequested=$true;$script:WizTreeWindow.FindName('WizTreeStop').IsEnabled=$false
 $script:WizTreeWindow.FindName('WizTreeStatus').Text='Đang hủy mở WizTree… Nếu trình cài đặt đang chạy, cần đợi cài xong trước khi đóng.'
}
function Show-WizTreeOpenResult {
 $w=$script:WizTreeWindow;$s=$script:WizTreeState
 try {
  $result=$s.Preparation
  if (-not $result -or $result.ScanMode -ne 'DirectDrive') {throw 'Chưa nhận được kết quả mở ổ đĩa thật.'}
  if ($result.Launched) {
   $script:Window.FindName('Status').Text='Đã mở WizTree để tự quét trực tiếp ổ '+$result.Drive+'. Sau khi quét, xem tổng dung lượng, đã dùng và còn trống ở phía trên.';$w.Close()
  } elseif ($script:IsSimulation -or $script:WriteBlocked -or $script:ToolSimulation) {$w.FindName('WizTreeStatus').Text='MÔ PHỎNG — đã chuẩn bị mở WizTree trực tiếp ở C:, không tạo CSV và không cài hoặc quét ổ thật.'}
  else {throw 'WizTree chưa khởi động; bấm Thử lại.'}
 } catch {$w.FindName('WizTreeStatus').Text='Chưa mở được WizTree: '+$_.Exception.Message}
}
function Poll-WizTreeTask {
 $s=$script:WizTreeState;if (-not $s.Job) {return}
 $w=$script:WizTreeWindow
 if (-not $s.CancelRequested) {
  $statusPath=Join-Path $s.Job.Path 'status.json'
  if ([IO.File]::Exists($statusPath)) {try {$status=Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json;if ($status.Message) {$w.FindName('WizTreeStatus').Text=$status.Message}} catch {}}
 }
 $r=Get-ToolJobResult $s.Job;if ($null -eq $r) {return}
 Complete-ToolJob $s.Job;$s.Job=$null;$s.Timer.Stop();Set-WizTreeBusy $false
 if ($r.Status -eq 'Completed' -and $r.Result.Launched) {$s.Preparation=$r.Result;Show-WizTreeOpenResult;return}
 if ($s.CloseRequested) {$w.Close();return}
 if ($s.CancelRequested) {$w.FindName('WizTreeStatus').Text='Đã hủy yêu cầu mở. Bấm Thử lại khi cần dùng WizTree.';return}
 if ($r.Status -ne 'Completed') {$w.FindName('WizTreeStatus').Text='Chưa hoàn tất. '+$r.Message;return}
 $s.Preparation=$r.Result;Show-WizTreeOpenResult
}
function New-WizTreeWindow {
 [xml]$xml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="WinTune VI — Chuẩn bị WizTree" Width="680" Height="440" MinWidth="540" MinHeight="380" FontFamily="Segoe UI" FontSize="14" Background="{DynamicResource Theme.WindowBrush}" Foreground="{DynamicResource Theme.TextBrush}" WindowStartupLocation="CenterOwner">
 <Grid Margin="24"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <StackPanel><TextBlock Text="Mở ổ đĩa bằng WizTree" FontSize="24" FontWeight="SemiBold" TextWrapping="Wrap"/><TextBlock Text="Tự cài WizTree nếu chưa có → mở ổ C: → WizTree tự quét." TextWrapping="Wrap" Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,8,0,16"/></StackPanel>
 <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel>
 <ProgressBar x:Name="WizTreeProgress" Height="5" IsIndeterminate="True" Visibility="Collapsed" Margin="0,0,0,12"/>
 <TextBlock x:Name="WizTreeStatus" Text="Đang chuẩn bị…" TextWrapping="Wrap" Margin="0,0,0,16"/>
 <TextBlock Text="WizTree mở ở ổ C: thật, không phải CSV. Ổ C: tự quét khi mở; sau đó phía trên hiện tổng dung lượng, đã dùng và còn trống. Tiến trình quét nằm ngay trong WizTree." TextWrapping="Wrap" Margin="0,0,0,12"/>
 <TextBlock Text="Lần đầu cần Internet để cài qua WinGet. WizTree miễn phí cho dùng cá nhân; dùng trong công việc cần giấy phép phù hợp. WinTune không tự xóa tệp." TextWrapping="Wrap" FontSize="12" Foreground="{DynamicResource Theme.MutedBrush}"/>
 <WrapPanel Margin="0,8,0,12"><TextBlock x:Name="WizTreeTerms" Margin="0,0,16,0"/><TextBlock x:Name="WizTreeSource"/></WrapPanel>
 </StackPanel></ScrollViewer>
 <WrapPanel Grid.Row="2" Margin="0,12,0,0"><Button x:Name="WizTreeStop" Content="Hủy mở" Visibility="Collapsed"/><Button x:Name="WizTreeRetry" Content="Thử lại" Visibility="Collapsed"/><Button x:Name="WizTreeDownload" Content="Trang tải chính thức"/><Button x:Name="WizTreeClose" Content="Đóng"/></WrapPanel>
 </Grid>
</Window>
'@
 $reader=New-Object Xml.XmlNodeReader $xml;$w=[Windows.Markup.XamlReader]::Load($reader);$reader.Close();$w.Resources=$script:Window.Resources;Register-ThemeWindow $w
 if ($script:Window.IsVisible) {$w.Owner=$script:Window};$area=[Windows.SystemParameters]::WorkArea;$w.Width=[Math]::Min($area.Width,$w.Width);$w.Height=[Math]::Min($area.Height,$w.Height)
 $script:WizTreeWindow=$w;$script:WizTreeState=[pscustomobject]@{Job=$null;Timer=$null;Preparation=$null;CancelRequested=$false;CloseRequested=$false}
 Set-SourceLink $w.FindName('WizTreeTerms') 'https://diskanalyzer.com/eula';Set-SourceLink $w.FindName('WizTreeSource') 'https://learn.microsoft.com/en-us/windows/package-manager/winget/source'
 $w.FindName('WizTreeRetry').Add_Click({Start-WizTreeTask})
 $w.FindName('WizTreeStop').Add_Click({Stop-WizTreeTask})
 $w.FindName('WizTreeDownload').Add_Click({if ($script:IsSimulation -or $script:WriteBlocked) {Message 'MÔ PHỎNG — không mở trình duyệt.'} else {Start-Process 'https://diskanalyzer.com/download'}})
 $w.FindName('WizTreeClose').Add_Click({$script:WizTreeWindow.Close()})
 $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(300);$timer.Add_Tick({Poll-WizTreeTask});$script:WizTreeState.Timer=$timer
 $w.Add_Closing({param($sender,$eventArgs) if ($script:WizTreeState.Job) {$eventArgs.Cancel=$true;$script:WizTreeState.CloseRequested=$true;Stop-WizTreeTask}})
 $w.Add_Closed({$script:WizTreeState.Timer.Stop()});return $w
}
function Open-Storage {
 try {
  if ($script:ToolJob -and -not $script:ToolJob.Handled) {throw 'Đợi công cụ đang chạy hoàn tất trước khi mở dung lượng ổ đĩa.'}
  Initialize-Tools (Join-Path $script:DataRoot 'tools') ([bool]($script:IsSimulation -or $script:WriteBlocked)) $script:UserId
  $w=New-WizTreeWindow;$w.Add_ContentRendered({Start-WizTreeTask});$null=$w.ShowDialog()
 } catch {Message $_.Exception.Message} finally {$script:WizTreeWindow=$null}
}
