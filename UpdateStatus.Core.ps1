# Compare the running version separately from any newer package already prepared.
function Get-WinTuneUpdateStatus($Info,[string]$RunningVersion) {
 if ($Info.Status -notin @('Available','Current')) {throw 'Chưa có kết quả kiểm tra bản phát hành hợp lệ.'}
 foreach ($value in @($RunningVersion,[string]$Info.Manifest.Version,[string]$Info.CurrentVersion)) {if ($value -notmatch '^\d{1,4}\.\d{1,4}\.\d{1,4}$') {throw 'Kết quả kiểm tra có số phiên bản không hợp lệ.'}}
 $latest=[version]$Info.Manifest.Version;$running=[version]$RunningVersion;$prepared=[version]$Info.CurrentVersion
 $state='Available';$title='Có bản cập nhật '+$latest;$detail='Bấm Cập nhật để tải bản mới. WinTune kiểm tra bản tải trước khi sử dụng.';$download=$true
 if ($running -gt $latest) {$state='Ahead';$title='Bản đang dùng mới hơn bản phát hành';$detail='Bạn đang dùng '+$running+'; bản stable trên GitHub là '+$latest+'. Không cần tải bản cũ hơn.';$download=$false}
 elseif ($running -eq $latest) {$state='Latest';$title='Bạn đang dùng bản mới nhất';$detail='Phiên bản '+$running+' trùng với bản stable mới nhất đã xác minh trên GitHub.';$download=$false}
 elseif ($prepared -ge $latest) {$state='Ready';$title='Bản cập nhật đã sẵn sàng';$detail='Đang chạy '+$running+'; bản '+$prepared+' đã được tải và xác minh. Đóng WinTune hiện tại, rồi mở Mo-WinTune.cmd trong thư mục bản mới.';$download=$false}
 return [pscustomobject]@{State=$state;Title=$title;Detail=$detail;LatestVersion=[string]$latest;CanDownload=$download}
}
