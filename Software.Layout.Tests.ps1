# Render actual WPF cards/resize/preview, all installation handlers mocked.
$sw=New-ToolsWindow 'Phần mềm';$sw.Show();$baselineWrites=$ToolMockWrites
Assert-UI ($sw.FindName('SoftwareSuggestions').Children.Count -eq 17 -and $ToolsState.Packages.Count -eq 0) 'Curated catalog opens with seventeen apps, each unchecked'
foreach ($size in @(@(1180,800),@(1024,650),@(900,580))) {
    $sw.Width=$size[0];$sw.Height=$size[1];$sw.UpdateLayout();Update-SoftwareGrid;$sw.UpdateLayout()
    $cards=@($sw.FindName('SoftwareSuggestions').Children)
    Assert-UI (@($cards | Where-Object {[Math]::Abs($_.ActualWidth-$cards[0].ActualWidth) -gt 0.6 -or [Math]::Abs($_.ActualHeight-104) -gt 0.6}).Count -eq 0) "Software cards have equal width/height at $($size[0])x$($size[1])"
    $button=$sw.FindName('RunTool');$point=$button.TranslatePoint([Windows.Point]::new(0,0),$sw.Content)
    $close=$sw.FindName('ToolsClose');$closePoint=$close.TranslatePoint([Windows.Point]::new(0,0),$sw.Content)
    Assert-UI ($point.Y -ge 0 -and $point.Y+$button.ActualHeight -le $sw.Content.ActualHeight+1 -and $button.IsDescendantOf($sw.FindName('SoftwareActions')) -and $closePoint.Y+$close.ActualHeight -le $sw.Content.ActualHeight+1 -and [Math]::Abs($sw.ActualHeight-$size[1]) -lt 1) "Install, agreement and close footer stay visible at $($size[0])x$($size[1])"
    Assert-UI ($sw.FindName('SoftwareSuggestions').Columns -ge 2 -and $sw.FindName('SoftwareGallery').ScrollableHeight -eq 0) "Card columns respond to width and catalog uses the outer page scroll at $($size[0])x$($size[1])"
}
$box=$sw.FindName('SoftwareSuggestions').Children[0];$box.IsChecked=$true;$box.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
$sw.FindName('SourceConsent').IsChecked=$true;$sw.FindName('PackageConsent').IsChecked=$true;$script:DialogResponse=$false
$sw.FindName('RunTool').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($LastDialogText.Contains('7-Zip') -and -not $LastDialogText.Contains('System.Windows.Controls.StackPanel') -and $null -eq $ToolJob) 'Card installation preview names chosen software and cancellation starts no installer'
$sw.FindName('SoftwareSearch').Text='UniKey'
Assert-UI ($sw.FindName('SoftwareSuggestions').Children.Count -eq 1 -and $sw.FindName('SoftwareSuggestions').Children[0].Content.Children[1].Text.Contains('tiếng Việt')) 'Vietnamese typing app is searchable with a short purpose'
$sw.FindName('SoftwareSearch').Text='';$sw.Width=1024;$sw.Height=800
$ToolsState.Packages.Clear();$sw.FindName('SourceConsent').IsChecked=$false;$sw.FindName('PackageConsent').IsChecked=$false;Render-SoftwareSuggestions
function Save-SoftwareRendering($W,[string]$Name) {
    Set-ThemeResource $W.Content Background Window
    # Capture the entire measured content; the older fixed-size fixture crop
    # omitted the bottom buttons when this window became taller.
    $width=[int][Math]::Ceiling($W.Content.ActualWidth);$height=[int][Math]::Ceiling($W.Content.ActualHeight)
    $visual=New-Object Windows.Media.DrawingVisual;$drawing=$visual.RenderOpen()
    try {
        $rect=[Windows.Rect]::new(0,0,$width,$height)
        $drawing.DrawRectangle($W.Resources['Theme.WindowBrush'],$null,$rect)
        $drawing.DrawRectangle((New-Object Windows.Media.VisualBrush $W.Content),$null,$rect)
    } finally {$drawing.Close()}
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap $width,$height,96,96,([Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($visual)
    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $PSScriptRoot ('evidence/'+$Name+'.png')));try {$encoder.Save($stream)} finally {$stream.Dispose()}
}
foreach ($mode in @('Dark','Light')) {Set-AppThemeMode $mode $false;$sw.UpdateLayout();Update-SoftwareGrid;$sw.UpdateLayout();Save-SoftwareRendering $sw ('software-curated-'+$mode.ToLowerInvariant())}
Assert-UI ($ToolMockWrites -eq $baselineWrites -and $ActionWrites -eq 0) 'Layout tests install/remove nothing and preserve confirmations'
$sw.Close();$script:ToolsWindow=$null;Set-AppThemeMode Dark $false
