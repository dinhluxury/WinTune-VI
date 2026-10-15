# Xem dung lượng ổ C: bằng WizTree

Trong WinTune, bấm **Dung lượng ổ đĩa**:

1. Nếu máy chưa có WizTree, WinTune tự cài đúng gói `AntibodySoftware.WizTree` từ WinGet và kiểm tra chữ ký Antibody Software. Lần đầu cần Internet; Windows có thể hỏi quyền quản trị.
2. WinTune mở WizTree trực tiếp với **ổ C:**. WizTree tự quét ổ C: thật, không mở CSV và không cần bấm Scan cho lượt mở này.
3. Sau khi quét, phía trên WizTree hiển thị **Total Space** (tổng dung lượng), **Space Used** (đã dùng), **Space Free** (còn trống). Cây thư mục và bản đồ màu cho biết phần nào chiếm nhiều chỗ.

Ô **Select** ở góc trên trái phải là ổ **C:**, không phải `<CSV file>`. Những lần sau bấm Dung lượng ổ đĩa vẫn dùng WizTree đã cài và mở trực tiếp C:. Nếu máy không có C: sẵn sàng, WinTune chọn ổ Windows hoặc ổ cứng/USB sẵn sàng khác.

Các ổ khác dùng hộp **Select** của WizTree; chọn ổ muốn xem và bấm **Scan**. Bản này ưu tiên tự quét trực tiếp C:, không còn tạo bản CSV chung cho mọi ổ. Dừng quét đang chạy bằng điều khiển của WizTree. Nút **Hủy mở** trong WinTune chỉ áp dụng lúc đang chuẩn bị; nếu trình cài đang chạy sẽ đợi cài xong, không cưỡng bức tắt trình cài.

Nếu WinGet thiếu hoặc cài lỗi, có **Thử lại** và **Trang tải chính thức**. WinTune không tự xóa tệp, không sao chép WizTree vào ZIP và đã bỏ trình xem cơ bản. CSV từ bản cũ không còn được đọc hoặc tạo lại.

WizTree là ứng dụng riêng của Antibody Software, miễn phí cho sử dụng cá nhân; [điều khoản](https://diskanalyzer.com/eula) quy định việc dùng trong công việc. Xem [hướng dẫn chính thức](https://diskanalyzer.com/guide), [FAQ](https://diskanalyzer.com/faq), [trang tải](https://diskanalyzer.com/download) và [gói trong kho Microsoft](https://github.com/microsoft/winget-pkgs/tree/master/manifests/a/AntibodySoftware/WizTree).

Kiểm thử dùng worker mô phỏng cài/mở, xác minh đối số mở là C:, từ chối đường dẫn CSV, không tạo CSV, dùng lại bản đã cài và hủy trước khi mở. Không cài WinGet hoặc quét toàn bộ ổ C: thật trong các bài tự động.
