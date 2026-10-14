# Real WPF controls with simulated registry/app providers only.
$coverageWrites=$SimWriteCount;$Selected.Clear();$FeatureChoices.Clear();$Search.Text='';Render-List
$item=@($List.Items | Where-Object {$_.Tag.Id -eq 'search'})[0]
$picker=@($item.Content.Children | Where-Object {$_ -is [Windows.Controls.ComboBox]})[0]
$picker.SelectedIndex=3
Assert-UI ($Selected.ContainsKey('search') -and (Get-FeatureChoice (Get-Feature search)).Id -eq 'box' -and $SimWriteCount -eq $coverageWrites) 'Changing inline choice queues only that feature without changing Windows'
$chip=@($Window.FindName('SelectedFeatures').Children | Where-Object Tag -eq 'search')[0]
Assert-UI ($chip.Content.Contains('Ô tìm kiếm') -and $Window.FindName('Technical').Text.Contains("Giá trị yêu cầu: '2'")) 'Pending chip names exact choice and technical detail shows the selected target'
$script:DialogResponse=$false;$Window.FindName('Preview').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($LastDialogText.Contains('Ô tìm kiếm') -and $LastDialogText.Contains("'2'") -and $SimWriteCount -eq $coverageWrites) 'Choice preview lists actual intended value and cancel performs no write'
$script:DialogResponse=$true;$Window.FindName('Preview').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));Set-FeatureChoice search hidden
$Window.FindName('Undo').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($Memory.Count -eq 0) 'GUI undo uses persisted choice after current dropdown choice changes'
$sw=New-ToolsWindow 'Phần mềm'
Assert-UI ($sw.FindName('SoftwareSearch').Foreground.ToString() -eq $Window.Resources['Theme.TextBrush'].ToString() -and $sw.FindName('SoftwareSearch').Background.ToString() -eq $Window.Resources['Theme.InputBrush'].ToString()) 'New software search uses current theme brushes instead of a white dark-mode field'
$sw.FindName('SoftwareSearch').Text='Audacity'
Assert-UI ($sw.FindName('SoftwareSuggestions').Children.Count -eq 1 -and $sw.FindName('SoftwareSuggestions').Children[0].Tag -eq 'Audacity.Audacity') 'Software search finds Audacity in curated catalog'
$box=$sw.FindName('SoftwareSuggestions').Children[0];$box.IsChecked=$true;$box.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
$sw.FindName('SoftwareSearch').Text='';$sw.FindName('SoftwareCategory').SelectedIndex=1
Assert-UI ($ToolsState.Packages.ContainsKey('Audacity.Audacity') -and $sw.FindName('SoftwareSelected').Text.Contains('Audacity') -and -not $sw.FindName('PackageConsent').IsChecked) 'Filtering software retains choices visibly without accepting terms or installing'
Save-ManagerRendering $sw 'software-expanded';$sw.Close();$script:ToolsWindow=$null
$Selected.Clear();$FeatureChoices.Clear();$Search.Text='';Render-List
Assert-UI ($ActionWrites -eq 0) 'Expanded software browsing performs no app removal'
