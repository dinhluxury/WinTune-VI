# WinTune VI 0.7 — giao diện cài đặt và theo dõi máy

Giữ nguyên 22 tính năng registry, 32 DWORD, ID và dữ liệu phục hồi của 0.6.
Không khởi tạo lại dự án. Workspace chưa có Git; bản trước được giữ ở
`baseline-v0.6`. Không thực thi script upstream hoặc thêm module ngoài.

## Đã thực hiện

- Bố cục Windows Settings: thanh điều hướng, Tổng quan, thẻ bo góc, tông tối
  trung tính và điểm nhấn xanh. Thu gọn kỹ thuật/hoàn tác; giữ tìm kiếm,
  chọn nhóm, hồ sơ, màn hình xác nhận và toàn bộ handler cũ.
- Bốn thẻ CPU, RAM, GPU/VRAM và lưu trữ, chuyển thành hai cột ở cửa sổ nhỏ.
  Đọc lại cấu hình và chi tiết bo mạch/Windows/thanh RAM/driver GPU.
- CPU/RAM/tiến trình/GPU/mạng/tốc độ ổ/dung lượng trống cập nhật qua runspace
  bất đồng bộ. Biểu đồ CPU/RAM 60 mẫu. Mục tiêu 2 giây sau khi bộ đọc xong.
  Danh sách 10 tiến trình có working set lớn nhất; không đóng tiến trình.
- Tạm dừng/tiếp tục; rời trang hoặc thu nhỏ không lấy mẫu mới. Không ghi log
  định kỳ, không tạo worker riêng cho giám sát. Đóng app giải phóng bộ đọc.
- DXGI 64-bit đọc VRAM; thẻ làm tròn GB, tooltip/chi tiết giữ giá trị API.
  Không dùng WMI AdapterRAM 32-bit để suy ra VRAM.
- Bỏ ghi chú Administrator ở tên Bing/Edge, mô tả, xem trước thông thường.
  Guard quyền, UAC worker và lỗi truy cập vẫn giữ. Các công cụ dùng chung
  tông màu; bảo mật/TPM/Secure Boot/thiết bị lỗi vẫn truy cập từ Tổng quan.

## Kiểm tra

328 kiểm tra: Core18, Extended71, Actions42, Tools56, Worker16, Monitor20,
WPF105. Mọi thao tác thay đổi hệ thống dùng mock/mô phỏng. Windows PowerShell
5.1 kiểm tra cú pháp; WPF/XAML dựng được. Bố cục 1280×860, 1024×650, 900×560;
ảnh dựng 100/125/150% được lưu và kiểm tra trực quan.

Kiểm tra thật **chỉ đọc** trên Windows11Pro build26300: nhận i5-14400F,
32GB RAM, RTX5060, ba mẫu CPU/RAM/tiến trình và bộ đếm khác. Trang WPF thật
lấy ba mẫu bất đồng bộ, chọn0 và khóa mọi ghi. Bằng chứng trong
`evidence/monitor-read-only.json`, `monitor-ui-read-only.json`,
`dashboard-native.png`. Đây là đọc và dựng trong app, không phải kiểm thử
desktop bằng chuột. Không thực hiện thao tác gỡ/xóa/tối ưu thật trong lượt này.

## Giới hạn

Chưa thử chạy nhiều giờ, nhiều GPU, ARM64 hoặc nhiều edition/build. Bộ đếm
GPU có thể thiếu/chậm theo driver/WDDM/VM; không giả 0%. Không đo nhiệt/quạt/
điện hoặc xung CPU tức thời. >64 luồng có giới hạn processor group của API.
Working set chứa bộ nhớ chia sẻ. Bộ đếm mạng có thể gồm card ảo; dung lượng
lưu trữ cộng volume Fixed truy cập được, khác dung lượng ổ vật lý quảng cáo.
Cấu hình đọc khi mở/Đọc lại; số liệu hoạt động cập nhật định kỳ. WMI chậm làm
chu kỳ dài hơn; mẫu cũ có thông báo. Demo không giả dữ liệu thật. Theme sáng
chưa triển khai. Giữ giới hạn các chức năng hệ thống từ bản0.6 ở README.

## File thay đổi

`MainWindow.xaml`, `WinTune.ps1`, `features.json`, `Actions.UI.ps1`,
`Tools.UI.ps1`, `UI.SelfTests.ps1`, `Run-Tests.ps1`, `Build-Package.ps1`,
`Package.Check.ps1`, `README.md`, `HUONG-DAN.txt`, `FEATURE_MATRIX.md`,
`KIEM-THU.md`, `TIEN-DO.md`.

Thêm `Monitor.Native.cs`, `Monitor.Core.ps1`, `Monitor.UI.ps1`,
`Monitor.Tests.ps1`, `Monitor.UI.Tests.ps1`, `Monitor.ReadCheck.ps1`,
`UI.MonitorReadProbe.ps1`, tài liệu này và bằng chứng mới trong `evidence`.

## Tham khảo chính thức

Mã bộ đọc viết riêng; tham khảo chữ ký API/định nghĩa dữ liệu:

- [GetSystemTimes](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getsystemtimes)
- [GlobalMemoryStatusEx](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-globalmemorystatusex)
- [DXGI_ADAPTER_DESC1](https://learn.microsoft.com/en-us/windows/win32/api/dxgi/ns-dxgi-dxgi_adapter_desc1)
- [Win32_PhysicalMemory](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-physicalmemory)
- [GPU trong Task Manager](https://devblogs.microsoft.com/directx/gpus-in-the-task-manager/)

Không sao chép bộ triển khai bên thứ ba. Giữ license/commit WinUtil,
Win11Debloat và Microsoft winget-dsc đã ghim ở bản0.6.
