# WinTune VI 0.16.0

- Thêm bảng Toàn bộ tùy chỉnh Windows với đủ 67 ID cấu hình trong ảnh WinUtil (bao gồm DNS, MPO, O&O và hai thao tác Ultimate Performance). Có tên tiếng Việt, tác dụng, ảnh hưởng, cách hoàn tác và liên kết nguồn cho từng mục.
- Đổi nhóm Nguồn điện thành **Hiệu năng và chế độ ngủ**. Sửa lỗi hiện `System.Windows.Controls.StackPanel` thay tên tính năng trong bảng mới.
- Bổ sung các mục trong hai ảnh Win11Debloat: AI cho từng app, Start, thanh tác vụ, File Explorer, Alt+Tab, Sandbox và WSL. Có 110 mục, gồm 32 mục nhiều lựa chọn; bảng đối chiếu ghi rõ 88 lựa chọn/checkbox Win11Debloat và 67 ID WinUtil. Số mục không phải cam kết hiệu lực trên mọi bản Windows.
- Hiện sẵn **Chi tiết phần cứng và Windows** trên Tổng quan, bỏ nút xổ xuống, xuống dòng khi cửa sổ hẹp.
- Thêm chọn nhanh Tối thiểu/Tiêu chuẩn/Nâng cao, tìm không dấu, lọc nhóm, hiện mục đã chọn, chọn mục có giá trị registry đang khớp và hoàn tác theo mục đã chọn.
- Thực thi trong worker riêng; xem trước không ghi Windows. Kế hoạch/nhật ký được bảo vệ bằng DPAPI theo tài khoản, kiểm tra lại đích và trạng thái trước khi ghi, hỗ trợ xử lý đợt bị ngắt và từ chối ghi đè thay đổi bên ngoài.
- Giữ engine và nhật ký tinh chỉnh cũ; bỏ hai đường tắt mở Settings dư thừa khỏi danh sách. Bảng đầy đủ dùng thư mục dữ liệu riêng để không làm hỏng lịch sử trước đây.
- Thẻ nhóm tự co theo nội dung, giảm khoảng cách và vùng trống. Ba tùy chọn thanh tác vụ có ví dụ về nhiều cửa sổ và nhiều màn hình.
- Đánh dấu gỡ Copilot rồi chạy ngay trong bảng chính: kiểm tra đúng gói Microsoft của tài khoản hiện tại, xem trước chung với các thiết lập đã chọn và gỡ qua worker. Không có gói thì báo rõ, không báo đã gỡ.
- Thay Dọn dẹp bằng Dung lượng ổ đĩa với WizTree. Hai mục dọn tệp cũ được ẩn khỏi bảng đầy đủ theo yêu cầu mới, còn 108 mục hiển thị.
- Nhật ký hiển thị tên ứng dụng/dịch vụ, gộp bản ghi lặp và giải thích việc nên làm ngay cạnh danh sách. Trạng thái dịch vụ hiện tại được đọc riêng; không coi nhật ký cũ là lỗi vẫn còn.
- Đổi mục Chế độ nguồn điện thành Hiệu năng và pin, giải thích Cân bằng/Tiết kiệm/Hiệu năng cao và đánh dấu chế độ đang dùng; giữ nguyên bộ thiết lập của Windows.
- Cài ứng dụng dành diện tích cho danh sách; vùng tiến trình ẩn khi chưa chạy và có thể thu gọn.
- Bấm Dung lượng ổ đĩa: tự cài WizTree nếu chưa có, mở trực tiếp C: để WizTree tự quét ổ thật. Bỏ cách xuất/ghép/mở CSV khiến tổng dung lượng và chỗ trống hiện n/a. Các ổ khác dùng Select/Scan của WizTree. Giữ đúng gói WinGet, kiểm tra chữ ký Antibody Software, không kèm WizTree trong ZIP, không có trình xem cơ bản và không tự xóa tệp.
- Bỏ xổ xuống ở nhóm khôi phục và công cụ Windows trên thanh bên. Dời mục Về WinTune/cập nhật xuống cạnh chọn giao diện. Trang cập nhật chỉ giữ phiên bản đang dùng, trạng thái mới nhất/có bản mới, nút kiểm tra và tải bản đã xác minh. Bỏ giao diện đăng ký lệnh wintune; không thay PATH hiện có.
- Không sao chép nguyên mọi tác dụng phụ của script WinUtil: không giảm bảo vệ Defender, không ép xóa Edge/WebView2/tệp hệ thống, không xóa dữ liệu OneDrive, không gỡ Appx mọi tài khoản, không dùng DISM ResetBase. Giới hạn cụ thể có trong TINH-CHINH-DAY-DU.md.
- Chỉ kiểm thử mô phỏng và giao diện; chưa xác nhận hiệu lực thực tế của mọi mục trên Windows. Không tự áp dụng tinh chỉnh, cập nhật bản đã cài hay phát hành GitHub Release.
