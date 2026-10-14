# WinTune VI 0.15.0 — khởi chạy và phân phối

Giữ baseline-v0.14 và mọi bản đóng gói trước; workspace không có Git.
Registry/config/Appx/WinGet/cleanup/repair/monitor giữ nguyên các handler cũ.

- Online bootstrapper: tải file có hash ghim, trust config public key,
  RSA-SHA256 manifest + SHA256 ZIP, xử lý HTTP/redirect/timeouts, ZIP staging.
- Command installer: chỉ User PATH/HKCU App Paths, receipt, bảo vệ lệnh
  cùng tên, đăng ký lặp không ghi lại, bỏ đăng ký/khắc phục có điều kiện.
- Resolver EXE đọc pointer trong apps, từ chối đường dẫn ngoài root/junction;
  lệnh wintune/demo/update. Không auto elevate hoặc cài dependency.
- Cập nhật chỉ khi bấm và xác nhận; side-by-side, pointer nguyên tử,
  giữ bản cũ/v2, không tự thực thi bản mới hoặc hạ bản đã chuẩn bị.
- UI tiếng Việt, lazy load, runspace theo tác vụ, hủy tải/kiểm tra,
  dispose worker/timer khi xong; mở thường không giữ process wrapper.
- Phiên bản từ version.json, Build-Package/Package.Check dùng phiên bản này.
  Portable ZIP có đầy đủ XAML/JSON/module/tài nguyên, không single EXE.

Đã cấu hình dinhluxury/WinTune-VI và khóa công khai RSA3072; khóa riêng tạo
ngoài workspace, không phân phối. Bộ ký sửa lỗi tải assembly System.Security
trên PowerShell 5.1. Build kiểm cấu hình portable/ZIP và yêu cầu Windows từ
metadata thật. PublicRelease loại nhật ký/ảnh máy và runner VM cũ khỏi ZIP;
Prepare-GitHub tách Source/Release, kiểm lại chữ ký/hash, không tự upload.
Chưa đăng mã hoặc phát hành Release, thay PATH/HKCU/cài lên Windows thật.
Online chưa dùng thật cho đến khi bản stable ký được đưa lên GitHub.
Thử cơ chế thay thế EXE hiện có; không cài/thử PS2EXE. Giải thích tại DISTRIBUTION.md.

Thêm Distribution.Core/UI/Tests/UI.Tests, CommandRegistration, CommandRouter.cs,
Register-WinTune, Bootstrapper.template, Build-Distribution, Configure-Release,
New-ReleaseSigningKey, Sign-Release, version.json, release-config.json và
DISTRIBUTION.md. Sửa Launcher.cs, wintune.cmd, WinTune.ps1, MainWindow.xaml,
Build-Package, Package.Check, Run-Tests, UI.SelfTests, README, HUONG-DAN,
KIEM-THU, TIEN-DO, FEATURE_MATRIX. Không thay đích features/app/software catalog.

Đợt đầu695 assertions đạt (WPF238, Distribution67), gói353 checksum và
compiled Demo /probe đạt; resolver /resolve+/probe đạt với fixture workspace.
Thêm20 bài author tool RSA3072/DPAPI và nhánh WPF nguồn đã ghim. Kết quả
trong KIEM-THU.md và evidence local; ảnh/log máy không đưa vào bộ public.
Một số EXE fixture so sánh startup bị Application Control chặn; không bỏ
chính sách. Native PATH/Win+R, benchmark và Release sản xuất chưa xác minh.
Mọi thao tác thay đổi thiết lập Windows trong kiểm thử dùng mock.

Sau cấu hình nguồn:715 assertions đạt; khóa riêng ngoài dự án. Online
chờ phát hành. Probe tạo evidence khi yêu cầu, không phụ thuộc thư mục
ảnh/log phát triển đã được loại khỏi gói public.
