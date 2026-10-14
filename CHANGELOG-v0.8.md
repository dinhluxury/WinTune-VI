# WinTune VI 0.8 — Tối, Sáng và Theo hệ thống

Chọn **Giao diện** ở cuối thanh trái: **Theo hệ thống**, **Tối**, **Sáng**.
Mặc định theo hệ thống. Đổi màu ngay, không dựng lại giao diện hoặc mất lựa
chọn đang chờ. Áp dụng cho Tổng quan, tính năng, quản lý ứng dụng/phần mềm,
hộp xem trước, lịch sử, thông báo, các ô nhập và thanh cuộn.

Lựa chọn lưu riêng ở `%LOCALAPPDATA%\WinTuneVI\v2\ui-settings.json`. Demo
dùng thư mục mô phỏng; kiểm thử dùng thư mục cô lập. Ghi file theo phương
pháp thay thế nguyên tử, báo lỗi khi không lưu được; không sửa registry để
đổi màu của Windows. Tệp lỗi được báo rõ và giữ nguyên cho đến khi người
dùng chọn lại. File này không liên quan nhật ký tối ưu/hoàn tác.

Theo hệ thống đọc **màu dành cho ứng dụng** qua AppsUseLightTheme, phù hợp
khi Windows chọn Custom và màu taskbar khác màu app. Cập nhật trong khoảng
2 giây và khi kích hoạt cửa sổ. Timer chỉ chạy khi chọn Theo hệ thống và
app còn mở; không có service/tác vụ nền riêng. Màu thanh tiêu đề dùng DWM
cho từng cửa sổ WinTune khi Windows hỗ trợ; thất bại không ngăn đổi màu client.

373 assertions đạt: Core18, Extended71, Actions42, Tools56, Worker16,
Monitor20, Theme29, WPF121. Phần theme kiểm tra ba chế độ, lưu/đọc lại,
JSON hỏng, ID sai, ghi bị chặn giữ file cũ, tương phản chữ >=4.5, cập nhật
popup/cửa sổ đang có, giữ input/lựa chọn, theo hệ thống đổi qua reader mock
và bật/tắt watcher. Mọi thao tác thay đổi Windows trong kiểm thử vẫn mock.
Ảnh dựng giao diện tối/sáng và công cụ được kiểm tra trực quan.

Chưa đổi giao diện Windows thật để kiểm thử; theo hệ thống được kiểm tra
bằng reader mock và phép đọc thật riêng. Màu titlebar là best effort theo
DWM/Windows; startup error trước khi WPF mở vẫn là thông báo hệ thống.
Giữ các giới hạn tính năng và monitor ở README/CHANGELOG-v0.7.md.

File mới: Theme.Core.ps1, Theme.UI.ps1, Theme.Native.cs, Theme.Tests.ps1,
Theme.UI.Tests.ps1, Theme.ReadCheck.ps1 và tài liệu này. Sửa MainWindow.xaml,
WinTune.ps1, Monitor.UI.ps1, Actions.UI.ps1, Tools.UI.ps1, UI.SelfTests.ps1,
Actions.UI.Tests.ps1 (ảnh dùng đúng nền), Run-Tests.ps1, Build-Package.ps1,
Package.Check.ps1, README.md, HUONG-DAN.txt, FEATURE_MATRIX.md,
KIEM-THU.md, TIEN-DO.md. Giữ baseline-v0.7; backend Core/Actions/Tools không đổi.

Mã theme viết riêng, không tải dependency hoặc thực thi dữ liệu JSON.
Tham khảo API chính thức, không sao chép bộ triển khai:

- [Microsoft: Dark/Light cho Win32](https://learn.microsoft.com/windows/apps/desktop/modernize/apply-windows-themes)
- [DWM attributes](https://learn.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute)
- [Microsoft PowerToys: đọc AppsUseLightTheme](https://github.com/microsoft/PowerToys/blob/main/src/modules/ZoomIt/ZoomIt/Utility.cpp)
