# Tiến độ audit WinTune VI

Cập nhật 2026-10-16 (Asia/Saigon). Dự án được khôi phục theo yêu cầu từ tag v0.16.3; HEAD `f3aad2f0b4bcbaa6336034263e68afaf6807c2d5`, detached HEAD. Bản Documents v0.15.2 không bị sửa.

## 1. Discovery — đã hoàn thành trong phạm vi local

- Tracked tree sạch trước sửa. Baseline `.audit/baseline-v0.16.3.zip`; SHA256 `ADC0A1E5A6CECD93B4DED654280494DCC6F4A7158E385310D27A14434C1B66F3`.
- Đã lập inventory mã, entry points, module/UI/worker, catalog và cơ chế phân phối. Vét AST toàn bộ PowerShell ở root; tài liệu upstream trong sources được coi là dữ liệu tham khảo.
- Pages live và main đã được đối chiếu ngày audit: đúng commit/tag và hash của get.ps1/docs/index.html. Không thực thi launcher Internet.

## 2. Audit và sửa có kiểm soát — đã triển khai local

- Sửa Type/phạm vi/kiểm tra trước xóa cho bố cục Explorer.
- Sửa Pending bị mở khóa bởi undo không liên quan; kiểm tra dữ liệu ngoài WinTune trước xóa giá trị; flush backup xuống đĩa trước mutation.
- Sửa abandoned mutex ở main và full worker.
- Sửa Close event dùng biến args, khoảng hở sau worker exit, dispose Process, đọc kết quả JSON sai kiểu.
- Chuyển đọc inventory/chuẩn bị preview Appx sang worker, có hủy/timeout riêng cho reader.
- Ràng buộc checksum bản đã cài với ZIP/manifest có chữ ký trong template bootstrap. Thay đổi này CHƯA được phát hành lên GitHub.
- Bỏ một lần render trùng. Không đổi catalog, URL hay lệnh online.

## 3. Performance — đã hoàn thành phép đo khả dụng

- 3 lượt WPF mô phỏng trước và 3 lượt sau; median ContentRendered ~2196 ms -> ~1804 ms. RAM không giảm; số đo không phải online/cold-start benchmark.
- Probe Windows thật chỉ đọc: registry đọc được; CIM/Appx bị giới hạn quyền môi trường. Không coi các phép đọc thất bại là thành công.

## 4. Testing — đã hoàn thành lượt kiểm thử khả dụng

- Regression mới: 19 PASS, Windows API ghi đều giả lập; có mutex fixture riêng.
- WPF đã đạt 310 kiểm tra, GUI lifecycle dựng/đóng thật ở DPI scale 1.25; lượt Run-Tests cuối đã PASS; các case thêm muộn được chạy riêng và ghi rõ trong TEST_REPORT.
- Mock phân phối, ký RSA, cache tamper và author tool đã PASS riêng.
- Pages loopback fixture không kết nối được trong môi trường; cần ghi UNAVAILABLE/FAIL môi trường, không tính PASS.
- Tải thêm bootstrap/manifest/chữ ký production bị auto-review dừng do giới hạn sử dụng; kiểm chứng RSA production chưa hoàn tất. Không thử vượt chặn.

## 5. Final review — đã hoàn thành trong phạm vi kiểm chứng

Đã chốt `.audit/verified-final.log`: 310 WPF checks; Tools 63, worker 20; legacy launcher comparison SKIPPED đúng phạm vi. Regression riêng cuối 19 PASS. Vét tĩnh 114 PowerShell/9 JSON/MainWindow XML PASS. Diff không lỗi whitespace theo line endings của dự án; catalog, version, URL/Pages, main XAML và public key không đổi. Đã tạo đủ 5 báo cáo cùng ma trận chức năng. Raw evidence và baseline được bỏ qua bởi .gitignore. Không push, deploy, release, cài dependency hoặc mutation Windows thật.

Các lỗi harness ban đầu (PSModulePath khi Start-Process từ PS7, ExitCode null) đã được tách khỏi kết luận ứng dụng. ParseFile get.ps1 được sửa trong runner để đọc UTF-8 đúng với đường HTTP không BOM.
Bổ sung cuối: sửa đọc tên Registry khác hoa/thường để bảo toàn backup; giữ thông báo restart của batch installer. Probe 30 vòng render/đổi trang/dialog: 0 write, 0 monitor job và timer đều dừng sau cleanup; bộ nhớ có tăng/giảm, không chứng nhận soak dài hạn.

Lượt audit local kết thúc. Các giới hạn production signature, loopback, CIM/Appx permissions, mutation Windows thật, nhiều build/DPI và soak đã được giữ ở NOT TESTED/UNAVAILABLE; không coi là đã đạt.

## Tiếp tục theo yêu cầu kiểm thử và upload

Đã tạo nhánh codex/audit-v0.16.4 từ baseline đã ghi. Main GitHub vẫn ở f3aad2f khi bắt đầu lượt này. Phát hiện/sửa thêm A14–A17, giữ catalog/key/URL cũ. Pages loopback fixture đã PASS khi có kết nối ngoài sandbox. User cho phép publish bản mới; đang hoàn tất suite và kiểm chứng artifact, chưa mặc định đã upload.
