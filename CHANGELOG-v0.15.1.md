# WinTune VI 0.15.1 — lối mở PowerShell/WPF

Bản 0.15.0 kiểm checksum thành công nhưng caller `& $p` bị ExecutionPolicy
Restricted chặn. Sau khi sửa caller, EXE tự biên dịch chưa ký bị App Control
chặn. Người dùng xác nhận lối PowerShell/WPF có sẵn mở được ứng dụng.

- Online: tải bootstrapper ra file, kiểm SHA256 rồi chạy host PowerShell
  cố định với policy chỉ trong process con; không đổi CurrentUser/LocalMachine.
- PowerShell/WPF là entry point chính được chọn trước khi mở; không thử
  EXE rồi tự fallback sau khi Windows từ chối. Windows vẫn kiểm script/module.
- Lệnh cục bộ `wintune.cmd` dùng source cho app/demo/update/probe.
- Đăng ký theo tài khoản dùng `command/wintune.cmd` + CommandRouter.ps1,
  User PATH, receipt schema2; không tạo App Paths mới hoặc phụ thuộc resolver EXE.
- Reader kiểm pointer nằm trong apps, từ chối junction/đường ngoài, kiểm
  resource checksum trước khi nạp module; chỉ cho phép các mode cố định.
- Đọc pointer UTF-8 tường minh, kể cả không có BOM; kiểm tra đường dẫn
  chứa dấu tiếng Việt và khoảng trắng cho CLI và gói đã giải nén.
- Gỡ/khắc phục receipt EXE schema1 vẫn hỗ trợ. Chuyển từ đăng ký cũ cần
  tự bỏ đăng ký cũ trước; không tự di chuyển hoặc ghi đè lệnh khác.
- EXE portable giữ để dùng khi được chính sách cho phép; chưa có chứng chỉ
  Authenticode được tin cậy, không thêm self-signed cert/allowlist hoặc tắt bảo mật.

Giữ handler features, XAML/theme, Appx, WinGet, cleanup/repair và dữ liệu v2.
Không sửa Release 0.15.0 đã phát hành, không cài/đăng ký lệnh hoặc thay Windows.

Kiểm thử mới:17 native CLI/ShellExecute fixture (PATH chỉ ở process),
74 distribution (thêm7 cho schema1/tamper/UTF-8) và24 author (Restricted parent,
hash/mạng, RSA/DPAPI). Registry/Appx/PATH thực vẫn mock. Native Win+R qua
Explorer/PATH user và cập nhật mới từ GitHub chưa được thử; không đồng nhất
ShellExecute fixture với thao tác người dùng thật. EXE bị App Control chặn
không coi là PASS. WPF/source là lối kiểm chính. Kết quả hồi quy ghi KIEM-THU.md.

File thay đổi:version.json, Bootstrapper.template, Build-Distribution,
Distribution.Core, CommandRegistration, SourceCommandRegistration, CommandRouter.ps1,
Wintune.Registered.cmd, wintune.cmd, Register-WinTune, Distribution.UI,
Distribution/SourceCommand/Release.Author.Tests, Run-Tests, Build-Package,
Package.Check, Prepare-GitHub và tài liệu. Chưa phát hành0.15.1.
