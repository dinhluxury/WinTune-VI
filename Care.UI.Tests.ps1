# Actual WPF controls and a strictly simulated repair worker.
Assert-UI ($null -eq $Window.FindName('Power') -and $null -eq $Window.FindName('Distribution')) 'Both removed sidebar sections are absent'
Assert-UI ($null -eq (Get-Command Open-DistributionCenter -ErrorAction SilentlyContinue)) 'Manual app update UI is not loaded'
Assert-UI (@(Get-VisibleTools|Where-Object {$_.Id -in @('powerlist','powerset','powerundo','dismcheck','dismscan')}).Count -eq 0) 'Redundant power controls and duplicate diagnostic scans are not exposed elsewhere'
$repairWrites=$SimWriteCount;$cw=New-CareRepairWindow;$cw.Show();$cw.UpdateLayout()
Assert-UI ($CareState.Buttons.Count -eq 3 -and $null -eq $cw.FindName('ToolGroup') -and -not $cw.FindName('CareTechnical').IsExpanded) 'Repair opens as three guided cards, with technical output closed'
Assert-UI ($cw.FindName('CareResultTitle').Text -eq 'Chưa thực hiện kiểm tra' -and $null -eq $CareState.Job) 'Opening repair performs no repair or fake diagnosis'
$owned=New-TextDialog 'fixture' 'fixture'
Assert-UI ($owned.Owner -eq $cw) 'Confirmation belongs to the visible repair window'
$owned.Close();$script:DialogResponse=$false
$CareState.Buttons[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($null -eq $CareState.Job -and $LastDialogText.Contains('Microsoft') -and $SimWriteCount -eq $repairWrites) 'Cancelled repair starts no worker and explains the selected step'
$script:DialogResponse=$true;Start-CareRepair dismrestore @{MockDelayMs=900}
Assert-UI ($null -ne $CareState.Job -and -not $CareState.Buttons[0].IsEnabled -and $cw.FindName('CareProgress').Visibility -eq 'Visible' -and -not $cw.FindName('CareClose').IsEnabled) 'While repairing, only the progress indication is shown and repeated actions are disabled'
$cw.Close()
Assert-UI ($cw.IsVisible -and $cw.FindName('CareElapsed').Text.Contains('Đợi')) 'Closing cannot abandon an active repair'
$deadline=[DateTime]::UtcNow.AddSeconds(25)
while(-not $CareState.Job.Handled -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 60;Poll-CareRepair}
Assert-UI ($CareState.Job.Handled -and $cw.FindName('CareResultTitle').Text.Contains('mô phỏng') -and $cw.FindName('CareProgress').Visibility -eq 'Collapsed' -and $CareState.Buttons[1].IsEnabled) 'Completed simulated worker produces a plain-language result and restores buttons'
Assert-UI ($cw.FindName('CareRaw').Text.Contains('MÔ PHỎNG') -and -not $cw.FindName('CareTechnical').IsExpanded) 'Native details are available without replacing the understandable summary'
$careFormatter=${function:Get-CareRepairResult}
try {
 function Get-CareRepairResult($Result) {throw 'Injected presentation failure'}
 Start-CareRepair sfc @{}
 $deadline=[DateTime]::UtcNow.AddSeconds(25)
 while(-not $CareState.Job.Handled -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 60;Poll-CareRepair}
 Assert-UI ($CareState.Job.Handled -and $cw.FindName('CareProgress').Visibility -eq 'Collapsed' -and $CareState.Buttons[0].IsEnabled -and $cw.FindName('CareResultTitle').Text -eq 'Chưa đọc được kết quả') 'Presentation failure restores repair controls and never claims successful repair'
} finally {Set-Item Function:Get-CareRepairResult $careFormatter}
$summary=Get-CareRepairResult ([pscustomobject]@{Id='sfc';Mode='Native';Message='fixture';Result=[pscustomobject]@{ExitCode=0;Output='Windows Resource Protection found corrupt files but was unable to fix some of them.'}})
$cw.FindName('CareResultTitle').Text=$summary.Title;$cw.FindName('CareResultBody').Text=$summary.Body;$cw.FindName('CareNext').Text=$summary.Next;Set-ThemeResource $cw.FindName('CareResultTitle') Foreground $summary.Tone
Apply-AppTheme Dark;Save-FullRendering $cw 'repair-simple-dark' 1120 820
Apply-AppTheme Light;Save-FullRendering $cw 'repair-simple-light' 1120 820
Apply-AppTheme Dark;Save-FullRendering $cw 'repair-simple-820' 820 580
Assert-UI ($cw.FindName('CareClose').ActualHeight -ge 20 -and $cw.FindName('CareResultScroll').ActualHeight -gt 100) 'Small layout keeps results scrollable and the close button reachable'
$cw.Close();$script:CareWindow=$null;$script:ToolJob=$null
Assert-UI ($SimWriteCount -eq $repairWrites -and -not $CareState.Timer.IsEnabled) 'Repair testing preserves Windows state and disposes its timer'
