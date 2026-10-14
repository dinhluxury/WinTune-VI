# WinTune VI 0.13 — bổ sung có chọn lọc WinUtil và Win11Debloat

Đọc lại HEAD qua GitHub API ngày14/10/2026: hai commit không đổi so với
snapshot đang có. Đối chiếu100 cấu hình WinUtil và104 mục Win11Debloat;
FEATURE_MATRIX.md và feature-coverage.json ghi từng mục giữ/chờ kiểm chứng/
loại bỏ. Sửa các liên kết nguồn và các trạng thái lỗi thời của báo cáo cũ.
Giữ phạm vi đã được người dùng xác nhận: bổ sung tính năng hữu ích, giữ các
mục đã loại trừ trước đây. Không sao chép/chạy toàn bộ hai dự án.

Thêm18 tính năng: đề xuất/mẹo Start, nhắc tài khoản Start/Settings, lời mời
hoàn tất thiết lập, hạn chế tự cài app gợi ý, toast gợi ý Windows, Phone Link
trong Start, khay kéo/chia sẻ tệp, Snap Assist, Snap Layouts, luôn hiện thanh
cuộn, tăng tốc con trỏ, sắp cửa sổ bằng kéo, thông báo app, gộp taskbar chính/
phụ, hiển thị nút app trên nhiều màn hình, thứ tự ký tự ổ đĩa.

31 lựa chọn trong10 ô chọn: Search, vị trí taskbar, Task View, Alt+Tab,
thư mục mở Explorer, màu Windows, gộp nút taskbar chính/phụ, nhiều taskbar,
ký tự ổ đĩa. Mỗi chức năng một ID; không có checkbox trái ngược cùng giá trị.
Chọn ô chỉ chuẩn bị thay đổi. Xem trước ghi đúng lựa chọn; nhật ký lưu lựa
chọn và hoàn tác sau khởi động lại không phụ thuộc lựa chọn hiện tại.
Giữ đọc/hoàn tác nhật ký DWORD v2/v3 cũ không có trường Choice.

43 tính năng registry:51 DWORD+5 REG_SZ. Chuột/WindowArrangementActive dùng
REG_SZ theo Win11Debloat, có sao lưu chuỗi gốc; giữ bảo vệ COM/menu cũ riêng.
Không thay bộ hồ sơ tự chọn các mục mới, không vô hiệu hóa bảo mật/dịch vụ.

Appx:30 ứng dụng được xác minh, tăng từ10;10 đề xuất xem xét và20 app thông
thường. Các ứng dụng phổ biến được giải thích, có màu/phân loại. Store,
Edge, Shell, security, framework/runtime, Gaming Services, driver vẫn giữ.
Cài lại chỉ có khi nguồn Store được xác minh; Solitaire thiếu Store ID
trong nguồn ghim không được hứa cài lại. Không gỡ sẵn, AllUsers/provisioned.

Phần mềm:234 mã WinGet từ config WinUtil, có tìm kiếm tên/ID, lọc nhóm,
danh sách đang chọn. Mặc định hiện8 app phổ biến, không chọn/cài sẵn.
Giữ kiểm tra exact ID khi cài, hai xác nhận điều khoản, không silent mặc
định. Không đưa lại tính năng update/list WinGet và shortcut Settings đã bỏ.

599 assertions đạt:18+100+42+56+16+25+29+23+8+69+213. Mọi thao tác thay đổi
Windows dùng mock.69 kiểm tra mới về lựa chọn/khởi động lại/hoàn tác,
chống target không được duyệt/choice trộn; native RegistryKey giả xác minh
REG_SZ chuột. WPF kiểm tra dropdown, chip, xem trước/hủy/hoàn tác, tìm kiếm
và giữ lựa chọn phần mềm, màu theme; regression cũ tiếp tục đạt.

Native chỉ đọc56 giá trị,21 thay đổi đề xuất, zero writes/journals. Không
áp dụng registry, gỡ/cài app hoặc chạy sửa Windows thật để kiểm thử.
Chưa kiểm chứng hiệu lực thực tế của mọi tùy chỉnh trên mọi build/edition,
chưa cài thử234 phần mềm. Các mục “Tùy chọn nâng cao — Chưa tích hợp” không
có nút giả. Không tuyên bố đã tích hợp toàn bộ hai dự án hoặc tắt mọi AI/
telemetry. Các giới hạn0.12 và0.11 giữ nguyên.

Sửa Core, WinTune, MainWindow, FeatureBoard.UI, Actions.Core, Tools.UI,
features/app/software-catalog, Catalog.Verify, Review-Matrix, Run-Tests,
Core.ExtendedTests, Actions.Tests/UI.Tests, Tools.Worker.Tests, Registry.Typed.Tests,
UI.SelfTests, RealRead.Check, Build-Package/Package.Check, README/HUONG-DAN,
FEATURE_MATRIX/KIEM-THU/TIEN-DO. Thêm Software.UI, Coverage.Tests/UI.Tests,
feature-coverage.json, các snapshot .reg.txt đã dùng và các generator phát
triển riêng. Giữ baseline-v0.12, dữ liệu v2 và bản0.12 cũ.
