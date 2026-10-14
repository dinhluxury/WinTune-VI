# Read-only event summaries. Known IDs describe observations, never root cause.
function Convert-WindowsEventSummary($Event) {
 $meaning='Windows ghi nhận lỗi từ '+$Event.ProviderName
 $advice='Nếu đang gặp sự cố, xem chi tiết hoặc gửi thông tin này khi tìm hỗ trợ. Không cần thay đổi máy chỉ vì có nhật ký cũ.'
 if ($Event.ProviderName -eq 'Microsoft-Windows-Kernel-Power' -and $Event.Id -eq 41) {$meaning='Máy đã tắt hoặc khởi động lại đột ngột';$advice='Nhật ký không xác định nguyên nhân. Có thể liên quan đến mất điện, máy bị treo hoặc bị tắt cưỡng bức; đối chiếu với lúc sự cố xảy ra.'}
 elseif ($Event.ProviderName -in @('Application Error','.NET Runtime') -and $Event.Id -in @(1000,1026)) {$meaning='Một ứng dụng gặp lỗi';$advice='Xem tên ứng dụng trong chi tiết. Chỉ xử lý nếu lỗi lặp lại hoặc ảnh hưởng công việc; xem hỗ trợ của ứng dụng đó.'}
 elseif ($Event.ProviderName -eq 'Microsoft-Windows-WindowsUpdateClient' -and $Event.Id -eq 20) {$meaning='Một lần cài cập nhật Windows không thành công';$advice='Đối chiếu với Lịch sử cập nhật trong Settings. Lỗi cũ có thể đã được xử lý ở lần cập nhật sau.'}
 [pscustomobject]@{Timestamp=$Event.TimeCreated;Time=$Event.TimeCreated.ToString('dd/MM HH:mm');Level=$(if ($Event.Level -eq 1) {'Nghiêm trọng'} else {'Lỗi'});Meaning=$meaning;Advice=$advice;Provider=$Event.ProviderName;Id=$Event.Id;Log=$Event.LogName;Detail=$Event.Message}
}
function Get-WindowsLogSummary([bool]$Simulation) {
 if ($Simulation) {return [pscustomobject]@{Mode='Simulation';Rows=@();Issues=@();Limited=$false}}
 $rows=@();$issues=@();$limited=$false
 foreach ($log in @('System','Application')) {
  try {
   $events=@(Get-WinEvent -FilterHashtable @{LogName=$log;Level=@(1,2);StartTime=(Get-Date).AddDays(-3)} -MaxEvents 200 -ErrorAction Stop)
   if ($events.Count -eq 200) {$limited=$true}
   foreach ($event in $events) {try {$rows+=Convert-WindowsEventSummary $event} catch {$issues+='Không đọc đủ thông tin một sự kiện trong '+$log}}
  } catch {if ($_.FullyQualifiedErrorId -notmatch '^NoMatchingEventsFound') {$issues+=('Không đọc được '+$log+': '+$_.Exception.Message)}}
 }
 [pscustomobject]@{Mode='Native';Rows=@($rows | Sort-Object Timestamp -Descending);Issues=$issues;Limited=$limited}
}
