# In-process WPF tests using the isolated provider. No UI Automation or real writes.
$script:UiPass=0
function Assert-UI([bool]$ok,[string]$name) { if (-not $ok) { throw "UI FAILED: $name" }; $script:UiPass++; Write-Output "PASS UI: $name" }
Assert-UI ($IsSimulation -and $Selected.Count -eq 0 -and $SimWriteCount -eq 0) 'Opening selects nothing and uses simulated writes only'
Assert-UI ($List.Items.Count -eq $Features.Count) 'All catalog entries rendered'
foreach ($f in $Features) {
    Show-Detail $f
    Assert-UI ($Window.FindName('DetailTitle').Text -eq $f.Title) "Correct detail for $($f.Id)"
}
$Selected['ads']=$true; $Selected['dvr']=$true
$Search.Text='File Explorer'
Assert-UI ($Selected.Count -eq 2 -and $List.Items.Count -ge 2) 'Filtering preserves selections in other groups'
$Search.Text='không-có-kết-quả-xyz'
Assert-UI ($List.Items.Count -eq 0 -and $null -eq $Current -and -not $Window.FindName('Toggle').IsEnabled) 'Empty search clears obsolete detail'
$Search.Text=''
Assert-UI ($Selected.Count -eq 2) 'Clearing search preserves selected IDs'
$Search.Text='ghi hình'
Assert-UI ($Current.Id -eq 'dvr' -and $Window.FindName('DetailCost').Text.Contains('OBS')) 'Search shows correct Game Bar detail'
$Search.Text='ghi hinh'
Assert-UI ($Current.Id -eq 'dvr') 'Vietnamese search works without accents'
$Search.Text='thoi tiet'
Assert-UI ($Current.Id -eq 'widgets' -and $SimWriteCount -eq 0) 'Weather search opens Widgets details without changing state'
$bing=Get-Feature 'bing'
Assert-UI (-not $bing.Title.Contains('quyền quản trị') -and -not $bing.Title.Contains('Administrator')) 'Bing label has no repetitive administration note'
$script:Build=19045; $Search.Text=''; Render-List
Show-Detail (Get-Feature 'endtask')
Assert-UI (-not $Window.FindName('Toggle').IsEnabled) 'Unsupported feature cannot be added'
Show-Detail (Get-Feature 'widgets')
Assert-UI (-not $Window.FindName('Toggle').IsEnabled) 'Windows 10 cannot queue the Windows 11 Widgets feature'
$script:Build=[int]$cv.CurrentBuild; Render-List
Assert-UI (@($List.Items | Where-Object {$_.Tag.Group -eq 'Quản lý ứng dụng' -or $_.Tag.Kind -eq 'Settings'}).Count -eq 0) 'Tweaks board omits the redundant app-management Settings group'
$plan=@(New-ChangePlan @($Selected.Keys))
Assert-UI ($plan.Count -eq 3 -and $SimWriteCount -eq 0) 'Preview matches selections without writes'
$Selected.Clear(); Render-List
Assert-UI (-not $Window.FindName('Preview').IsEnabled) 'Empty selection disables apply'
$List.SelectedIndex=0
$li=$List.SelectedItem
$check=$li.Content.Children[0]
$check.IsChecked=$true
$check.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($Selected.ContainsKey('ads') -and $Current.Id -eq 'ads') 'Checkbox event queues the clicked item and shows its detail'
$List.SelectedItem=@($List.Items | Where-Object {$_.Tag.Id -eq 'dvr'})[0]
Assert-UI ($Current.Id -eq 'dvr' -and $Selected.Count -eq 1 -and $SimWriteCount -eq 0) 'Selecting a name only opens matching detail'
$Window.FindName('Toggle').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($Selected.ContainsKey('dvr') -and $SimWriteCount -eq 0) 'Detail button queues without applying'
$Window.FindName('Clear').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($Selected.Count -eq 0) 'Clear selection event works'
$script:HistoryError='Injected corrupt history'; $Selected['ads']=$true; Update-Selection
Assert-UI (-not $Window.FindName('Preview').IsEnabled) 'Corrupt history locks apply while browsing remains available'
$script:HistoryError=''; $Selected.Clear(); Render-List
Set-AppThemeMode Dark $true;$Selected['ads']=$true;Refresh-UI
Assert-UI ($Window.FindName('Preview').IsEnabled -and -not $HistoryError -and $Window.FindName('ApplyBlockReason').Visibility -eq 'Collapsed') 'Saving theme then refreshing keeps selected changes applicable'
Assert-UI ((Read-ThemePreference $ThemeState.Path).Mode -eq 'Dark' -and $SimWriteCount -eq 0) 'Theme preference remains saved without system writes'
$badHistory=Join-Path $DataRoot 'invalid-backup.json';[IO.File]::WriteAllText($badHistory,'{');Refresh-UI
$Window.FindName('Profile').SelectedIndex=1
Assert-UI (-not $Window.FindName('Preview').IsEnabled -and $Window.FindName('ApplyBlockReason').Visibility -eq 'Visible' -and $Window.FindName('Status').Text.Contains('không đọc được bản sao lưu')) 'Profile cannot hide genuine backup errors or bypass the disabled apply guard'
Remove-Item -LiteralPath $badHistory;Refresh-UI
Assert-UI ($Window.FindName('Preview').IsEnabled -and -not $HistoryError) 'Removing only the isolated test corruption restores applicability'
$Window.FindName('Profile').SelectedIndex=0;$Selected.Clear();Render-List
Show-Detail (Get-Feature 'dvr')
# Layout at different effective desktop sizes; no change to Windows DPI.
foreach ($size in @(@(1180,800),@(1024,650),@(900,560))) {
    $Window.Width=$size[0]; $Window.Height=$size[1]
    $Window.Content.Measure([Windows.Size]::new($size[0]-16,$size[1]-40)); $Window.Content.Arrange([Windows.Rect]::new(0,0,$size[0]-16,$size[1]-40)); $Window.Content.UpdateLayout()
    Assert-UI ($Window.FindName('Preview').ActualWidth -gt 100 -and $Window.FindName('FeatureList').ActualHeight -gt 120) "Layout available at $($size[0])x$($size[1]) logical pixels"
    Assert-UI ($Window.FindName('Profile').ActualWidth -ge 150 -and $Window.FindName('Search').ActualWidth -ge 200 -and $Window.FindName('ThemeChoice').ActualWidth -ge 150) "Quick selection, search and theme remain usable at $($size[0])x$($size[1])"
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'evidence')) {
        foreach ($scale in @(1.0,1.25,1.5)) {
            $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap ([int](($size[0]-16)*$scale)),([int](($size[1]-40)*$scale)),(96*$scale),(96*$scale),([Windows.Media.PixelFormats]::Pbgra32)
            $bitmap.Render($Window.Content)
            $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
            $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
            $output=Join-Path $PSScriptRoot "evidence/render-$($size[0])x$($size[1])-$([int]($scale*100)).png"
            $stream=[IO.File]::Create($output)
            try { $encoder.Save($stream) } finally { $stream.Dispose() }
        }
    }
}
Assert-UI ($SimWriteCount -eq 0) 'Browsing and layout tests never write'
# Construct the production dialog and verify its controls; handler responses are
# injected below so automated tests never wait for a human or perform real writes.
$dialog=New-TextDialog 'Xem trước thử nghiệm' 'Nội dung tiếng Việt dài để kiểm tra vùng cuộn.' $true
Assert-UI ($dialog.Content.Children[1].IsReadOnly -and $dialog.Content.Children[0].Children.Count -eq 2) 'Preview dialog contains read-only changes, close and apply buttons'
$dialog.Content.Measure([Windows.Size]::new(690,540)); $dialog.Content.Arrange([Windows.Rect]::new(0,0,690,540)); $dialog.Content.UpdateLayout()
Assert-UI ($dialog.Content.Children[1].ActualHeight -gt 100) 'Preview dialog leaves room for scrolling content'
$dialog.Close()
function Message([string]$Text) { $script:LastMessage=$Text; $script:UndoEnabledAtMessage=$Window.FindName('Undo').IsEnabled; $script:PreviewEnabledAtMessage=$Window.FindName('Preview').IsEnabled }
function Show-TextDialog([string]$Title,[string]$Text,[bool]$CanApply=$false,[string]$ActionText='Áp dụng các thay đổi này') {
    $script:LastDialogText=$Text; $script:LastDialogTitle=$Title; return $script:DialogResponse
}
$script:DialogResponse=$false; $script:LastMessage=''
$Selected['ads']=$true; $Selected['dvr']=$true; Update-Selection
$Window.FindName('Preview').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($LastDialogText.Contains('GameDVR_Enabled') -and $LastDialogText.Contains('AppCaptureEnabled') -and $LastDialogText.Contains('HKCU\')) 'Preview handler displays exact selected paths and names'
Assert-UI ($SimWriteCount -eq 0 -and @(Get-Journals).Count -eq 0 -and $Selected.Count -eq 2) 'Cancelling preview writes nothing and retains selection'
$script:DialogResponse=$true
$Window.FindName('Preview').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($SimWriteCount -eq 3 -and $Selected.Count -eq 0 -and (Get-LatestJournal).Journal.Status -eq 'Applied') 'Apply handler writes only simulated selections and clears queue'
$Window.FindName('History').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($LastDialogText.Contains('Đã ghi và xác minh') -and $LastDialogText.Contains('AppCaptureEnabled')) 'History handler displays per-value outcomes'
$Selected['ads']=$true; Update-Selection
$Window.FindName('Preview').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($LastMessage.Contains('Không có thay đổi mới') -and @(Get-Journals).Count -eq 1) 'No-op handler creates no fake batch'
$script:DialogResponse=$false
$Window.FindName('Undo').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($SimWriteCount -eq 3 -and $LastDialogText.Contains('xóa giá trị')) 'Undo preview explains missing originals; cancel does nothing'
$script:DialogResponse=$true
$Window.FindName('Undo').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($Memory.Count -eq 0 -and $null -eq (Get-LatestJournal)) 'Undo handler restores the simulated batch'
$originalWriter=${function:Set-RegistryValue}
function Set-RegistryValue($Change,[bool]$Exists,$Value) {
    if ($Change.Name -eq 'AppCaptureEnabled') { throw 'Injected mid-batch permission loss' }
    & $script:originalWriter $Change $Exists $Value
}
$Selected.Clear(); $Selected['ads']=$true; $Selected['dvr']=$true; Update-Selection
$Window.FindName('Preview').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($UndoEnabledAtMessage -and -not $PreviewEnabledAtMessage) 'Partial failure enables recovery and blocks another batch before the error message'
Assert-UI ($LastMessage.Contains('ghi một phần') -and (Get-LatestJournal).Journal.Status -eq 'Pending') 'Partial failure explains recovery and retains the pending journal'
$partialWrites=$SimWriteCount;$Window.FindName('Profile').SelectedIndex=1
Assert-UI (-not $Window.FindName('Preview').IsEnabled -and $Window.FindName('ApplyBlockReason').Text.Contains('Đợt trước chưa hoàn tất') -and $SimWriteCount -eq $partialWrites) 'Choosing a profile leaves pending recovery visible and does not write another batch'
Set-Item Function:Set-RegistryValue $originalWriter
$Window.FindName('Undo').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($Memory.Count -eq 0 -and $null -eq (Get-LatestJournal)) 'UI recovery restores successful writes after a mid-batch failure'
$Selected.Clear(); $Selected['widgets']=$true; Update-Selection
$script:DialogResponse=$false; $widgetWritesBefore=$SimWriteCount
$Window.FindName('Preview').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($LastDialogText.Contains('TaskbarDa') -and -not $LastDialogText.Contains('AppCaptureEnabled') -and $SimWriteCount -eq $widgetWritesBefore) 'Widgets preview lists only the selected change; cancel performs no write'
$script:DialogResponse=$true
$Window.FindName('Preview').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
$widgetJournal=(Get-LatestJournal).Journal
Assert-UI ($widgetJournal.Rows.Count -eq 1 -and $widgetJournal.Rows[0].Feature -eq 'widgets' -and $Memory.Count -eq 1) 'Widgets GUI apply backs up only its visibility setting'
$Window.FindName('Undo').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($Memory.Count -eq 0 -and $null -eq (Get-LatestJournal)) 'Widgets GUI undo restores its missing original value'
$Window.FindName('Profile').SelectedIndex=0
. "$PSScriptRoot/Actions.UI.Tests.ps1"
. "$PSScriptRoot/Tools.UI.Tests.ps1"
. "$PSScriptRoot/Monitor.UI.Tests.ps1"
. "$PSScriptRoot/Theme.UI.Tests.ps1"
. "$PSScriptRoot/Board.UI.Tests.ps1"
. "$PSScriptRoot/Hover.UI.Tests.ps1"
. "$PSScriptRoot/Usability.UI.Tests.ps1"
. "$PSScriptRoot/Coverage.UI.Tests.ps1"
. "$PSScriptRoot/FullTweaks.UI.Tests.ps1"
. "$PSScriptRoot/Software.Layout.Tests.ps1"
. "$PSScriptRoot/Distribution.UI.Tests.ps1"
. "$PSScriptRoot/UX.UI.Tests.ps1"
. "$PSScriptRoot/Storage.Navigation.Tests.ps1"
. "$PSScriptRoot/UnifiedTweaks.UI.Tests.ps1"
Write-Output "UI SELF TESTS PASSED: $script:UiPass (WPF controls, isolated providers; not a substitute for screen observation)."
$Window.Close()
