# Loaded in the WPF SelfTest. No native app removals, registry writes or Store.
function Save-ManagerRendering($W,[string]$Name) {
    Set-ThemeResource $W.Content Background Window
    $W.Content.Measure([Windows.Size]::new(1010,690)); $W.Content.Arrange([Windows.Rect]::new(0,0,1010,690)); $W.Content.UpdateLayout()
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap 1010,690,96,96,([Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($W.Content); $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $PSScriptRoot ('evidence/'+$Name+'.png')))
    try {$encoder.Save($stream)} finally {$stream.Dispose()}
}
$appManager=New-ManagementWindow 'Appx'
Assert-UI ($ActionSimulation -and $ActionWrites -eq 0 -and $ManagerState.Selected.Count -eq 0 -and $ManagerState.Inventory.Count -eq 30) 'App manager opens with zero selections and a fake-only provider'
Save-ManagerRendering $appManager 'app-manager-render'
$appList=$appManager.FindName('Items')
$appChosen=$appList.Items[0].Tag
$appBox=$appList.Items[0].Content.Children[0]; $appBox.IsChecked=$true
$appBox.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($ManagerState.Current.Id -eq $appChosen.Id -and $ManagerState.Selected.Count -eq 1 -and $ActionWrites -eq 0) 'App checkbox updates matching details and queues without removal'
$script:ManagerTypes.SelectedItem='Được bảo vệ'
Assert-UI ($appList.Items.Count -eq 0 -and $ManagerState.Selected.Count -eq 1) 'Classification filter preserves selected apps in another category'
$script:ManagerTypes.SelectedItem='Tất cả'
$appManager.FindName('Filter').Text='no-app-here-xyz'
Assert-UI ($null -eq $ManagerState.Current -and $ManagerState.Selected.Count -eq 1 -and -not $appManager.FindName('Queue').IsEnabled) 'Empty app search clears detail but preserves selected package'
$appManager.FindName('Filter').Text=''
$script:DialogResponse=$false
$appManager.FindName('Review').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($ActionWrites -eq 0 -and @(Get-ActionJournals).Count -eq 0 -and $LastDialogText.Contains($appChosen.Id) -and $LastDialogText.Contains('không được sao lưu')) 'App removal preview lists exact package/data limits and cancel has no effect'
$script:DialogResponse=$true
$appManager.FindName('Review').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($ActionWrites -eq 1 -and $ManagerState.Inventory.Count -eq 29 -and $ManagerState.Selected.Count -eq 0 -and $Memory.Count -eq 0) 'GUI removes only one fake package and never touches registry simulation'
$appManager.FindName('ActionHistory').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($LastDialogText.Contains($appChosen.Id) -and $LastDialogText.Contains('không khôi phục dữ liệu')) 'App history contains exact removed package and honest reinstall limitation'
$reinstallWindow=New-ReinstallChooser
$reinstallItems=$reinstallWindow.Content.Children[1]
$reinstallButton=$reinstallWindow.Content.Children[2]
Assert-UI ($reinstallItems.Items.Count -eq 1 -and $reinstallItems.SelectedItem.Tag -eq $appChosen.StoreId) 'Reinstall chooser points to the selected removed app product'
$reinstallButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($LastMessage.Contains('không mở Store thật')) 'Simulated reinstall never opens Store or claims data restoration'
$reinstallWindow.Close()
$partialApps=@($ManagerState.Inventory | Select-Object -First 3)
foreach ($p in $partialApps) {$ManagerState.Selected[$p.Id]=$true}
$script:ActionFailId=$partialApps[1].Id; $script:ActionFailAfter=$true
Invoke-ManagementReview
Assert-UI ($ManagerState.Inventory.Count -eq 27 -and $ManagerState.Selected.Count -eq 1 -and $ManagerState.Selected.ContainsKey($partialApps[2].Id) -and $LastMessage.Contains('chưa hoàn tất')) 'Partial removal refresh discards vanished selections and keeps the skipped app selected'
$appManager.Close()
$startupManager=New-ManagementWindow 'Startup'
Assert-UI ($ManagerState.Inventory.Count -eq 1 -and $ManagerState.Selected.Count -eq 0 -and $ActionWrites -eq 0) 'Startup manager opens without disabling anything'
Save-ManagerRendering $startupManager 'startup-manager-render'
$script:ManagerState.Selected['Discord']=$true; Update-ManagementSelection
$script:DialogResponse=$false
$startupManager.FindName('Review').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($ActionWrites -eq 0 -and $LastDialogText.Contains('HKCU Run\Discord')) 'Startup preview explains the exact Run entry and cancel does nothing'
$script:DialogResponse=$true
$startupManager.FindName('Review').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($ManagerState.Inventory.Count -eq 0 -and $ActionMemoryStartup.Count -eq 0) 'Startup GUI removes the selected fake entry'
$startupManager.FindName('UndoStartup').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($ManagerState.Inventory.Count -eq 1 -and (Read-StartupExact 'Discord').Command -eq '"C:\Demo\Discord.exe" --startup') 'Startup GUI restores the original fake command'
$startupManager.Close(); $script:ManagerState=$null
