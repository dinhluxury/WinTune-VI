#Requires -Version 5.1
#Requires -PSEdition Desktop
param([switch]$Simulation,[switch]$Updates,[switch]$SelfTest,[switch]$GuiProbe,[switch]$ReadOnlyProbe,[switch]$MonitorProbe,[string]$TestDataRoot='')
if ($MonitorProbe) {$ReadOnlyProbe=$true}
if ($ReadOnlyProbe) { $GuiProbe=$true }
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Add-Type -AssemblyName @('PresentationFramework','PresentationCore','WindowsBase')
. (Join-Path $PSScriptRoot 'Core.ps1')
$mutexName=if ($SelfTest -or $GuiProbe) {'Local\WinTuneVI-Test-'+[guid]::NewGuid().ToString('N')} elseif ($Simulation) {'Local\WinTuneVI-Simulation'} else {'Local\WinTuneVI-v2'}
$mutex=New-Object Threading.Mutex($false,$mutexName)
if (-not $mutex.WaitOne(0)) { $null=[Windows.MessageBox]::Show('WinTune VI đang mở.'); exit }
try {
    $cv=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build=[int]$cv.CurrentBuild
    $osName=if ($build -ge 22000) {'Windows 11'} else {'Windows 10'}
    $data=Join-Path $env:LOCALAPPDATA 'WinTuneVI\v2'
    if ($Simulation) { $data=Join-Path $PSScriptRoot 'simulation-data' }
    if ($SelfTest -or $GuiProbe) { $data=Join-Path $PSScriptRoot ('.test-runs/ui-'+[guid]::NewGuid().ToString('N')) }
    if (($Simulation -or $SelfTest -or $GuiProbe) -and $TestDataRoot) { $data=$TestDataRoot }
    Initialize-WinTune (Join-Path $PSScriptRoot 'features.json') $data ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value) $build
    $script:WriteBlocked=$false
    if (($Simulation -or $SelfTest -or $GuiProbe) -and -not $ReadOnlyProbe) { . (Join-Path $PSScriptRoot 'Simulation.ps1'); $script:IsSimulation=$true }
    if ($ReadOnlyProbe) {
        $script:WriteBlocked=$true; $script:SimWriteCount=0
        function Set-RegistryValue { throw 'Chế độ kiểm tra chỉ đọc: cấm mọi thao tác ghi registry thật.' }
    }
    if ($Simulation -and -not $SelfTest -and -not $GuiProbe) { Enable-SimulationStorage }
    [xml]$xml=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'MainWindow.xaml') -Raw -Encoding UTF8
    $reader=New-Object Xml.XmlNodeReader $xml
    $script:Window=[Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()
    $appVersion=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'version.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($appVersion.Version -notmatch '^\d+\.\d+\.\d+$') {throw 'Thông tin phiên bản không hợp lệ.'}
    $Window.FindName('AppVersion').Text=$appVersion.Version+' • Portable'
    $script:Selected=@{}
    $script:Current=$null
    $script:Rendering=$false
    $script:HistoryError=''
    $script:PendingBatch=$false
    $script:ManagementWindow=$null
    $script:ManagerState=$null
    $script:ToolsWindow=$null
    $script:RestoreWindow=$null
    $script:LogsWindow=$null
    $script:ToolJob=$null
    $script:DistributionWindow=$null;$script:DistributionJob=$null;$script:DistributionTimer=$null
    $script:FullWindow=$null;$script:FullJob=$null;$script:FullTimer=$null;$script:MainActionBusy=$false;$script:UnifiedTweaksPageActive=$false
    . (Join-Path $PSScriptRoot 'Theme.UI.ps1')
    Initialize-ThemeUI
    . (Join-Path $PSScriptRoot 'Links.UI.ps1')
    $script:List=$Window.FindName('FeatureList')
    $script:Search=$Window.FindName('Search')
    . (Join-Path $PSScriptRoot 'Monitor.UI.ps1')
    . (Join-Path $PSScriptRoot 'FeatureBoard.UI.ps1')
    Initialize-FeatureBoard
    $mode=if ($ReadOnlyProbe) {' • KIỂM TRA CHỈ ĐỌC — chặn ghi'} elseif ($script:IsSimulation) {' • MÔ PHỎNG — không ghi Windows'} else {''}
    $Window.FindName('Machine').Text="$osName $($cv.EditionID) • Build $build • $(@($Features | Where-Object Kind -eq Registry).Count) tùy chỉnh$mode"
    if ($script:IsSimulation) { $Window.Title+=' [MÔ PHỎNG]' }
    if ($ReadOnlyProbe) { $Window.Title+=' [CHỈ ĐỌC]' }
    $work=[Windows.SystemParameters]::WorkArea
    $Window.Width=[Math]::Min($Window.Width,$work.Width)
    $Window.Height=[Math]::Min($Window.Height,$work.Height)

    function Message([string]$Text) {
        $dialog=New-TextDialog 'WinTune VI' $Text
        $dialog.MinHeight=220;$dialog.MinWidth=420;$dialog.Width=580;$dialog.Height=[Math]::Min(340,[Windows.SystemParameters]::WorkArea.Height)
        $null=$dialog.ShowDialog()
    }
    function Search-Text([string]$Text) {
        $normal=$Text.Normalize([Text.NormalizationForm]::FormD)
        $builder=New-Object Text.StringBuilder
        foreach ($char in $normal.ToCharArray()) {
            if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($char) -ne [Globalization.UnicodeCategory]::NonSpacingMark) { $null=$builder.Append($char) }
        }
        return $builder.ToString().Replace('đ','d').Replace('Đ','D')
    }
    function Update-Selection {
        $Window.FindName('SelectionCount').Text="Đã chọn $($script:Selected.Count) tính năng"
        Update-SelectedFeatureSummary
        $Window.FindName('Preview').IsEnabled=$script:Selected.Count -gt 0 -and -not $script:PendingBatch -and -not $script:HistoryError -and -not $script:MainActionBusy
        $reason=if ($script:HistoryError) {'Chưa thể áp dụng: không đọc được bản sao lưu. Bấm Lịch sử để xem lỗi. '+$script:HistoryError} elseif ($script:PendingBatch) {'Đợt trước chưa hoàn tất. Bấm Lịch sử để xem, rồi Hoàn tác trước khi áp dụng đợt mới.'} else {''}
        $Window.FindName('ApplyBlockReason').Text=$reason
        $Window.FindName('ApplyBlockReason').Visibility=if ($reason) {'Visible'} else {'Collapsed'}
        $Window.FindName('Preview').ToolTip=if ($reason) {$reason} elseif ($script:Selected.Count -eq 0) {'Chọn ít nhất một thiết lập trước.'} else {'Xem các thay đổi trước khi xác nhận áp dụng.'}
        if ($reason) {$Window.FindName('Status').Text=if ($script:HistoryError) {'Chưa thể áp dụng: không đọc được bản sao lưu.'} else {'Cần hoàn tác đợt trước trước khi áp dụng.'}}
        if ($null -ne $script:Current) {
            $Window.FindName('Toggle').Content=if ($script:Current.Kind -eq 'Settings') {'Mở cài đặt Windows →'} elseif ($script:Selected.ContainsKey($script:Current.Id)) {'Bỏ khỏi danh sách áp dụng'} else {'Thêm vào danh sách áp dụng'}
            $Window.FindName('Toggle').IsEnabled=(Test-FeatureSupported $script:Current) -and -not $script:MainActionBusy
        }
    }
    function Get-PermissionDescription($Feature) {
        if ($Feature.Kind -ne 'Registry') { return '' }
        $blocked=@($Feature.Changes | Where-Object { -not (Test-RegistryWriteAccess $_).Allowed })
        if ($blocked.Count -gt 0) { return ('Windows đang chặn ghi: '+(($blocked | ForEach-Object { $_.Hive+'\'+$_.Path+'\'+$_.Name }) -join '; ')+'. WinTune không tự sửa quyền registry hoặc vượt chính sách của máy.') }
        return ''
    }
    function Show-Detail($Feature) {
        $changed=$null -eq $script:Current -or $script:Current.Id -ne $Feature.Id
        $script:Current=$Feature
        if ($changed) { $Window.FindName('DetailScroll').ScrollToTop() }
        $Window.FindName('DetailGroup').Text=$Feature.Group.ToUpperInvariant()
        $Window.FindName('DetailTitle').Text=$Feature.Title
        try { $state=Get-FeatureState $Feature } catch { $state="Không đọc được: $($_.Exception.Message)" }
        $Window.FindName('DetailState').Text="Trạng thái: $state"
        $Window.FindName('DetailBenefit').Text=$Feature.Benefit
        $choice=Get-FeatureChoice $Feature
        if ($null -ne $choice) {$Window.FindName('DetailBenefit').Text='Đang chuẩn bị chọn: '+$choice.Title+"`n`n"+$Feature.Benefit}
        $Window.FindName('DetailCost').Text=$Feature.Cost
        $Window.FindName('DetailWho').Text="$($Feature.Who)`n`nNên giữ nguyên: $($Feature.Keep)"
        $range=if ($Feature.MaxBuild -gt 0) {"$($Feature.MinBuild)–$($Feature.MaxBuild)"} else {"$($Feature.MinBuild) trở lên"}
        $permission=Get-PermissionDescription $Feature
        $Window.FindName('Source').IsEnabled=$true
        Set-SourceLink ($Window.FindName('Source')) $(if ($null -ne $choice) {$choice.Source} else {$Feature.Source})
        $Window.FindName('DetailUndo').Text=(($permission+"`n`n$($Feature.Timing)`n`n$($Feature.Undo)`n`nWindows build $range. Trạng thái xác minh giá trị thiết lập; hiệu lực còn phụ thuộc Windows và chính sách của máy.").Trim())
        if ($Feature.Kind -eq 'Action') {$Window.FindName('Technical').Text='Gói được xác minh: Microsoft.Copilot. Chỉ quản lý gói của tài khoản hiện tại, không AllUsers hoặc provisioned.'}
        elseif ($Feature.Kind -eq 'Settings') { $Window.FindName('Technical').Text="Mở trang: $($Feature.SettingsUri)`nKhông tự ghi thiết lập; thao tác tại Settings không được WinTune sao lưu." }
        else {
            $Window.FindName('Technical').Text=(@(Get-FeatureChanges $Feature | ForEach-Object {
                $c=$_
                try { $value=Read-RegistryValue $c; $now=if ($value.Exists) {"'$($value.Value)' ($($c.Type))"} else {'Chưa tồn tại (không suy ra đã tắt)'} } catch { $now="Không đọc được: $($_.Exception.Message)" }
                "$($c.Hive)\$($c.Path)`n$($c.Name)`nHiện tại: $now`nGiá trị yêu cầu: '$($c.Value)' ($($c.Type))"
            }) -join "`n`n")
        }
        $Window.FindName('Toggle').IsEnabled=Test-FeatureSupported $Feature
        Update-Selection
    }
    function Render-List {
        $script:Rendering=$true
        try {
            $keep=if ($null -ne $script:Current) {$script:Current.Id} else {''}
            $script:List.ItemsSource=$null
            $entries=New-Object Collections.ArrayList
            $query=$script:Search.Text.Trim()
            foreach ($f in $script:Features) {
                if ($Window.FindName('OnlySelected').IsChecked -and -not $script:Selected.ContainsKey($f.Id)) {continue}
                if ($query -and (Search-Text "$($f.Title) $($f.Benefit) $($f.Group)").IndexOf((Search-Text $query),[StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
                $item=New-Object Windows.Controls.ListBoxItem
                $item.Tag=$f
                $item.Padding='6,6'
                [Windows.Automation.AutomationProperties]::SetName($item,$f.Title)
                $row=New-Object Windows.Controls.DockPanel
                $check=New-Object Windows.Controls.CheckBox
                $check.Tag=$f
                [Windows.Automation.AutomationProperties]::SetName($check,"Chọn: $($f.Title)")
                $check.IsChecked=$script:Selected.ContainsKey($f.Id)
                $check.IsEnabled=(Test-FeatureSupported $f) -and ($f.Kind -eq 'Registry' -or $f.Id -eq 'copilotapp') -and -not $script:MainActionBusy
                $check.Margin='0,3,10,0'
                $check.VerticalAlignment='Top'
                [Windows.Controls.DockPanel]::SetDock($check,'Left')
                $check.Add_Click({param($sender,$args)
                    if ($sender.IsChecked) { $script:Selected[$sender.Tag.Id]=$true } else { $script:Selected.Remove($sender.Tag.Id) }
                    Render-List;Show-Detail $sender.Tag
                    foreach ($li in $script:List.Items) { if ($li.Tag.Id -eq $sender.Tag.Id) {$li.IsSelected=$true;break} }
                    Update-Selection
                })
                $null=$row.Children.Add($check)
                $detail=New-Object Windows.Controls.Button;$detail.Content='ⓘ';$detail.Tag=$f;$detail.ToolTip='Đọc tác dụng, trạng thái và cách hoàn tác';$detail.Padding='6,2';$detail.Margin='5,0,0,0';$detail.VerticalAlignment='Top'
                [Windows.Controls.DockPanel]::SetDock($detail,'Right')
                $detail.Add_Click({param($sender,$args) Open-FeatureDetail $sender.Tag})
                $null=$row.Children.Add($detail)
                $inlineHint=Get-FeatureInlineHint $f
                if ($inlineHint) {$hint=New-Object Windows.Controls.TextBlock;$hint.Text=$inlineHint;$hint.TextWrapping='Wrap';$hint.FontSize=12;$hint.Margin='0,4,0,0';$hint.Tag='InlineHint';Set-ThemeResource $hint Foreground Muted;[Windows.Controls.DockPanel]::SetDock($hint,'Bottom');$null=$row.Children.Add($hint)}
                if ($f.PSObject.Properties['Choices']) {
                    $selector=New-Object Windows.Controls.ComboBox;$selector.Tag=$f.Id;$selector.Margin='0,5,0,0';$selector.FontSize=12;$selector.IsEnabled=Test-FeatureSupported $f
                    [Windows.Automation.AutomationProperties]::SetName($selector,('Lựa chọn: '+$f.Title))
                    [Windows.Controls.DockPanel]::SetDock($selector,'Bottom')
                    $chosen=Get-FeatureChoice $f
                    foreach ($option in $f.Choices) {$entry=New-Object Windows.Controls.ComboBoxItem;$entry.Content=$option.Title;$entry.Tag=$option.Id;$null=$selector.Items.Add($entry);if ($option.Id -ceq $chosen.Id) {$selector.SelectedItem=$entry}}
                    $selector.Add_SelectionChanged({param($sender,$eventArgs)
                        if ($script:Rendering -or $null -eq $sender.SelectedItem) {return}
                        $eventArgs.Handled=$true
                        Set-FeatureChoice $sender.Tag $sender.SelectedItem.Tag
                        $script:Selected[$sender.Tag]=$true
                        Render-List;Update-Selection
                        foreach ($li in $script:List.Items) {if ($li.Tag.Id -eq $sender.Tag) {$li.IsSelected=$true;break}}
                        Show-Detail (Get-Feature $sender.Tag)
                    })
                    $null=$row.Children.Add($selector)
                }
                $text=New-Object Windows.Controls.TextBlock
                $text.Text=$f.Title
                if ($f.Kind -eq 'Action') {$text.Text+='  • Gỡ trực tiếp'}
                elseif ($f.Kind -eq 'Settings') { $text.Text+='  • Mở cài đặt' }
                elseif (-not (Test-FeatureSupported $f)) { $text.Text+='  • Không tương thích' }
                $text.TextWrapping='Wrap'
                $null=$row.Children.Add($text)
                $item.Content=$row
                $null=$entries.Add($item)
                if ($f.Id -eq $keep) { $item.IsSelected=$true }
            }
            $view=[Windows.Data.ListCollectionView]::new($entries)
            $view.GroupDescriptions.Add([Windows.Data.PropertyGroupDescription]::new('Tag.Group'))
            $script:List.ItemsSource=$view
            Update-FeatureBoardWidth
            $Window.FindName('Count').Text="$($script:List.Items.Count) mục • ⓘ để xem chi tiết"
            if ($script:List.SelectedIndex -lt 0 -and $script:List.Items.Count -gt 0) { $script:List.SelectedIndex=0 }
        } finally { $script:Rendering=$false }
        if ($null -ne $script:List.SelectedItem) { Show-Detail $script:List.SelectedItem.Tag }
        else {
            $script:Current=$null
            foreach ($name in @('DetailGroup','DetailState','DetailBenefit','DetailCost','DetailWho','DetailUndo','Technical')) { $Window.FindName($name).Text='' }
            $Window.FindName('DetailTitle').Text='Không có mục phù hợp'
            $Window.FindName('Toggle').IsEnabled=$false
            $Window.FindName('Source').IsEnabled=$false
        }
        Update-Selection
    }
    function New-TextDialog([string]$Title,[string]$Text,[bool]$CanApply=$false,[string]$ActionText='Áp dụng các thay đổi này') {
        $dialog=New-Object Windows.Window
        $dialog.Title=$Title; $dialog.Width=740; $dialog.Height=600
        $dialog.MinWidth=520; $dialog.MinHeight=400
        if ($null -ne $script:FullWindow -and $script:FullWindow.IsVisible) { $dialog.Owner=$script:FullWindow; $dialog.WindowStartupLocation='CenterOwner' }
        elseif ($null -ne $script:LogsWindow -and $script:LogsWindow.IsVisible) { $dialog.Owner=$script:LogsWindow; $dialog.WindowStartupLocation='CenterOwner' }
        elseif ($null -ne $script:RestoreWindow -and $script:RestoreWindow.IsVisible) { $dialog.Owner=$script:RestoreWindow; $dialog.WindowStartupLocation='CenterOwner' }
        elseif ($null -ne $script:ToolsWindow -and $script:ToolsWindow.IsVisible) { $dialog.Owner=$script:ToolsWindow; $dialog.WindowStartupLocation='CenterOwner' }
        elseif ($null -ne $script:ManagementWindow -and $script:ManagementWindow.IsVisible) { $dialog.Owner=$script:ManagementWindow; $dialog.WindowStartupLocation='CenterOwner' }
        elseif ($script:Window.IsVisible) { $dialog.Owner=$script:Window; $dialog.WindowStartupLocation='CenterOwner' }
        else { $dialog.WindowStartupLocation='CenterScreen' }
        Set-ThemeResource $dialog Background Window;Set-ThemeResource $dialog Foreground Text
        $dialog.Resources=$script:Window.Resources
        Register-ThemeWindow $dialog
        $dialog.Width=[Math]::Min($dialog.Width,[Windows.SystemParameters]::WorkArea.Width)
        $dialog.Height=[Math]::Min($dialog.Height,[Windows.SystemParameters]::WorkArea.Height)
        $panel=New-Object Windows.Controls.DockPanel; $panel.Margin='22'
        $buttons=New-Object Windows.Controls.StackPanel; $buttons.Orientation='Horizontal'; $buttons.HorizontalAlignment='Right'; $buttons.Margin='0,15,0,0'
        [Windows.Controls.DockPanel]::SetDock($buttons,'Bottom')
        $close=New-Object Windows.Controls.Button; $close.Content='Đóng'; $close.Padding='18,10'; $close.Margin='0,0,10,0'
        $close.IsCancel=$true
        $close.Add_Click({param($sender,$args) [Windows.Window]::GetWindow($sender).DialogResult=$false})
        $null=$buttons.Children.Add($close)
        if ($CanApply) {
            $ok=New-Object Windows.Controls.Button; $ok.Content=$ActionText; $ok.Padding='18,10';Set-ThemeResource $ok Background AccentButton;Set-ThemeResource $ok Foreground OnAccent
            $ok.Add_Click({param($sender,$args) [Windows.Window]::GetWindow($sender).DialogResult=$true})
            $null=$buttons.Children.Add($ok)
        }
        $null=$panel.Children.Add($buttons)
        $box=New-Object Windows.Controls.TextBox
        $box.Text=$Text; $box.IsReadOnly=$true; $box.TextWrapping='Wrap'; $box.VerticalScrollBarVisibility='Auto'
        Set-ThemeResource $box Background Surface;Set-ThemeResource $box Foreground Text;$box.BorderThickness=0; $box.Padding='15'; $box.FontSize=14
        $null=$panel.Children.Add($box); $dialog.Content=$panel
        return $dialog
    }
    function Show-TextDialog([string]$Title,[string]$Text,[bool]$CanApply=$false,[string]$ActionText='Áp dụng các thay đổi này') {
        $dialog=New-TextDialog $Title $Text $CanApply $ActionText
        return $dialog.ShowDialog()
    }
    function Refresh-UI {
        try { $latest=Get-LatestJournal; $script:HistoryError='' }
        catch { $script:HistoryError=$_.Exception.Message; $latest=$null }
        $script:PendingBatch=$null -ne $latest -and $latest.Journal.Status -eq 'Pending'
        $Window.FindName('Undo').IsEnabled=$null -ne $latest -and -not $script:HistoryError -and -not $script:MainActionBusy
        if ($null -ne $script:Current) { Show-Detail $script:Current }
        if ($script:PendingBatch) { $Window.FindName('Status').Text='Đợt trước chưa hoàn tất: xem lịch sử và Hoàn tác trước khi tiếp tục.' }
        if ($script:HistoryError) { $Window.FindName('Status').Text='Lịch sử lỗi; đã khóa áp dụng/hoàn tác. '+$script:HistoryError }
        if($script:UnifiedTweaksPageActive){Update-UnifiedRecovery}
        Update-Selection
    }
    $Search.Add_TextChanged({if (-not $script:Rendering) {Render-List}})
    $List.Add_SelectionChanged({if (-not $script:Rendering -and $null -ne $script:List.SelectedItem) {Show-Detail $script:List.SelectedItem.Tag}})
    $Window.FindName('Toggle').Add_Click({
        if ($null -eq $script:Current) {return}
        if ($script:MainActionBusy) {return}
        if ($script:Current.Kind -eq 'Settings') {
            try { if ($script:IsSimulation) { Message 'Chế độ mô phỏng: không mở Settings thật.' } else { Start-Process $script:Current.SettingsUri } } catch { Message $_.Exception.Message }
            return
        }
        $id=$script:Current.Id
        if ($script:Selected.ContainsKey($id)) { $script:Selected.Remove($id) } else { $script:Selected[$id]=$true }
        Render-List
    })
    $Window.FindName('Clear').Add_Click({$script:Selected.Clear();Render-List})
    $Window.FindName('Refresh').Add_Click({try {Refresh-UI; if (-not $script:HistoryError -and -not $script:PendingBatch) { $Window.FindName('Status').Text='Đã đọc lại các giá trị hiện tại.' }} catch {Message $_.Exception.Message}})
    $Window.FindName('Preview').Add_Click({
        try {
            $ids=@($script:Features | Where-Object { $script:Selected.ContainsKey($_.Id) } | ForEach-Object Id)
            $registryIds=@($ids | Where-Object {(Get-Feature $_).Kind -eq 'Registry'})
            $rows=@();if ($registryIds.Count) {$rows=@(New-ChangePlan $registryIds)}
            if ($ids -ccontains 'copilotapp') {Start-MainCopilotReview $ids @($rows);return}
            if ($rows.Count -eq 0) {Message 'Các mục đã ở trạng thái yêu cầu. Không có thay đổi mới.';return}
            $sections=@('XEM TRƯỚC — Chưa thay đổi máy.','Lưu trạng thái gốc trước khi ghi; chỉ áp dụng cho tài khoản hiện tại.','')
            $sections+="Đã chọn $($ids.Count) tính năng; cần ghi $($rows.Count) giá trị."
            foreach ($id in $ids) { if ($id -notin $rows.Feature) { $sections+="Giữ nguyên (đã đúng yêu cầu): $((Get-Feature $id).Title)" } }
            foreach ($id in @($rows.Feature | Select-Object -Unique)) {
                $f=Get-Feature $id
                $choice=Get-FeatureChoice $f
                if ($null -ne $choice) {$sections+='Lựa chọn: '+$choice.Title}
                $sections+="$($f.Title)`n$($f.Benefit)`nẢnh hưởng: $($f.Cost)"
                foreach ($row in @($rows | Where-Object Feature -eq $id)) {
                    $old=if ($row.Exists) {[string]$row.Value} else {'chưa có giá trị'}
                    $c=Assert-Row $row
                    $sections+="  $($c.Hive)\$($row.Path)`n  $($row.Name): '$old' → '$($row.Target)' ($($c.Type))"
                }
                $permission=Get-PermissionDescription $f
                if ($permission) {$sections+=$permission}
                $sections+="Hiệu lực: $($f.Timing)`nHoàn tác: $($f.Undo)"
                $sections+=''
            }
            $sections+='Có thể cần đăng xuất rồi đăng nhập lại. Không tự khởi động lại.'
            $sections+="Bản sao lưu: $script:DataRoot"
            if ($script:IsSimulation) { $sections=@('MÔ PHỎNG — chỉ ghi bộ nhớ và nhật ký thử nghiệm. Không ghi registry thật.','')+$sections }
            if (Show-TextDialog 'Xem trước thay đổi' ($sections -join "`r`n") $true) {
                $null=Invoke-ChangePlan $rows
                $script:Selected.Clear(); Render-List
                $Window.FindName('Status').Text='Đã áp dụng và lưu bản sao. Có thể cần đăng xuất rồi đăng nhập lại.'
                Message 'Đã ghi và kiểm tra các giá trị. Bạn có thể hoàn tác từng đợt theo thứ tự từ mới đến cũ.'
            }
        } catch {
            $reason=$_.Exception.Message
            try {Refresh-UI} catch {}
            $recovery=if ($script:PendingBatch) {'Đợt có thể đã ghi một phần. Xem lịch sử để biết từng giá trị, rồi dùng Hoàn tác đợt gần nhất.'} else {'Nếu chưa bắt đầu đợt mới, không có thay đổi nào từ đợt này.'}
            Message "Chưa hoàn tất: $reason`n$recovery"
        }
        finally {try {Refresh-UI} catch {Message $_.Exception.Message}}
    })
    $Window.FindName('Undo').Add_Click({
        try {
            $last=Get-LatestJournal
            if ($null -eq $last) {Message 'Không còn đợt nào để hoàn tác.';return}
            $titles=@($last.Journal.Rows.Feature | Select-Object -Unique | ForEach-Object {(Get-Feature $_).Title}) -join "`n• "
            $undoLines=@("KHÔI PHỤC ĐỢT $($last.Journal.Created)","• $titles",'')
            foreach ($r in $last.Journal.Rows) {
                $c=(Get-Feature $r.Feature).Changes[$r.Index]
                if ($r.PSObject.Properties['State'] -and $r.State -in @('Prepared','Skipped')) { $undoLines+="Không ghi lại $($c.Name): mục chưa được áp dụng."; continue }
                $now=Read-RegistryValue $c
                $current=if ($now.Exists) { [string]$now.Value } else {'chưa có giá trị'}
                $original=if ($r.Exists) { [string]$r.Value } else {'xóa giá trị để trả về trạng thái chưa đặt'}
                $undoLines+="HKCU\$($c.Path)`n$($c.Name): $current → $original"
            }
            $undoLines+='WinTune kiểm tra xung đột trước khi ghi. Không tự khởi động lại hay đóng ứng dụng.'
            if (-not (Show-TextDialog 'Xem trước hoàn tác' ($undoLines -join "`r`n") $true 'Khôi phục các giá trị này')) {return}
            $null=Undo-LatestJournal
            $Window.FindName('Status').Text='Đã hoàn tác. Có thể cần đăng xuất rồi đăng nhập lại.'
            Refresh-UI
        } catch {Message $_.Exception.Message}
    })
    $Window.FindName('History').Add_Click({
        try {
            $lines=@('LỊCH SỬ THAY ĐỔI','')
            foreach ($entry in @(Get-Journals)) {
                $j=$entry.Journal
                $label=switch ($j.Status) {
                    'Applied' {'Đã áp dụng'}
                    'Pending' {'Chưa hoàn tất'}
                    'Undone' {'Đã hoàn tác'}
                    default {'Không rõ'}
                }
                $lines+="$($j.Created) — $label"
                foreach ($id in @($j.Rows.Feature | Select-Object -Unique)) {$lines+='• '+(Get-Feature $id).Title}
                foreach ($r in $j.Rows) {
                    $state=if ($r.PSObject.Properties['State']) { switch ($r.State) {'Applied' {'Đã ghi và xác minh'} 'Failed' {'Ghi lỗi / có thể đã ghi'} 'Skipped' {'Chưa ghi'} 'Writing' {'Bị ngắt khi ghi'} default {'Chưa ghi'} } } else {'Nhật ký v0.2 — không có kết quả từng giá trị'}
                    $c=(Get-Feature $r.Feature).Changes[$r.Index]
                    $lines+="  $($c.Name): $state"
                    if ($r.PSObject.Properties['Error'] -and $r.Error) { $lines+='  Lỗi: '+$r.Error }
                    if ($r.PSObject.Properties['UndoState'] -and $r.UndoState -ne 'None') {
                        $undoLabel=switch ($r.UndoState) {
                            'Restored' {'Đã khôi phục và xác minh'}
                            'Restoring' {'Bị ngắt khi khôi phục'}
                            'Failed' {'Khôi phục lỗi / có thể đã ghi'}
                            default {'Không rõ'}
                        }
                        $lines+='  Phục hồi: '+$undoLabel+' '+$r.UndoError
                    }
                }
                $lines+=''
            }
            if ($lines.Count -eq 2) {$lines+='Chưa có thay đổi nào.'}
            $null=Show-TextDialog 'Lịch sử WinTune VI' ($lines -join "`r`n")
        } catch {Message $_.Exception.Message}
    })
    . "$PSScriptRoot/Profiles.ps1"
    . "$PSScriptRoot/FullTweaks.UI.ps1"
    $Window.FindName('FullFeatures').Add_Click({Open-FullTweaks})
    Initialize-Profiles
    $profileBox=$Window.FindName('Profile')
    foreach ($p in $Profiles) {$entry=New-Object Windows.Controls.ComboBoxItem;$entry.Content=$p.Title;$entry.Tag=$p.Id;$entry.ToolTip=$p.Description;$null=$profileBox.Items.Add($entry)}
    $profileBox.SelectedIndex=0
    $profileBox.Add_SelectionChanged({
        if ($null -eq $profileBox.SelectedItem) {return}
        try {
            Set-MainPage 'Features'
            $ids=@(Get-ProfileSelection $profileBox.SelectedItem.Tag)
            $script:FeatureChoices.Clear();$script:Selected.Clear();foreach ($id in $ids) {$script:Selected[$id]=$true}
            $script:Rendering=$true
            try {$Search.Text='';$Window.FindName('OnlySelected').IsChecked=$false;$Window.FindName('DetailDrawer').Visibility='Collapsed'} finally {$script:Rendering=$false}
            Render-List;Update-Selection
            $profile=($Profiles | Where-Object Id -eq $profileBox.SelectedItem.Tag)[0]
            $Window.FindName('Status').Text=$profile.Title+': '+$script:Selected.Count+' mục đã chuẩn bị. Chưa áp dụng.'
            Update-Selection # Keep a real backup/pending error visible after choosing a profile.
        } catch {Message $_.Exception.Message}
    })
    . "$PSScriptRoot/Tools.Core.ps1"
    . "$PSScriptRoot/Software.UI.ps1"
    . "$PSScriptRoot/Tools.UI.ps1"
    . "$PSScriptRoot/WizTree.UI.ps1"
    Initialize-Tools (Join-Path $script:DataRoot 'tools') ([bool]($script:IsSimulation -or $script:WriteBlocked)) $script:UserId
    foreach ($pair in @(@('Software','Phần mềm'),@('Repair','Sửa lỗi'),@('Power','Tối ưu'))) {
        $button=$Window.FindName($pair[0]);$button.Tag=$pair[1];$button.Add_Click({param($sender,$args) Open-Tools $sender.Tag})
    }
    $Window.FindName('Cleanup').Content='Dung lượng ổ đĩa';$Window.FindName('Cleanup').ToolTip='Tự cài WizTree nếu chưa có, mở ổ C: thật và tự quét để xem tổng dung lượng, đã dùng và còn trống.';$Window.FindName('Cleanup').Add_Click({Open-Storage})
    $Window.FindName('Power').Content='Hiệu năng và pin'
    $Window.FindName('DeviceManager').Add_Click({if ($script:IsSimulation -or $script:WriteBlocked) {Message 'Mô phỏng/chỉ đọc: không mở công cụ hệ thống thật.'} else {Start-Process -FilePath (Join-Path $env:WINDIR 'System32/devmgmt.msc')}})
    . "$PSScriptRoot/Diagnostics.UI.ps1"
    . "$PSScriptRoot/Restore.UI.ps1"
    . "$PSScriptRoot/Logs.UI.ps1"
    $Window.FindName('EventViewer').Add_Click({Open-WindowsLogs})
    $Window.FindName('BackupTools').Add_Click({Open-RestoreCenter 'Create'})
    $Window.FindName('RestoreWindows').Add_Click({Open-RestoreCenter 'Restore'})
    . "$PSScriptRoot/Actions.Core.ps1"
    . "$PSScriptRoot/Actions.UI.ps1"
    . "$PSScriptRoot/Copilot.UI.ps1"
    Initialize-MainCopilot
    $Window.FindName('ManageApps').Add_Click({Open-Management 'Appx'})
    $Window.FindName('ManageStartup').Add_Click({Open-Management 'Startup'})
    . "$PSScriptRoot/Distribution.UI.ps1"
    $Window.FindName('Distribution').Add_Click({Open-DistributionCenter})
    $Window.Add_Closing({param($sender,$eventArgs) if ($null -ne $script:DistributionJob) {$eventArgs.Cancel=$true;$script:DistributionWindow.Activate() | Out-Null;$script:DistributionWindow.FindName('DistributionStatus').Text='Hủy hoặc đợi tác vụ khởi chạy/cập nhật trước khi đóng WinTune.'}})
    Initialize-MonitorUI
    Render-List
    Refresh-UI
    if(-not $SelfTest){Initialize-UnifiedTweaksPage}
    if ($MonitorProbe) { . (Join-Path $PSScriptRoot 'UI.MonitorReadProbe.ps1') }
    elseif ($GuiProbe) { . (Join-Path $PSScriptRoot 'UI.GuiProbe.ps1') }
    elseif ($SelfTest) { . (Join-Path $PSScriptRoot 'UI.SelfTests.ps1') }
    else { if ($Updates) {$Window.Add_ContentRendered({Open-DistributionCenter})}; $null=$Window.ShowDialog() }
} catch {
    $reason=$_.Exception.Message
    $log=Join-Path $PSScriptRoot 'startup-error.log'
    try { $_ | Out-String | Set-Content -LiteralPath $log -Encoding UTF8 } catch { $log='Không ghi được tệp log trong thư mục app' }
    if ($SelfTest -or $GuiProbe) { Write-Output "Khởi động / kiểm thử WPF thất bại: $reason. $log"; exit 1 }
    $null=[Windows.MessageBox]::Show("Không mở được app: $reason`n`nChi tiết: $log",'WinTune VI'); exit 1
}
finally { if (Get-Command Stop-FullTweaksUI -ErrorAction SilentlyContinue) {Stop-FullTweaksUI}; if (Get-Command Stop-DistributionUI -ErrorAction SilentlyContinue) {Stop-DistributionUI}; if (Get-Command Stop-ThemeUI -ErrorAction SilentlyContinue) {Stop-ThemeUI}; if (Get-Command Stop-Monitor -ErrorAction SilentlyContinue) {Stop-Monitor}; $mutex.ReleaseMutex(); $mutex.Dispose() }
