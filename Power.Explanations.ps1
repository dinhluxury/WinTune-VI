function Get-PowerExplanation([string]$Guid,[string]$Title) {
 $name=$Title;$effect='Chế độ do Windows hoặc hãng máy cung cấp. Tác động tùy thiết lập của chế độ này; WinTune không sửa từng thông số bên trong.'
 switch ($Guid.ToLowerInvariant()) {
  '381b4222-f694-41f0-9685-ff5bb260df2e' {$name='Cân bằng';$effect='Tự cân đối tốc độ xử lý và điện tiêu thụ theo công việc. Phù hợp để dùng hằng ngày.'}
  'a1841308-3541-4fab-bc81-f71556f20b4a' {$name='Tiết kiệm điện / pin';$effect='Ưu tiên giảm điện tiêu thụ, có thể giảm tốc độ xử lý. Hữu ích khi laptop dùng pin hoặc cần máy mát hơn.'}
  '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' {$name='Hiệu năng cao';$effect='Ưu tiên khả năng đáp ứng, có thể dùng nhiều điện, nóng và quạt kêu hơn. Laptop có thể hết pin nhanh hơn; không bảo đảm tăng FPS.'}
  'e9a42b02-d5df-448d-aa00-03f14749eb61' {$name='Hiệu năng tối đa';$effect='Ưu tiên hiệu năng, có thể tăng điện và nhiệt. Thường không cần cho việc hằng ngày; không bảo đảm nhanh hơn chế độ Hiệu năng cao.'}
 }
 return [pscustomobject]@{Name=$name;Effect=$effect;Guid=$Guid}
}
function Format-PowerList($Data) {
 $lines=@('CHẾ ĐỘ HIỆU NĂNG VÀ PIN','')
 foreach ($plan in $Data.Plans) {$info=Get-PowerExplanation $plan.Guid $plan.Title;$lines+=($(if ($plan.Guid -eq $Data.Active) {'ĐANG DÙNG: '} else {'• '})+$info.Name);$lines+=$info.Effect;$lines+=''}
 $lines+='Đây là các bộ thiết lập nguồn có sẵn của Windows (power plan). Chúng có thể quy định hiệu năng, thời gian ngủ và tắt màn hình; khác với thanh chọn Power mode trên một số máy. Chỉ xem danh sách không làm thay đổi máy.'
 return ($lines -join "`n")
}
