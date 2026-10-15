# Selection board: existing feature IDs and execution handlers are preserved.
function Update-FeatureBoardWidth {
    $width=$script:List.ActualWidth
    if ($width -le 0) {$width=[Math]::Max(300,$Window.Width-280)}
    $columns=if ($width -ge 960) {3} elseif ($width -ge 600) {2} else {1}
    # Reserve scrollbar/padding and fractional pixels at 125/150% DPI.
    $Window.Resources['FeatureGroupWidth']=[double][Math]::Max(240,[Math]::Floor(($width-24)/$columns)-8)
}
function Update-SelectedFeatureSummary {
    $panel=$Window.FindName('SelectedFeatures');$panel.Children.Clear()
    foreach ($feature in $script:Features) {
        if (-not $script:Selected.ContainsKey($feature.Id)) {continue}
        $choice=Get-FeatureChoice $feature
        $button=New-Object Windows.Controls.Button;$button.Tag=$feature.Id;$button.Content=$feature.Title+$(if ($null -ne $choice) {': '+$choice.Title} else {''})+'  ×';$button.Margin='0,0,6,6';$button.Padding='9,6';$button.FontSize=12
        Set-ThemeResource $button Background Selected
        $button.ToolTip='Bỏ chọn: '+$feature.Title
        $button.Add_Click({param($sender,$args) $script:Selected.Remove([string]$sender.Tag);Render-List})
        $null=$panel.Children.Add($button)
    }
    $Window.FindName('SelectionEmpty').Visibility=if ($script:Selected.Count) {'Collapsed'} else {'Visible'}
    $Window.FindName('SelectionChips').Visibility=if ($script:Selected.Count) {'Visible'} else {'Collapsed'}
    $Window.FindName('ChosenHeading').Text="Đang chọn: $($script:Selected.Count) tính năng"
}
function Open-FeatureDetail($Feature) {
    Show-Detail $Feature
    $Window.FindName('DetailDrawer').Visibility='Visible'
    $Window.FindName('DetailScroll').ScrollToTop()
}
function Get-FeatureInlineHint($Feature) {
    if (-not $Feature.PSObject.Properties['InlineHelp']) {return ''}
    $choice=Get-FeatureChoice $Feature;$value=$Feature.InlineHelp.PSObject.Properties[$choice.Id]
    if ($null -ne $value) {return [string]$value.Value};return ''
}
function Initialize-FeatureBoard {
    if (-not ('WinTune.CompactGroupsPanel' -as [type])) {Add-Type -Path (Join-Path $PSScriptRoot 'CompactGroupsPanel.cs') -ReferencedAssemblies @('PresentationFramework','PresentationCore','WindowsBase','System.Xaml')}
    $factory=[Windows.FrameworkElementFactory]::new([WinTune.CompactGroupsPanel])
    $factory.SetResourceReference([WinTune.CompactGroupsPanel]::ColumnWidthProperty,'FeatureGroupWidth')
    $script:List.GroupStyle[0].Panel=[Windows.Controls.ItemsPanelTemplate]::new($factory)
    $Window.FindName('CloseDetail').Add_Click({$Window.FindName('DetailDrawer').Visibility='Collapsed'})
    $Window.FindName('OnlySelected').Add_Click({$Window.FindName('DetailDrawer').Visibility='Collapsed';Render-List})
    $script:List.Add_SizeChanged({Update-FeatureBoardWidth})
    Update-FeatureBoardWidth
}
