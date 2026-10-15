# In-process WPF integration tests; no real Windows settings are changed.
Initialize-UnifiedTweaksPage;Set-MainPage Features
$full=$script:FullWindow
function Get-UnifiedCard([string]$Id){return @($script:FullWindow.FindName('FullCards').Children | Where-Object {$_ -is [Windows.Controls.Border] -and $_.Tag -ceq $Id})[0]}
function Click-UnifiedRow($Target){$e=[Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice,0,[Windows.Input.MouseButton]::Left);$e.RoutedEvent=[Windows.UIElement]::MouseUpEvent;$Target.RaiseEvent($e)}
$beforeLegacy=$SimWriteCount;$beforeNative=$FullMockWrites
Assert-UI ($UnifiedTweaksPageActive -and $UnifiedTweaksView.Parent -eq $Window.FindName('FeaturesPage')) 'Full feature view is embedded directly in the main page'
Assert-UI (@($full.FindName('FullCards').Children | Where-Object {$_ -is [Windows.Controls.Border]}).Count -eq ($FullCatalog.Count-2) -and $FullSelection.Count -eq 0) 'All available entries are present immediately without a preset or extra window'
Assert-UI ($null -eq $full.FindName('FullAppx') -and $full.FindName('FullClose').Visibility -eq 'Collapsed' -and -not $full.IsVisible -and $Window.FindName('FeatureFooter').Visibility -eq 'Collapsed') 'No duplicate uninstall button, visible secondary window or obsolete footer'
Assert-UI ($full.FindName('FullPreset').Items.Count -eq 4 -and $full.FindName('FullPreset').SelectedItem.Content -ceq 'Tùy chỉnh') 'Custom and three reviewed presets are immediately available'
$card=Get-UnifiedCard WPFTweaksActivity
Click-UnifiedRow $card
Assert-UI ($FullCurrent.Id -ceq 'WPFTweaksActivity' -and $FullSelection.Count -eq 0) 'Clicking row whitespace opens exact details without selecting or applying'
$card=Get-UnifiedCard WPFToggleLongPaths
Click-UnifiedRow $card.Child.Children[1].Children[0]
Assert-UI ($FullCurrent.Id -ceq 'WPFToggleLongPaths') 'Clicking the feature name opens its own details'
$full.FindName('FullPreset').SelectedIndex=2
Assert-UI ($FullActivePreset -ceq 'standard' -and $FullSelection.Count -eq @(Get-FullPresetRows standard).Count -and $FullChoices['WPFToggleLongPaths'] -ceq 'On') 'Preset dropdown queues all compatible standard settings with explicit values'
$card=Get-UnifiedCard DBDisableNotifications;$box=$card.Child.Children[0]
Assert-UI (Test-FullInteractiveSource $box $card) 'Checkbox is excluded from row-detail gestures'
$box.IsChecked=$true;$box.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($FullActivePreset -ceq 'custom' -and $full.FindName('FullPreset').SelectedItem.Content -ceq 'Tùy chỉnh' -and $FullSelection.ContainsKey('DBDisableNotifications') -and $FullSelection.ContainsKey('WPFToggleLongPaths') -and $FullCurrent.Id -ceq 'WPFToggleLongPaths') 'Adding one feature switches to custom while retaining the preset selection and open details'
$full.FindName('FullPreset').SelectedIndex=2
Show-FullDetail (Get-FullFeature WPFToggleLongPaths)
foreach($item in $full.FindName('FullChoice').Items){if($item.Tag -ceq 'Off'){$full.FindName('FullChoice').SelectedItem=$item;break}}
Assert-UI ($FullActivePreset -ceq 'custom' -and $FullChoices['WPFToggleLongPaths'] -ceq 'Off' -and $FullSelection.Count -eq @(Get-FullPresetRows standard).Count) 'Changing only a dropdown value also switches to custom without clearing any checks'
$snapshot=Get-FullParameters;$FullChoices['WPFToggleLongPaths']='On'
Assert-UI ($snapshot.Choices['WPFToggleLongPaths'] -ceq 'Off') 'Pending worker parameters are an independent snapshot'
$full.FindName('FullPreset').SelectedIndex=1
Assert-UI ($FullActivePreset -ceq 'minimal' -and -not $FullChoices.ContainsKey('WPFToggleLongPaths')) 'Choosing another preset replaces stale selections and dropdown values'
$card=Get-UnifiedCard WPFToggleShowExt;$box=$card.Child.Children[0];$box.IsChecked=$false;$box.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($FullActivePreset -ceq 'custom' -and -not $FullSelection.ContainsKey('WPFToggleShowExt')) 'Unchecking a preset item changes the label to custom'
$retained=$FullSelection.Count;$full.FindName('FullSearch').Text='duong dan tep dai';Set-MainPage Dashboard;Set-MainPage Features
Assert-UI ($FullSelection.Count -eq $retained -and $FullActivePreset -ceq 'custom' -and (Get-UnifiedCard WPFToggleLongPaths)) 'Search and navigation preserve custom selection'
Assert-UI ($Window.FindName('FeatureFooter').Visibility -eq 'Collapsed') 'Returning to the page never exposes the legacy apply footer'
$full.FindName('FullSearch').Text='';$script:DialogResponse=$false
$script:PendingBatch=$true;Update-UnifiedRecovery;$blocked=$false
try{Start-FullPreview @('WPFToggleLongPaths')}catch{$blocked=$true}
Assert-UI ($blocked -and $null -eq $FullJob -and $full.FindName('FullRecovery').Visibility -eq 'Visible') 'An unfinished legacy batch remains visible and blocks new writes through the unified page'
$script:PendingBatch=$false;Update-UnifiedRecovery
Start-FullPreview @('WPFToggleLongPaths')
Assert-UI (-not $full.FindName('FullApply').IsEnabled -and -not $Window.FindName('Repair').IsEnabled) 'Preview worker prevents concurrent Windows actions'
$limit=[DateTime]::UtcNow.AddSeconds(30)
while($script:FullJob -and [DateTime]::UtcNow -lt $limit){Start-Sleep -Milliseconds 100;Poll-FullJob}
Assert-UI (-not $script:FullJob -and $full.FindName('FullApply').IsEnabled -and $Window.FindName('Repair').IsEnabled -and $FullMockWrites -eq $beforeNative -and $SimWriteCount -eq $beforeLegacy) 'Cancelling embedded preview writes nothing and restores main actions'
Set-FullPreset minimal;Show-FullDetail (Get-FullFeature WPFToggleShowExt);$full.FindName('FullScroll').ScrollToTop()
Apply-AppTheme Dark;Save-FullRendering $Window 'unified-tweaks-dark' 1480 960
Apply-AppTheme Light;Save-FullRendering $Window 'unified-tweaks-light' 1480 960
Apply-AppTheme Dark;Save-FullRendering $Window 'unified-tweaks-900' 900 620
Assert-UI ($full.FindName('FullScroll').ScrollableHeight -gt 0 -and $full.FindName('FullApply').ActualHeight -ge 20 -and $full.FindName('FullRunOne').ActualHeight -ge 20) 'At small window sizes the full catalog scrolls and preview controls remain reachable'
$full.FindName('FullScroll').ScrollToEnd();$Window.UpdateLayout()
Assert-UI ($full.FindName('FullScroll').VerticalOffset -gt 0 -and $full.FindName('FullBody').ColumnDefinitions[1].ActualWidth -le 280) 'Compact layout keeps a narrower detail panel and reaches the last entries'
$full.FindName('FullScroll').ScrollToTop();$script:DialogResponse=$true
