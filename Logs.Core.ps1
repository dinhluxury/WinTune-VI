# Observed events, grouped by actual subject; never infer a root cause.
function Get-EventFields($Event) {
 $fields=@{}
 try {
  $xml=if ($Event.PSObject.Properties['Xml']) {[xml]$Event.Xml} else {[xml]$Event.ToXml()}
  $index=0;foreach ($data in @($xml.Event.EventData.Data)) {$index++;$name=[string]$data.Name;if (-not $name) {$name='param'+$index};$fields[$name]=[string]$data.'#text'}
 } catch {}
 return $fields
}
function Convert-WindowsEventSummary($Event) {
 $d=Get-EventFields $Event;$target=[string]$Event.ProviderName;$kind='Other';$state='Nhật ký cũ; chưa kiểm tra trạng thái hiện tại'
 $meaning='Windows ghi nhận lỗi từ '+$target+' (mã '+$Event.Id+')'
 $advice='Chưa có cách diễn giải riêng cho sự kiện này. Đọc nội dung gốc bên dưới; khi cần hỗ trợ, gửi tên nguồn, mã và thời điểm. Không tự sửa máy chỉ vì có bản ghi cũ.'
 if ($Event.ProviderName -eq 'Microsoft-Windows-Kernel-Power' -and $Event.Id -eq 41) {
  $kind='Power';$target='Windows';$meaning='Máy đã tắt hoặc khởi động lại đột ngột';$advice='Nhật ký không xác định nguyên nhân. Đối chiếu thời điểm với mất điện, máy treo hoặc tắt cưỡng bức. Nếu lặp lại, kiểm tra nhiệt độ, nguồn điện và lỗi màn hình xanh; mã này không chứng minh bộ nguồn hỏng.'
 } elseif (($Event.ProviderName -eq 'Application Error' -and $Event.Id -eq 1000) -or ($Event.ProviderName -eq '.NET Runtime' -and $Event.Id -eq 1026)) {
  $kind='App';$target=[string]$d.AppName
  if (-not $target -and [string]$Event.Message -match '(?im)^Application:\s*([^\r\n]+)') {$target=$Matches[1].Trim()}
  if (-not $target) {$target='Ứng dụng chưa xác định'} else {$target=[IO.Path]::GetFileName($target)}
  $meaning=$target+' đã bị lỗi hoặc đóng ngoài ý muốn'
  if ($d.ModuleName) {$meaning+='; Windows ghi tại mô-đun '+$d.ModuleName}
  if ($d.ExceptionCode) {$meaning+=' (mã '+$d.ExceptionCode+')'}
  $advice='Nếu ứng dụng đang dùng bình thường, chưa cần sửa Windows. Nếu tiếp tục bị thoát: cập nhật hoặc sửa cài đặt ứng dụng này, ghi lại thao tác gây lỗi và mã bên trên. Mô-đun được ghi nhận chưa chắc là nguyên nhân gốc.'
 } elseif ($Event.ProviderName -eq 'Service Control Manager' -and $Event.Id -in @(7000,7001,7009,7011,7022,7023,7024,7031,7034)) {
  $kind='Service';$target=if ($Event.Id -in @(7009,7011)) {[string]$d.param2} else {[string]$d.param1}
  if (-not $target) {$target='Dịch vụ chưa xác định'}
  $meaning=$target+$(if ($Event.Id -in @(7031,7034)) {' đã dừng ngoài ý muốn'} elseif ($Event.Id -in @(7009,7011,7022)) {' không phản hồi trong thời gian Windows chờ'} else {' không khởi động hoặc kết thúc với lỗi'})
  $code=[string]$d.param2;if ($code -match '^%%(\d+)$') {$reason=switch ($Matches[1]) {'2' {'không tìm thấy tệp'} '5' {'không có quyền truy cập'} '1053' {'quá thời gian chờ'} '1058' {'dịch vụ bị vô hiệu hóa'} '1068' {'dịch vụ phụ thuộc không chạy'} default {'mã Windows '+$Matches[1]}};$meaning+='; Windows báo '+$reason}
  $advice='Đối chiếu với phần mềm sở hữu dịch vụ này. Nếu chức năng liên quan vẫn lỗi, cập nhật hoặc sửa cài đặt phần mềm đó. Không bật tất cả dịch vụ; một số dịch vụ được thiết kế chỉ chạy khi cần.'
 } elseif ($Event.ProviderName -eq 'Microsoft-Windows-WindowsUpdateClient' -and $Event.Id -eq 20) {
  $kind='Update';$target=if ($d.updateTitle) {$d.updateTitle} else {'Windows Update'};$meaning='Chưa cài được '+$target;if ($d.errorCode) {$meaning+=' (mã '+$d.errorCode+')'}
  $advice='Mở Cài đặt → Windows Update → Lịch sử cập nhật. Nếu bản này đã cài thành công ở lần sau, không cần xử lý bản ghi cũ. Nếu vẫn thất bại, dùng mã lỗi bên trên để tìm đúng cách sửa.'
 }
 $time=[datetime]$Event.TimeCreated
 [pscustomobject]@{Timestamp=$time;Time=$time.ToString('dd/MM HH:mm');Level=$(if ($Event.Level -eq 1) {'Nghiêm trọng'} else {'Lỗi'});Kind=$kind;Target=$target;Meaning=$meaning;Advice=$advice;Current=$state;Provider=$Event.ProviderName;Id=$Event.Id;Log=$Event.LogName;Detail=[string]$Event.Message;Count=1}
}
function Group-WindowsEventSummaries([object[]]$Rows,[object[]]$Services=@()) {
 $serviceMap=@{};foreach ($service in $Services) {$serviceMap[[string]$service.Name]=$service;$serviceMap[[string]$service.DisplayName]=$service}
 $result=@()
 foreach ($group in @($Rows | Group-Object -Property Kind,Target,Provider,Id)) {
  $events=@($group.Group | Sort-Object Timestamp -Descending);$row=$events[0].PSObject.Copy();$row.Count=$events.Count
  if ($row.Kind -eq 'Service' -and $serviceMap.ContainsKey($row.Target)) {
   $service=$serviceMap[$row.Target];$row.Current=if ([string]$service.Status -eq 'Running') {'Hiện tại: dịch vụ đã chạy lại'} elseif ([string]$service.Status -eq 'Stopped') {'Hiện tại: đang dừng — có thể là bình thường nếu chỉ chạy khi cần'} else {'Hiện tại: '+[string]$service.Status}
  }
  $row.Detail=@($events | ForEach-Object {$_.Time+' • '+$_.Provider+' • Mã '+$_.Id+"`n"+$_.Detail}) -join "`n`n────────`n`n";$result+=$row
 }
 return @($result | Sort-Object Timestamp -Descending)
}
function Get-WindowsLogSummary([bool]$Simulation) {
 if ($Simulation) {return [pscustomobject]@{Mode='Simulation';Rows=@();Records=0;Issues=@();Limited=$false}}
 $rows=@();$issues=@();$limited=$false
 foreach ($log in @('System','Application')) {
  try {
   $events=@(Get-WinEvent -FilterHashtable @{LogName=$log;Level=@(1,2);StartTime=(Get-Date).AddDays(-3)} -MaxEvents 200 -ErrorAction Stop)
   if ($events.Count -eq 200) {$limited=$true}
   foreach ($event in $events) {try {$rows+=Convert-WindowsEventSummary $event} catch {$issues+='Không đọc đủ thông tin một sự kiện trong '+$log}}
  } catch {if ($_.FullyQualifiedErrorId -notmatch '^NoMatchingEventsFound') {$issues+=('Không đọc được '+$log+': '+$_.Exception.Message)}}
 }
 $services=@();try {$services=@(Get-Service -ErrorAction Stop)} catch {$issues+='Chưa đọc được trạng thái dịch vụ hiện tại.'}
 [pscustomobject]@{Mode='Native';Rows=@(Group-WindowsEventSummaries $rows $services);Records=$rows.Count;Issues=$issues;Limited=$limited}
}
