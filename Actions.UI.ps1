function New-ManagementWindow([string]$Kind) {
    if ($Kind -notin @('Appx','Startup')) { throw 'Loại quản lý không hợp lệ.' }
    Initialize-Actions (Join-Path $script:DataRoot 'actions') ([bool]($script:IsSimulation -or $script:WriteBlocked)) $script:UserId
    [xml]$view=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Width="1060" Height="760" MinWidth="760" MinHeight="520" Background="{DynamicResource Theme.InputBrush}" Foreground="{DynamicResource Theme.TextBrush}" FontFamily="Segoe UI" FontSize="14" WindowStartupLocation="CenterOwner">
 <Grid Margin="22"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <TextBlock x:Name="Heading" FontSize="24" FontWeight="Bold" Foreground="{DynamicResource Theme.AccentBrush}"/>
  <TextBlock x:Name="Explanation" Grid.Row="1" Margin="0,12,0,16"/>
  <Grid Grid.Row="2"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="16"/><ColumnDefinition Width="1.2*"/></Grid.ColumnDefinitions>
   <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition/></Grid.RowDefinitions><TextBlock Text="Tìm tên ứng dụng" Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,0,0,6"/><TextBox x:Name="Filter" Grid.Row="1" Padding="10" Background="{DynamicResource Theme.ButtonBrush}" Foreground="{DynamicResource Theme.TextBrush}"/><ListBox x:Name="Items" Grid.Row="2" Margin="0,10,0,0" Background="{DynamicResource Theme.WindowBrush}" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled"/></Grid>
   <ScrollViewer x:Name="ManagerDetailsScroll" Grid.Column="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel Margin="0,0,8,0"><TextBlock x:Name="ItemTitle" FontSize="22" FontWeight="Bold"/><TextBlock x:Name="Details" Margin="0,16,0,12"/><Expander Header="Thông tin kỹ thuật"><TextBlock x:Name="TechnicalInfo"/></Expander><Button x:Name="Queue" Content="Thêm vào danh sách chờ" Margin="0,15,0,8"/><Button x:Name="Store" Content="Mở Store để cài lại"/></StackPanel></ScrollViewer>
  </Grid>
  <StackPanel Grid.Row="3" Margin="0,16,0,0"><TextBlock x:Name="State"/><WrapPanel Margin="0,10,0,0"><Button x:Name="Reload" Content="Đọc lại"/><Button x:Name="Review" Content="Xem trước và áp dụng"/><Button x:Name="UndoStartup" Content="Phục hồi đợt khởi động gần nhất"/><Button x:Name="ActionHistory" Content="Lịch sử và cách cài lại"/><Button x:Name="CloseManager" Content="Đóng"/></WrapPanel></StackPanel>
 </Grid>
</Window>
'@
    $reader=New-Object Xml.XmlNodeReader $view
    $w=[Windows.Markup.XamlReader]::Load($reader); $reader.Close()
    $w.Resources=$script:Window.Resources
    Register-ThemeWindow $w
    if ($script:Window.IsVisible) { $w.Owner=$script:Window }
    $work=[Windows.SystemParameters]::WorkArea; $w.Width=[Math]::Min($w.Width,$work.Width); $w.Height=[Math]::Min($w.Height,$work.Height)
    $script:ManagerState=[pscustomobject]@{Window=$w;Kind=$Kind;Selected=@{};Inventory=@();Current=$null;Error=''}
    $w.Title=if ($Kind -eq 'Appx') {'WinTune — Gỡ ứng dụng Windows'} else {'WinTune — Quản lý tự khởi động'}
    if ($ActionSimulation) { $w.Title+=' [MÔ PHỎNG]' }
    $w.FindName('Heading').Text=if ($Kind -eq 'Appx') {'Chọn ứng dụng bạn không dùng'} else {'Ứng dụng tự mở khi đăng nhập'}
    $w.FindName('Explanation').Text=if ($Kind -eq 'Appx') {'Liệt kê Appx/MSIX của tài khoản hiện tại. Mục được bảo vệ chỉ xem, không chọn gỡ. Đề xuất xem xét không có nghĩa bạn không cần app. Nhấp tên để đọc; đánh dấu chưa gỡ. Gỡ có thể xóa dữ liệu: tự sao lưu trước. Không gỡ mọi tài khoản hoặc gói cấp sẵn. Nguồn cài lại chỉ có khi đã xác định đáng tin cậy.'} else {'Tắt tự mở các ứng dụng phổ biến trong HKCU Run, có sao lưu và phục hồi. Không đóng app đang chạy. Giảm app tự mở ở lần đăng nhập sau; không bảo đảm giảm RAM ngay. Danh sách không gồm mọi nguồn khởi động. Mở Windows Settings để quản lý các nguồn khác.'}
    if ($Kind -eq 'Appx') {$w.FindName('Explanation').Text='Nhấp tên để xem công dụng, đánh dấu những ứng dụng bạn muốn gỡ. Chưa gỡ cho đến khi xem trước và xác nhận. Thành phần Windows được bảo vệ. Gỡ có thể mất dữ liệu; giữ ứng dụng nếu bạn chưa rõ nó dùng để làm gì.'}
    if ($ActionSimulation) { $w.FindName('Explanation').Text='MÔ PHỎNG — không gỡ app hoặc đổi tự khởi động thật. '+$w.FindName('Explanation').Text }
    $w.FindName('Store').Visibility=if ($Kind -eq 'Appx') {'Visible'} else {'Collapsed'}
    $w.FindName('UndoStartup').Visibility=if ($Kind -eq 'Startup') {'Visible'} else {'Collapsed'}
    $types=New-Object Windows.Controls.ComboBox;$types.Name='AppTypes';$types.Margin='0,8,0,0';$types.Tag='Tất cả'
    foreach ($label in @('Có thể gỡ','Đề xuất xem xét','Ứng dụng thông thường','Được bảo vệ','Tất cả')) {$null=$types.Items.Add($label)}
    $filterParent=[Windows.Controls.Grid]$w.FindName('Filter').Parent
    $stack=New-Object Windows.Controls.StackPanel;[Windows.Controls.Grid]::SetRow($stack,1)
    $filter=$w.FindName('Filter');$null=$filterParent.Children.Remove($filter);$null=$stack.Children.Add($filter)
    if ($Kind -eq 'Appx') {$null=$stack.Children.Add($types)}
    $null=$filterParent.Children.Add($stack);$script:ManagerTypes=$types;$types.SelectedIndex=0
    $types.Add_SelectionChanged({Render-ManagementList})
    $w.FindName('Items').Add_SelectionChanged({param($sender,$args) if ($null -ne $sender.SelectedItem) {Show-ManagementDetail $sender.SelectedItem.Tag}})
    $w.FindName('Filter').ToolTip='Tìm tên ứng dụng, có hoặc không dấu'
    Set-ThemeResource ($w.FindName('TechnicalInfo')) Foreground Muted
    Set-ThemeResource ($w.FindName('TechnicalInfo').Parent) Foreground Text
    $w.FindName('Filter').Add_TextChanged({Render-ManagementList})
    $w.FindName('Queue').Add_Click({ if ($null -ne $script:ManagerState.Current) { $id=$script:ManagerState.Current.Id; if ($script:ManagerState.Selected.ContainsKey($id)) {$script:ManagerState.Selected.Remove($id)} else {$script:ManagerState.Selected[$id]=$true}; Render-ManagementList } })
    $w.FindName('Reload').Add_Click({Refresh-Management})
    $w.FindName('Review').Add_Click({Invoke-ManagementReview})
    $w.FindName('UndoStartup').Add_Click({
        try {
            $last=Get-LatestStartupAction
            if ($null -eq $last) {Message 'Không còn đợt khởi động để phục hồi.'; return}
            $text='Phục hồi lệnh tự khởi động đã lưu. Không mở hoặc chạy lệnh này ngay. Kiểm tra xung đột trước khi ghi.'+"`n`n"+(@($last.Journal.Rows | ForEach-Object { $_.Item.Title+': '+$_.Item.Command }) -join "`n")
            if (Show-TextDialog 'Xem trước phục hồi tự khởi động' $text $true 'Khôi phục các lệnh này') { if ($SelfTest) {Undo-StartupAction;Message 'Đã phục hồi và đọc lại lệnh khởi động.'} else {$null=Start-ToolJob 'startupundo' ([pscustomobject]@{ActionRoot=$script:ActionRoot}) $true;Start-ManagementPolling} }
        } catch {Message $_.Exception.Message} finally {Refresh-Management}
    })
    $w.FindName('ActionHistory').Add_Click({Show-ManagementHistory})
    $reinstall=New-Object Windows.Controls.Button; $reinstall.Content='Cài lại app đã gỡ'; $reinstall.Visibility=if ($Kind -eq 'Appx') {'Visible'} else {'Collapsed'}
    $reinstall.Add_Click({Open-ReinstallChooser})
    $footer=[Windows.Controls.Panel]$w.FindName('ActionHistory').Parent
    $null=$footer.Children.Insert($footer.Children.Count-1,$reinstall)
    $w.FindName('Store').Add_Click({
        if ($null -eq $script:ManagerState.Current) {return}
        if ($ActionSimulation) {Message 'Mô phỏng: không mở Store thật.';return}
        $id=$script:ManagerState.Current.StoreId
        if ($id -notmatch '^[A-Z0-9]{12,14}$') {Message 'Chưa có liên kết Store hợp lệ.';return}
        Start-Process ('ms-windows-store://pdp/?ProductId='+$id)
    })
    $w.FindName('CloseManager').Add_Click({param($sender,$args) [Windows.Window]::GetWindow($sender).Close()})
    $w.Add_Closing({param($sender,$args) if ($null -ne $script:ToolJob -and -not $script:ToolJob.Process.HasExited) {$args.Cancel=$true;Message 'Thao tác đang chạy; đợi kết quả. WinTune không tự kết thúc app/worker.'}})
    Refresh-Management
    return $w
}
function Update-ManagementSelection {
    $m=$script:ManagerState; $w=$m.Window
    $busy=$null -ne $script:ToolJob -and -not $script:ToolJob.Process.HasExited
    $w.FindName('Review').IsEnabled=$m.Selected.Count -gt 0 -and -not $m.Error -and -not $script:PendingBatch -and -not $script:HistoryError -and -not $busy
    $w.FindName('Reload').IsEnabled=-not $busy;$w.FindName('UndoStartup').IsEnabled=-not $busy
    if ($busy) {$w.FindName('Queue').IsEnabled=$false}
    $w.FindName('State').Text=if ($m.Error) {'Không thể tiếp tục: '+$m.Error} else {"Đang hiện $($w.FindName('Items').Items.Count) / $($m.Inventory.Count) mục • Đã chọn $($m.Selected.Count). Đánh dấu chưa thay đổi Windows."}
    if ($null -ne $m.Current) { $w.FindName('Queue').Content=if ($m.Selected.ContainsKey($m.Current.Id)) {'Bỏ khỏi danh sách chờ'} else {'Thêm vào danh sách chờ'} }
}
function Show-ManagementDetail($Item) {
    $m=$script:ManagerState; $m.Current=$Item; $w=$m.Window
    $w.FindName('ItemTitle').Text=$Item.Title
    $undo=if ($m.Kind -eq 'Appx' -and $Item.StoreId) {'Cài lại qua Microsoft Store; không hứa khôi phục dữ liệu hoặc đúng phiên bản cũ. Có thể cần mạng, tài khoản Store và giấy phép. App đang mở phải tự lưu/đóng trước. Chỉ gỡ gói cho tài khoản hiện tại.'} elseif ($m.Kind -eq 'Appx') {'Chưa có phương pháp cài lại được xác minh trong WinTune. Tự giữ nguồn cài chính thức và sao lưu dữ liệu trước khi gỡ; không hứa khôi phục dữ liệu. Không chọn nếu bạn chưa biết cách cài lại.'} else {'Phục hồi đúng lệnh và kiểu dữ liệu cũ khi không có xung đột. Không tự khởi động app. Tác dụng chủ yếu ở lần đăng nhập sau; không thay đổi các dịch vụ hay tác vụ lịch.'}
    $protection=if ($m.Kind -eq 'Appx') {Get-AppProtection $Item} else {$null}
    $status=if ($m.Kind -eq 'Appx') {'Trạng thái: đang cài cho tài khoản hiện tại. '+$protection.Category+'. '+$protection.Reason} else {'Trạng thái: có lệnh trong HKCU Run; không đồng nghĩa Windows đang cho phép tự chạy.'}
    $w.FindName('Details').Text=$status+"`n`n"+$Item.Impact+"`n`nLợi ích và giới hạn: chỉ có thể bớt hoạt động nền nếu app đó đang tự mở hoặc chạy nền. App không chạy có thể không dùng RAM; gỡ có thể chỉ tiết kiệm dung lượng.`n`nNên giữ nếu bạn cần chức năng trên. Không chọn sẵn.`n`nPhạm vi: tài khoản Windows hiện tại.`n`n"+$undo
    $publisher=if ($Item.PSObject.Properties['Publisher']) {$Item.Publisher} else {$Item.PublisherId}
    if ($m.Kind -eq 'Appx') {
        $publisherLabel=if ($Item.PublisherId -eq '8wekyb3d8bbwe') {'Microsoft'} elseif ($publisher -match '^CN=([^,]+)') {$Matches[1]} else {$publisher}
        $w.FindName('Details').Text="CÔNG DỤNG`n$($Item.Impact)`n`nPHÂN LOẠI`n$($protection.Category) — $($protection.Reason)`n`nNhà phát hành: $publisherLabel`nChỉ gỡ cho tài khoản Windows hiện tại.`n`nGỡ chỉ giảm hoạt động nền nếu ứng dụng đang chạy hoặc tự mở; không bảo đảm giảm RAM.`n`n$undo"
    }
    $w.FindName('TechnicalInfo').Text=if ($m.Kind -eq 'Appx') {"Tên gói: $($Item.Name)`nGói chính xác: $($Item.Id)`nPhiên bản: $($Item.Version)`nNhà phát hành: $publisher`nMã Store (nếu đã xác minh): $($Item.StoreId)`nNguồn danh mục gợi ý: ChrisTitusTech/winutil (đã ghim), API Microsoft Remove-AppxPackage. Không dùng wildcard/AllUsers. Tên/mô tả chưa xác định thì hiển thị tên gói thật."} else {"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`nTên: $($Item.Name)`nKiểu: $($Item.ValueKind)`nLệnh gốc: $($Item.Command)`nKhông sửa StartupApproved. Có lệnh không đồng nghĩa Windows hiện cho phép nó tự chạy."}
    $w.FindName('Queue').IsEnabled=$null -eq $protection -or -not $protection.Protected; $w.FindName('Store').IsEnabled=$m.Kind -eq 'Appx' -and $Item.StoreId -match '^[A-Z0-9]{12,14}$'; Update-ManagementSelection
}
function Render-ManagementList {
    $m=$script:ManagerState; $keep=if ($null -ne $m.Current) {$m.Current.Id} else {''}; $list=$m.Window.FindName('Items'); $list.Items.Clear()
    $query=Search-Text $m.Window.FindName('Filter').Text
    foreach ($p in $m.Inventory) {
        if ($query -and (Search-Text ($p.Title+' '+$p.Name)).IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -lt 0) {continue}
        if ($m.Kind -eq 'Appx' -and $script:ManagerTypes.SelectedItem -ne 'Tất cả') {
            $protection=Get-AppProtection $p
            if ($script:ManagerTypes.SelectedItem -eq 'Có thể gỡ') {if ($protection.Protected) {continue}}
            elseif ($script:ManagerTypes.SelectedItem -eq 'Được bảo vệ') {if (-not $protection.Protected) {continue}}
            elseif ($script:ManagerTypes.SelectedItem -ne $protection.Category) {continue}
        }
        $item=New-Object Windows.Controls.ListBoxItem; $item.Tag=$p
        $row=New-Object Windows.Controls.DockPanel
        $box=New-Object Windows.Controls.CheckBox; $box.Tag=$p; $box.IsChecked=$m.Selected.ContainsKey($p.Id); $box.Margin='0,3,10,0'
        if ($m.Kind -eq 'Appx') {$box.IsEnabled=-not (Get-AppProtection $p).Protected}
        [Windows.Controls.DockPanel]::SetDock($box,'Left')
        $box.Add_Click({param($sender,$args) if ($sender.IsChecked) {$script:ManagerState.Selected[$sender.Tag.Id]=$true} else {$script:ManagerState.Selected.Remove($sender.Tag.Id)}; Show-ManagementDetail $sender.Tag; foreach ($li in $script:ManagerState.Window.FindName('Items').Items) { if ($li.Tag.Id -eq $sender.Tag.Id) {$li.IsSelected=$true;break} }; Update-ManagementSelection})
        $null=$row.Children.Add($box);$textPanel=New-Object Windows.Controls.StackPanel
        $text=New-Object Windows.Controls.TextBlock;$text.Text=$p.Title;$text.FontWeight='SemiBold';$null=$textPanel.Children.Add($text)
        if ($m.Kind -eq 'Appx') {
            $protection=Get-AppProtection $p;$badge=New-Object Windows.Controls.TextBlock;$badge.FontSize=12;$badge.Margin='0,5,0,0'
            $badge.Text=if ($protection.Protected) {'▣ Thành phần được bảo vệ'} elseif ($protection.Category -eq 'Đề xuất xem xét') {'● Xem xét gỡ nếu không dùng'} else {'● Ứng dụng thông thường'}
            Set-ThemeResource $badge Foreground $(if ($protection.Protected) {'Muted'} elseif ($protection.Category -eq 'Đề xuất xem xét') {'Accent'} else {'Warning'})
            $null=$textPanel.Children.Add($badge)
        }
        $null=$row.Children.Add($textPanel);$item.Content=$row;$null=$list.Items.Add($item)
    }
    if ($list.Items.Count -gt 0) { $match=@($list.Items | Where-Object {$_.Tag.Id -ceq $keep}); if ($match.Count) {$list.SelectedItem=$match[0]} else {$list.SelectedIndex=0} } else { $m.Current=$null; $m.Window.FindName('ItemTitle').Text='Không có mục phù hợp'; $m.Window.FindName('Details').Text='Không tìm thấy hoặc app không nằm trong danh mục đã duyệt. Không báo đã gỡ khi chưa có app.'; $m.Window.FindName('TechnicalInfo').Text=''; $m.Window.FindName('Queue').IsEnabled=$false; $m.Window.FindName('Store').IsEnabled=$false }
    Update-ManagementSelection
}
function Refresh-Management {
    $m=$script:ManagerState
    try {
        $null=@(Get-ActionJournals); $m.Inventory=@(if ($m.Kind -eq 'Appx') {Get-AllAppInventory} else {Get-ActionInventory $m.Kind}); $m.Error=''
        $m.Inventory=@($m.Inventory | Sort-Object Title)
        # Retain selections hidden by search, but remove packages/entries that
        # physically disappeared, including those removed before a batch error.
        $present=@($m.Inventory | ForEach-Object Id)
        foreach ($id in @($m.Selected.Keys)) { if ($id -cnotin $present) {$m.Selected.Remove($id)} }
    }
    catch { $m.Error=$_.Exception.Message }
    Render-ManagementList
}
function Invoke-ManagementReview {
    $m=$script:ManagerState
    try {
        if ($script:PendingBatch -or $script:HistoryError) {throw 'Phục hồi đợt tùy chỉnh đang dở trước khi làm tiếp.'}
        $ids=@($m.Inventory | Where-Object {$m.Selected.ContainsKey($_.Id)} | ForEach-Object Id)
        if ($ids.Count -ne $m.Selected.Count) {throw 'Danh sách đã thay đổi; đọc lại trước khi xem trước.'}
        $plan=@(New-ActionPlan $m.Kind $ids)
        if ($plan.Count -eq 0) {Message 'Không có mục cần thay đổi; không tạo đợt.';return}
        $lines=@('XEM TRƯỚC — chưa thay đổi Windows.', "Tài khoản: $script:UserId", '')
        if ($ActionSimulation) {$lines+='MÔ PHỎNG — không thay đổi Windows thật.'}
        foreach ($r in $plan) { $lines+=$r.Item.Title; $lines+=if ($m.Kind -eq 'Appx') {"GỠ GÓI CHÍNH XÁC: $($r.Item.Id)`n$($r.Item.Impact)`nCài lại: $(if ($r.Item.StoreId) {'ms-windows-store://pdp/?ProductId='+$r.Item.StoreId} else {'Chưa có nguồn xác minh; giữ nguồn chính thức trước khi gỡ.'})`nDữ liệu app không được sao lưu/hoàn tác."} else {"XÓA LỆNH TỰ MỞ: HKCU Run\$($r.Item.Name)`n$($r.Item.Command)`nKiểu $($r.Item.ValueKind). Lưu nguyên lệnh để phục hồi; không đóng app đang chạy."}; $lines+=''}
        $lines+='Nhật ký: '+$script:ActionRoot
        $action=if ($m.Kind -eq 'Appx') {'Gỡ đúng các ứng dụng đã chọn'} else {'Tắt tự mở các mục đã chọn'}
        if (-not (Show-TextDialog 'Xem trước quản lý ứng dụng' ($lines -join "`r`n") $true $action)) {return}
        if (-not $SelfTest) {
            $null=Start-ToolJob 'actionsapply' ([pscustomobject]@{ActionRoot=$script:ActionRoot;Rows=$plan}) $true
            Start-ManagementPolling
            return
        }
        $null=Invoke-ActionPlan $plan; $m.Selected.Clear()
        Message $(if ($m.Kind -eq 'Appx') {'Đã gỡ và kiểm tra lại gói cho tài khoản này. Xem lịch sử để cài lại; dữ liệu không được hoàn tác.'} else {'Đã tắt lệnh tự mở và xác minh. Có thể phục hồi trong cửa sổ này; không đóng app đang chạy.'})
    } catch {Message $_.Exception.Message} finally {Refresh-Management}
}
function Show-ManagementHistory {
    try {
        $lines=@('LỊCH SỬ QUẢN LÝ ỨNG DỤNG','')
        foreach ($e in @(Get-ActionJournals | Sort-Object { $_.Journal.Created } -Descending)) {
            $j=$e.Journal; $label=switch ($j.Status) {'Completed' {'Đã áp dụng'} 'Undone' {'Đã phục hồi Startup'} 'Partial' {'Một phần — có lỗi'} default {'Chưa hoàn tất'}}
            $lines+="$($j.Created) — $label"
            foreach ($r in $j.Rows) {
                $state=switch ($r.State) {'Applied' {'Đã làm và kiểm tra lại'} 'Failed' {'Lỗi, có thể đã làm một phần'} 'Skipped' {'Chưa làm'} 'Writing' {'Bị ngắt khi thao tác'} default {'Chưa làm'}}
                $lines+="$($r.Item.Title): $state — $($r.Error)"
                if ($r.Item.Kind -eq 'Appx') {if ($r.Item.StoreId) {$lines+="Gói: $($r.Item.Id)`nCài lại: ms-windows-store://pdp/?ProductId=$($r.Item.StoreId). Mở liên kết bằng trình duyệt/Store; không khôi phục dữ liệu."} else {$lines+="Gói: $($r.Item.Id)`nChưa có nguồn cài lại được xác minh; dùng nguồn chính thức của nhà phát hành. Không khôi phục dữ liệu."}}
                elseif ($r.UndoState -ne 'None') {$lines+='Phục hồi: '+$(if ($r.UndoState -eq 'Restored') {'Đã phục hồi và xác minh'} else {'Chưa hoàn tất'})}
            }
            $lines+=''
        }
        if ($lines.Count -eq 2) {$lines+='Chưa có thay đổi.'}
        $null=Show-TextDialog 'Lịch sử và cách cài lại' ($lines -join "`r`n")
    } catch {Message $_.Exception.Message}
}
function Start-ManagementPolling {
    $w=$script:ManagerState.Window
    foreach ($name in @('Review','Reload','UndoStartup','Queue')) {$w.FindName($name).IsEnabled=$false}
    $w.FindName('State').Text='Đang thực hiện trong worker; bạn vẫn có thể cuộn/xem chi tiết. Chưa có kết quả cuối.'
    $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(500);$script:ManagerTimer=$timer
    $timer.Add_Tick({
        $r=Get-ToolJobResult $script:ToolJob
        if ($null -eq $r) {return}
        $script:ManagerTimer.Stop();$script:ToolJob.Handled=$true
        Initialize-Actions $script:ActionRoot ([bool]($script:IsSimulation -or $script:WriteBlocked)) $script:UserId
        if ($r.Status -eq 'Completed') {$script:ManagerState.Selected.Clear()}
        foreach ($name in @('Review','Reload','UndoStartup','Queue')) {$script:ManagerState.Window.FindName($name).IsEnabled=$true}
        Refresh-Management
        Message ((Get-ToolStatusLabel $r.Status)+' — '+$r.Message+' Xem lịch sử từng mục. Gỡ app không khôi phục dữ liệu.')
    });$timer.Start()
}
function Open-Management([string]$Kind) {
    try { $script:ManagementWindow=New-ManagementWindow $Kind; $null=$script:ManagementWindow.ShowDialog() }
    catch {Message $_.Exception.Message}
    finally { $script:ManagementWindow=$null; $script:ManagerState=$null }
}
function New-ReinstallChooser {
    $items=@(Get-ActionJournals | ForEach-Object {$_.Journal.Rows} | Where-Object {$_.Item.Kind -eq 'Appx' -and $_.State -in @('Applied','Failed','Writing') -and $_.Item.StoreId -match '^[A-Z0-9]{12,14}$'} | ForEach-Object Item | Sort-Object StoreId -Unique)
    $w=New-Object Windows.Window; $w.Title='Cài lại ứng dụng — không khôi phục dữ liệu'; $w.Width=600; $w.Height=390;Set-ThemeResource $w Background Window;Set-ThemeResource $w Foreground Text;$w.FontFamily='Segoe UI'; $w.FontSize=14; $w.Resources=$script:Window.Resources;Register-ThemeWindow $w
    if ($null -ne $script:ManagementWindow -and $script:ManagementWindow.IsVisible) {$w.Owner=$script:ManagementWindow} elseif ($script:Window.IsVisible) {$w.Owner=$script:Window}
    $panel=New-Object Windows.Controls.StackPanel; $panel.Margin='22'
    $text=New-Object Windows.Controls.TextBlock; $text.Text='Chọn app đã gỡ và mở trang Microsoft Store. Bạn tự xác nhận cài lại tại Store; có thể cần mạng/tài khoản/giấy phép. Không tự cài và không khôi phục dữ liệu đã mất.'; $text.Margin='0,0,0,16'; $null=$panel.Children.Add($text)
    $list=New-Object Windows.Controls.ComboBox; $list.Name='ReinstallItems'; $list.Margin='0,0,0,16'
    foreach ($p in $items) { $entry=New-Object Windows.Controls.ComboBoxItem; $entry.Content=$p.Title; $entry.Tag=$p.StoreId; $null=$list.Items.Add($entry) }
    if ($list.Items.Count) {$list.SelectedIndex=0} else {$text.Text='Chưa có app đã gỡ trong lịch sử. Không có gì để cài lại.'}
    $null=$panel.Children.Add($list)
    $button=New-Object Windows.Controls.Button; $button.Name='OpenReinstall'; $button.Content='Mở trang Store của app đã chọn'; $button.IsEnabled=$list.Items.Count -gt 0; $button.Tag=$list
    $button.Add_Click({param($sender,$args) $id=[string]$sender.Tag.SelectedItem.Tag; if ($script:ActionSimulation) {Message 'Mô phỏng: không mở Store thật.';return}; if ($id -match '^[A-Z0-9]{12,14}$') {Start-Process ('ms-windows-store://pdp/?ProductId='+$id)} })
    $null=$panel.Children.Add($button); $w.Content=$panel
    return $w
}
function Open-ReinstallChooser {
    try {$w=New-ReinstallChooser; $null=$w.ShowDialog()} catch {Message $_.Exception.Message}
}
function Open-CopilotManager {
    try {$w=New-ManagementWindow Appx;$w.FindName('Filter').Text='Copilot';$null=$w.ShowDialog()} catch {Message $_.Exception.Message} finally {$script:ManagementWindow=$null}
}
function Show-ResourceMeasurement {
    try {
        if ($script:IsSimulation) {Message 'Mô phỏng: không đo hoặc công bố mức RAM thật.';return}
        $os=Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 10
        $total=[Math]::Round($os.TotalVisibleMemorySize/1MB,2); $available=[Math]::Round($os.FreePhysicalMemory/1MB,2)
        $sample=[pscustomobject]@{Time=(Get-Date).ToString('o');TotalGiB=$total;AvailableGiB=$available;UsedEstimateGiB=[Math]::Round($total-$available,2);Processes=@(Get-Process).Count}
        $sample | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $script:DataRoot 'resource-measurements.jsonl') -Encoding UTF8
        $null=Show-TextDialog 'RAM và số tiến trình — chỉ đọc' ("RAM khả dụng: $available / $total GiB`nƯớc tính đang dùng: $($sample.UsedEstimateGiB) GiB`nSố tiến trình: $($sample.Processes)`nThời điểm: $($sample.Time)`n`nĐo lại sau khi tự đăng nhập lại và đợi máy ổn định, cùng các app đang mở. Không cộng RAM từng tiến trình vì có bộ nhớ dùng chung. Windows dùng RAM cho cache; không xóa cache để tạo số đẹp. Mức RAM không cố định và có thể khác Task Manager.`nLog: $script:DataRoot\resource-measurements.jsonl")
    } catch {Message ('Không đọc được thống kê: '+$_.Exception.Message)}
}
