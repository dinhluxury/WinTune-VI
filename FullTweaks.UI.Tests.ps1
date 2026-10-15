# Loaded by UI.SelfTests.ps1 inside the application's isolated WPF context.
function Save-FullRendering($W,[string]$Name,[int]$Width=1260,[int]$Height=820) {
    Set-ThemeResource $W.Content Background Window
    $W.Content.Measure([Windows.Size]::new($Width,$Height));$W.Content.Arrange([Windows.Rect]::new(0,0,$Width,$Height));$W.Content.UpdateLayout()
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap $Width,$Height,96,96,([Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($W.Content)
    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $PSScriptRoot ('evidence/'+$Name+'.png')));try {$encoder.Save($stream)} finally {$stream.Dispose()}
}
$beforeFullWrites=$SimWriteCount
$full=New-FullTweaksWindow
Assert-UI (@($full.FindName('FullCards').Children | Where-Object {$_ -is [Windows.Controls.Border]}).Count -eq ($FullCatalog.Count-2) -and $FullCatalog.Count -ge 110) 'Full board exposes the WinUtil and Win11Debloat screenshot features'
$firstCard=@($full.FindName('FullCards').Children | Where-Object {$_ -is [Windows.Controls.Border]})[0]
Assert-UI ($firstCard.Child.Children[1] -is [Windows.Controls.StackPanel] -and $firstCard.Child.Children[1].Children[0].Text.Contains('lịch sử hoạt động') -and $firstCard.Child.Children.Count -eq 2) 'Feature names render directly as text with no redundant details button'
Assert-UI ('Hiệu năng và chế độ ngủ' -in $FullCatalog.Group -and 'Nguồn điện' -notin $FullCatalog.Group) 'Power settings use the clarified Vietnamese category name'
Assert-UI ($FullMockWrites -eq 0 -and $SimWriteCount -eq $beforeFullWrites) 'Opening full board never applies tweaks'
$full.FindName('FullSearch').Text='duong dan tep dai'
Assert-UI (@($full.FindName('FullCards').Children | Where-Object {$_ -is [Windows.Controls.Border]}).Count -eq 1) 'Full board supports Vietnamese search without accents'
$full.FindName('FullSearch').Text='';$full.FindName('FullGroup').SelectedItem='Mạng'
Assert-UI (@($full.FindName('FullCards').Children | Where-Object {$_ -is [Windows.Controls.Border]}).Count -eq 6) 'Category filter keeps related network choices together'
$full.FindName('FullGroup').SelectedItem='Tất cả'
Set-FullPreset standard
Assert-UI ($FullSelection.Count -eq @(Get-FullPresetRows standard).Count -and $full.FindName('FullChosen').Text.Contains('đường dẫn')) 'Preset lists the actual chosen feature names without applying them'
$full.FindName('FullOnlySelected').IsChecked=$true;Render-FullTweaks
Assert-UI (@($full.FindName('FullCards').Children | Where-Object {$_ -is [Windows.Controls.Border]}).Count -eq @(Get-FullPresetRows standard).Count) 'Only-selected filter is distinct from installed-state selection'
Show-FullDetail (Get-FullFeature WPFTweaksWindowsAI)
Assert-UI ($full.FindName('FullDetailImpact').Text.Contains('Recall') -and $full.FindName('FullSource').Inlines.Count -eq 2) 'AI explanation includes data-loss impact and a labelled clickable source'
Show-FullDetail (Get-FullFeature WPFchangedns)
Assert-UI ($full.FindName('FullDnsOptions').Visibility -eq 'Visible' -and $full.FindName('FullProvider').Items.Count -eq 10 -and $full.FindName('FullAdapter').Items.Count -eq 1) 'DNS requires a named adapter and provider, with a simulated fixture'
Show-FullDetail (Get-FullFeature WPFTweaksDisableBitLocker)
Assert-UI ($full.FindName('FullVolumeOptions').Visibility -eq 'Visible' -and -not $full.FindName('FullAck').IsChecked) 'BitLocker is a separate explicit drive choice with acknowledgement reset'
$full.FindName('FullOnlySelected').IsChecked=$false;$FullSelection.Clear();Render-FullTweaks
Show-FullDetail (Get-FullFeature WPFToggleLongPaths)
$full.FindName('FullGroup').SelectedItem='Tệp và thư mục'
$card=@($full.FindName('FullCards').Children | Where-Object {$_ -is [Windows.Controls.Border] -and $_.Child.Children[0].Tag -eq 'WPFToggleLongPaths'})[0]
$box=$card.Child.Children[0];$box.IsChecked=$true;$box.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($FullSelection.ContainsKey('WPFToggleLongPaths') -and $FullMockWrites -eq 0) 'A checkbox only queues its exact feature'
Show-FullDetail (Get-FullFeature DBExplorerLocation)
$full.FindName('FullChoice').SelectedIndex=2
Assert-UI ($full.FindName('FullChoiceOptions').Visibility -eq 'Visible' -and (Get-FullParameters).Choices['DBExplorerLocation'] -ceq 'ExplorerToDownloads' -and $FullMockWrites -eq 0) 'Dropdown queues an explicit File Explorer destination without applying it'
$FullSelection['DBExplorerLocation']=$true;Render-FullTweaks
Assert-UI ($full.FindName('FullChosen').Text.Contains('Downloads') -and $full.FindName('FullChosen').Text.Contains('Thư mục mở đầu')) 'Chosen list names both the setting and the selected value'
$full.FindName('FullSearch').Text='khong-co';$full.FindName('FullSearch').Text='';Show-FullDetail (Get-FullFeature DBExplorerLocation)
Assert-UI ($full.FindName('FullChoice').SelectedItem.Tag -ceq 'ExplorerToDownloads') 'Filtering and reopening details preserve pending dropdown values'
$FullSelection.Remove('DBExplorerLocation');Show-FullDetail (Get-FullFeature WPFToggleLongPaths)
$full.FindName('FullGroup').SelectedItem='Tất cả';$script:DialogResponse=$false
Start-FullPreview @('WPFToggleLongPaths')
$limit=[DateTime]::UtcNow.AddSeconds(30)
while ($null -ne $script:FullJob -and [DateTime]::UtcNow -lt $limit) {Start-Sleep -Milliseconds 100;Poll-FullJob}
Assert-UI ($null -eq $script:FullJob -and $LastDialogText.Contains('đường dẫn') -and $FullMockWrites -eq 0) 'Asynchronous preview returns exact Vietnamese explanation; cancelling writes nothing'
$full.FindName('FullSearch').Text='';$FullSelection.Clear();Render-FullTweaks
Apply-AppTheme Dark;Save-FullRendering $full 'full-tweaks-dark'
Apply-AppTheme Light;Save-FullRendering $full 'full-tweaks-light'
Apply-AppTheme Dark;Save-FullRendering $full 'full-tweaks-900' 900 560
Assert-UI ($full.FindName('FullScroll').ScrollableHeight -gt 0 -and $full.FindName('FullClose').ActualHeight -ge 20) 'At 900x560 the full list scrolls and bottom actions remain reachable'
Assert-UI ($full.FindName('FullRunOne').ActualHeight -ge 20 -and $full.FindName('FullAck').ActualHeight -ge 20) 'Details keep confirmation and run buttons visible at small sizes'
$full.FindName('FullScroll').ScrollToEnd();$full.UpdateLayout()
Assert-UI ($full.FindName('FullScroll').VerticalOffset -gt 0) 'Scrolling reaches the final features'
Assert-UI ($SimWriteCount -eq $beforeFullWrites -and $ActionWrites -eq 0) 'Full-board browsing preserves existing providers and protection rules'
$full.Close();$script:FullWindow=$null
