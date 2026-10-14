# Loaded lazily on demand; no network polling, extra runspace or timer at startup.
function Open-DistributionCenter {
    if ($null -ne $script:DistributionWindow) {$script:DistributionWindow.Activate() | Out-Null;return}
    Import-Module "$PSScriptRoot/Distribution.Runtime.psm1" -Global
    [xml]$xml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="WinTune VI — Khởi chạy và cập nhật" Width="660" Height="670" MinWidth="540" MinHeight="540" WindowStartupLocation="CenterOwner" Background="{DynamicResource Theme.WindowBrush}" Foreground="{DynamicResource Theme.TextBrush}" FontFamily="Segoe UI" FontSize="14">
 <Grid Margin="24"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <StackPanel><TextBlock Text="Khởi chạy và cập nhật" FontSize="25" FontWeight="SemiBold"/><TextBlock x:Name="DistributionVersion" Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,8,0,14"/></StackPanel>
 <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel>
  <Border Background="{DynamicResource Theme.SurfaceBrush}" CornerRadius="8" Padding="16" Margin="0,0,0,12"><StackPanel><TextBlock Text="Bản cập nhật WinTune" FontSize="18" FontWeight="SemiBold"/><TextBlock Text="Chỉ kiểm tra khi bạn bấm. Bản tải được kiểm tra chữ ký và checksum, giữ bản cũ. Không tự cài hoặc chạy cập nhật." TextWrapping="Wrap" Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,10,0,10"/><TextBlock x:Name="DistributionSource" TextWrapping="Wrap" Margin="0,0,0,10"/><WrapPanel><Button x:Name="DistributionCheck" Content="Kiểm tra phiên bản"/><Button x:Name="DistributionInstall" Content="Tải bản đã xác minh" IsEnabled="False"/></WrapPanel></StackPanel></Border>
  <Border Background="{DynamicResource Theme.SurfaceBrush}" CornerRadius="8" Padding="16"><StackPanel><TextBlock Text="Mở nhanh bằng lệnh wintune" FontSize="18" FontWeight="SemiBold"/><TextBlock Text="Chép bản portable vào thư mục của tài khoản, đăng ký lệnh CMD/PowerShell vào User PATH. Sau đó gõ wintune trong CMD, PowerShell hoặc Win + R. Không đổi Machine PATH; không tự mở ứng dụng." TextWrapping="Wrap" Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,10,0,10"/><TextBlock x:Name="DistributionFolder" TextWrapping="Wrap" Margin="0,0,0,10"/><WrapPanel><Button x:Name="DistributionRegister" Content="Đăng ký lệnh wintune"/><Button x:Name="DistributionUnregister" Content="Bỏ đăng ký lệnh"/><Button x:Name="DistributionRecover" Content="Khắc phục đăng ký lỗi" Visibility="Collapsed"/></WrapPanel></StackPanel></Border>
 </StackPanel></ScrollViewer>
 <TextBlock x:Name="DistributionStatus" Grid.Row="2" Text="Chưa có thao tác nào. Bản portable vẫn dùng được khi không có Internet." TextWrapping="Wrap" Margin="0,14,0,12"/>
 <WrapPanel Grid.Row="3"><Button x:Name="DistributionCancel" Content="Hủy tác vụ" IsEnabled="False"/><Button x:Name="DistributionClose" Content="Đóng"/></WrapPanel>
 </Grid>
</Window>
'@
    $reader=New-Object Xml.XmlNodeReader $xml;$w=[Windows.Markup.XamlReader]::Load($reader);$reader.Close();$w.Resources=$script:Window.Resources;Register-ThemeWindow $w
    if ($Window.IsVisible) {$w.Owner=$Window}
    $work=[Windows.SystemParameters]::WorkArea;$w.Width=[Math]::Min($w.Width,$work.Width);$w.Height=[Math]::Min($w.Height,$work.Height)
    $script:DistributionWindow=$w;$script:DistributionJob=$null;$script:DistributionInfo=$null;$script:DistributionConfig=$null
    $v=Get-WinTuneVersion $PSScriptRoot;$w.FindName('DistributionVersion').Text='Đang chạy WinTune '+$v.Version+$(if ($script:IsSimulation -or $script:WriteBlocked) {' • MÔ PHỎNG — không tải/cài/đổi PATH thật'} else {''})
    $w.FindName('DistributionFolder').Text=if ($script:IsSimulation -or $script:WriteBlocked) {'MÔ PHỎNG: không chép ứng dụng hoặc đăng ký lệnh thật.'} else {Get-WinTuneInstallRoot}
    try {$script:DistributionConfig=Get-ReleaseConfig $PSScriptRoot;$w.FindName('DistributionSource').Text='GitHub: '+$DistributionConfig.Repository+' • Chữ ký RSA-SHA256'} catch {$w.FindName('DistributionCheck').IsEnabled=$false;$w.FindName('DistributionSource').Text=$_.Exception.Message}
    if (-not (Test-Path -LiteralPath "$PSScriptRoot/SHA256.txt")) {$w.FindName('DistributionRegister').IsEnabled=$false;$w.FindName('DistributionRegister').ToolTip='Mở từ gói portable đã đóng gói có SHA256.txt để đăng ký.'}
    $w.FindName('DistributionCheck').Add_Click({Start-DistributionJob Check})
    $w.FindName('DistributionInstall').Add_Click({
        $info=$script:DistributionInfo
        if ($null -eq $info -or $info.Status -ne 'Available') {return}
        $text='Bản mới: '+$info.Manifest.Version+"`nNguồn: "+$info.ReleaseUrl+"`nZIP: "+$info.Manifest.Size+" byte`n`nTải và xác minh chữ ký/checksum, giải nén riêng, chuẩn bị cho lần mở tiếp theo. Không thay file đang chạy, không tự mở bản mới, không sửa nhật ký Windows."
        if (Show-TextDialog 'Xác nhận tải bản cập nhật' $text $true 'Tải và chuẩn bị bản mới') {Start-DistributionJob Install}
    })
    $w.FindName('DistributionRegister').Add_Click({if (Show-TextDialog 'Đăng ký lệnh wintune' ('Chép gói vào '+(Get-WinTuneInstallRoot)+"`nThêm thư mục command vào User PATH để mở qua PowerShell/WPF. Không đăng ký App Paths mới, không ghi đè lệnh khác, không đổi Machine PATH. Không tự khởi chạy.") $true 'Đăng ký cho tài khoản này') {Start-DistributionJob Register}})
    $w.FindName('DistributionUnregister').Add_Click({if (Show-TextDialog 'Bỏ đăng ký lệnh' 'Chỉ bỏ User PATH do WinTune thêm. Đăng ký EXE cũ chỉ bỏ App Paths thuộc WinTune nếu không xung đột. Giữ ứng dụng, bản cũ và lịch sử.' $true 'Bỏ đăng ký') {Start-DistributionJob Unregister}})
    $w.FindName('DistributionRecover').Add_Click({if (Show-TextDialog 'Khắc phục đăng ký lỗi' 'Trả User PATH và App Paths về trước đợt dang dở nếu chưa bị thay đổi bên ngoài. Giữ mọi dữ liệu ứng dụng.' $true 'Phục hồi đăng ký') {Start-DistributionJob Recover}})
    Update-DistributionRecoveryButton
    $w.FindName('DistributionCancel').Add_Click({if ($null -ne $script:DistributionJob) {$script:DistributionJob.Cancel.Cancel();$script:DistributionWindow.FindName('DistributionStatus').Text='Đang yêu cầu hủy. Đợi kết quả; không kết thúc tiến trình.'}})
    $w.FindName('DistributionClose').Add_Click({param($sender,$eventArgs) [Windows.Window]::GetWindow($sender).Close()})
    $w.Add_Closing({param($sender,$eventArgs) if ($null -ne $script:DistributionJob) {$eventArgs.Cancel=$true;$sender.FindName('DistributionStatus').Text='Tác vụ đang chạy. Bấm Hủy hoặc đợi kết quả trước khi đóng.'}})
    $w.Add_Closed({$script:DistributionTimer.Stop();$script:DistributionWindow=$null;$script:DistributionInfo=$null;$script:DistributionConfig=$null})
    $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(200);$timer.Add_Tick({Receive-DistributionUIJob});$script:DistributionTimer=$timer
    $w.Show()
}
function Start-DistributionJob([ValidateSet('Check','Install','Register','Unregister','Recover')][string]$Mode) {
    if ($null -ne $script:DistributionJob) {return}
    $ps=[PowerShell]::Create();$cancel=New-Object Threading.CancellationTokenSource
    $code=@'
param($source,$mode,$cfg,$info,$cancel,$simulation)
$ErrorActionPreference='Stop'
. (Join-Path $source 'Distribution.Core.ps1');. (Join-Path $source 'CommandRegistration.ps1');. (Join-Path $source 'SourceCommandRegistration.ps1')
if ($simulation) {Start-Sleep -Milliseconds 600;Assert-DistributionCancelled $cancel;return [pscustomobject]@{Status='Simulation';Message='MÔ PHỎNG: không kết nối Internet, tải/cài/đổi PATH hoặc mở ứng dụng thật.'}}
$root=Get-WinTuneInstallRoot
switch ($mode) {
 'Check' {Get-DistributionUpdate $cfg (Get-PreparedDistributionVersion $root (Get-WinTuneVersion $source).Version) $cancel}
 'Install' {Install-DistributionUpdate $info $root $true $cancel $cfg}
 'Register' {Assert-DistributionCancelled $cancel;$installed=Install-LocalDistribution $source $root $true;Register-WinTuneCommand $installed.Path $root $true}
 'Unregister' {Assert-DistributionCancelled $cancel;Unregister-WinTuneCommand $root $true}
 'Recover' {Assert-DistributionCancelled $cancel;Repair-WinTuneCommandRegistration $root $true}
 default {throw 'Không có handler phân phối này.'}
}
'@
    $null=$ps.AddScript($code).AddArgument($PSScriptRoot).AddArgument($Mode).AddArgument($script:DistributionConfig).AddArgument($script:DistributionInfo).AddArgument($cancel).AddArgument([bool]($script:IsSimulation -or $script:WriteBlocked))
    try {$handle=$ps.BeginInvoke();$script:DistributionJob=[pscustomobject]@{PowerShell=$ps;Handle=$handle;Cancel=$cancel;Mode=$Mode}} catch {$ps.Dispose();$cancel.Dispose();throw}
    foreach ($name in @('DistributionCheck','DistributionInstall','DistributionRegister','DistributionUnregister','DistributionRecover')) {$script:DistributionWindow.FindName($name).IsEnabled=$false}
    $script:DistributionWindow.FindName('DistributionCancel').IsEnabled=$Mode -in @('Check','Install')
    $script:DistributionWindow.FindName('DistributionStatus').Text='Đang '+$(switch ($Mode) {'Check' {'kiểm tra metadata ký số…'} 'Install' {'tải và xác minh bản mới…'} 'Register' {'đăng ký lệnh cho tài khoản này…'} 'Unregister' {'bỏ đăng ký lệnh…'} 'Recover' {'phục hồi đăng ký dang dở…'}})
    $script:DistributionTimer.Start()
}
function Receive-DistributionUIJob {
    $j=$script:DistributionJob;if ($null -eq $j -or -not $j.Handle.IsCompleted) {return}
    try {
        $result=@($j.PowerShell.EndInvoke($j.Handle));if ($j.PowerShell.HadErrors) {throw ($j.PowerShell.Streams.Error | Out-String)}
        if ($result.Count -ne 1) {throw 'Tác vụ không trả kết quả hợp lệ.'};$r=$result[0]
        if ($j.Mode -eq 'Check' -and $r.Status -in @('Available','Current')) {
            $script:DistributionInfo=$r;$script:DistributionWindow.FindName('DistributionStatus').Text=if ($r.Status -eq 'Available') {'Có bản '+$r.Manifest.Version+'. Chữ ký đúng; ZIP chưa được tải. Bấm Tải để xem và xác nhận.'} else {'Bản stable đã xác minh: '+$r.Manifest.Version+'. Đã có bản này hoặc bản mới hơn; mở lại nếu đang chạy bản cũ.'}
        } else {$script:DistributionWindow.FindName('DistributionStatus').Text=$r.Message;if ($j.Mode -eq 'Install') {$script:DistributionInfo=$null;if ($r.PSObject.Properties['Path']) {$script:DistributionWindow.FindName('DistributionStatus').Text+="`nBản mới: "+(Join-Path $r.Path 'Mo-WinTune.cmd')}}}
    } catch {
        $reason=$_.Exception;while ($null -ne $reason.InnerException) {$reason=$reason.InnerException}
        $script:DistributionWindow.FindName('DistributionStatus').Text=if ($reason.Message.Contains('Đã hủy')) {'Đã hủy. Không kích hoạt bản cập nhật.'} else {'Không hoàn thành: '+$reason.Message}
        $script:DistributionInfo=$null
    }
    finally {
        $j.PowerShell.Dispose();$j.Cancel.Dispose();$script:DistributionJob=$null;$script:DistributionTimer.Stop()
        $w=$script:DistributionWindow;$w.FindName('DistributionCancel').IsEnabled=$false
        $w.FindName('DistributionCheck').IsEnabled=$null -ne $script:DistributionConfig
        $w.FindName('DistributionInstall').IsEnabled=$null -ne $script:DistributionInfo -and $script:DistributionInfo.Status -eq 'Available'
        $w.FindName('DistributionRegister').IsEnabled=Test-Path -LiteralPath "$PSScriptRoot/SHA256.txt";$w.FindName('DistributionUnregister').IsEnabled=$true;$w.FindName('DistributionRecover').IsEnabled=$true;Update-DistributionRecoveryButton
    }
}
function Stop-DistributionUI {
    if ($null -ne $script:DistributionWindow) {$script:DistributionWindow.Close()}
    if ($null -ne $script:DistributionTimer) {$script:DistributionTimer.Stop()}
}
function Update-DistributionRecoveryButton {
    $receipt=Join-Path (Get-WinTuneInstallRoot) 'command-registration.json'
    $pending=$false;$registered=$false
    if (Test-Path -LiteralPath $receipt) {try {$status=(Get-Content -LiteralPath $receipt -Raw|ConvertFrom-Json).Status;$pending=$status -in @('Pending','PendingRemoval');$registered=$status -eq 'Registered'} catch {$script:DistributionWindow.FindName('DistributionStatus').Text='Không đọc được receipt đăng ký. Giữ file để kiểm tra; không tự sửa PATH.'}}
    $script:DistributionWindow.FindName('DistributionRecover').Visibility=if ($pending) {'Visible'} else {'Collapsed'}
    $script:DistributionWindow.FindName('DistributionUnregister').IsEnabled=$registered
    if ($pending) {$script:DistributionWindow.FindName('DistributionRegister').IsEnabled=$false}
}
