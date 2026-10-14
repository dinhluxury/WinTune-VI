# Local catalog filtering only; no WinGet call or installation when browsing.
function Initialize-SoftwarePicker($Window,$Data) {
    $script:ToolsState | Add-Member -NotePropertyName Software -NotePropertyValue @($Data)
    Set-ThemeResource ($Window.FindName('SoftwareSearch')) Background Input
    Set-ThemeResource ($Window.FindName('SoftwareSearch')) Foreground Text
    $Window.Resources['SoftwareCardStyle']=[Windows.Markup.XamlReader]::Parse(@'
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="CheckBox">
 <Setter Property="Foreground" Value="{DynamicResource Theme.TextBrush}"/><Setter Property="Background" Value="{DynamicResource Theme.SurfaceBrush}"/><Setter Property="HorizontalContentAlignment" Value="Stretch"/><Setter Property="FocusVisualStyle" Value="{x:Null}"/>
 <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="CheckBox"><Border x:Name="Card" Background="{TemplateBinding Background}" BorderBrush="{DynamicResource Theme.InputBrush}" BorderThickness="1" CornerRadius="8" Padding="12"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions><Border x:Name="Mark" Width="18" Height="18" VerticalAlignment="Center" CornerRadius="3" Background="{DynamicResource Theme.InputBrush}" BorderBrush="{DynamicResource Theme.MutedBrush}" BorderThickness="1"><TextBlock x:Name="Tick" Text="✓" Visibility="Collapsed" FontSize="14" FontWeight="Bold" Foreground="{DynamicResource Theme.OnAccentBrush}" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ContentPresenter Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center" HorizontalAlignment="Stretch"/></Grid></Border><ControlTemplate.Triggers><Trigger Property="IsChecked" Value="True"><Setter TargetName="Mark" Property="Background" Value="{DynamicResource Theme.AccentButtonBrush}"/><Setter TargetName="Tick" Property="Visibility" Value="Visible"/><Setter TargetName="Card" Property="BorderBrush" Value="{DynamicResource Theme.AccentBrush}"/></Trigger><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Card" Property="BorderBrush" Value="{DynamicResource Theme.AccentBrush}"/></Trigger><Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter TargetName="Card" Property="BorderThickness" Value="2"/><Setter TargetName="Card" Property="BorderBrush" Value="{DynamicResource Theme.AccentBrush}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
</Style>
'@)
    $Window.FindName('SoftwareGallery').Add_PreviewMouseWheel({param($sender,$eventArgs)
        $atEdge=($eventArgs.Delta -gt 0 -and $sender.VerticalOffset -le 0) -or ($eventArgs.Delta -lt 0 -and $sender.VerticalOffset -ge $sender.ScrollableHeight)
        if ($atEdge) {$outer=$script:ToolsWindow.FindName('ToolSetup');$outer.ScrollToVerticalOffset($outer.VerticalOffset-$eventArgs.Delta/120.0*48);$eventArgs.Handled=$true}
    })
    $category=$Window.FindName('SoftwareCategory')
    foreach ($label in @('Tất cả','Hằng ngày','Chơi game & trò chuyện','Livestream & nội dung','Công việc & tiện ích')) {$null=$category.Items.Add($label)}
    $category.SelectedIndex=0
    $Window.FindName('SoftwareSearch').Add_TextChanged({Render-SoftwareSuggestions})
    $category.Add_SelectionChanged({Render-SoftwareSuggestions})
    $Window.FindName('SoftwareGallery').Add_SizeChanged({Update-SoftwareGrid})
    Render-SoftwareSuggestions
}
function Update-SoftwareSelection {
    $w=$script:ToolsWindow;$names=@($ToolsState.Software | Where-Object {$ToolsState.Packages.ContainsKey($_.Id)} | Select-Object -ExpandProperty Title)
    $w.FindName('SoftwareSelected').Text=if ($names.Count) {'Đang chọn '+$names.Count+': '+($names -join ', ')} else {'Chưa chọn ứng dụng nào.'}
}
function Render-SoftwareSuggestions {
    $w=$script:ToolsWindow
    if ($null -eq $w -or -not $ToolsState.PSObject.Properties['Software']) {return}
    $panel=$w.FindName('SoftwareSuggestions');$panel.Children.Clear()
    $query=$w.FindName('SoftwareSearch').Text.Trim();$category=[string]$w.FindName('SoftwareCategory').SelectedItem
    foreach ($p in $ToolsState.Software) {
        if ($query) {if ((Search-Text ($p.Title+' '+$p.Id)).IndexOf((Search-Text $query),[StringComparison]::OrdinalIgnoreCase) -lt 0) {continue}}
        elseif ($category -ne 'Tất cả' -and $p.Group -ne $category) {continue}
        if ($p.Id -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]{2,127}$') {throw 'Danh mục phần mềm không hợp lệ.'}
        $box=New-Object Windows.Controls.CheckBox;$box.Tag=$p.Id;$box.Style=$w.Resources['SoftwareCardStyle']
        $labels=New-Object Windows.Controls.StackPanel
        $title=New-Object Windows.Controls.TextBlock;$title.Text=$p.Title;$title.FontSize=14;$title.FontWeight='SemiBold';$title.TextWrapping='Wrap';Set-ThemeResource $title Foreground Text
        $description=New-Object Windows.Controls.TextBlock;$description.Text=$p.Description;$description.FontSize=12;$description.TextWrapping='Wrap';$description.Margin='0,6,0,0';Set-ThemeResource $description Foreground Muted
        $null=$labels.Children.Add($title);$null=$labels.Children.Add($description);$box.Content=$labels
        [Windows.Automation.AutomationProperties]::SetName($box,$p.Title)
        Set-ThemeResource $box Foreground Text
        $box.Margin='5,5,5,5';$box.Height=104;$box.FontSize=14;$box.HorizontalContentAlignment='Stretch'
        $box.IsChecked=$ToolsState.Packages.ContainsKey($p.Id);$box.ToolTip=$p.Id+' • '+$p.Group
        $box.Add_Click({param($sender,$eventArgs)
            if ($sender.IsChecked) {$script:ToolsState.Packages[$sender.Tag]=$true} else {$script:ToolsState.Packages.Remove($sender.Tag)}
            $script:ToolsWindow.FindName('PackageConsent').IsChecked=$false;$script:ToolsWindow.FindName('SilentConsent').IsChecked=$false
            Update-SoftwareSelection
        })
        $null=$panel.Children.Add($box)
    }
    Update-SoftwareSelection
    Update-SoftwareGrid
}
function Update-SoftwareGrid {
    $w=$script:ToolsWindow;if ($null -eq $w) {return}
    $width=$w.FindName('SoftwareGallery').ActualWidth
    $w.FindName('SoftwareSuggestions').Columns=[Math]::Max(1,[Math]::Min(4,[Math]::Floor(($width-18)/250)))
}
function Pin-SoftwareActions($Window) {
    # Put confirmation/install below the scrollable catalog, always reachable.
    $root=[Windows.Controls.Grid]$Window.Content
    $row=New-Object Windows.Controls.RowDefinition;$row.Height='Auto';$root.RowDefinitions.Insert(3,$row)
    foreach ($child in $root.Children) {if ([Windows.Controls.Grid]::GetRow($child) -ge 3) {[Windows.Controls.Grid]::SetRow($child,[Windows.Controls.Grid]::GetRow($child)+1)}}
    $footer=New-Object Windows.Controls.StackPanel;$footer.Name='SoftwareActions';$footer.Margin='0,10,0,0';$Window.RegisterName('SoftwareActions',$footer)
    foreach ($name in @('SourceConsent','PackageConsent','RunTool')) {$control=$Window.FindName($name);$parent=[Windows.Controls.Panel]$control.Parent;$parent.Children.Remove($control);$null=$footer.Children.Add($control)}
    $run=$Window.FindName('RunTool');$run.Margin='0,10,0,0'
    [Windows.Controls.Grid]::SetRow($footer,3);$null=$root.Children.Add($footer)
    $Window.FindName('SoftwareGallery').MaxHeight=[double]::PositiveInfinity;$Window.FindName('SoftwareGallery').VerticalScrollBarVisibility='Disabled'
}
