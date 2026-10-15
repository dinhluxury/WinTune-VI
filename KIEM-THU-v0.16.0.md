# Kiểm tra bản local 0.16.0 — 15/10/2026

Đã chạy trên Windows PowerShell 5.1 STA/WPF trong workspace. Các thay đổi Windows dùng mô phỏng hoặc API giả lập; không áp dụng tinh chỉnh thật.

| Phần | Kết quả | Phạm vi |
|---|---|---|
| Engine tùy chỉnh đầy đủ | 349 kiểm tra đạt | Xem trước, mọi handler trong mô phỏng, xác nhận, lỗi giữa đợt, nhật ký, hoàn tác và chống ghi đè thay đổi ngoài |
| Adapter gốc | 18 kiểm tra đạt | DNS, dịch vụ, ACL, xác minh BitLocker/AI/TEMP; không gọi bộ ghi Windows thật |
| Đối chiếu Win11Debloat và lựa chọn | 563 kiểm tra đạt | 88 ánh xạ, giá trị từ snapshot registry, từng lựa chọn/hoàn tác, optional features giả lập và bố cục Start trong thư mục thử của workspace |
| Giao diện WPF | 281 kiểm tra đạt | Điều khiển thật, dữ liệu mô phỏng; có bảng đầy đủ, lựa chọn, cuộn, màu sáng/tối, cửa sổ hẹp, cập nhật và một lần bấm Dung lượng ổ đĩa chuẩn bị mở trực tiếp C: |
| Trải nghiệm mới | 12 kiểm tra đạt | Phân loại/gộp sự kiện, lời giải thích hiệu năng và gỡ Copilot mô phỏng |
| WizTree | 14 kiểm tra đạt | Worker mô phỏng, phát hiện bản có sẵn, xác nhận cài, chữ ký đúng/sai, lỗi cài và không tìm được tệp sau cài; không cài/mở WizTree thật |
| WizTree mở ổ thật | 15 kiểm tra đạt | Worker mở C: trực tiếp, không tạo/đọc CSV, từ chối đối số CSV, dùng lại bản đã cài, hủy, chọn ổ C: trước và dự phòng khi máy không có C:; không tự quét thật trong kiểm thử |
| Trạng thái cập nhật | 8 kiểm tra đạt | So phiên bản đang chạy với bản public/đã chuẩn bị; không nhầm tải xong là đang chạy bản mới nhất, không đề nghị hạ phiên bản local |
| Bộ hồi quy trước đó | Đạt | Core, Appx, công cụ, worker, theo dõi máy, theme, phần mềm, phân phối, tác giả phát hành, lệnh/launcher; không đăng ký PATH thật |
| Portable | Kiểm SHA256 và giải nén kiểm tra lại | Đối chiếu mọi tài nguyên chạy với workspace; không kèm dữ liệu evidence riêng hay khóa riêng |

Các ảnh trong thư mục evidence được tạo bằng WPF với dữ liệu ghi rõ mô phỏng. Không dùng chúng làm bằng chứng số đo của máy thật.

Chưa xác minh hiệu lực của mọi chính sách, gỡ ứng dụng, bố cục Start, Sandbox/WSL hoặc các thao tác nâng cao trên từng edition/build/phần cứng thật. Không tự tắt bảo vệ Windows, không chứng nhận rằng mọi máy đều cho phép EXE chưa ký. Gói chạy vẫn cần đủ PowerShell, XAML, JSON, module và tài nguyên cạnh launcher.

Đây là kết quả kiểm tra của gói chuẩn bị phát hành 0.16.0. Lệnh online chỉ dùng bản mới sau khi GitHub Release và GitHub Pages cùng được cập nhật. Hướng dẫn và giới hạn từng mục: TINH-CHINH-DAY-DU.md.

Kiểm tra CSV trước đó chỉ là lịch sử, không còn đại diện cho cách mở hiện tại. Người dùng đã xác nhận bản cũ mở CSV và thiếu tổng dung lượng/chỗ trống; bản sửa truyền ký tự C: trực tiếp cho WizTree, không còn đọc hoặc tạo CSV. Các bài kiểm thử tự động không quét toàn bộ ổ C: thật và chưa xác minh bằng tay các con số trong GUI WizTree. WizTree và evidence riêng không nằm trong ZIP public; trình xem cơ bản đã bỏ khỏi runtime và gói portable.
