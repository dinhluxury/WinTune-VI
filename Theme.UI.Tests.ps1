$writes=$SimWriteCount;$queueCount=$Selected.Count
$script:TestSystemTheme='Dark';$readerBefore=$ThemeState.SystemReader
$ThemeState.SystemReader={ [pscustomobject]@{Mode=$script:TestSystemTheme;Error=''} }
Set-AppThemeMode System $false
Assert-UI ($Window.FindName('ThemeChoice').Items.Count -eq 3 -and $ThemeState.Effective -eq 'Dark') 'Appearance exposes exactly System, Dark and Light'
$dialog=New-TextDialog 'Kiểm tra giao diện' 'Mô phỏng; không sửa Windows.' $true
$tools=New-ToolsWindow 'Phần mềm';$manager=New-ManagementWindow Appx
$tools.FindName('ToolInput').Text='OBSProject.OBSStudio';$script:ManagerState.Selected['fixture-selected']=$true
($tools.FindName('ToolList').Items | Where-Object {$_.Tag.Id -eq 'wingetinstall'}).IsSelected=$true
foreach ($mode in @('Light','Dark')) {
    $entry=@($Window.FindName('ThemeChoice').Items | Where-Object Tag -eq $mode)[0]
    $Window.FindName('ThemeChoice').SelectedItem=$entry
    $Window.Content.UpdateLayout();$tools.UpdateLayout();$manager.UpdateLayout();$dialog.UpdateLayout()
    $palette=Get-ThemePalette $mode
    Assert-UI ($Window.Background.ToString() -eq ('#FF'+$palette.Window.Substring(1))) "$mode applies to main window immediately"
    Assert-UI ($tools.FindName('ToolInput').Foreground.ToString() -eq ('#FF'+$palette.Text.Substring(1)) -and $manager.FindName('Filter').Foreground.ToString() -eq ('#FF'+$palette.Text.Substring(1))) "$mode recolors open tool and application manager input text"
    Assert-UI ($dialog.Content.Children[1].Foreground.ToString() -eq ('#FF'+$palette.Text.Substring(1)) -and $dialog.Content.Children[0].Children[1].Foreground.ToString() -eq '#FFFFFFFF') "$mode updates an already created preview and keeps accent button readable"
    Assert-UI ((Read-ThemePreference $ThemeState.Path).Mode -eq $mode) "$mode selection persists only in isolated app preferences"
    Set-MainPage Dashboard
    $Window.Width=1180;$Window.Height=800;$Window.Content.Measure([Windows.Size]::new(1164,760));$Window.Content.Arrange([Windows.Rect]::new(0,0,1164,760));$Window.Content.UpdateLayout()
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap 1164,760,96,96,([Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($Window.Content)
    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create((Join-Path $PSScriptRoot ('evidence/theme-'+$mode.ToLowerInvariant()+'.png')))
    try {$encoder.Save($stream)} finally {$stream.Dispose()}
    Save-ManagerRendering $tools ('theme-tools-'+$mode.ToLowerInvariant())
}
Assert-UI ($tools.FindName('ToolInput').Text -eq 'OBSProject.OBSStudio' -and $ManagerState.Selected.ContainsKey('fixture-selected') -and $Selected.Count -eq $queueCount) 'Changing theme preserves pending inputs and selections in every window'
$Window.FindName('ThemeChoice').SelectedIndex=0
$script:TestSystemTheme='Light';Update-SystemAppTheme
Assert-UI ($ThemeState.Effective -eq 'Light') 'System switches open app to light when the system reader changes'
$script:TestSystemTheme='Dark';Update-SystemAppTheme
Assert-UI ($ThemeState.Effective -eq 'Dark') 'System switches back to dark without rebuilding views'
Set-AppThemeMode Light $false;$script:TestSystemTheme='Dark';Update-SystemAppTheme
Assert-UI ($ThemeState.Effective -eq 'Light') 'Explicit light is unaffected by later system changes'
$ThemeState.AutoWatch=$true;Set-AppThemeMode System $false
Assert-UI $ThemeState.Timer.IsEnabled 'System mode activates the app-local preference watcher'
Set-AppThemeMode Dark $false
Assert-UI (-not $ThemeState.Timer.IsEnabled) 'Explicit mode stops the preference watcher'
$ThemeState.AutoWatch=$false
Assert-UI ($SimWriteCount -eq $writes) 'Appearance never changes simulated or native Windows registry'
$dialog.Close();$tools.Close();$manager.Close();$script:ToolsWindow=$null;$script:ManagementWindow=$null
$ThemeState.SystemReader=$readerBefore;Set-AppThemeMode Dark $false;Set-MainPage Features
