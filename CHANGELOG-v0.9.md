# WinTune VI 0.9 — bảng chọn và sửa màu rê chuột

Danh sách tiến trình trước đây chỉ đổi Foreground; template ListViewItem
mặc định của Windows vẫn dùng nền hover/selection sáng, làm chữ khó đọc
ở theme tối. Thay bằng template của app, giữ GridViewRowPresenter ba cột.
Hover/selection/focus dùng brush theo theme; không giảm opacity khi rê chuột.

Tùy chỉnh Windows chuyển thành bảng lớn với card theo nhóm, 3 cột khi đủ
rộng, 2 hoặc 1 khi hẹp. Giữ Sidebar/tìm kiếm và24 mục cũ. Ô tick thể hiện
lựa chọn, nút ⓘ mở chi tiết bên phải và có nút đóng để xem toàn bộ bảng.

Vùng **Đang chọn** liệt kê tên mọi mục đã chọn, gồm các nhóm đang bị lọc.
Nhấp × bỏ từng mục, **Chỉ hiện đang chọn** lọc bảng. Chọn nhanh xóa bộ lọc
cũ, đánh dấu đúng hồ sơ rồi hiện đầy đủ lựa chọn. Chọn hồ sơ chỉ chuẩn bị;
vẫn cần xem trước/xác nhận, không tự tối ưu hoặc gỡ ứng dụng.

398 assertions: Core18, Extended71, Actions42, Tools56, Worker16, Monitor20,
Theme29, WPF146. WPF thêm25: board/profile/chips/filter/detail, nhóm nằm
ngang tại1280/900, theme tối/sáng; row template thật giữ3 cột, hover/selected
đủ màu và opaque. Kiểm thử hover dùng bản template tách rời với trigger
được kích hoạt có kiểm soát; không tự di chuyển chuột desktop hoặc đổi
Windows thật. XAML writer không giữ ancestor binding trong bản tách rời,
nên fixture gắn lại3 cột; binding của template sản xuất được kiểm tra riêng.
Ảnh board và row đã được kiểm tra trực quan. Hiệu lực với chuột trong VM
vẫn cần người dùng xác nhận. Toàn bộ thao tác thay đổi hệ thống được mock.

Giữ baseline-v0.8; Core/Actions.Core/Tools.Core không sửa. Không thêm đích
registry, dependency hoặc mã upstream. Tham khảo cách tổ chức giao diện
[WinUtil XAML](https://github.com/ChrisTitusTech/winutil/blob/main/xaml/inputXML.xaml),
viết lại riêng; nguồn/commit/license tính năng trước vẫn giữ nguyên.

Thêm FeatureBoard.UI.ps1, Board.UI.Tests.ps1, Hover.UI.Tests.ps1 và tài liệu
này. Sửa MainWindow.xaml, WinTune.ps1, UI.SelfTests.ps1, Build-Package.ps1,
Package.Check.ps1, README.md, HUONG-DAN.txt, FEATURE_MATRIX.md, KIEM-THU.md,
TIEN-DO.md. Dữ liệu lựa chọn theme/lịch sử/hoàn tác không thay đổi.
