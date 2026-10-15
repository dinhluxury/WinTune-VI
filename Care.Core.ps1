# Plain-language presentation of the fixed Windows repair operations.
function Get-CareRepairSteps {
 @(
  [pscustomobject]@{Id='dismrestore';Number='1';Title='Chuẩn bị tệp để sửa Windows';When='Làm bước này trước khi Windows thường báo lỗi, thiếu tệp hoặc cập nhật gặp trục trặc.';Action='Nhờ Windows kiểm tra và sửa bộ tệp dùng để khôi phục hệ thống. Có thể tải tệp cần thiết từ Microsoft.';Note='Cần Internet khi Windows phải tải tệp. Có thể mất nhiều phút. Xong bước này, làm tiếp bước 2.';Button='Bắt đầu bước 1'}
  [pscustomobject]@{Id='sfc';Number='2';Title='Kiểm tra và sửa Windows';When='Làm sau bước 1 để tìm những tệp Windows bị thiếu hoặc bị thay đổi.';Action='Dùng bộ tệp đã kiểm tra ở bước 1 để kiểm tra các tệp Windows đang dùng và thay tệp hỏng nếu sửa được.';Note='Có thể mất nhiều phút. Không xóa tài liệu cá nhân. Kết quả sẽ nói rõ có tìm thấy lỗi và có sửa được không.';Button='Bắt đầu bước 2'}
  [pscustomobject]@{Id='diskcheck';Number='?';Title='Kiểm tra lỗi lưu tệp trên ổ Windows';When='Dùng thêm khi gặp lỗi mở, chép hoặc lưu tệp trên ổ cài Windows.';Action='Kiểm tra cách Windows quản lý tệp trên ổ đĩa. Lần kiểm tra này chỉ đọc, không sửa hoặc xóa tệp.';Note='Không kiểm tra được toàn bộ tình trạng phần cứng ổ đĩa. Nếu ổ có dấu hiệu hỏng, sao lưu tệp quan trọng trước.';Button='Kiểm tra ổ Windows'}
 )
}
function Get-CareRepairResult($Result) {
 $title='Chưa hoàn tất';$body='Chưa nhận được kết quả kiểm tra.';$next='Đọc thông báo bên dưới rồi thử lại khi đã xử lý nguyên nhân.';$tone='Warning'
 if($Result.PSObject.Properties['Mode'] -and $Result.Mode -eq 'Simulation'){return [pscustomobject]@{Title='Đây là kết quả mô phỏng';Body='Quy trình đã chạy thử; Windows thật chưa được kiểm tra hay sửa.';Next='Mở bản chạy bình thường khi bạn muốn thực hiện trên máy.';Tone='Accent'}}
 $native=if($Result.PSObject.Properties['Result']){$Result.Result}else{$null}
 if($null -eq $native -or -not $native.PSObject.Properties['ExitCode']){$body=$Result.Message}
 else {
  $code=[int]$native.ExitCode;$output=[string]$native.Output
  if($code -notin @(0,3010)){$body='Windows chưa thực hiện xong yêu cầu này.';$next='Xem thông báo chi tiết để biết bước bị chặn. Với bước 1, kiểm tra kết nối Internet trước khi thử lại.'}
  elseif($code -eq 3010){$title='Windows yêu cầu khởi động lại';$body='Bước này đã kết thúc nhưng Windows cần khởi động lại để hoàn tất.';$next='Lưu công việc rồi tự khởi động lại máy. WinTune không tự khởi động lại.'}
  elseif($Result.Id -eq 'dismrestore' -and $output -match 'restore operation completed successfully'){$title='Đã hoàn tất bước 1';$body='Windows báo đã sửa xong bộ tệp khôi phục.';$next='Tiếp tục bước 2 để kiểm tra các tệp hệ thống đang dùng.';$tone='Accent'}
  elseif($Result.Id -eq 'sfc' -and $output -match 'did not find any integrity violations'){$title='Không tìm thấy tệp hệ thống bị lỗi';$body='Các tệp Windows trong lần kiểm tra này không có lỗi được phát hiện.';$next='Nếu sự cố vẫn còn, có thể nó nằm ở ứng dụng, thiết bị hoặc phần khác. Kết quả này không xác nhận toàn bộ máy đã hết lỗi.';$tone='Accent'}
  elseif($Result.Id -eq 'sfc' -and $output -match 'found corrupt files and successfully repaired'){$title='Đã sửa được tệp hệ thống bị lỗi';$body='Windows báo tìm thấy tệp hỏng và đã sửa được.';$next='Mở lại ứng dụng hoặc thao tác từng gặp lỗi để kiểm tra. Nếu Windows yêu cầu, lưu công việc rồi khởi động lại.';$tone='Accent'}
  elseif($Result.Id -eq 'sfc' -and $output -match 'unable to fix some'){$title='Còn tệp chưa sửa được';$body='Windows tìm thấy tệp bị lỗi nhưng chưa sửa được hết.';$next='Nếu chưa làm bước 1, thực hiện bước 1 rồi chạy lại bước 2. Nếu vẫn lỗi, giữ thông báo chi tiết để nhờ hỗ trợ.'}
  elseif($Result.Id -eq 'diskcheck'){$title='Lần kiểm tra này không báo lỗi lưu tệp';$body='Windows kết thúc kiểm tra ổ đang dùng và trả về kết quả không có lỗi (mã 0).';$next='Không cần chạy sửa ổ từ đây. Kết quả chỉ đọc này không chứng minh phần cứng ổ đĩa còn tốt.';$tone='Accent'}
  else{$title='Đã chạy xong, cần đọc thông báo';$body='WinTune chưa nhận diện được thông báo của Windows, nên chưa thể nói đã sửa được hay chưa.';$next='Mở Thông báo gốc bên dưới. Không cần chạy lặp lại chỉ vì chưa có kết luận.'}
 }
 [pscustomobject]@{Title=$title;Body=$body;Next=$next;Tone=$tone}
}
