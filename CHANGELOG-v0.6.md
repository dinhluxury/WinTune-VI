# Thay đổi 0.6 — 14/10/2026

Nền 0.5 ở baseline-v0.5. Không có Git; không reset hoặc khởi tạo lại dự án.
Core.ps1/features.json/Simulation.ps1 và 32 đích registry cũ được giữ nguyên.

## Tệp đã sửa

- MainWindow.xaml, WinTune.ps1: hồ sơ, nút công cụ, WPF sidebar/cuộn.
- Actions.Core.ps1/UI.ps1: inventory Appx user, phân loại/protection thực thi,
  publisher, nguồn cài lại khi biết, worker apply/startup undo, busy/conflict.
- Actions.Tests.ps1/UI.Tests.ps1, UI.SelfTests.ps1, Run-Tests.ps1: kiểm tra
  bảo vệ, gói thông thường, hồ sơ, worker/dispatcher/UAC mock/cleanup mock.
- VM.Check.ps1, Kiem-Thu-May-Ao.cmd: chặn thử tự động thật kể cả VM theo yêu
  cầu mới. Giữ RecoverLast đợt cũ có guard; CMD nay chạy Run-Tests mô phỏng.
- Build-Package.ps1/Package.Check.ps1: gói0.6 đủ module/docs/license/source,
  checksum, launcher/WPF và test từ thư mục giải nén Unicode.
- HUONG-DAN.txt, README.md, FEATURE_MATRIX.md, KIEM-THU.md, TIEN-DO.md và
  sources/README.md: nguồn, hướng dẫn, bằng chứng/giới hạn. Hướng dẫn0.5 thêm
  ghi chú lịch sử, không dùng native autotest cũ để chứng minh công cụ mới.

## Tệp mới

Tools.Core.ps1, Tools.UI.ps1, Tools.Worker.ps1, Tools.Tests.ps1,
Tools.Worker.Tests.ps1, Tools.UI.Tests.ps1, Tools.ReadCheck.ps1;
Profiles.ps1, profiles.json, software-catalog.json;
Review-Matrix.ps1, FEATURE_MATRIX.md, README.md, CHANGELOG-v0.6.md;
sources/review-20261014, sources/winget-package-ids.json, bằng chứng mới.

## Kết quả và hạn chế

293 bài tự động: Core18, Extended71, Actions42, Tools56, Worker16, WPF90.
Mọi tác vụ thay đổi được mock/mô phỏng. Parser5.1/XAML/C# helper compile;
dispatcher WPF vẫn phản hồi trong worker giả kéo dài. Native chỉ đọc hardware/
security, WinGet--version và power plans; plan trước/sau không đổi.

Chưa thực thi thật search/install/upgrade WinGet, repair, cleanup, Restore
Point, power change, appx/startup mới, UAC worker hoặc mức giảm RAM. Chưa
chuột desktop, nhiều build/edition/DPI/màn hình, ARM64. Không hứa FPS/RAM.
Menu chuột phải cũ, Start layout/AI sâu, optional feature apply, light theme
WinTune và giải mã ms-resource đầy đủ chưa triển khai, không có nút áp dụng giả.
Protection bảo thủ với Microsoft chưa xác minh; không biết mọi phụ thuộc app
bên thứ ba. Người dùng cần đọc tác động, giữ nguồn cài lại và sao lưu dữ liệu.
Không phát hiện sửa rồi trả cùng giá trị hoặc mọi race giữa đọc/ghi. Cleanup
dùng handle kiểm tra đích/kích thước/mtime trước đánh dấu xóa để giảm race.
Installer có hành vi riêng/UAC/restart theo nhà phát hành; app không truyền
allow-reboot, không tự đóng app. Tự lưu công việc trước xác nhận.

Báo cáo17 vòng registry thật và hiệu lực đuôi tệp trước đây thuộc0.3 trong VM;
không coi là bằng chứng cho chức năng mới. Kết quả package ở evidence.
