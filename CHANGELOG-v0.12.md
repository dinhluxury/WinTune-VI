# WinTune VI 0.12 — bảng RAM cập nhật và sửa nút áp dụng

- Bảng 10 tiến trình dùng RAM nhiều nhất có bộ đọc riêng, chu kỳ mục tiêu
  2 giây. Cập nhật tên/PID/RAM, sắp xếp RAM giảm dần, bỏ tiến trình đã thoát
  và giữ lựa chọn theo PID. Hiển thị giờ lấy mẫu ngay tại bảng.
- Bộ đọc chạy bất đồng bộ, tối đa một tác vụ tiến trình cùng lúc; không chờ
  bộ đếm GPU/ổ đĩa. Tạm dừng khi rời Tổng quan, thu nhỏ hoặc nhấn Tạm dừng;
  giải phóng bộ đọc khi đóng ứng dụng. Mẫu cũ/lỗi được ghi rõ, không giả số 0.
- Sửa lỗi `ui-settings.json` (lựa chọn giao diện) bị đọc thành bản sao lưu
  Windows, gây khóa nút áp dụng sau khi đổi theme. Chỉ loại trừ đúng tên
  file này; vẫn giữ kiểm tra nhật ký bị hỏng, phạm vi và đợt chưa hoàn tất.
  Không xóa file giao diện hoặc bản sao lưu của người dùng.
- Khi có lỗi sao lưu thật, bảng hiện thông báo rõ. Chọn nhanh không che mất
  lý do nút bị khóa; nút bị khóa vẫn có lời giải thích khi rê chuột.

Kiểm thử: 483 assertions (18+82+42+56+16+25+29+23+5+187), PowerShell 5.1
và WPF. Ghi registry/gỡ/cài/dọn/sửa Windows đều dùng provider mô phỏng.
Kiểm tra dispatcher với bộ đọc cảm biến chậm xác minh bảng tiến trình vẫn
cập nhật; kiểm tra tiến trình thoát, RAM đổi thứ tự, lỗi đọc, tạm dừng,
file giao diện cùng thư mục với nhật ký, khởi động lại, áp dụng và hoàn tác.

Đọc Windows thật bằng WPF + runspace, cấm ghi: `evidence/monitor-ui-read-only.json`
ghi các lần cập nhật và các hàng thực đọc; `dashboard-process-live.png`
là ảnh dựng WPF. Đây không phải kiểm thử chuột thật trong máy ảo. Không
thay đổi cấu hình Windows, dừng tiến trình hay áp dụng tối ưu để kiểm thử.

File sửa: Core.ps1, Core.ExtendedTests.ps1, WinTune.ps1, MainWindow.xaml,
UI.SelfTests.ps1, Monitor.Core.ps1, Monitor.UI.ps1, Monitor.Tests.ps1,
Monitor.UI.Tests.ps1, UI.MonitorReadProbe.ps1, Build-Package.ps1,
Package.Check.ps1, README.md, HUONG-DAN.txt, KIEM-THU.md, FEATURE_MATRIX.md,
TIEN-DO.md. Thêm CHANGELOG-v0.12.md; giữ baseline-v0.11 và gói 0.11 cũ.

Giới hạn: RAM là working set, có thể gồm bộ nhớ chia sẻ; không cộng các
hàng để tính tổng RAM. Windows có thể từ chối đọc một số tiến trình hoặc
tiến trình thoát giữa lúc lấy mẫu; bảng báo số mục bỏ qua. Chu kỳ 2 giây
là mục tiêu, có thể chậm hơn khi Windows bận. Không thêm tính năng kết thúc
tiến trình hoặc thay đổi ưu tiên. Các giới hạn/tính năng chưa triển khai
của 0.11 vẫn được ghi tại CHANGELOG-v0.11.md.
