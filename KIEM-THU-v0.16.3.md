# Kiểm tra WinTune VI 0.16.3 — 15/10/2026

Thay đổi chỉ bỏ một vùng thông tin trên trang Tổng quan máy tính và thao tác cập nhật vùng đó.

- Kiểm tra XAML không còn mục xổ xuống hoặc ô MonitorIssues.
- Chạy bộ kiểm tra WPF sẵn có bằng Windows PowerShell 5.1 STA, gồm cập nhật mẫu CPU/RAM/GPU, dữ liệu chưa đọc được, tạm dừng và bố cục Tổng quan ở nhiều kích thước. Các thao tác thay đổi Windows dùng mô phỏng.
- Dựng thử ứng dụng từ ZIP cuối; đối chiếu tài nguyên SHA256, chữ ký manifest và các tệp tải từ GitHub sau phát hành.

Không chạy các lệnh sửa Windows hoặc áp dụng tùy chỉnh thật để kiểm thử thay đổi giao diện này. Phạm vi và giới hạn của bản 0.16.2 được giữ trong KIEM-THU-v0.16.2.md.
