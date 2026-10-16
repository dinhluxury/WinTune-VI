# A guided surface for the existing restore-point worker. Never restores Windows.
function Format-RestoreDate($Value) {
    if ($Value -is [DateTime]) {return $Value.ToLocalTime().ToString('dd/MM/yyyy HH:mm')}
    try {return [Management.ManagementDateTimeConverter]::ToDateTime([string]$Value).ToString('dd/MM/yyyy HH:mm')} catch {return [string]$Value}
}
function Show-RestorePoints($Result) {
    $s=$script:RestoreState;$w=$script:RestoreWindow
    $s.PointsKnown=$true;$s.Points=@($Result.Points);$rows=@()
    foreach ($p in $s.Points) {$rows+=[pscustomobject]@{Time=(Format-RestoreDate $p.CreationTime);Description=$p.Description}}
    $w.FindName('RestorePoints').ItemsSource=$rows
    if ($Result.Mode -eq 'Simulation') {$s.PointsKnown=$false;$w.FindName('RestoreStatus').Text='MÔ PHỎNG — không đọc hoặc tạo mốc trên Windows thật.'}
    elseif (-not $s.Points.Count) {$w.FindName('RestoreStatus').Text='Chưa có mốc khôi phục. Nếu Bảo vệ hệ thống đang tắt, hãy bật theo bước 1 rồi tạo mốc ở bước 2.'}
    else {$w.FindName('RestoreStatus').Text="Có $($s.Points.Count) mốc Windows đang lưu. Chọn bước 3 khi cần quay lại."}
    $w.FindName('RestoreWizard').IsEnabled=$s.PointsKnown -and $s.Points.Count -gt 0
}
function Read-RestorePoints {
    if ($null -ne $script:RestoreState.ReadJob -or $script:RestoreState.Busy) {return}
    $script:RestoreState.PointsKnown=$false
    $script:RestoreWindow.FindName('RestoreWizard').IsEnabled=$false
    $script:RestoreWindow.FindName('RestoreStatus').Text='Đang đọc các mốc Windows đang lưu…'
    try {$script:RestoreState.ReadJob=New-MonitorJob RestorePoints;$script:RestoreState.Timer.Start()}
    catch {$script:RestoreWindow.FindName('RestoreStatus').Text='Không đọc được danh sách mốc: '+$_.Exception.Message}
}
function Poll-RestoreCenter {
    $s=$script:RestoreState;$w=$script:RestoreWindow
    if ($null -eq $w) {return}
    if ($null -ne $s.ReadJob -and $s.ReadJob.Handle.IsCompleted) {
        $job=$s.ReadJob;$s.ReadJob=$null
        try {Show-RestorePoints (Receive-MonitorJob $job)} catch {$s.PointsKnown=$false;$w.FindName('RestoreStatus').Text='Không đọc được các mốc. Không kết luận máy đã có mốc khôi phục. '+$_.Exception.Message}
    }
    if ($s.Busy) {
        $r=Get-ToolJobResult $s.Job
        if ($null -ne $r) {
            $s.Busy=$false;Complete-ToolJob $s.Job;$w.FindName('CreateRestore').IsEnabled=$true
            if ($r.Status -eq 'Completed') {
                $w.FindName('RestoreOperation').Text=if ($r.Mode -eq 'Simulation') {'MÔ PHỎNG — đã thử quy trình; không tạo mốc thật.'} else {'Đã tạo mốc khôi phục và kiểm tra mốc mới trong Windows.'}
                Read-RestorePoints
            } else {$w.FindName('RestoreOperation').Text='Chưa tạo được mốc. Kiểm tra Bảo vệ hệ thống ở bước 1. Windows cũng có thể từ chối nếu vừa tạo mốc trong 24 giờ qua. Chi tiết: '+$r.Message}
        }
    }
    if (-not $s.Busy -and $null -eq $s.ReadJob) {$s.Timer.Stop()}
}
function Create-RestorePointFromUI {
    if ($script:RestoreState.Busy) {return}
    if ($script:WriteBlocked) {Message 'Chế độ chỉ đọc: không tạo mốc khôi phục.';return}
    $text="Tạo một mốc cấu hình Windows hiện tại, mang tên WinTune VI và thời điểm tạo.`n`nDùng trước khi thay đổi quan trọng để có thể quay lại nếu Windows gặp lỗi. Mốc này không sao lưu ảnh, tài liệu hoặc khôi phục file đã xóa.`n`nCần bật Bảo vệ hệ thống ở bước 1. Windows có thể giới hạn tạo mốc trong 24 giờ. Không tự bật bảo vệ hoặc khởi động lại máy."
    if (-not (Show-TextDialog 'Tạo mốc khôi phục Windows' $text $true 'Xác nhận tạo mốc')) {return}
    try {
        $script:RestoreState.Job=Start-ToolJob restorepoint ([pscustomobject]@{}) $true $true
        $script:RestoreState.Busy=$true;$script:RestoreWindow.FindName('CreateRestore').IsEnabled=$false
        $script:RestoreWindow.FindName('RestoreOperation').Text='Đang tạo mốc… Đợi kết quả trước khi đóng cửa sổ.'
        $script:RestoreState.Timer.Start()
    } catch {$script:RestoreWindow.FindName('RestoreOperation').Text='Chưa tạo mốc: '+$_.Exception.Message}
}
function Open-RestoreProtection {
    if ($script:IsSimulation -or $script:WriteBlocked) {Message 'Mô phỏng/chỉ đọc: không mở cài đặt Bảo vệ hệ thống thật.';return}
    try {Start-Process -FilePath (Join-Path $env:WINDIR 'System32/SystemPropertiesProtection.exe')} catch {Message $_.Exception.Message}
}
function Open-RestoreWizard {
    if ($script:RestoreState.Busy) {Message 'Đợi tạo mốc xong trước khi mở khôi phục.';return}
    if ($script:IsSimulation -or $script:WriteBlocked) {Message 'Mô phỏng/chỉ đọc: không mở khôi phục Windows thật.';return}
    if (-not $script:RestoreState.PointsKnown -or -not $script:RestoreState.Points.Count) {Message 'Chưa tìm thấy mốc để quay về. Bật Bảo vệ hệ thống ở bước 1 nếu đang tắt, rồi tạo mốc ở bước 2. Nhấn Đọc lại sau khi tạo.';return}
    $text="Mở hướng dẫn khôi phục của Windows. WinTune chưa thực hiện khôi phục.`n`nTrong cửa sổ Windows, chọn mốc, xem các ứng dụng bị ảnh hưởng rồi tự quyết định. Chương trình, driver hoặc cập nhật sau mốc có thể bị gỡ hoặc thay đổi. Windows có thể khởi động lại khi bạn xác nhận khôi phục; lưu công việc trước.`n`nĐây không phải cách lấy lại file cá nhân đã xóa."
    if (-not (Show-TextDialog 'Quay về mốc Windows đã lưu' $text $true 'Mở hướng dẫn Windows')) {return}
    try {Start-Process -FilePath (Join-Path $env:WINDIR 'System32/rstrui.exe')} catch {Message $_.Exception.Message}
}
function New-RestoreWindow([ValidateSet('Create','Restore')][string]$Focus='Create') {
    Add-Type -AssemblyName System.Management
    [xml]$xml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="WinTune VI — Mốc khôi phục Windows" Width="850" Height="760" MinWidth="680" MinHeight="520" WindowStartupLocation="CenterOwner" Background="{DynamicResource Theme.WindowBrush}" Foreground="{DynamicResource Theme.TextBrush}" FontFamily="Segoe UI" FontSize="14">
 <DockPanel Margin="24"><Button x:Name="CloseRestore" DockPanel.Dock="Bottom" Content="Đóng" HorizontalAlignment="Right" Margin="0,16,0,0"/>
 <ScrollViewer x:Name="RestoreScroll" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel Margin="0,0,10,0">
  <TextBlock Text="Mốc khôi phục Windows" FontSize="26" FontWeight="SemiBold"/><TextBlock Text="Lưu một mốc cấu hình để quay lại nếu Windows gặp lỗi sau khi cài driver, phần mềm hoặc thay đổi thiết lập. Mốc này không sao lưu ảnh, tài liệu hoặc file cá nhân đã xóa." Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,12,0,18"/>
  <Border Style="{DynamicResource RowCard}"><StackPanel><TextBlock Text="1. Bật bảo vệ nếu chưa bật" FontSize="18" FontWeight="SemiBold"/><TextBlock Text="Nếu cửa sổ Windows báo ‘System protection is turned off’, nghĩa là Bảo vệ hệ thống đang tắt. Bạn cần bật trước khi tạo mốc." Margin="0,10,0,8"/><TextBlock Text="Mở cài đặt bên dưới → chọn ổ Windows (thường là C:) → Configure (Cấu hình) → Turn on system protection (Bật bảo vệ) → chọn dung lượng lưu mốc → Apply (Áp dụng)." Foreground="{DynamicResource Theme.MutedBrush}"/><Button x:Name="ProtectionSettings" Content="Mở cài đặt bảo vệ" HorizontalAlignment="Left" Margin="0,14,0,0"/></StackPanel></Border>
  <Border x:Name="CreateSection" Style="{DynamicResource RowCard}"><StackPanel><TextBlock Text="2. Tạo mốc trước khi thay đổi quan trọng" FontSize="18" FontWeight="SemiBold"/><TextBlock Text="Windows sẽ lưu trạng thái hệ thống lúc này. Tên mốc gồm WinTune VI và thời điểm tạo. Chỉ tạo khi bạn bấm và xác nhận; có thể mất vài phút." Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,10,0,0"/><Button x:Name="CreateRestore" Content="Tạo mốc bây giờ" Background="{DynamicResource Theme.AccentButtonBrush}" Foreground="{DynamicResource Theme.OnAccentBrush}" HorizontalAlignment="Left" Margin="0,14,0,0"/><TextBlock x:Name="RestoreOperation" Margin="0,12,0,0" Foreground="{DynamicResource Theme.WarningBrush}"/></StackPanel></Border>
  <Border x:Name="RestoreSection" Style="{DynamicResource RowCard}"><StackPanel><TextBlock Text="3. Quay về mốc đã tạo khi Windows gặp lỗi" FontSize="18" FontWeight="SemiBold"/><TextBlock Text="Chỉ dùng khi cần quay lại cấu hình cũ. Chương trình, driver hoặc cập nhật sau mốc có thể bị gỡ hoặc thay đổi. Windows có thể khởi động lại khi bạn xác nhận trong hướng dẫn của Windows." Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,10,0,12"/><TextBlock x:Name="RestoreStatus" Text="Chưa đọc danh sách mốc."/><ListView x:Name="RestorePoints" MaxHeight="180" Background="{DynamicResource Theme.SurfaceBrush}" BorderThickness="0" Margin="0,10,0,12"><ListView.View><GridView><GridViewColumn Header="Thời điểm" Width="150" DisplayMemberBinding="{Binding Time}"/><GridViewColumn Header="Tên mốc" Width="450" DisplayMemberBinding="{Binding Description}"/></GridView></ListView.View></ListView><WrapPanel><Button x:Name="ReadRestorePoints" Content="Đọc lại"/><Button x:Name="RestoreWizard" Content="Mở hướng dẫn quay về mốc cũ"/></WrapPanel></StackPanel></Border>
  <TextBlock Text="Chỉ muốn bỏ thay đổi do WinTune vừa áp dụng? Dùng Hoàn tác ở thanh trái; không cần khôi phục cả Windows." Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,12,0,0"/><TextBlock x:Name="RestoreSource" Margin="0,12,0,0"/>
 </StackPanel></ScrollViewer></DockPanel>
</Window>
'@
    $reader=New-Object Xml.XmlNodeReader $xml;$w=[Windows.Markup.XamlReader]::Load($reader);$reader.Close();$w.Resources=$script:Window.Resources;Register-ThemeWindow $w
    if ($script:Window.IsVisible) {$w.Owner=$script:Window}
    $work=[Windows.SystemParameters]::WorkArea;$w.Width=[Math]::Min($w.Width,$work.Width);$w.Height=[Math]::Min($w.Height,$work.Height)
    $script:RestoreWindow=$w;$script:RestoreState=[pscustomobject]@{PointsKnown=$false;Points=@();ReadJob=$null;Job=$null;Busy=$false;Timer=$null}
    $w.FindName('RestoreWizard').IsEnabled=$false
    Set-SourceLink ($w.FindName('RestoreSource')) 'https://support.microsoft.com/en-us/windows/experience/backup-recovery/system-protection'
    $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(300);$timer.Add_Tick({Poll-RestoreCenter});$script:RestoreState.Timer=$timer
    $w.FindName('ProtectionSettings').Add_Click({Open-RestoreProtection});$w.FindName('CreateRestore').Add_Click({Create-RestorePointFromUI});$w.FindName('RestoreWizard').Add_Click({Open-RestoreWizard});$w.FindName('ReadRestorePoints').Add_Click({Read-RestorePoints})
    $w.FindName('CloseRestore').Add_Click({param($sender,$eventArgs) [Windows.Window]::GetWindow($sender).Close()})
    $w.Add_Closing({param($sender,$eventArgs) if ($script:RestoreState.Busy) {$eventArgs.Cancel=$true;Message 'Windows đang tạo mốc. Đợi kết quả trước khi đóng cửa sổ.'}})
    $w.Add_Closed({$script:RestoreState.Timer.Stop()})
    $w.Tag=$Focus;$w.Add_ContentRendered({param($sender,$eventArgs) if ($sender.Tag -eq 'Restore') {$sender.FindName('RestoreSection').BringIntoView()}})
    return $w
}
function Open-RestoreCenter([ValidateSet('Create','Restore')][string]$Focus) {
    try {$w=New-RestoreWindow $Focus;Read-RestorePoints;$null=$w.ShowDialog()}
    catch {Message $_.Exception.Message}
    finally {
        if ($null -ne $script:RestoreWindow) {$script:RestoreState.Timer.Stop();$job=$script:RestoreState.ReadJob;if ($null -ne $job) {try {$job.PowerShell.Stop()} catch {};$job.PowerShell.Dispose()}}
        $script:RestoreWindow=$null
    }
}
