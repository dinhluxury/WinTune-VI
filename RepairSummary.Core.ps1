# Unknown/localized messages stay inconclusive. Exit 0 alone is not SFC health.
function Get-RepairConclusion($Result) {
 if ($Result.PSObject.Properties['Mode'] -and $Result.Mode -eq 'Simulation') {return 'MÔ PHỎNG — đã thử quy trình, chưa kiểm tra hoặc sửa Windows thật.'}
 if (-not $Result.PSObject.Properties['Result'] -or $null -eq $Result.Result) {return 'Chưa kiểm tra xong. '+$Result.Message}
 $r=$Result.Result
 if (-not $r.PSObject.Properties['ExitCode']) {return 'Chưa đủ thông tin để kết luận.'}
 $code=[int]$r.ExitCode;$output=[string]$r.Output
 if ($code -notin @(0,3010)) {return "Chưa kiểm tra hoặc sửa xong (mã $code). Xem chi tiết; không kết luận hệ thống đã ổn."}
 switch ($Result.Id) {
  'diskcheck' {return 'Không phát hiện lỗi hệ tệp trong lần kiểm tra này (mã 0). Đây là kiểm tra chỉ đọc khi ổ đang dùng, không đánh giá toàn bộ sức khỏe ổ cứng.'}
  'sfc' {
   if ($output -match 'did not find any integrity violations') {return 'Không phát hiện lỗi trong các file hệ thống được SFC kiểm tra.'}
   if ($output -match 'found corrupt files and successfully repaired') {return 'Windows báo đã sửa được file hệ thống bị lỗi. Kiểm tra lại sự cố thực tế; kết quả này không chứng minh mọi ứng dụng đều đã ổn.'}
   if ($output -match 'unable to fix some') {return 'Có file hệ thống bị lỗi và SFC chưa sửa được hết. Xem chi tiết và tài liệu Microsoft trước khi chọn bước sửa tiếp theo.'}
  }
  {$_ -in @('dismcheck','dismscan')} {
   if ($output -match 'No component store corruption detected') {return 'Windows không phát hiện lỗi kho thành phần theo phép kiểm tra đã chọn. Kiểm tra nhanh chỉ đọc trạng thái đã ghi nhận; Quét kỹ kiểm tra sâu hơn.'}
   if ($output -match 'component store is repairable') {return 'Windows phát hiện lỗi kho thành phần và báo có thể sửa. Chọn Khôi phục thành phần Windows (DISM) riêng nếu muốn sửa, rồi xác nhận.'}
   if ($output -match 'component store cannot be repaired') {return 'Windows báo kho thành phần có lỗi không sửa được bằng phép này. Xem tài liệu Microsoft; WinTune không tự cài lại Windows.'}
  }
  'dismrestore' {if ($output -match 'restore operation completed successfully') {return 'Windows báo đã hoàn thành khôi phục kho thành phần. Kiểm tra lại sự cố thực tế; WinTune không tự khởi động lại.'}}
 }
 return "Lệnh đã kết thúc (mã $code) nhưng thông báo chưa đủ để kết luận rõ. Có thể Windows dùng ngôn ngữ khác; xem chi tiết hoặc tài liệu Microsoft."
}
