# WinTune VI 0.16.2

- Làm lại **Sửa lỗi Windows** thành ba thẻ rõ ràng: **bước 1 — chuẩn bị tệp để sửa Windows**, **bước 2 — kiểm tra và sửa Windows**, **kiểm tra lỗi lưu tệp trên ổ Windows** chỉ khi cần. Không còn danh sách lệnh và menu xổ nhóm trong màn hình này.
- Mỗi việc giải thích khi nên dùng, sẽ làm gì, có cần Internet/quyền quản trị và việc nên làm tiếp. Giữ thao tác DISM RestoreHealth, SFC và chkdsk chỉ đọc; bỏ hai phép kiểm DISM trùng lặp khỏi giao diện.
- Kết quả có tiêu đề dễ hiểu, giải thích và hướng dẫn bước tiếp theo. Phân biệt rõ không thấy lỗi, đã sửa, chưa sửa hết, cần khởi động lại, chưa hoàn tất và thông báo chưa nhận diện. Không kết luận máy đã hết lỗi chỉ từ mã thoát 0 của SFC.
- Thông báo gốc của Windows nằm trong phần có thể mở ra khi cần. Khi đang chạy, hiện thời gian đã chờ, khóa nút chạy lại và không cho đóng cửa sổ giữa bước sửa. Không tự chạy bước kế hoặc khởi động lại.
- **Bỏ hẳn mục Hiệu năng và pin** theo lựa chọn của người dùng. Không còn các nút xem/đổi/hoàn tác chế độ nguồn trong menu công cụ. Các bộ đọc và nhật ký cũ vẫn được giữ tương thích nội bộ.
- **Bỏ phần cập nhật WinTune trong ứng dụng**, gồm nút trên thanh bên và màn hình cập nhật. Lệnh online vẫn kiểm tra bản stable mới nhất, xác minh SHA256/chữ ký và mở app; thư viện xác minh và cơ chế cache không bị gỡ.
- Hướng dẫn ghi rõ phải sao chép toàn bộ dòng `irm https://dinhluxury.github.io/WinTune-VI | iex`. Chỉ nhập `irm` kèm địa chỉ sẽ hiện mã nguồn, chưa thực thi ứng dụng.
- Giữ nguyên trang 111 tùy chỉnh, các bộ chọn 8/19/31 mục, WizTree mở trực tiếp C: và các tính năng khác.

Các kiểm tra sửa Windows dùng mô phỏng. Không chạy sửa Windows thật trên máy đang dùng để kiểm thử.
