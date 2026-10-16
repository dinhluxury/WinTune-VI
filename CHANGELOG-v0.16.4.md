# WinTune VI 0.16.4

Bản vá sau audit và kiểm thử sâu; giữ nguyên tính năng và lệnh mở PowerShell.

- Sửa sao lưu/hoàn tác bố cục Explorer; kiểm tra snapshot trước khi thay đổi.
- Sửa hoàn tác các giá trị trong khóa Registry mới; giữ bảo vệ dữ liệu ngoài WinTune và các đợt chưa khôi phục xong.
- Sửa phục hồi đợt lỗi khi thao tác không thể tự hoàn tác chưa tạo thay đổi.
- Chuyển đọc danh sách ứng dụng và chuẩn bị xem trước sang worker, giữ giao diện phản hồi; quản lý hủy tác vụ đọc, timer, process và đóng cửa sổ.
- Kết quả worker thiếu/hỏng không được báo thành công; giữ thông báo cần khởi động lại sau cài phần mềm.
- Kiểm tra cache bản cài theo manifest có chữ ký và danh sách tệp từ ZIP đã ký; phục hồi mutex sau process bị ngắt.
- Bỏ render trùng lúc mở trang tùy chỉnh. Không tuyên bố giảm RAM; số đo khả dụng và giới hạn trong PERFORMANCE_REPORT.md.

Các thao tác thay đổi Windows được kiểm thử bằng mô phỏng/mock. Xem TEST_REPORT.md và KIEM-THU-v0.16.4.md.
