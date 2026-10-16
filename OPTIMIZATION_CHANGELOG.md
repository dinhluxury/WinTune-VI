# WinTune VI — Nhật ký thay đổi audit

16/10/2026. Baseline v0.16.3, không bump version hoặc phát hành.

| File/nhóm | Vấn đề ban đầu và thay đổi | Tác động / rủi ro | Kiểm tra |
|---|---|---|---|
| FullTweaks.Native.ps1 | Sửa Type cho FolderDiscovery/tree restore; giới hạn đúng root, validate snapshot trước xóa và từ chối kiểu không hỗ trợ hoàn tác | Bảo vệ bố cục Explorer; có thể từ chối bố cục đặc biệt thay vì xóa khi không thể khôi phục | Audit regression, native adapter mocks |
| FullTweaks.Core.ps1 | Đọc tên Registry không phân biệt hoa/thường; giữ Pending khi undo không liên quan; chặn Partial cũ có lỗi; hỗ trợ recovery trước write; foreign content precheck; Flush(true) backup | An toàn recovery hơn; journal có thể chậm hơn; journal hỏng vẫn fail closed | Full engine/profile/typed/19 regression checks |
| FullTweaks.Core/Worker + WinTune.ps1 | Nhận ownership sau abandoned mutex, release/dispose ở finally | Mở lại/recovery sau crash; không tự bỏ qua journal bị ngắt | Child mutex fixture và WPF startup |
| Actions.UI.ps1 + Tools.Worker.ps1 | Inventory/plan Appx chạy trong worker; read timeout/hủy; timer/closing đúng vòng đời | UI không chờ Get-AppxPackage trực tiếp; thêm process lúc đọc; chỉ kill reader được định danh cố định | Worker fixtures, dispatcher-delay/cancel/refused-cancel UI tests |
| Tools.UI.ps1 | Complete-ToolJob, Handled guards, kiểm JSON envelope/Id/ExitCode/rows | Không dùng disposed Process; kết quả hỏng thành lỗi; không mở thao tác mới trước nhận result | Tools.Worker.Tests, Tools.UI.Tests |
| Care.UI/Copilot.UI/Restore.UI/WizTree.UI | Hoàn tất job thì Dispose, Closing dùng eventArgs | Dọn tài nguyên và tránh lỗi Cancel của biến args | WPF/worker regression |
| FullTweaks.UI + UnifiedTweaks.UI | Giữ closing guard tới nhận kết quả, dispose full worker, bỏ render trùng ban đầu | Giữ 111 card; median startup mô phỏng tốt hơn trong mẫu nhỏ | Unified UI + GuiProbe + benchmark |
| Distribution.Core.ps1 + Bootstrapper.template.ps1 | So cache inventory với signed ZIP thay vì chỉ self-checksum | Tăng xác thực đường online; cache cũ tải thêm ZIP một lần; fail closed khi cache/version khác | 79 distribution assertions, cache tamper + RSA fixtures |
| Run-Tests.ps1 | Hosted get.ps1 parse UTF-8; thêm regression; legacy missing baseline báo SKIPPED | Kết quả kiểm thử đúng phạm vi; không đổi get.ps1/Pages | Parser và full runner |
| Build-Package.ps1 | Kèm hai test audit mà UI/runner mới tham chiếu | Không bỏ sót dependency test trong gói tương lai; không chạy đóng gói/phát hành | Static dependency review, fixture author tests |
| Audit.Regression.Tests.ps1 / Audit.UI.Tests.ps1 | Thêm lỗi thực đã tái hiện, mock APIs/worker delay/close/cancel | Không ghi Windows; dùng mutex và files fixture riêng | Regression 19; UI tổng 310 |
| Distribution/Setup/Tools/WizTree test scripts; UI.SelfTests | Thêm case signed cache, async reader, Dispose contract; chạy suite UI audit | Giữ kiểm tra cũ, mở rộng theo hành vi mới | Test report |
| Audit.Benchmark.ps1 | Tạo benchmark WPF mô phỏng có raw JSON | Chưa thay baseline online; dữ liệu workload được ghi rõ | 3 trước + 3 sau |
| Tools.Core/Worker/Tests + Tools.UI.Tests | Giữ cờ yêu cầu restart của từng installer trong batch và trong thông báo UI | Không tự restart; tránh mất hướng dẫn khi tổng exit code bằng 0 | Pure result fixtures + WPF summary test |
| .gitignore | Bỏ qua raw evidence/backup ở .audit khi git add | Giữ dữ liệu audit local; báo cáo root vẫn được review | Git status |
| Các báo cáo + AUDIT_FEATURE_MATRIX/AUDIT_PROGRESS | Ghi architecture, evidence, severity, limits và checkpoint | Tiếp tục được khi gián đoạn | Đối chiếu git và log cuối |

## Những gì giữ nguyên

Catalog/tài nguyên gốc, phương thức `irm https://dinhluxury.github.io/WinTune-VI | iex`, URL, version 0.16.3, public key, phong cách UI, công nghệ và tính năng hiện có. Không chuyển sang EXE, không cài dependency, không tự publish. Encoding/BOM và line endings gốc được giữ theo từng đoạn để diff không bị phình bởi định dạng.

## Hướng khôi phục

Chưa tạo commit nên có thể xem `git diff HEAD` để review. Nguồn chính xác trước audit còn trong `.audit/baseline-v0.16.3.zip` với digest ở AUDIT_REPORT. Khi cần hoàn nguyên: sao lưu công việc hiện tại, trích từng file cần hoàn nguyên từ baseline sang một thư mục riêng, so diff rồi thay riêng file đó. Không dùng reset/clean toàn repo vì có thể xóa công việc về sau. Không thay journal đang dùng để thử rollback mã.

Template mới và Distribution.Core phải được review/build/sign cùng nhau trước khi phát hành. Không chép nguồn đã sửa đè vào gói public còn dùng checksum cũ; giữ gói cũ và lịch sử, làm quy trình phát hành riêng khi được phép.

## Sửa bổ sung trước phát hành 0.16.4

- FullTweaks.Core.ps1: ownership cùng journal cho khóa mới nhiều giá trị; phục hồi native chưa có thay đổi với reader xác minh được; từ chối snapshot Registry không hỗ trợ. Không tự bỏ khóa đợt có thay đổi không thể hoàn tác.
- FullTweaks.Native.ps1 và FullTweaks.Native.Tests.ps1: Recall servicing read thất bại phải dừng; preflight pending/protected AI package trước gỡ. Không thay chính sách bảo mật hoặc tự restart.
- Audit.RegistryUndo.Tests.ps1, Audit.Regression.Tests.ps1: fake RegistryKey/in-memory state; regression sibling, foreign data, lỗi trước mutation và snapshot không phục hồi được.
- version.json, README.md, PUBLISHING.md, Prepare-GitHub.ps1, Build-Package.ps1, Package.Check.ps1, CHANGELOG/KIEM-THU v0.16.4: version mới, mô tả đúng tính năng hiện có, đóng gói test/report, số mục trong probe lấy từ kết quả thật.
- Khôi phục mã: dùng nguồn/tag v0.16.3 để so sánh; không xóa hoặc viết lại lịch sử/backup người dùng. Không thay asset cũ. Hạ mã không tự hoàn tác Windows.
