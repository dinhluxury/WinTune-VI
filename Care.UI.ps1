. "$PSScriptRoot/Care.Core.ps1"
function New-CareRepairWindow {
 Initialize-Tools (Join-Path $script:DataRoot 'tools') ([bool]($script:IsSimulation -or $script:WriteBlocked)) $script:UserId
 [xml]$xml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="WinTune VI — Sửa lỗi Windows" Width="1140" Height="830" MinWidth="820" MinHeight="580" Background="{DynamicResource Theme.WindowBrush}" Foreground="{DynamicResource Theme.TextBrush}" FontFamily="Segoe UI" FontSize="14" WindowStartupLocation="CenterOwner">
 <Grid Margin="22"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <StackPanel Margin="0,0,0,16"><TextBlock Text="Sửa lỗi Windows" FontSize="28" FontWeight="SemiBold"/><TextBlock x:Name="CareIntro" Margin="0,8,0,0" Text="Windows thường báo lỗi hoặc hoạt động bất thường? Làm bước 1 rồi đến bước 2. Không cần chạy nếu máy đang dùng bình thường." TextWrapping="Wrap" Foreground="{DynamicResource Theme.MutedBrush}"/></StackPanel>
 <Grid Grid.Row="1"><Grid.ColumnDefinitions><ColumnDefinition Width="1.1*"/><ColumnDefinition Width="16"/><ColumnDefinition/></Grid.ColumnDefinitions>
 <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel x:Name="CareSteps" Margin="0,0,10,0"/></ScrollViewer>
 <Border Grid.Column="2" Background="{DynamicResource Theme.SurfaceBrush}" CornerRadius="10" Padding="20" VerticalAlignment="Top"><ScrollViewer x:Name="CareResultScroll" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel>
 <TextBlock Text="Kết quả và bước tiếp theo" FontSize="18" FontWeight="SemiBold"/><TextBlock x:Name="CareResultTitle" Text="Chưa thực hiện kiểm tra" FontSize="23" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,20,0,10" Foreground="{DynamicResource Theme.AccentBrush}"/>
 <TextBlock x:Name="CareResultBody" Text="Chọn một bước ở bên trái để bắt đầu. Sau khi chạy, kết quả sẽ hiện tại đây bằng lời dễ hiểu." TextWrapping="Wrap"/>
 <ProgressBar x:Name="CareProgress" IsIndeterminate="True" Height="5" Visibility="Collapsed" Margin="0,18,0,8"/><TextBlock x:Name="CareElapsed" TextWrapping="Wrap" Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,10,0,0"/>
 <Border Background="{DynamicResource Theme.InputBrush}" CornerRadius="7" Padding="14" Margin="0,18,0,0"><StackPanel><TextBlock Text="Nên làm gì tiếp?" FontWeight="SemiBold"/><TextBlock x:Name="CareNext" Text="Bắt đầu với bước 1. Mỗi bước chỉ chạy khi bạn bấm và đồng ý." TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Border>
 <Expander x:Name="CareTechnical" Header="Thông báo gốc của Windows" Margin="0,18,0,0" Foreground="{DynamicResource Theme.TextBrush}"><TextBox x:Name="CareRaw" IsReadOnly="True" TextWrapping="Wrap" MaxHeight="220" VerticalScrollBarVisibility="Auto" Background="{DynamicResource Theme.InputBrush}" Foreground="{DynamicResource Theme.TextBrush}" Padding="10"/></Expander>
 <TextBlock x:Name="CareSource" Margin="0,18,0,0"/>
 </StackPanel></ScrollViewer></Border></Grid>
 <DockPanel Grid.Row="2" Margin="0,14,0,0"><Button x:Name="CareClose" Content="Đóng" DockPanel.Dock="Right"/><TextBlock Text="Lưu công việc trước khi sửa. WinTune không tự khởi động lại máy." TextWrapping="Wrap" Foreground="{DynamicResource Theme.MutedBrush}" VerticalAlignment="Center" Margin="0,0,12,0"/></DockPanel>
 </Grid>
</Window>
'@
 $reader=[Xml.XmlNodeReader]::new($xml);$w=[Windows.Markup.XamlReader]::Load($reader);$reader.Close();$w.Resources=$script:Window.Resources;Register-ThemeWindow $w
 if($script:Window.IsVisible){$w.Owner=$script:Window};$work=[Windows.SystemParameters]::WorkArea;$w.Width=[Math]::Min($w.Width,$work.Width);$w.Height=[Math]::Min($w.Height,$work.Height)
 $script:CareWindow=$w;$script:CareState=[pscustomobject]@{Kind='Repair';Buttons=@();Timer=$null;Current=$null;Job=$null;Results=@{}}
 foreach($step in Get-CareRepairSteps){
  $card=[Windows.Controls.Border]::new();$card.Background=$w.FindResource('Theme.SurfaceBrush');Set-ThemeResource $card Background Surface;$card.CornerRadius='9';$card.Padding='16';$card.Margin='0,0,0,10'
  $panel=[Windows.Controls.StackPanel]::new();$title=[Windows.Controls.TextBlock]::new();$title.Text=$(if($step.Number -eq '?'){'Dùng thêm khi cần'}else{'Bước '+$step.Number})+' · '+$step.Title;$title.FontSize=18;$title.FontWeight='SemiBold';$title.TextWrapping='Wrap';Set-ThemeResource $title Foreground Accent;$null=$panel.Children.Add($title)
  foreach($text in @($step.When,$step.Action,$step.Note)){$line=[Windows.Controls.TextBlock]::new();$line.Text=$text;$line.TextWrapping='Wrap';$line.Margin='0,8,0,0';if($text -eq $step.Note){$line.FontSize=12;Set-ThemeResource $line Foreground Muted};$null=$panel.Children.Add($line)}
  $button=[Windows.Controls.Button]::new();$button.Content=$step.Button;$button.Tag=$step.Id;$button.Margin='0,14,0,0';$button.HorizontalAlignment='Stretch';$button.Add_Click({param($sender,$eventArgs) Start-CareRepair $sender.Tag});$script:CareState.Buttons+=@($button);$null=$panel.Children.Add($button);$card.Child=$panel;$null=$w.FindName('CareSteps').Children.Add($card)
 }
 if($ToolSimulation){$w.Title+=' [MÔ PHỎNG]';$w.FindName('CareIntro').Text='MÔ PHỎNG — thử giao diện và quy trình; không sửa Windows thật. '+$w.FindName('CareIntro').Text}
 Set-SourceLink $w.FindName('CareSource') 'https://support.microsoft.com/en-us/windows/experience/backup-recovery/using-system-file-checker-in-windows'
 $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(300);$timer.Add_Tick({Poll-CareRepair});$script:CareState.Timer=$timer
 $w.FindName('CareClose').Add_Click({$script:CareWindow.Close()})
 $w.Add_Closing({param($sender,$eventArgs) if($script:CareState.Job -and -not $script:CareState.Job.Handled){$eventArgs.Cancel=$true;$sender.FindName('CareElapsed').Text='Windows đang thực hiện. Đợi có kết quả trước khi đóng cửa sổ.'}})
 $w.Add_Closed({$script:CareState.Timer.Stop();if($script:CareState.Job -and $script:CareState.Job.Handled){$script:ToolJob=$null};$script:CareWindow=$null})
 return $w
}
function Start-CareRepair([string]$Id,$Parameters=@{}) {
 try {
  if($script:CareState.Job -and -not $script:CareState.Job.Handled){throw 'Đợi bước đang chạy kết thúc trước.'}
  if($script:MainActionBusy -or ($script:FullJob)){throw 'Đợi thao tác Windows đang chạy kết thúc trước.'}
  $step=@(Get-CareRepairSteps|Where-Object Id -CEQ $Id);if($step.Count -ne 1){throw 'Bước sửa chưa được hỗ trợ.'}
  $text=$step[0].Title+"`n`n"+$step[0].Action+"`n`n"+$step[0].Note+"`n`nWindows có thể hỏi quyền quản trị. Lưu công việc trước; WinTune không tự khởi động lại."
  if(-not (Show-TextDialog 'Bắt đầu bước đã chọn?' $text $true $step[0].Button)){return}
  $job=Start-ToolJob $Id $Parameters $true $true;$script:CareState.Job=$job;$script:CareState.Current=$Id
  foreach($button in $script:CareState.Buttons){$button.IsEnabled=$false};$w=$script:CareWindow;$w.FindName('CareClose').IsEnabled=$false
  $w.FindName('CareResultTitle').Text='Đang '+$step[0].Title.ToLowerInvariant()+'…';Set-ThemeResource $w.FindName('CareResultTitle') Foreground Accent
  $w.FindName('CareResultBody').Text='Windows đang làm việc. Bước này có thể mất nhiều phút; chưa có kết quả cuối.';$w.FindName('CareNext').Text='Đợi có kết quả rồi đọc hướng dẫn tại đây. Không cần bấm lại.'
  $w.FindName('CareRaw').Text='';$w.FindName('CareTechnical').IsExpanded=$false;$w.FindName('CareProgress').Visibility='Visible';$w.FindName('CareResultScroll').ScrollToTop();$script:CareState.Timer.Start()
 }catch{Message $_.Exception.Message}
}
function Poll-CareRepair {
 $state=$script:CareState;if(-not $state -or -not $state.Job -or $state.Job.Handled){return}
 $w=$script:CareWindow;$seconds=[int]((Get-Date)-$state.Job.Started).TotalSeconds;$w.FindName('CareElapsed').Text='Đã chạy '+$seconds+' giây · Chưa có kết quả cuối'
 $result=Get-ToolJobResult $state.Job;if($null -eq $result){return}
 Complete-ToolJob $state.Job;$state.Timer.Stop();$script:ToolJob=$null
 try {
 $summary=Get-CareRepairResult $result;$state.Results[$state.Current]=$summary
 $w.FindName('CareResultTitle').Text=$summary.Title;Set-ThemeResource $w.FindName('CareResultTitle') Foreground $summary.Tone
 $w.FindName('CareResultBody').Text=$summary.Body;$w.FindName('CareNext').Text=$summary.Next;$w.FindName('CareRaw').Text=Format-ToolResult $result
 } catch {$w.FindName('CareResultTitle').Text='Chưa đọc được kết quả';$w.FindName('CareResultBody').Text='Không đủ thông tin để kết luận đã sửa được Windows.';$w.FindName('CareNext').Text='Giữ nhật ký để kiểm tra; không cần chạy lặp lại ngay.';$w.FindName('CareRaw').Text=$_.Exception.Message}
 finally {
  $w.FindName('CareElapsed').Text='Đã kết thúc sau '+$seconds+' giây';$w.FindName('CareProgress').Visibility='Collapsed';$w.FindName('CareClose').IsEnabled=$true
  foreach($button in $state.Buttons){$button.IsEnabled=$true}
 }
}
function Open-CareRepair {try{$w=New-CareRepairWindow;$null=$w.ShowDialog()}catch{Message $_.Exception.Message}}
