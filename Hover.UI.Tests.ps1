# Controlled in-process template states, no desktop pointer automation.
# IsMouseOver is read-only; a detached template maps that trigger to IsEnabled.
$hoverWriteBaseline=$SimWriteCount
foreach ($mode in @('Dark','Light')) {
    Set-AppThemeMode $mode $false;$palette=Get-ThemePalette $mode
    $hoverWindow=New-Object Windows.Window;$hoverWindow.Resources=$Window.Resources
    Set-ThemeResource $hoverWindow Background Surface;Set-ThemeResource $hoverWindow Foreground Text
    $table=New-Object Windows.Controls.ListView;$table.Background=$Window.Resources['Theme.SurfaceBrush'];$table.BorderThickness=0
    $grid=New-Object Windows.Controls.GridView
    foreach ($pair in @(@('Tiến trình','Name',250),@('PID','Id',80),@('RAM','Memory',120))) {$column=New-Object Windows.Controls.GridViewColumn;$column.Header=$pair[0];$column.Width=$pair[2];$column.DisplayMemberBinding=[Windows.Data.Binding]::new($pair[1]);$null=$grid.Columns.Add($column)}
    $table.View=$grid;$hoverWindow.Content=$table
    $row=New-Object Windows.Controls.ListViewItem;$row.Content=[pscustomobject]@{Name='Tiến trình thử giao diện';Id=1234;Memory='64 MB'};$null=$table.Items.Add($row)
    $table.Measure([Windows.Size]::new(580,130));$table.Arrange([Windows.Rect]::new(0,0,580,130));$table.UpdateLayout();$row.ApplyTemplate() | Out-Null
    $template=$row.Template
    Assert-UI ($null -ne $template.FindName('ProcessRowSurface',$row)) "$mode process rows use app template instead of native pale highlights"
    $originalSurface=$template.FindName('ProcessRowSurface',$row)
    $originalPresenter=[Windows.Media.VisualTreeHelper]::GetChild($originalSurface,0)
    Assert-UI ($originalPresenter.Columns.Count -eq 3 -and $originalPresenter.Content.Name -eq 'Tiến trình thử giao diện') "$mode production row preserves name, PID and memory columns"
    $markup=[Windows.Markup.XamlWriter]::Save($template);$hoverTemplate=[Windows.Markup.XamlReader]::Parse($markup)
    $hover=@($hoverTemplate.Triggers | Where-Object {$_.Property.Name -eq 'IsMouseOver'})[0];$hover.Property=[Windows.UIElement]::IsEnabledProperty
    $row.Template=$hoverTemplate;$row.ApplyTemplate() | Out-Null;$table.UpdateLayout()
    $surface=$hoverTemplate.FindName('ProcessRowSurface',$row)
    # XamlWriter does not retain the live ancestor binding in a detached copy.
    ([Windows.Controls.GridViewRowPresenter][Windows.Media.VisualTreeHelper]::GetChild($surface,0)).Columns=$grid.Columns
    Assert-UI ($surface.Background.ToString() -eq ('#FF'+$palette.Hover.Substring(1)) -and $row.Foreground.ToString() -eq ('#FF'+$palette.Text.Substring(1)) -and $surface.Opacity -eq 1) "$mode hovered row keeps opaque themed background and readable text"
    $row.IsSelected=$true;$table.UpdateLayout()
    Assert-UI ($surface.Background.ToString() -eq ('#FF'+$palette.Selected.Substring(1))) "$mode selection remains readable even with hover active"
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap 580,130,96,96,([Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($table);$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create((Join-Path $PSScriptRoot ('evidence/process-hover-'+$mode.ToLowerInvariant()+'.png')));try {$encoder.Save($stream)} finally {$stream.Dispose()}
    $hoverWindow.Close()
}
Assert-UI ($SimWriteCount -eq $hoverWriteBaseline) 'Hover and selection rendering use no Windows writes'
Set-AppThemeMode Dark $false
