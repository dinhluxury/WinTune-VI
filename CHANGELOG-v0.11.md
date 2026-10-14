# WinTune VI 0.11 — thao tác rõ ràng hơn

Các yêu cầu được thực hiện cùng đợt:

- Kiểm tra bảo mật/TPM/thiết bị chạy một lần ngay từ Tổng quan, có giải thích
  cạnh nút và kết quả ngay bên dưới. Bộ đọc riêng bất đồng bộ; lỗi từng nguồn
  giữ trạng thái chưa đọc được. Không tự sửa bảo mật, không quét mỗi hai giây.
- Bảng tiến trình chuyển sự kiện lăn chuột về trang Tổng quan, không giữ bánh
  xe trong danh sách con. Kiểm tra bằng sự kiện WPF tổng hợp, chưa dùng chuột
  thật trong máy ảo để chứng minh.
- Khôi phục có cửa sổ riêng: bật bảo vệ nếu chưa bật, tạo mốc trước thay đổi,
  quay về mốc cũ. Giải thích thông báo System Protection đang tắt. Chỉ mở
  hướng dẫn Windows sau khi đọc được mốc; không tự áp dụng System Restore.
  Tạo mốc giữ worker/xác nhận/kiểm tra mốc mới cũ. Hoàn tác nguồn điện chuyển
  về nhóm Nguồn điện, không còn trộn với tạo mốc Windows.
- Phần mềm chỉ có chọn ứng dụng và cài; bỏ các menu WinGet/check/list/update
  khỏi giao diện. Bên trong vẫn dùng ID chính xác, show/verify và cơ chế
  điều khoản. Không chọn sẵn, tự chấp nhận điều khoản hoặc cài im lặng.
- Công cụ Windows chỉ còn Quản lý thiết bị và Nhật ký Windows dễ hiểu. Bỏ
  lối tắt trùng Settings. Bảng nhật ký đọc System/Application ba ngày, tối đa
  200 sự kiện mỗi log, chỉ lỗi/nghiêm trọng; sự kiện chưa nhận diện giữ nguồn
  và chi tiết. Không đoán hỏng nguồn hay tạo chỉ số sức khỏe.
- Sửa lỗi có kết luận tiếng Việt từ mã thoát hoặc thông báo rõ của Windows.
  SFC/DISM không dùng mã 0 đơn thuần để khẳng định sạch. Ngôn ngữ chưa nhận
  diện giữ kết luận chưa đủ thông tin; chi tiết gốc và lỗi vẫn hiện.
- Nguồn tham khảo chuyển thành chữ có liên kết Microsoft/WinUtil/Win11Debloat.
- Chọn nhanh: Tự chọn/Tối thiểu/Tiêu chuẩn/Nâng cao, tham khảo nhóm của CTT,
  giữ tập con của WinTune. Không chọn gỡ app, xóa dữ liệu hay tắt dịch vụ.
- Gỡ ứng dụng mặc định lọc Có thể gỡ; tên thân thiện từ 136 nhãn Win11Debloat
  và manifest có thể đọc an toàn. Tên chưa rõ không được đoán. Nhãn xanh xem
  xét, vàng ứng dụng thông thường, xám bảo vệ; luôn có chữ, không chỉ màu.

## Tính năng bổ sung

Menu chuột phải Windows 10: một REG_SZ mặc định rỗng trong HKCU, theo hai
repo. Không tự đóng Explorer. Lưu cả trạng thái giá trị và việc khóa tồn tại;
hoàn tác chỉ xóa khóa lá mới nếu còn trống. Dữ liệu COM khác bị từ chối.

Notepad AI: một DWORD HKLM DisableAIFeatures, theo WinUtil/Win11Debloat và
Microsoft. Đổi toàn máy, chỉ có tác dụng với Notepad hỗ trợ AI. Recall: một
DWORD HKCU theo Win11Debloat/Microsoft, dành cho máy có Recall; Windows có
thể xóa ảnh Recall cũ. Chỉ hoàn tác thiết lập, không ảnh đã xóa; không đưa
vào chọn nhanh. Gỡ Microsoft.Copilot qua Appx hiện có, current-user, chọn
và xác nhận riêng, Store ID 9NHT9RB2F4HD theo WinUtil.

Không nhập nút Windows AI của WinUtil: nó sửa AllUsers, CoreAI, dịch vụ và
optional feature. Không dùng TurnOffWindowsCopilot cũ cho app Copilot mới.
Các chính sách Edge AI dành cho Edge Business/Entra, Click to Do còn giới
hạn Insider và Paint AI cấp máy không được thêm bừa vào PC cá nhân.

## Kiểm tra và giới hạn

458 assertions: Core18, Extended74, Actions42, Tools56, Worker16, Monitor20,
Theme29, Usability23, TypedRegistry5, WPF175. Tất cả thay đổi Windows dùng
mock. Production registry reader/writer chạy qua API RegistryKey giả để
kiểm tra REG_SZ, khóa lá, dữ liệu bên ngoài và trường hợp bị từ chối.
WPF thử nút chạy trực tiếp, lỗi/unknown, nguồn hyperlink, quy trình khôi
phục, hủy, worker chậm, bánh xe tổng hợp và bố cục hai theme.

Native chỉ đọc: bộ bảo mật và 63 sự kiện, không lỗi đọc log khi chạy ngoài
sandbox. Danh sách restore point bị quyền Windows từ chối, giữ unknown;
không suy ra đã bật/tắt. Không tạo mốc hoặc thực hiện SFC/DISM/chkdsk thật,
không đổi registry/gỡ/cài ứng dụng để thử. Hiệu lực menu cũ, Notepad AI,
Recall và gỡ Copilot mới trong VM cần người dùng kiểm chứng có chọn lọc.

Giữ baseline-v0.10, dữ liệu v2 và lịch sử DWORD v2/v3 vẫn đọc được. 25 tùy
chỉnh registry (34 DWORD +1 REG_SZ), 2 liên kết Settings cũ và1 hành động
Copilot; không sao chép nguyên bộ upstream. Không thêm dependency.

Nguồn/commit/license giữ trong FEATURE_MATRIX.md, sources và app-labels.json.
File sửa/thêm xem TIEN-DO.md; hướng dẫn dùng trong README.md.
