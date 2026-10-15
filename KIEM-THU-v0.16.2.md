# Kiểm tra WinTune VI 0.16.2 — 15/10/2026

Chạy Windows PowerShell 5.1 STA và WPF. Thao tác sửa Windows được mô phỏng; không dùng kết quả kiểm thử để kết luận Windows thật đã được sửa.

- **Kết luận sửa lỗi:** 13 kiểm tra với dữ liệu mẫu, gồm DISM xong, SFC không thấy lỗi/đã sửa/chưa sửa hết, thông báo không nhận diện, mã lỗi, yêu cầu khởi động lại và worker chưa trả kết quả. Kết luận luôn kèm việc nên làm tiếp.
- **WPF sửa lỗi:** ba thẻ đúng thứ tự; mở cửa sổ chưa chạy gì; hủy xác nhận không tạo worker; xác nhận chạy đúng một bước trong mô phỏng; khóa bấm lặp; không cho đóng giữa bước sửa; hoàn tất mở lại nút; chi tiết gốc mặc định đóng; đóng cửa sổ dừng timer.
- **Bố cục:** dựng và xem giao diện sáng/tối ở 1120×820 và cửa sổ nhỏ 820×580. Thẻ và kết quả có thanh cuộn, nút đóng còn truy cập được.
- **Loại bỏ giao diện:** không còn nút Hiệu năng và pin hoặc Cập nhật WinTune trên thanh bên; không tải giao diện cập nhật vào app; danh sách công cụ không lộ các nút đổi chế độ nguồn hoặc hai phép quét DISM dư thừa.
- **Hồi quy:** Run-Tests.ps1 hoàn tất; 298 kiểm tra giao diện WPF đạt. Gồm engine tùy chỉnh, bộ chọn, nguồn dữ liệu, worker, ứng dụng, phần mềm, theo dõi máy, màu giao diện, chữ ký và các launcher. Phần xác minh/tải mới nhất khi mở online vẫn được kiểm tra riêng.
- **Gói phát hành:** kiểm SHA256 từng tài nguyên, chữ ký manifest và thử dựng cửa sổ từ ZIP cuối. Không đưa nhật ký riêng, thư mục evidence hoặc khóa ký riêng lên public.

Application Control trên máy kiểm tra chặn bài thử EXE tự biên dịch; không thay chính sách để vượt chặn. Lối mở PowerShell/WPF được kiểm tra riêng. Kiểm thử mô phỏng không chứng minh mọi lệnh sửa được mọi sự cố trên mọi máy.

Luồng bước 1 rồi bước 2 tham khảo [hướng dẫn System File Checker của Microsoft](https://support.microsoft.com/en-us/windows/experience/backup-recovery/using-system-file-checker-in-windows). WinTune yêu cầu người dùng xác nhận riêng mỗi bước và không tự khởi động lại.
