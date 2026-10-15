function New-FullTweaksWindow([switch]$Embedded) {
    if ($null -ne $script:ToolJob -and -not $script:ToolJob.Process.HasExited) {throw 'Đợi công cụ đang chạy hoàn tất trước khi mở bảng tinh chỉnh.'}
    Initialize-FullTweaks (Join-Path $script:DataRoot 'full-tweaks') ([bool]($script:IsSimulation -or $script:WriteBlocked)) $script:Build
    [xml]$xml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="WinTune VI — Toàn bộ tùy chỉnh" Width="1320" Height="880" MinWidth="880" MinHeight="540" Background="{DynamicResource Theme.WindowBrush}" Foreground="{DynamicResource Theme.TextBrush}" FontFamily="Segoe UI" FontSize="14" WindowStartupLocation="CenterOwner">
 <Grid Margin="22"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <StackPanel x:Name="FullHeading"><TextBlock Text="Toàn bộ tùy chỉnh Windows" FontSize="27" FontWeight="SemiBold"/><TextBlock Text="Chọn mục cần dùng, đọc ảnh hưởng rồi xem trước. Chưa có thay đổi nào chỉ vì mở bảng này." TextWrapping="Wrap" Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,6,0,12"/></StackPanel>
 <StackPanel Grid.Row="1"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="190"/><ColumnDefinition/><ColumnDefinition Width="220"/></Grid.ColumnDefinitions><ComboBox x:Name="FullPreset" Margin="0,0,12,0" AutomationProperties.Name="Chọn nhanh" ToolTip="Chọn bộ thiết lập để xem trước; chưa thay đổi Windows."/><Grid Grid.Column="1"><TextBox x:Name="FullSearch" Padding="10" Background="{DynamicResource Theme.InputBrush}" Foreground="{DynamicResource Theme.TextBrush}" ToolTip="Tìm tính năng, có hoặc không dấu" AutomationProperties.Name="Tìm tính năng"/><TextBlock Text="Tìm tính năng…" IsHitTestVisible="False" VerticalAlignment="Center" Margin="11,0" Foreground="{DynamicResource Theme.MutedBrush}"><TextBlock.Style><Style TargetType="TextBlock"><Setter Property="Visibility" Value="Collapsed"/><Style.Triggers><DataTrigger Binding="{Binding Text, ElementName=FullSearch}" Value=""><Setter Property="Visibility" Value="Visible"/></DataTrigger></Style.Triggers></Style></TextBlock.Style></TextBlock></Grid><ComboBox x:Name="FullGroup" Grid.Column="2" Margin="12,0,0,0" MinHeight="38"/></Grid><WrapPanel Margin="0,10,0,6"><Button x:Name="FullInstalled" Content="Chọn mục đã áp dụng"/><Button x:Name="FullClear" Content="Bỏ chọn"/><CheckBox x:Name="FullOnlySelected" Content="Chỉ hiện mục đã chọn" VerticalAlignment="Center" Margin="10,0"/></WrapPanel><TextBlock x:Name="FullPresetDescription" TextWrapping="Wrap" Foreground="{DynamicResource Theme.MutedBrush}" FontSize="12" Margin="0,0,0,6"/><ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" MaxHeight="44" Margin="0,0,0,10"><TextBlock x:Name="FullChosen" TextWrapping="Wrap" Foreground="{DynamicResource Theme.AccentBrush}"/></ScrollViewer></StackPanel>
 <Grid x:Name="FullBody" Grid.Row="2"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="370"/></Grid.ColumnDefinitions><ScrollViewer x:Name="FullScroll" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel x:Name="FullCards" Margin="0,0,14,0"/></ScrollViewer>
 <Border Grid.Column="1" Background="{DynamicResource Theme.SurfaceBrush}" CornerRadius="8" Padding="18"><DockPanel><StackPanel DockPanel.Dock="Bottom"><CheckBox x:Name="FullAck" MinHeight="24" Margin="0,12,0,8"><TextBlock Text="Tôi đã đọc và hiểu ảnh hưởng của mục này" TextWrapping="Wrap"/></CheckBox><Button x:Name="FullRunOne" Content="Xem trước mục này" Margin="0,6,0,0"/></StackPanel><ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel>
 <TextBlock x:Name="FullDetailTitle" Text="Chọn một tính năng để đọc" FontSize="21" FontWeight="SemiBold" TextWrapping="Wrap"/>
 <StackPanel x:Name="FullChoiceOptions" Visibility="Collapsed" Margin="0,12,0,0"><TextBlock Text="Chọn cách hiển thị hoặc hoạt động"/><ComboBox x:Name="FullChoice" Margin="0,6,0,0"/><TextBlock Text="Chọn giá trị rồi đánh dấu mục trong danh sách để xem trước." TextWrapping="Wrap" Foreground="{DynamicResource Theme.MutedBrush}" FontSize="12" Margin="0,6,0,0"/></StackPanel><TextBlock x:Name="FullDetailBenefit" Margin="0,12,0,0" TextWrapping="Wrap"/><TextBlock Text="Ảnh hưởng cần biết" FontWeight="SemiBold" Margin="0,16,0,6"/><TextBlock x:Name="FullDetailImpact" TextWrapping="Wrap" Foreground="{DynamicResource Theme.WarningBrush}"/>
 <TextBlock Text="Hoàn tác" FontWeight="SemiBold" Margin="0,16,0,6"/><TextBlock x:Name="FullDetailUndo" TextWrapping="Wrap"/><TextBlock x:Name="FullSource" Margin="0,12,0,10"/>
 <StackPanel x:Name="FullCleanupOptions" Visibility="Collapsed"><CheckBox x:Name="FullComponentCleanup" Margin="0,6,0,12"><TextBlock Text="Dọn thêm kho thành phần Windows (DISM, có thể mất nhiều phút)" TextWrapping="Wrap"/></CheckBox></StackPanel><StackPanel x:Name="FullDnsOptions" Visibility="Collapsed"><TextBlock Text="Card mạng cần đổi"/><ComboBox x:Name="FullAdapter" Margin="0,6,0,12"/><TextBlock Text="Nhà cung cấp DNS"/><ComboBox x:Name="FullProvider" Margin="0,6,0,12"/></StackPanel>
 <StackPanel x:Name="FullVolumeOptions" Visibility="Collapsed"><TextBlock Text="Ổ đĩa cần giải mã"/><ComboBox x:Name="FullVolume" Margin="0,6,0,12"/></StackPanel>
 <StackPanel x:Name="FullOosuOptions" Visibility="Collapsed"><TextBlock Text="Tải O&amp;O từ trang chính thức, rồi chọn tệp để chạy. WinTune kiểm tra chữ ký O&amp;O." TextWrapping="Wrap"/><Button x:Name="FullOosuSite" Content="Trang chính thức O&amp;O"/><Button x:Name="FullOosuFile" Content="Chọn tệp OOSU10.exe"/><TextBlock x:Name="FullOosuPath" TextWrapping="Wrap"/></StackPanel>
 
 </StackPanel></ScrollViewer></DockPanel></Border></Grid>
 <StackPanel Grid.Row="3" Margin="0,12,0,0"><TextBlock x:Name="FullRecovery" Visibility="Collapsed" Foreground="{DynamicResource Theme.WarningBrush}" TextWrapping="Wrap" Margin="0,0,0,6"/><TextBlock x:Name="FullStatus" Text="Chưa áp dụng thay đổi" TextWrapping="Wrap"/><WrapPanel Margin="0,10,0,0"><Button x:Name="FullApply" Content="Xem trước các mục đã chọn"/><Button x:Name="FullUndo" Content="Hoàn tác các mục đã chọn"/><Button x:Name="FullHistory" Content="Lịch sử"/><Button x:Name="FullClose" Content="Đóng"/></WrapPanel></StackPanel>
 </Grid>
</Window>
'@
    $reader=New-Object Xml.XmlNodeReader $xml;$w=[Windows.Markup.XamlReader]::Load($reader);$reader.Close();$w.Resources=$script:Window.Resources;Register-ThemeWindow $w
    if ($script:Window.IsVisible) {$w.Owner=$script:Window};$area=[Windows.SystemParameters]::WorkArea;$w.Width=[Math]::Min($w.Width,$area.Width);$w.Height=[Math]::Min($w.Height,$area.Height)
    $script:FullWindow=$w;$script:FullSelection=@{};$script:FullChoices=@{};$script:FullCurrent=$null;$script:FullJob=$null;$script:FullOosuExecutable='';$script:FullChoiceLoading=$false;$script:FullPresetLoading=$false;$script:FullActivePreset='custom';$script:FullEmbedded=[bool]$Embedded;$script:FullMainControls=@{}
    $w.FindName('FullStatus').Text=($FullCatalog.Count-2).ToString()+' mục • Chưa áp dụng thay đổi'
    $w.FindName('FullChoice').Add_SelectionChanged({if (-not $script:FullChoiceLoading -and $null -ne $script:FullCurrent -and $script:FullWindow.FindName('FullChoice').SelectedItem) {$script:FullChoices[$script:FullCurrent.Id]=$script:FullWindow.FindName('FullChoice').SelectedItem.Tag;Set-FullCustom;Render-FullTweaks}})
    foreach ($group in @('Tất cả')+@($FullCatalog.Group | Select-Object -Unique)) {$null=$w.FindName('FullGroup').Items.Add($group)}
    foreach ($p in @(Get-FullDnsProviders)) {$item=New-Object Windows.Controls.ComboBoxItem;$item.Content=$p.Title;$item.Tag=$p.Id;$null=$w.FindName('FullProvider').Items.Add($item)};$w.FindName('FullProvider').SelectedIndex=0
    # Enumerate local drive letters only; BitLocker state is read in the worker after selection.
    foreach ($drive in @([IO.DriveInfo]::GetDrives() | Where-Object DriveType -eq Fixed)) {$null=$w.FindName('FullVolume').Items.Add($drive.Name.TrimEnd('\'))}
    $w.FindName('FullSearch').Add_TextChanged({Render-FullTweaks});$w.FindName('FullGroup').Add_SelectionChanged({Render-FullTweaks});$w.FindName('FullOnlySelected').Add_Click({Render-FullTweaks})
    $w.FindName('FullClear').Add_Click({$script:FullSelection.Clear();$script:FullChoices.Clear();Set-FullCustom;Render-FullTweaks})
    foreach($profile in Get-FullProfiles){$item=New-Object Windows.Controls.ComboBoxItem;$item.Tag=$profile.Id;$item.Content=$profile.Title;$item.ToolTip=$profile.Description;$null=$w.FindName('FullPreset').Items.Add($item)};Set-FullPresetLabel 'custom'
    $w.FindName('FullPreset').Add_SelectionChanged({if(-not $script:FullPresetLoading -and $script:FullWindow.FindName('FullPreset').SelectedItem){Set-FullPreset $script:FullWindow.FindName('FullPreset').SelectedItem.Tag}})
    $w.FindName('FullInstalled').Add_Click({try {Start-FullJob Installed @() @{} $false} catch {Message $_.Exception.Message}})
    $w.FindName('FullApply').Add_Click({try {Start-FullPreview @($script:FullSelection.Keys)} catch {Message $_.Exception.Message}})
    $w.FindName('FullRunOne').Add_Click({try {if ($null -eq $script:FullCurrent) {return};if ($script:FullCurrent.Handler -eq 'Route') {Open-FullRoute $script:FullCurrent;return};if ($script:FullCurrent.Risk -and -not $script:FullWindow.FindName('FullAck').IsChecked) {throw 'Đọc ảnh hưởng và đánh dấu xác nhận của mục này trước.'};Start-FullPreview @($script:FullCurrent.Id)} catch {Message $_.Exception.Message}})
    $w.FindName('FullUndo').Add_Click({try {if (-not $script:FullSelection.Count) {throw 'Đánh dấu mục cần hoàn tác trước.'};if (Show-TextDialog 'Hoàn tác mục đã chọn' ('Khôi phục lần thay đổi gần nhất có bản sao cho từng mục đã chọn. Không ghi đè thay đổi của ứng dụng khác; gỡ ứng dụng và giải mã ổ đĩa không tự hoàn tác.') $true 'Hoàn tác') {Start-FullJob Undo @($script:FullSelection.Keys) @{} $true}} catch {Message $_.Exception.Message}})
    $w.FindName('FullHistory').Add_Click({try {$lines=@('LỊCH SỬ TÙY CHỈNH ĐẦY ĐỦ','');foreach ($j in @(Get-FullJournals)) {$lines+=($j.Data.Created+' — '+(Get-FullStatusText $j.Data.Status));foreach ($r in $j.Data.Rows) {$lines+=((Get-FullFeature $r.Id).Title+': '+(Get-FullStatusText $r.State)+' '+$r.Error)}};$null=Show-TextDialog 'Lịch sử tinh chỉnh' ($lines -join "`n")} catch {Message $_.Exception.Message}})
    $w.FindName('FullOosuSite').Add_Click({if (-not $script:FullSimulation) {Start-Process 'https://www.oo-software.com/en/shutup10'}})
    $w.FindName('FullOosuFile').Add_Click({$dialog=New-Object Microsoft.Win32.OpenFileDialog;$dialog.Filter='Ứng dụng O&O (*.exe)|*.exe';if ($dialog.ShowDialog()) {$script:FullOosuExecutable=$dialog.FileName;$script:FullWindow.FindName('FullOosuPath').Text=$dialog.FileName}})
    $w.FindName('FullClose').Add_Click({$script:FullWindow.Close()})
    $w.Add_Closing({param($sender,$eventArgs) if ($null -ne $script:FullJob -and -not $script:FullJob.Process.HasExited) {$eventArgs.Cancel=$true;$script:FullWindow.FindName('FullStatus').Text='Đợi tác vụ hoàn tất trước khi đóng. Không kết thúc công cụ giữa lúc ghi thay đổi.'}})
    $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(250);$timer.Add_Tick({Poll-FullJob});$script:FullTimer=$timer
    $w.Add_Closed({$script:FullTimer.Stop();$script:FullWindow=$null})
    $w.FindName('FullGroup').SelectedIndex=0;Render-FullTweaks
    if($Embedded){$view=$w.Content;$w.Content=$null;$view.Resources=$w.Resources;$view.Margin='0';[Windows.NameScope]::SetNameScope($view,[Windows.NameScope]::GetNameScope($w));$w.FindName('FullHeading').Visibility='Collapsed';$w.FindName('FullClose').Visibility='Collapsed';return $view}
    return $w
}
function Render-FullTweaks {
    if ($null -eq $script:FullWindow) {return}
    $w=$script:FullWindow;$panel=$w.FindName('FullCards');$panel.Children.Clear();$query=Search-Text $w.FindName('FullSearch').Text.Trim();$group=[string]$w.FindName('FullGroup').SelectedItem
    $visible=@($FullCatalog | Where-Object {$_.Id -notin @('WPFTweaksDiskCleanup','WPFTweaksDeleteTempFiles') -and ($group -eq 'Tất cả' -or $_.Group -eq $group) -and (-not $query -or (Search-Text ($_.Title+' '+$_.Explanation)).IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -ge 0) -and (-not $w.FindName('FullOnlySelected').IsChecked -or $script:FullSelection.ContainsKey($_.Id))})
    foreach ($g in @($visible | Group-Object Group)) {
        $heading=New-Object Windows.Controls.TextBlock;$heading.Text=$g.Name;$heading.FontSize=18;$heading.FontWeight='SemiBold';$heading.Margin='0,14,0,8';Set-ThemeResource $heading Foreground Accent;$null=$panel.Children.Add($heading)
        if ($g.Name -eq 'Hiệu năng và chế độ ngủ') {$help=New-Object Windows.Controls.TextBlock;$help.Text='Chọn cách máy ngủ, dùng pin và ưu tiên hiệu năng.';$help.FontSize=12;$help.TextWrapping='Wrap';$help.Margin='0,0,0,8';Set-ThemeResource $help Foreground Muted;$null=$panel.Children.Add($help)}
        foreach ($f in $g.Group) {
            $border=New-Object Windows.Controls.Border;$border.Tag=$f.Id;$border.CornerRadius='7';$border.Padding='12';$border.Margin='0,0,0,7';$border.BorderThickness='1';$border.Focusable=$true;$border.ToolTip='Nhấp vào tên hoặc phần trống để đọc chi tiết';Set-ThemeResource $border Background Surface
            $dock=New-Object Windows.Controls.DockPanel;$check=New-Object Windows.Controls.CheckBox;$check.Tag=$f.Id;$check.IsChecked=$script:FullSelection.ContainsKey($f.Id);$check.IsEnabled=$f.Handler -ne 'Route' -and $script:FullBuild -ge $f.MinBuild;$check.VerticalAlignment='Center';$check.Margin='0,0,12,0'
            $check.Add_Click({param($sender,$eventArgs) if ($sender.IsChecked) {$script:FullSelection[$sender.Tag]=$true} else {$script:FullSelection.Remove($sender.Tag)};Set-FullCustom;Render-FullTweaks});[Windows.Controls.DockPanel]::SetDock($check,'Left');$null=$dock.Children.Add($check)
            $text=New-Object Windows.Controls.StackPanel;$title=New-Object Windows.Controls.TextBlock;$title.Text=$f.Title+$(if ($f.Risk) {'  • Cần cân nhắc'} else {''});$title.TextWrapping='Wrap';$title.FontWeight='SemiBold';$null=$text.Children.Add($title)
            $description=New-Object Windows.Controls.TextBlock;$description.Text=$f.Explanation;$description.TextWrapping='Wrap';$description.FontSize=12;$description.Margin='0,5,0,0';Set-ThemeResource $description Foreground Muted;$null=$text.Children.Add($description)
            $border.Add_MouseUp({param($sender,$eventArgs) if($eventArgs.ChangedButton -eq [Windows.Input.MouseButton]::Left -and -not (Test-FullInteractiveSource $eventArgs.OriginalSource $sender)){Show-FullDetail (Get-FullFeature $sender.Tag);$eventArgs.Handled=$true}})
            $border.Add_KeyDown({param($sender,$eventArgs) if($eventArgs.Key -in @('Enter','Space') -and -not (Test-FullInteractiveSource $eventArgs.OriginalSource $sender)){Show-FullDetail (Get-FullFeature $sender.Tag);$eventArgs.Handled=$true}})
            [Windows.Automation.AutomationProperties]::SetName($border,$f.Title+' — xem chi tiết')
            $null=$dock.Children.Add($text);$border.Child=$dock;$null=$panel.Children.Add($border)
        }
    }
    $w.FindName('FullChosen').Text='Đang chọn '+$script:FullSelection.Count+' mục: '+(($FullCatalog | Where-Object {$script:FullSelection.ContainsKey($_.Id)} | ForEach-Object {Get-FullSelectionLabel $_}) -join ' • ')
    Update-FullRowHighlight
}
function Get-FullSelectionLabel($Feature) {
    if ($Feature.PSObject.Properties['Choices']) {$id=if ($script:FullChoices.ContainsKey($Feature.Id)) {$script:FullChoices[$Feature.Id]} else {$Feature.DefaultChoice};return $Feature.Title+': '+@($Feature.Choices | Where-Object Id -CEQ $id)[0].Title}
    return $Feature.Title
}
function Show-FullDetail($Feature) {
    $script:FullCurrent=$Feature;$w=$script:FullWindow
    $w.FindName('FullDetailTitle').Text=$Feature.Title;$w.FindName('FullDetailBenefit').Text=$Feature.Explanation;$w.FindName('FullDetailImpact').Text=$Feature.Impact;$w.FindName('FullDetailUndo').Text=$Feature.Undo;$w.FindName('FullAck').IsChecked=$false
    Set-SourceLink $w.FindName('FullSource') $Feature.Source
    $script:FullChoiceLoading=$true
    try {$w.FindName('FullChoice').Items.Clear();$hasChoices=[bool]$Feature.PSObject.Properties['Choices'];$w.FindName('FullChoiceOptions').Visibility=if ($hasChoices) {'Visible'} else {'Collapsed'}
        if ($hasChoices) {$id=if ($script:FullChoices.ContainsKey($Feature.Id)) {$script:FullChoices[$Feature.Id]} else {$Feature.DefaultChoice};foreach ($c in $Feature.Choices) {$item=New-Object Windows.Controls.ComboBoxItem;$item.Tag=$c.Id;$item.Content=$c.Title;$null=$w.FindName('FullChoice').Items.Add($item);if ($c.Id -ceq $id) {$w.FindName('FullChoice').SelectedItem=$item}}}
    } finally {$script:FullChoiceLoading=$false}
    $w.FindName('FullDnsOptions').Visibility=if ($Feature.Handler -eq 'Dns') {'Visible'} else {'Collapsed'};$w.FindName('FullVolumeOptions').Visibility=if ($Feature.Handler -eq 'BitLocker') {'Visible'} else {'Collapsed'};$w.FindName('FullOosuOptions').Visibility=if ($Feature.Handler -eq 'OOSU') {'Visible'} else {'Collapsed'}
    $w.FindName('FullRunOne').Content=if ($Feature.Handler -eq 'Route') {'Mở công cụ này'} else {'Xem trước mục này'}
    $w.FindName('FullCleanupOptions').Visibility=if ($Feature.Handler -eq 'DiskCleanup') {'Visible'} else {'Collapsed'}
    Update-FullRowHighlight
    if ($Feature.Handler -eq 'Dns' -and -not $w.FindName('FullAdapter').Items.Count) {
        if ($FullSimulation) {$item=New-Object Windows.Controls.ComboBoxItem;$item.Content='Card mạng mô phỏng';$item.Tag=12;$null=$w.FindName('FullAdapter').Items.Add($item)}
        else {Start-FullJob Adapters @() @{} $false}
    }
}
function Set-FullPreset([string]$Id) {
    $rows=@(Get-FullPresetRows $Id)
    if($Id -ne 'custom'){$script:FullSelection.Clear();$script:FullChoices.Clear();foreach($row in $rows){$script:FullSelection[$row.Id]=$true;if($row.Option -ne 'Apply'){$script:FullChoices[$row.Id]=$row.Option}}}
    Set-FullPresetLabel $Id;Render-FullTweaks
    if($script:FullCurrent){Show-FullDetail $script:FullCurrent}
}
function Get-FullParameters {
    $w=$script:FullWindow
    return [pscustomobject]@{Choices=$script:FullChoices.Clone();InterfaceIndex=$(if ($w.FindName('FullAdapter').SelectedItem) {$w.FindName('FullAdapter').SelectedItem.Tag} else {0});Provider=$w.FindName('FullProvider').SelectedItem.Tag;MountPoint=[string]$w.FindName('FullVolume').SelectedItem;Executable=$script:FullOosuExecutable;ComponentCleanup=[bool]$w.FindName('FullComponentCleanup').IsChecked}
}
function Start-FullPreview([string[]]$Ids) {
    if (-not $Ids.Count) {throw 'Chọn ít nhất một mục trước.'}
    $special=@($Ids | Where-Object {(Get-FullFeature $_).Handler -in @('Dns','BitLocker','OOSU','StartPins','WindowsAI')})
    if ($special.Count -and $Ids.Count -ne 1) {throw 'DNS, giải mã ổ đĩa, bố cục Start, tắt AI tổng thể và O&O cần thực hiện riêng để xem rõ đối tượng.'}
    Start-FullJob Preview $Ids (Get-FullParameters) $false
}
function Start-FullJob([string]$Operation,[string[]]$Ids,$Parameters,[bool]$Confirmed,[object[]]$Rows=@()) {
    if ($null -ne $script:FullJob -and -not $script:FullJob.Process.HasExited) {throw 'Đợi tác vụ hiện tại hoàn tất.'}
    if($Operation -in @('Preview','Apply') -and ($script:PendingBatch -or $script:HistoryError)){throw 'Cần xử lý bản sao lưu cũ trước: mở Lịch sử bản cũ và Hoàn tác bản cũ trên thanh bên.'}
    if($script:MainActionBusy -or ($script:ToolJob -and -not $script:ToolJob.Process.HasExited)){throw 'Đợi công cụ hoặc thao tác ứng dụng đang chạy hoàn tất.'}
    $request=Join-Path $script:FullRoot ('request-'+[guid]::NewGuid().ToString('N')+'.dat')
    Write-FullData ([pscustomobject]@{Version=1;User=$FullUser;Operation=$Operation;Simulation=$FullSimulation;Confirmed=$Confirmed;Ids=$Ids;Parameters=$Parameters;Rows=$Rows}) $request
    $exe=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments=@('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',"$PSScriptRoot/FullTweaks.Worker.ps1",'-RequestPath',$request)
    $start=@{FilePath=$exe;ArgumentList=(($arguments | ForEach-Object {'"'+$_+'"'}) -join ' ');PassThru=$true;WindowStyle='Hidden'}
    $readNeedsAdmin=$Operation -eq 'Preview' -and @($Ids | Where-Object {(Get-FullFeature $_).Handler -in @('Optional','Telemetry','StartPins','WindowsAI','ReservedStorage','BitLocker')}).Count -gt 0
    if (($Operation -in @('Apply','Undo') -or $readNeedsAdmin) -and -not $FullSimulation -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {$start.Verb='RunAs'}
    $process=Start-Process @start;$script:FullJob=[pscustomobject]@{Process=$process;Path=$request;Operation=$Operation;Ids=$Ids;Parameters=$Parameters}
    Set-FullJobBusy $true
    $script:FullWindow.FindName('FullStatus').Text='Đang xử lý… Bạn vẫn có thể đọc các mục trong bảng.';$script:FullTimer.Start()
}
function Poll-FullJob {
    if ($null -eq $script:FullJob -or -not $script:FullJob.Process.HasExited) {return}
    $job=$script:FullJob;$script:FullJob=$null;$script:FullTimer.Stop();Set-FullJobBusy $false
    try {
        if (-not (Test-Path -LiteralPath ($job.Path+'.result'))) {throw 'Tác vụ đã dừng nhưng chưa có kết quả. Không coi là thành công; giữ lịch sử để kiểm tra.'}
        $result=Read-FullData ($job.Path+'.result');$script:FullWindow.FindName('FullStatus').Text=$result.Message
        if (-not $result.Ok) {Message $result.Message;return}
        if ($job.Operation -eq 'Adapters') {foreach ($adapter in $result.Result) {$item=New-Object Windows.Controls.ComboBoxItem;$item.Content=$adapter.Name;$item.Tag=$adapter.Index;$null=$script:FullWindow.FindName('FullAdapter').Items.Add($item)};$script:FullWindow.FindName('FullStatus').Text='Chọn card mạng và nhà cung cấp DNS trước khi xem trước.';return}
        if ($job.Operation -eq 'Installed') {$script:FullSelection.Clear();$script:FullChoices.Clear();foreach ($selection in $result.Result) {$script:FullSelection[$selection.Id]=$true;if ($selection.Option -cne 'Apply') {$script:FullChoices[$selection.Id]=$selection.Option}};Set-FullCustom;Render-FullTweaks;$script:FullWindow.FindName('FullStatus').Text='Đã chọn các mục và lựa chọn có giá trị registry khớp. Không suy ra ứng dụng đã gỡ hoặc mọi chức năng đã có hiệu lực.';return}
        if ($job.Operation -eq 'Preview') {
            $rows=@($result.Result);if (-not $rows.Count) {$script:FullWindow.FindName('FullStatus').Text='Không có thay đổi phù hợp: trạng thái đã khớp hoặc thành phần không có trên máy.';return}
            $lines=@($(if ($FullSimulation) {'MÔ PHỎNG — không thay đổi Windows thật.'} else {'Bạn sắp thay đổi các mục dưới đây:'}), '')
            foreach ($id in @($rows.Id | Select-Object -Unique)) {$f=Get-FullFeature $id;$option=@($rows | Where-Object Id -CEQ $id)[0].Option;$title=$f.Title;if ($option -cne 'Apply') {$title+=': '+@($f.Choices | Where-Object Id -CEQ $option)[0].Title};$lines+=($title+"`n"+$f.Explanation+"`nẢnh hưởng: "+$f.Impact+"`nHoàn tác: "+$f.Undo+"`n")}
            foreach ($row in @($rows | Where-Object {$_.Kind -eq 'Native' -and (Get-FullFeature $_.Id).Handler -eq 'StartPins'})) {if ($row.Before.PSObject.Properties['Files']) {$lines+='Bố cục Start sẽ thay đổi tại:';$lines+=@($row.Before.Files | ForEach-Object Path)}}
            if ($job.Ids -contains 'WPFTweaksDisableBitLocker') {$lines+=('Ổ sẽ được giải mã: '+$job.Parameters.MountPoint)}
            if ($job.Ids -contains 'WPFchangedns') {$lines+=('Card mạng số '+$job.Parameters.InterfaceIndex+'; DNS: '+$job.Parameters.Provider)}
            foreach ($row in @($rows | Where-Object {$_.Kind -eq 'Native' -and $_.Id -eq 'WPFTweaksDeleteTempFiles'})) {if ($row.Before.PSObject.Properties['Files']) {$lines+=('Sẽ xóa tối đa '+$row.Before.Files.Count+' tệp cũ đã quét:');$lines+=@($row.Before.Files | Select-Object -First 30 | ForEach-Object Path);if ($row.Before.Files.Count -gt 30) {$lines+='Danh sách còn thêm các tệp trong hai thư mục TEMP đã nêu.'}}}
            $lines+='Không tự đóng ứng dụng hoặc khởi động lại. Lưu công việc trước khi tiếp tục.'
            if (Show-TextDialog 'Xác nhận thay đổi Windows' ($lines -join "`n") $true 'Tôi đồng ý thực hiện') {Start-FullJob Apply $job.Ids $job.Parameters $true $rows} else {$script:FullWindow.FindName('FullStatus').Text='Đã hủy xem trước. Chưa áp dụng thay đổi.'}
        } elseif ($job.Operation -eq 'Undo') {$notes=@($result.Result | ForEach-Object {$_.Notes});if ($notes.Count) {Message ($notes -join "`n")}}
        else {$script:FullSelection.Clear();Set-FullCustom;Render-FullTweaks}
    } catch {if ($null -ne $script:FullWindow) {$script:FullWindow.FindName('FullStatus').Text=$_.Exception.Message};Message $_.Exception.Message}
}
function Open-FullRoute($Feature) {
    if(-not $script:FullEmbedded){$script:FullWindow.Close()}
    switch ($Feature.Route) {'Restore' {Open-RestoreCenter 'Create'} 'Temp' {Open-Storage} 'DiskCleanup' {Open-Storage}}
}
function Open-FullTweaks {try {$w=New-FullTweaksWindow;$null=$w.ShowDialog()} catch {Message $_.Exception.Message}}
function Get-FullStatusText([string]$State) {switch ($State) {'Prepared' {'Chưa thực hiện'} 'Writing' {'Đang ghi thay đổi'} 'Applied' {'Đã áp dụng'} 'Failed' {'Chưa hoàn tất, có lỗi'} 'Restored' {'Đã hoàn tác'} 'Pending' {'Chưa hoàn tất hoặc bị ngắt'} 'Partial' {'Mới hoàn tất một phần'} 'Undone' {'Đã hoàn tác cả đợt'} default {'Chưa rõ'}}}
. "$PSScriptRoot/FullTweaks.Core.ps1"
. "$PSScriptRoot/FullTweaks.Native.ps1"
. "$PSScriptRoot/FullTweaks.Profiles.ps1"
. "$PSScriptRoot/UnifiedTweaks.UI.ps1"
