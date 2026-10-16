# Kiểm thử WinTune VI 0.16.4 — 16/10/2026

Kiểm tra Windows PowerShell 5.1 x64 STA trên Windows 11 build 26300.

- Chạy toàn bộ Run-Tests.ps1, gồm engine, native adapters được mock, preset, ứng dụng, worker, phân phối, chữ ký fixture và WPF.
- Thêm hồi quy hoàn tác Registry cùng khóa, đợt bị ngắt, lỗi Explorer, vòng đời worker/UI và dữ liệu kết quả không hợp lệ.
- Kiểm tra ZIP phát hành cuối, chữ ký RSA với khóa gốc, inventory SHA256 và entry PowerShell/CMD tương ứng trước công khai.
- Không sửa Registry, gỡ/cài app hay sửa Windows thật để kiểm thử. Không thực thi launcher Internet bằng Administrator.

Kết quả và giới hạn được cập nhật trong TEST_REPORT.md; chỉ các phép kiểm tra có log mới được ghi PASS. Hiệu lực trên nhiều Windows build, thao tác sửa chữa thật và soak dài hạn cần VM riêng.
