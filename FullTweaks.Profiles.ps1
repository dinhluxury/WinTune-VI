function Get-FullProfiles {
 $minimal=@('WPFTweaksConsumerFeatures','DBDisableSuggestions','DBDisableLockscreenTips','DBDisableSettings365Ads','WPFToggleShowExt','WPFToggleBingSearch','WPFTweaksEndTaskOnTaskbar','DBPreventUpdateAutoReboot')
 $standard=$minimal+@('WPFTweaksActivity','WPFTweaksTelemetry','WPFTweaksDeliveryOptimization','DBDisableEdgeAds','WPFToggleStartMenuRecommendations','WPFToggleScrollbars','WPFToggleLongPaths','DBHideDupliDrive','DBExplorerLocation','DBShowTabsInAltTab','WPFToggleGameMode')
 $advanced=$standard+@('WPFTweaksDisableBGapps','WPFTweaksPreventDeviceMetadataFromNetwork','WPFTweaksBraveDebloat','DBDisableDVR','DBDisableClickToDo','DBDisableEdgeAI','DBDisablePaintAI','DBDisableNotepadAI','DBDisableTransparency','DBDisableAnimations','WPFToggleStickyKeys','DBEnableLastActiveClick')
 return @(
  [pscustomobject]@{Id='custom';Title='Tùy chỉnh';Description='Tự chọn các mục và giá trị phù hợp với cách bạn dùng máy.';Ids=@()}
  [pscustomobject]@{Id='minimal';Title='Tối thiểu';Description='Giảm gợi ý, quảng cáo; hiện đuôi tệp và thêm tiện ích cơ bản.';Ids=$minimal}
  [pscustomobject]@{Id='standard';Title='Tiêu chuẩn';Description='Thêm quyền riêng tư, tiện ích Explorer và cách dùng Windows hằng ngày.';Ids=$standard}
  [pscustomobject]@{Id='advanced';Title='Nâng cao';Description='Thêm hạn chế ứng dụng nền, AI và quay màn hình Xbox; giảm hiệu ứng. Đọc kỹ tác động trước khi áp dụng.';Ids=$advanced}
 )
}
function Get-FullPresetRows([string]$Id) {
 $profile=@(Get-FullProfiles | Where-Object Id -CEQ $Id)
 if($profile.Count -ne 1){throw 'Bộ chọn nhanh không hợp lệ.'}
 foreach($key in $profile[0].Ids) {
  $f=Get-FullFeature $key
  if($f.Handler -notin @('Registry','Telemetry') -or $f.Risk){throw ('Mục cần thao tác riêng không được chọn sẵn: '+$key)}
  if($script:FullBuild -lt $f.MinBuild){continue}
  $option='Apply'
  if($f.PSObject.Properties['Choices']) {
   $option=switch($key){'DBExplorerLocation' {'ExplorerToThisPC'} 'DBShowTabsInAltTab' {'HideTabsInAltTab'} default {'On'}}
   $null=Get-FullChanges $f $option
  }
  [pscustomobject]@{Id=$key;Option=$option}
 }
}
function Set-FullPresetLabel([string]$Id) {
 $profile=@(Get-FullProfiles | Where-Object Id -CEQ $Id)[0]
 $script:FullActivePreset=$Id;$script:FullPresetLoading=$true
 try {foreach($item in $script:FullWindow.FindName('FullPreset').Items){if($item.Tag -ceq $Id){$script:FullWindow.FindName('FullPreset').SelectedItem=$item;break}}} finally {$script:FullPresetLoading=$false}
 $script:FullWindow.FindName('FullPresetDescription').Text=$profile.Description+' Chưa áp dụng thay đổi.'
}
function Set-FullCustom {Set-FullPresetLabel 'custom'}
