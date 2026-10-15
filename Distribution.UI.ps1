# On-demand update page; no command registration or network polling at startup.
. "$PSScriptRoot/UpdateStatus.Core.ps1"
function Open-DistributionCenter {
 if ($null -ne $script:DistributionWindow) {$script:DistributionWindow.Activate() | Out-Null;return}
 Import-Module "$PSScriptRoot/Distribution.Runtime.psm1" -Global
 [xml]$xml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="WinTune VI — Cập nhật" Width="650" Height="490" MinWidth="520" MinHeight="420" WindowStartupLocation="CenterOwner" Background="{DynamicResource Theme.WindowBrush}" Foreground="{DynamicResource Theme.TextBrush}" FontFamily="Segoe UI" FontSize="14">
 <Grid Margin="24"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <StackPanel><TextBlock Text="Cập nhật WinTune" FontSize="25" FontWeight="SemiBold"/><TextBlock x:Name="DistributionVersion" Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,8,0,16"/></StackPanel>
 <Border Grid.Row="1" Background="{DynamicResource Theme.SurfaceBrush}" CornerRadius="8" Padding="18"><ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel>
 <TextBlock x:Name="DistributionState" Text="Chưa kiểm tra cập nhật" FontSize="20" FontWeight="SemiBold" Foreground="{DynamicResource Theme.AccentBrush}" TextWrapping="Wrap"/>
 <TextBlock x:Name="DistributionLatest" Text="Bản mới nhất trên GitHub: chưa kiểm tra" TextWrapping="Wrap" Margin="0,12,0,6"/>
 <TextBlock x:Name="DistributionDetail" Text="Bấm Kiểm tra cập nhật để biết phiên bản đang dùng đã mới nhất chưa." TextWrapping="Wrap" Foreground="{DynamicResource Theme.MutedBrush}"/>
 <TextBlock x:Name="DistributionChecked" Text="Chưa kiểm tra lần nào trong cửa sổ này." FontSize="12" Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,12,0,0"/>
 <TextBlock x:Name="DistributionSource" FontSize="12" Foreground="{DynamicResource Theme.MutedBrush}" TextWrapping="Wrap" Margin="0,5,0,14"/>
 <WrapPanel><Button x:Name="DistributionCheck" Content="Kiểm tra cập nhật"/><Button x:Name="DistributionInstall" Content="Cập nhật" Background="{DynamicResource Theme.AccentButtonBrush}" Foreground="{DynamicResource Theme.OnAccentBrush}" IsEnabled="False"/><Button x:Name="DistributionOpenFolder" Content="Mở thư mục bản mới" Visibility="Collapsed"/></WrapPanel>
 </StackPanel></ScrollViewer></Border>
 <StackPanel Grid.Row="2" Margin="0,14,0,12"><ProgressBar x:Name="DistributionProgress" Height="5" IsIndeterminate="True" Visibility="Collapsed" Margin="0,0,0,10"/><TextBlock x:Name="DistributionStatus" Text="Chỉ tải bản cập nhật sau khi bạn xác nhận." TextWrapping="Wrap"/></StackPanel>
 <WrapPanel Grid.Row="3"><Button x:Name="DistributionCancel" Content="Hủy tác vụ" IsEnabled="False"/><Button x:Name="DistributionClose" Content="Đóng"/></WrapPanel>
 </Grid>
</Window>
'@
 $reader=New-Object Xml.XmlNodeReader $xml;$w=[Windows.Markup.XamlReader]::Load($reader);$reader.Close();$w.Resources=$script:Window.Resources;Register-ThemeWindow $w
 if ($Window.IsVisible) {$w.Owner=$Window}
 $work=[Windows.SystemParameters]::WorkArea;$w.Width=[Math]::Min($w.Width,$work.Width);$w.Height=[Math]::Min($w.Height,$work.Height)
 $script:DistributionWindow=$w;$script:DistributionJob=$null;$script:DistributionInfo=$null;$script:DistributionConfig=$null;$script:DistributionPreparedPath=''
 $script:DistributionRunningVersion=(Get-WinTuneVersion $PSScriptRoot).Version
 $w.FindName('DistributionVersion').Text='Phiên bản đang dùng: '+$script:DistributionRunningVersion+$(if ($script:IsSimulation -or $script:WriteBlocked) {' • MÔ PHỎNG'} else {''})
 try {$script:DistributionConfig=Get-ReleaseConfig $PSScriptRoot;$w.FindName('DistributionSource').Text='Nguồn: GitHub / '+$script:DistributionConfig.Repository}
 catch {$w.FindName('DistributionCheck').IsEnabled=$false;$w.FindName('DistributionSource').Text=$_.Exception.Message;$w.FindName('DistributionState').Text='Chưa thể kiểm tra cập nhật'}
 $w.FindName('DistributionCheck').Add_Click({Start-DistributionJob Check})
 $w.FindName('DistributionInstall').Add_Click({
  $info=$script:DistributionInfo;if ($null -eq $info -or $info.Status -ne 'Available') {return}
  $text='Cập nhật từ '+$script:DistributionRunningVersion+' lên '+$info.Manifest.Version+". Nguồn: "+$info.ReleaseUrl+". Tải và xác minh bản mới, giữ bản đang chạy. Sau khi hoàn tất, đóng WinTune hiện tại rồi mở Mo-WinTune.cmd trong thư mục bản mới."
  if (Show-TextDialog 'Cập nhật WinTune' $text $true 'Tải và chuẩn bị bản mới') {Start-DistributionJob Install}
 })
 $w.FindName('DistributionOpenFolder').Add_Click({
  try {
   if ($script:IsSimulation -or $script:WriteBlocked) {Message 'MÔ PHỎNG — không mở thư mục thật.';return}
   $path=[IO.Path]::GetFullPath($script:DistributionPreparedPath);$base=[IO.Path]::GetFullPath((Join-Path (Get-WinTuneInstallRoot) 'apps')).TrimEnd('\')+'\'
   if (-not $path.StartsWith($base,[StringComparison]::OrdinalIgnoreCase) -or -not [IO.Directory]::Exists($path)) {throw 'Không tìm thấy thư mục bản cập nhật đã chuẩn bị.'}
   Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList (Quote-ToolArgument $path)
  } catch {Message $_.Exception.Message}
 })
 $w.FindName('DistributionCancel').Add_Click({if ($null -ne $script:DistributionJob) {$script:DistributionJob.Cancel.Cancel();$script:DistributionWindow.FindName('DistributionStatus').Text='Đang hủy tác vụ…'}})
 $w.FindName('DistributionClose').Add_Click({param($sender,$eventArgs) [Windows.Window]::GetWindow($sender).Close()})
 $w.Add_Closing({param($sender,$eventArgs) if ($null -ne $script:DistributionJob) {$eventArgs.Cancel=$true;$sender.FindName('DistributionStatus').Text='Tác vụ đang chạy. Bấm Hủy hoặc đợi kết quả trước khi đóng.'}})
 $w.Add_Closed({$script:DistributionTimer.Stop();$script:DistributionWindow=$null;$script:DistributionInfo=$null;$script:DistributionConfig=$null})
 $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(200);$timer.Add_Tick({Receive-DistributionUIJob});$script:DistributionTimer=$timer
 $w.Show()
}
function Set-DistributionCheckResult($Info) {
 $display=Get-WinTuneUpdateStatus $Info $script:DistributionRunningVersion;$w=$script:DistributionWindow
 $script:DistributionInfo=$Info;$w.FindName('DistributionState').Text=$display.Title
 $w.FindName('DistributionLatest').Text='Bản stable mới nhất trên GitHub: '+$display.LatestVersion
 $w.FindName('DistributionDetail').Text=$display.Detail;$w.FindName('DistributionChecked').Text='Đã kiểm tra: '+(Get-Date).ToString('dd/MM/yyyy HH:mm:ss')
 $w.FindName('DistributionInstall').IsEnabled=$display.CanDownload
 Set-ThemeResource $w.FindName('DistributionState') Foreground Accent
 $script:DistributionPreparedPath=''
 if ($display.State -eq 'Ready' -and $Info.PSObject.Properties['PreparedPath']) {$script:DistributionPreparedPath=[string]$Info.PreparedPath}
 $w.FindName('DistributionOpenFolder').Visibility=if ($script:DistributionPreparedPath) {'Visible'} else {'Collapsed'}
 $w.FindName('DistributionStatus').Text='Đã xác minh thông tin bản phát hành.'
}
function Start-DistributionJob([ValidateSet('Check','Install')][string]$Mode) {
 if ($null -ne $script:DistributionJob) {return}
 if ($Mode -eq 'Install' -and ($null -eq $script:DistributionInfo -or $script:DistributionInfo.Status -ne 'Available')) {return}
 $ps=[PowerShell]::Create();$cancel=New-Object Threading.CancellationTokenSource
 $code=@'
param($source,$mode,$cfg,$info,$cancel,$simulation)
$ErrorActionPreference='Stop'
. (Join-Path $source 'Distribution.Core.ps1');. (Join-Path $source 'CommandRegistration.ps1')
if ($simulation) {Start-Sleep -Milliseconds 600;Assert-DistributionCancelled $cancel;return [pscustomobject]@{Status='Simulation';Message='MÔ PHỎNG: chưa kiểm tra hoặc tải bản phát hành thật.'}}
$root=Get-WinTuneInstallRoot
switch ($mode) {
 'Check' {
  $running=(Get-WinTuneVersion $source).Version;$prepared=Get-PreparedDistributionVersion $root $running
  $result=Get-DistributionUpdate $cfg $prepared $cancel
  if ([version]$prepared -gt [version]$running) {$path=Assert-DistributionPath ((Get-Content -LiteralPath (Join-Path $root 'current.txt') -Raw -Encoding UTF8).Trim()) (Join-Path $root 'apps');$result | Add-Member -NotePropertyName PreparedPath -NotePropertyValue $path}
  return $result
 }
 'Install' {Install-DistributionUpdate $info $root $true $cancel $cfg}
 default {throw 'Không có thao tác cập nhật này.'}
}
'@
 $null=$ps.AddScript($code).AddArgument($PSScriptRoot).AddArgument($Mode).AddArgument($script:DistributionConfig).AddArgument($script:DistributionInfo).AddArgument($cancel).AddArgument([bool]($script:IsSimulation -or $script:WriteBlocked))
 try {$handle=$ps.BeginInvoke();$script:DistributionJob=[pscustomobject]@{PowerShell=$ps;Handle=$handle;Cancel=$cancel;Mode=$Mode}} catch {$ps.Dispose();$cancel.Dispose();throw}
 $w=$script:DistributionWindow
 foreach ($name in @('DistributionCheck','DistributionInstall','DistributionOpenFolder')) {$w.FindName($name).IsEnabled=$false}
 $w.FindName('DistributionCancel').IsEnabled=$true;$w.FindName('DistributionProgress').Visibility='Visible'
 if ($Mode -eq 'Check') {$script:DistributionInfo=$null;$w.FindName('DistributionState').Text='Đang kiểm tra cập nhật…';$w.FindName('DistributionStatus').Text='Đang so sánh với bản phát hành đã xác minh trên GitHub…'}
 else {$w.FindName('DistributionState').Text='Đang tải và xác minh bản mới…';$w.FindName('DistributionStatus').Text='Giao diện vẫn dùng được trong lúc tải.'}
 $script:DistributionTimer.Start()
}
function Receive-DistributionUIJob {
 $j=$script:DistributionJob;if ($null -eq $j -or -not $j.Handle.IsCompleted) {return}
 $w=$script:DistributionWindow
 try {
  $result=@($j.PowerShell.EndInvoke($j.Handle));if ($j.PowerShell.HadErrors) {throw ($j.PowerShell.Streams.Error | Out-String)}
  if ($result.Count -ne 1) {throw 'Tác vụ không trả kết quả hợp lệ.'};$r=$result[0]
  if ($j.Mode -eq 'Check' -and $r.Status -in @('Available','Current')) {Set-DistributionCheckResult $r}
  elseif ($r.Status -eq 'Simulation') {$script:DistributionInfo=$null;$w.FindName('DistributionState').Text='MÔ PHỎNG — chưa kiểm tra bản phát hành thật';$w.FindName('DistributionStatus').Text=$r.Message}
  elseif ($j.Mode -eq 'Install' -and $r.Status -eq 'Prepared') {
   $script:DistributionPreparedPath=$r.Path;$script:DistributionInfo=$null
   $w.FindName('DistributionState').Text='Bản cập nhật đã sẵn sàng';$w.FindName('DistributionDetail').Text='Đã tải và xác minh bản '+$r.Version+'. Đóng WinTune hiện tại, rồi mở Mo-WinTune.cmd trong thư mục bản mới.'
   $w.FindName('DistributionStatus').Text='Mở thư mục bản mới để dùng phiên bản vừa cập nhật.';$w.FindName('DistributionOpenFolder').Visibility='Visible'
  } else {throw 'Chưa nhận được kết quả cập nhật hợp lệ.'}
 } catch {
  $reason=$_.Exception;while ($null -ne $reason.InnerException) {$reason=$reason.InnerException}
  $cancelled=$reason.Message.Contains('Đã hủy');$w.FindName('DistributionState').Text=if ($cancelled) {'Đã hủy tác vụ'} else {'Chưa kiểm tra / cập nhật được'}
  $w.FindName('DistributionStatus').Text=if ($cancelled) {'Đã hủy. Không kích hoạt bản cập nhật.'} else {'Không hoàn thành: '+$reason.Message}
  $script:DistributionInfo=$null;Set-ThemeResource $w.FindName('DistributionState') Foreground Warning
 } finally {
  $j.PowerShell.Dispose();$j.Cancel.Dispose();$script:DistributionJob=$null;$script:DistributionTimer.Stop()
  $w.FindName('DistributionCancel').IsEnabled=$false;$w.FindName('DistributionProgress').Visibility='Collapsed'
  $w.FindName('DistributionCheck').IsEnabled=$null -ne $script:DistributionConfig
  $w.FindName('DistributionInstall').IsEnabled=$null -ne $script:DistributionInfo -and $script:DistributionInfo.Status -eq 'Available'
  $w.FindName('DistributionOpenFolder').IsEnabled=[bool]$script:DistributionPreparedPath
 }
}
function Stop-DistributionUI {
 if ($null -ne $script:DistributionWindow) {$script:DistributionWindow.Close()}
 if ($null -ne $script:DistributionTimer) {$script:DistributionTimer.Stop()}
}

