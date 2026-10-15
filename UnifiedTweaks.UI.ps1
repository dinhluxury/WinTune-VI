function Initialize-UnifiedTweaksPage {
 if($script:UnifiedTweaksPageActive){return}
 $view=New-FullTweaksWindow -Embedded
 $parent=$script:Window.FindName('FeaturesPage')
 foreach($child in $parent.Children){$child.Visibility='Collapsed'}
 [Windows.Controls.Grid]::SetRowSpan($view,$parent.RowDefinitions.Count)
 $null=$parent.Children.Add($view);$script:UnifiedTweaksView=$view;$script:UnifiedTweaksPageActive=$true
 $script:Window.FindName('FeatureFooter').Visibility='Collapsed'
 Update-UnifiedRecovery
 $script:Window.FindName('Undo').Content='Hoàn tác bản cũ';$script:Window.FindName('Undo').ToolTip='Khôi phục thay đổi đã lưu từ bảng tùy chỉnh cũ. Dùng nút Hoàn tác trong trang để khôi phục thay đổi mới.'
 $script:Window.FindName('History').Content='Lịch sử bản cũ';$script:Window.FindName('History').ToolTip='Các thay đổi từ bảng tùy chỉnh cũ. Lịch sử thay đổi mới nằm trong trang Tùy chỉnh Windows.'
 $view.Add_SizeChanged({param($sender,$eventArgs) $body=$script:FullWindow.FindName('FullBody');$body.ColumnDefinitions[1].Width=[Windows.GridLength]::new($(if($sender.ActualWidth -lt 900){280}else{370}))})
 $script:Window.FindName('Machine').Text=$script:Window.FindName('Machine').Text -replace '• \d+ tùy chỉnh',('• '+($FullCatalog.Count-2)+' tùy chỉnh')
 $script:Window.Add_Closing({param($sender,$eventArgs) if($script:FullJob -and -not $script:FullJob.Process.HasExited){$eventArgs.Cancel=$true;$script:FullWindow.FindName('FullStatus').Text='Đợi thao tác đang chạy hoàn tất trước khi đóng WinTune.'}})
}
function Update-UnifiedRecovery {
 $text=if($script:HistoryError){'Chưa đọc được bản sao lưu cũ. Mở Lịch sử bản cũ trên thanh bên để xem lỗi trước khi áp dụng thêm.'}elseif($script:PendingBatch){'Có đợt thay đổi cũ chưa hoàn tất. Mở Lịch sử bản cũ rồi Hoàn tác bản cũ trước khi áp dụng thêm.'}else{''}
 $control=$script:FullWindow.FindName('FullRecovery');$control.Text=$text;$control.Visibility=if($text){'Visible'}else{'Collapsed'}
}
function Test-FullInteractiveSource($Source,$Row) {
 $node=$Source
 while($node -and $node -ne $Row) {
  if($node -is [Windows.Controls.Primitives.ButtonBase] -or $node -is [Windows.Controls.ComboBox] -or $node -is [Windows.Controls.Primitives.TextBoxBase] -or $node -is [Windows.Documents.Hyperlink]){return $true}
  $node=if($node -is [Windows.Media.Visual] -or $node -is [Windows.Media.Media3D.Visual3D]){[Windows.Media.VisualTreeHelper]::GetParent($node)}else{[Windows.LogicalTreeHelper]::GetParent($node)}
 }
 return $false
}
function Update-FullRowHighlight {
 foreach($row in $script:FullWindow.FindName('FullCards').Children){if($row -is [Windows.Controls.Border]){if($script:FullCurrent -and $row.Tag -ceq $script:FullCurrent.Id){Set-ThemeResource $row BorderBrush Accent}else{Set-ThemeResource $row BorderBrush Border}}}
}
function Set-FullJobBusy([bool]$Busy) {
 foreach($name in @('FullApply','FullUndo','FullInstalled','FullRunOne')){$script:FullWindow.FindName($name).IsEnabled=-not $Busy}
 if($Busy){$script:FullMainControls=@{};foreach($name in @('ManageApps','ManageStartup','Software','Cleanup','Repair','BackupTools','RestoreWindows','Undo','Preview','FullFeatures')){$control=$script:Window.FindName($name);$script:FullMainControls[$name]=$control.IsEnabled;$control.IsEnabled=$false}}
 elseif($script:FullMainControls){foreach($name in $script:FullMainControls.Keys){$script:Window.FindName($name).IsEnabled=$script:FullMainControls[$name]}}
}
function Stop-FullTweaksUI {
 if($script:FullTimer){$script:FullTimer.Stop()}
 if($script:FullWindow){$script:FullWindow.Close()}
}
