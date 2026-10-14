# WinTune VI 0.14 — danh mục cài ứng dụng gọn và đều

Tiếp tục từ 0.13, lưu baseline-v0.13. Workspace không có Git; so sánh trực
tiếp với bản lưu. Không khởi tạo lại dự án, xóa nhật ký hoặc đổi các đích
registry/hoàn tác đã có.

- Rút danh mục 234 ID xuống 17 ứng dụng thông dụng trong bốn nhóm. 16 ID
  giữ từ nguồn WinUtil đã ghim, thêm UniKey từ manifest WinGet chính thức.
- Thay ô có chiều rộng theo tên bằng UniformGrid tự chia 2–4 cột, chiều
  cao đồng nhất, tên và công dụng tiếng Việt. Ô chọn rõ ở cả sáng/tối/hệ thống.
- Cài và đồng ý điều khoản đặt dưới vùng cuộn, luôn nhìn thấy. Một vùng
  cuộn cho danh mục, lựa chọn được giữ khi tìm/lọc; mặc định không chọn gì.
- Sửa màn hình xem trước đọc tên ứng dụng từ danh mục thay vì đối tượng
  giao diện. Hủy không khởi chạy trình cài đặt.
- UniKey ghim phiên bản x64 4.6.230919, cả show và install. Manifest có số
  phiên bản cao hơn 4.6.250531 chỉ dành ARM64; trang UniKey chính thức vẫn
  cung cấp build 230919 cho x64. Màn hình xem trước giải thích; lỗi kho được
  báo, không tự đổi phiên bản hoặc bỏ qua hash. Parameters không thể thay pin.

Nguồn WinUtil 07ccd8e2e755a706f31569808b31f5b77acad6a9 MIT và Win11Debloat
4079b276e9e93aa8698a9f70f5aa228ba11f8265 MIT giữ nguyên. UniKey: metadata
winget-pkgs 2266f556516ee3159b4f2ac38a3e38e04ba6af3c, LICENSE MIT cùng
SHA256 các văn bản tại sources/curated-v014. Snapshot ARM64 được giữ riêng
để giải thích quyết định. Không phân phối hoặc chạy mã upstream/bộ cài UniKey.

Kiểm tra: cú pháp PS5.1/XAML, bộ mock hồi quy, WPF thật tại 1180×800,
1024×650, 900×580; kích thước ô, nút cài/đóng trong khung, tìm/lọc/hủy, hai theme.
616 kiểm tra đạt (226 WPF); kết quả ở KIEM-THU.md và evidence. Kiểm thử dùng simulation/mock
cho mọi thay đổi Windows; chưa cài thử 17 ứng dụng thật hoặc kiểm tra mọi
build/DPI. Nguồn WinGet/installer có thể thay đổi, yêu cầu mạng hoặc UAC.

File runtime sửa: Software.UI.ps1, Tools.UI.ps1, Tools.Core.ps1,
software-catalog.json, MainWindow.xaml. Kiểm thử/đóng gói: Software.Layout.Tests.ps1,
UI.SelfTests.ps1, Tools.Tests.ps1, Tools.UI.Tests.ps1, Coverage.UI.Tests.ps1,
Catalog.Verify.ps1, Build-Package.ps1, Package.Check.ps1. Tài liệu/nguồn:
README.md, HUONG-DAN.txt, FEATURE_MATRIX.md, Review-Matrix.ps1, KIEM-THU.md,
TIEN-DO.md, sources/README.md, sources/curated-v014. Curate-Software-v0.14.ps1
chỉ là công cụ phát triển, không chạy khi mở ứng dụng.
