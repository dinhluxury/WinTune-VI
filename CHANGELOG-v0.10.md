# WinTune VI 0.10 — rút gọn giao diện

Bỏ danh mục “Thiết lập Windows” ở thanh trái vì bảng đã chia nhóm và hiện
đầy đủ các tính năng. Xóa slogan “Cài đặt theo cách của bạn”. Không còn
control Categories, bộ lọc nhóm hoặc event handler cũ trong WinTune.ps1.

Chuyển Chọn nhanh lên bảng, cạnh ô Tìm tính năng có gợi ý nhập từ khóa.
Đọc lại trạng thái nằm cạnh tìm kiếm. Vùng Đang chọn giữ mọi tên đã chọn,
kể cả khi tìm hoặc chỉ xem lựa chọn. Chọn nhanh xóa bộ lọc và chuẩn bị
danh sách, không tự thay đổi Windows. Giữ xem trước/xác nhận cuối cùng.

Thanh trái chỉ giữ trang và công cụ. Gỡ ứng dụng, Cài đặt & cập nhật, Dọn
dẹp dùng tên ngắn; công cụ Windows dùng nhãn tiếng Việt. Hoàn tác và Lịch
sử hiện trực tiếp. Điểm khôi phục/khôi phục hệ thống vẫn riêng trong mục
Khôi phục Windows. Bỏ lối tắt Theo dõi tài nguyên trùng trang Tổng quan.
Hai trang chính tô màu trang đang mở. Tối/Sáng/Theo hệ thống giữ nguyên.

406 assertions: Core18, Extended71, Actions42, Tools56, Worker16, Monitor20,
Theme29, WPF154. WPF kiểm tra bộ lọc/tìm kiếm không mất lựa chọn, hồ sơ
hiện đúng tên, chuyển trang giữ lựa chọn, vị trí Chọn nhanh/tìm kiếm không
chồng nhau, Hoàn tác/Lịch sử truy cập trực tiếp. Bảng 1280/900 ở cả hai
theme; bố cục 1180x800/1024x650/900x560 và scale dựng 100/125/150%.
Tất cả thao tác thay đổi Windows được mô phỏng. Ảnh dựng đã được xem;
không tuyên bố đã tự di chuột hoặc kiểm chứng hiệu lực tinh chỉnh thật.

Giữ baseline-v0.9. Không thêm dependency, chức năng tối ưu hay mã upstream;
giữ ID, giá trị registry, nhật ký và dữ liệu theme. Core.ps1, Actions.Core.ps1,
Tools.Core.ps1 và Theme.Core.ps1 không sửa.

File sửa: MainWindow.xaml, WinTune.ps1, Monitor.UI.ps1, UI.SelfTests.ps1,
Board.UI.Tests.ps1, Build-Package.ps1, Package.Check.ps1, README.md,
HUONG-DAN.txt, FEATURE_MATRIX.md, KIEM-THU.md, TIEN-DO.md. Thêm tài liệu này.
Giới hạn kiểm thử tác vụ hệ thống/WPF thật của các bản trước vẫn còn; xem
README.md và KIEM-THU.md. Phần này chỉ thay luồng chọn/hiển thị.
