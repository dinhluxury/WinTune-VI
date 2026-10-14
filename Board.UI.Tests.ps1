$writesBeforeBoard=$SimWriteCount
function Get-BoardGroupVisuals($Visual) {
    if ($Visual -is [Windows.Controls.GroupItem]) {return $Visual}
    for ($i=0;$i -lt [Windows.Media.VisualTreeHelper]::GetChildrenCount($Visual);$i++) {Get-BoardGroupVisuals ([Windows.Media.VisualTreeHelper]::GetChild($Visual,$i))}
}
Set-MainPage Features;$Window.FindName('CloseDetail').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($null -eq $Window.FindName('Categories') -and $null -eq $Window.FindName('MeasureResources') -and -not ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'MainWindow.xaml'))).Contains('Cài đặt theo cách của bạn')) 'Sidebar has no duplicated category list, monitor shortcut or slogan'
Assert-UI ($Window.FindName('Profile').IsDescendantOf($Window.FindName('FeaturesPage')) -and $Window.FindName('Refresh').IsDescendantOf($Window.FindName('FeaturesPage'))) 'Quick selection and state refresh live beside the feature board'
$Window.FindName('OnlySelected').IsChecked=$true;$Search.Text='mo rong'
$Window.FindName('Profile').SelectedIndex=2
Assert-UI (-not $Window.FindName('OnlySelected').IsChecked -and $Search.Text -eq '' -and $List.Items.Count -eq $Features.Count) 'Quick profile clears stale filters so its checked features are visible'
$chips=@($Window.FindName('SelectedFeatures').Children)
Assert-UI ($Selected.Count -eq 10 -and $chips.Count -eq 10 -and @($chips | Where-Object {$_.Tag -eq 'extensions'}).Count -eq 1) 'Standard profile lists all ten selected names, including other categories'
Assert-UI (@($List.Items | Where-Object {$_.Content.Children[0].IsChecked}).Count -eq 10 -and $Window.FindName('DetailDrawer').Visibility -eq 'Collapsed') 'Board checkmarks match prepared profile without covering the board with details'
$Window.FindName('Overview').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($Window.FindName('FeaturesPage').Visibility -eq 'Collapsed' -and $Selected.Count -eq 10) 'Overview navigation hides board controls without losing prepared choices'
$Window.FindName('FeaturesNav').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($Window.FindName('FeaturesPage').Visibility -eq 'Visible' -and $Window.FindName('SelectedFeatures').Children.Count -eq 10) 'Returning to Windows settings shows all pending choices'
$Window.FindName('OnlySelected').IsChecked=$true;$Window.FindName('OnlySelected').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($List.Items.Count -eq 10 -and $List.Items.Groups.Count -ge 2) 'Selected-only board groups pending changes without applying them'
$remove=@($Window.FindName('SelectedFeatures').Children | Where-Object Tag -eq 'ads')[0]
$remove.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI (-not $Selected.ContainsKey('ads') -and $List.Items.Count -eq 9 -and $Window.FindName('SelectedFeatures').Children.Count -eq 9) 'Removing a selection chip updates both board and pending summary'
$Window.FindName('OnlySelected').IsChecked=$false;Render-List
$dvr=@($List.Items | Where-Object {$_.Tag.Id -eq 'dvr'})[0]
$dvr.Content.Children[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($Window.FindName('DetailDrawer').Visibility -eq 'Visible' -and $Current.Id -eq 'dvr' -and $Selected.Count -eq 9) 'Info button opens matching details without selecting or applying its feature'
$Window.FindName('CloseDetail').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($Window.FindName('DetailDrawer').Visibility -eq 'Collapsed') 'Closing details restores the full board'
foreach ($mode in @('Dark','Light')) {
    Set-AppThemeMode $mode $false
    foreach ($width in @(1280,900)) {
        $Window.Width=$width;$Window.Height=860
        $Window.Content.Measure([Windows.Size]::new($width-16,820));$Window.Content.Arrange([Windows.Rect]::new(0,0,$width-16,820));$Window.Content.UpdateLayout();Update-FeatureBoardWidth;$Window.Content.UpdateLayout()
        Assert-UI ($List.Items.Groups.Count -eq @($Features.Group | Select-Object -Unique).Count -and $Window.Resources['FeatureGroupWidth'] -ge 240 -and $List.ActualHeight -gt 200) "$mode grouped board fits $width logical pixels"
        $profileBounds=$Window.FindName('Profile').TransformToAncestor($Window.Content).TransformBounds([Windows.Rect]::new(0,0,$Window.FindName('Profile').ActualWidth,$Window.FindName('Profile').ActualHeight))
        $searchBounds=$Search.TransformToAncestor($Window.Content).TransformBounds([Windows.Rect]::new(0,0,$Search.ActualWidth,$Search.ActualHeight))
        # These layout fixtures are not shown on the desktop, so IsVisible is false
        # through the Window ancestor. Check arranged bounds and direct controls.
        Assert-UI ($searchBounds.Left -gt $profileBounds.Right -and $searchBounds.Right -lt $Window.Content.ActualWidth -and $Window.FindName('Undo').ActualHeight -gt 20 -and $Window.FindName('History').ActualHeight -gt 20 -and $Window.FindName('Undo').Parent -is [Windows.Controls.Grid]) "$mode quick chooser and search do not overlap; undo and history need no expander at $width pixels"
        $groups=@(Get-BoardGroupVisuals $List)
        $first=$groups[0].TransformToAncestor($List).Transform([Windows.Point]::new(0,0));$second=$groups[1].TransformToAncestor($List).Transform([Windows.Point]::new(0,0))
        if ([Math]::Abs($first.Y-$second.Y) -ge 2 -or $second.X -le $first.X) {Write-Output "BOARD LAYOUT: list=$($List.ActualWidth); group=$($Window.Resources['FeatureGroupWidth']); first=$first; second=$second; parent=$([Windows.Media.VisualTreeHelper]::GetParent($groups[0]).ActualWidth)"}
        Assert-UI ([Math]::Abs($first.Y-$second.Y) -lt 2 -and $second.X -gt $first.X) "$mode board puts category cards side by side at $width pixels"
        $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap ($width-16),820,96,96,([Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($Window.Content);$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $stream=[IO.File]::Create((Join-Path $PSScriptRoot "evidence/board-$($mode.ToLowerInvariant())-$width.png"));try {$encoder.Save($stream)} finally {$stream.Dispose()}
    }
}
Assert-UI ($SimWriteCount -eq $writesBeforeBoard) 'Profile board browsing, removing chips and opening details never write Windows'
$Window.FindName('Profile').SelectedIndex=0;$Selected.Clear();Render-List;Set-AppThemeMode Dark $false
