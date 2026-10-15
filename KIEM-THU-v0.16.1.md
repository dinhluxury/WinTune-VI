# Kiểm tra WinTune VI 0.16.1 — 15/10/2026

Chạy bằng Windows PowerShell 5.1 STA và WPF. Các thao tác ghi Windows trong bộ kiểm thử được mô phỏng; chỉ tạo dữ liệu thử trong workspace.

| Phần | Kết quả và phạm vi |
|---|---|
| Engine đầy đủ | 358 kiểm tra: xem trước, mọi mục trong mô phỏng, xác nhận, xử lý đợt bị ngắt, lưu nhật ký và hoàn tác |
| Bộ chọn sẵn | 135 kiểm tra: giữ đích của 43 mục registry cũ; Tối thiểu/Tiêu chuẩn/Nâng cao trên build 22000, 22621, 22631, 26100, 26300; không có giá trị xung đột; áp dụng/hoàn tác từng bộ trong mô phỏng |
| Adapter gốc | 18 kiểm tra DNS, dịch vụ, ACL, BitLocker và các adapter; không gọi bộ ghi Windows thật |
| Win11Debloat | 563 kiểm tra ánh xạ, từng giá trị lựa chọn, hoàn tác, thành phần Windows giả lập và bố cục Start trong thư mục thử |
| WPF | 301 kiểm tra đạt. Trang chính có toàn bộ 111 mục, không cần bảng phụ; bấm tên/phần trống mở đúng chi tiết; checkbox chỉ chọn; tự chuyển Tùy chỉnh khi thêm/bớt/đổi giá trị; giữ lựa chọn khi tìm kiếm/chuyển trang |
| Tác vụ và phục hồi | Tham số của worker là bản chụp riêng; xem trước bị hủy không ghi; khóa thao tác xung đột trong khi chạy; đợt cũ chưa hoàn tất vẫn hiện và chặn ghi mới |
| Bố cục | Dựng và xem ảnh WPF sáng/tối ở 1480×960 và 900×620; phần danh sách và chi tiết cuộn, nút xem trước còn truy cập được |
| WizTree | 14 kiểm tra tích hợp và 15 kiểm tra mở ổ: giữ cách mở C: trực tiếp, không CSV, không tự cài hoặc quét thật trong bộ thử |
| Hồi quy | Core, ứng dụng/khởi động, công cụ, worker, theo dõi máy, giao diện, phần mềm, chữ ký phát hành, cài đặt và các launcher |

Gói portable được kiểm SHA256, kiểm chữ ký manifest và thử mở WPF từ bộ đóng gói. Không phân phối thư mục evidence, nhật ký riêng của máy hoặc khóa ký riêng trong ZIP/source public.

Bài thử thực thi EXE biên dịch bị Application Control chặn trên máy kiểm tra; chưa xác minh đường chạy đó và không thay chính sách để vượt chặn. Lối mở PowerShell/WPF được kiểm tra riêng.

Kiểm thử mô phỏng không chứng minh mọi tinh chỉnh có hiệu lực trên mọi edition/build/phần cứng. Không dùng kết quả này để tuyên bố đã kiểm thử gỡ ứng dụng, giải mã ổ hoặc thay đổi chính sách trên Windows thật. Các giới hạn từng tính năng nằm trong TINH-CHINH-DAY-DU.md; kết quả chi tiết của lần chạy được lưu cục bộ tại evidence/test-v0.16.1.log.
