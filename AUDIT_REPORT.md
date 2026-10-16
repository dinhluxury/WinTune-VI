# WinTune VI — Báo cáo audit

Ngày: **16/10/2026**, Asia/Saigon. Phạm vi: mã nguồn local v0.16.3 và những phép kiểm tra an toàn khả dụng trên Windows hiện tại. Các thay đổi ở báo cáo này **chưa được phát hành**.

## Trạng thái nguồn và bảo vệ công việc

- Khôi phục theo xác nhận của chủ dự án từ tag `v0.16.3`. HEAD: `f3aad2f0b4bcbaa6336034263e68afaf6807c2d5`; detached HEAD; tracked tree sạch trước sửa. Không sửa clone v0.15.2 trong Documents.
- Baseline lưu ở `.audit/baseline-v0.16.3.zip`, SHA256 `ADC0A1E5A6CECD93B4DED654280494DCC6F4A7158E385310D27A14434C1B66F3`. `.audit/tracked-before.txt` và `.audit/status-before.txt` giữ inventory ban đầu.
- Không commit/push/deploy/release; không thay URL, version hoặc khóa tin cậy. Không thực thi launcher tải từ Internet. Không thực hiện tweak/gỡ/cài/sửa chữa Windows thật.
- Những log của workspace cũ đã mất không được dùng làm bằng chứng. Các kết luận ở đây dựa vào nguồn và bằng chứng được tạo lại.

## Kiến trúc đã xác định

| Lớp | Thành phần | Hành vi |
|---|---|---|
| Entry online | `docs/index.html`, `get.ps1`, `QuickLauncher.template.ps1` | `irm https://dinhluxury.github.io/WinTune-VI | iex`; ghim SHA256 bootstrap theo release |
| Bootstrap/phân phối | `Bootstrapper.template.ps1`, `Distribution.Core.ps1`, `Setup.Core.ps1` | Metadata GitHub; RSA manifest; ZIP/hash; staging; kích hoạt side by side; mở Windows PowerShell 5.1 STA |
| App chính | `WinTune.ps1`, `MainWindow.xaml`, `Theme.*`, `CompactGroupsPanel.cs` | WPF, state ở script scope, navigation, preview và lịch sử cũ |
| Tinh chỉnh hiện tại | `FullTweaks.Core/Native/Debloat/Profiles/UI/Worker.ps1`, `FullTweaks.json` | Catalog 113 mục, 111 mục được hiển thị; worker riêng cho đọc/apply/undo; DPAPI journal |
| Engine cũ | `Core.ps1`, `features.json`, `Profiles.ps1` | 43 registry tweaks + 1 app action; giữ khả năng đọc/undo lịch sử cũ |
| Ứng dụng | `Actions.Core/UI.ps1`, `Copilot.*` | Appx/MSIX tài khoản hiện tại; 30 app gợi ý, bảo vệ runtime/driver/security; HKCU Run có allowlist |
| Công cụ | `Tools.Core/UI/Worker.ps1`, `Care.*`, `Restore.UI`, `WizTree.*` | Lệnh cố định; xác nhận trước mutation; worker; đọc lại kết quả; WizTree mở ổ C trực tiếp |
| Theo dõi/chẩn đoán | `Monitor.Core/UI/Native`, `Logs.Core/UI`, `Diagnostics.UI` | Runspace chỉ đọc, cập nhật trên dispatcher, không coi dữ liệu thiếu là số 0 |
| Đóng gói/compatibility | `Build-*`, `Prepare-*`, `Sign-*`, `Command*`, `Launcher.cs` | Tool tác giả/entry cũ vẫn tồn tại; entry online hiện tại dùng PowerShell, không cần đổi sang EXE |

Dữ liệu dùng `$PSScriptRoot` hoặc LocalAppData, không phụ thuộc thư mục terminal hiện tại. Ngôn ngữ Việt dùng UTF-8; nguồn PowerShell trên đĩa cần BOM khi có ký tự ngoài ASCII. Entry HTTP cố ý không BOM.

## Phát hiện và xử lý

Không xác nhận P0 trong phần đã kiểm tra. Điều này không chứng nhận mọi mutation Windows là an toàn trên mọi build.

| ID | Mức | Bằng chứng / nguyên nhân | Xử lý local |
|---|---|---|---|
| A01 | P1 | `FolderDiscovery`/`Set-FullTree` thiếu `Change.Type`; lỗi sau khi xóa Bags/BagMRU; restore cũng lỗi | Bổ sung kiểu; adapter mock; giới hạn root đúng ranh giới; validate cả snapshot trước xóa. `FullTweaks.Native.ps1:77` |
| A02 | P1 | Undo không liên quan vẫn ghi lại journal và đổi Pending -> Partial; apply chỉ chặn Pending | Không viết journal không liên quan; giữ khóa cho đến recovery; chặn Partial cũ có Writing/Failed. `FullTweaks.Core.ps1:238` |
| A03 | P1 | Backup được ghi nhưng chưa flush bền vững; kiểm tra foreign content sau khi đã xóa giá trị; recovery After=null chặn cả trường hợp chưa ghi | Flush(true)/atomic replace; kiểm tra ngoại lai trước xóa; so current với Before trước khi yêu cầu After. `FullTweaks.Core.ps1:24`, `FullTweaks.Core.ps1:102` |
| A04 | P1 | WaitOne có thể ném AbandonedMutexException sau crash; full worker có thể không mở được recovery tiếp | Xác định ownership, release/dispose trong finally; test mutex riêng bị child fixture bỏ lại. `FullTweaks.Core.ps1:47`, `FullTweaks.Worker.ps1`, `WinTune.ps1` |
| A05 | P1 | Closing dùng `$args.Cancel` trùng biến tự động; chỉ xét HasExited bỏ khoảng chờ nhận result | Dùng eventArgs; giữ cửa sổ cho đến khi xử lý result; timer dừng khi đóng. `Actions.UI`, `Tools.UI`, `Copilot.UI`, `WizTree.UI`, `FullTweaks.UI`, `UnifiedTweaks.UI` |
| A06 | P1/P2 | Process giữ trong UI không Dispose; sau Dispose một guard vẫn đọc HasExited | Complete-ToolJob chung, guards dựa Handled; full job release riêng; regression đổi tool sau hoàn tất. `Tools.UI.ps1:17` |
| A07 | P1 | Get-AppxPackage/đọc manifest và chuẩn bị preview chạy ngay trên dispatcher | Chuyển inventory/plan sang worker cố định; timeout 60s/hủy riêng reader; không kill mutation. `Actions.UI.ps1:203`, `Tools.Worker.ps1` |
| A08 | P1 security | Cache tự đối chiếu với SHA256.txt trong cùng thư mục; chỉnh cả code và checksum có thể qua | Bootstrap template xác minh inventory với ZIP có hash trong manifest đã ký. Cache ZIP cũng kiểm lại mỗi lần. `Distribution.Core.ps1:167`. Chưa deploy; còn trust/race giới hạn ở SECURITY_REPORT |
| A09 | P2 | JSON hợp cú pháp nhưng sai kiểu ExitCode có thể làm formatter throw; hủy reader lỗi có thể mất phân loại reader | Validate envelope/Id/exit code/rows; giữ reader classification nếu Kill thất bại; retry không biến thành mutation. `Tools.UI`, `Actions.UI`; mock tests |
| A10 | P2 | FullGroup SelectionChanged render, sau đó gọi render lần nữa lúc tạo trang | Bỏ lần gọi dư, giữ nguyên 111 mục và không cache trạng thái Windows. `FullTweaks.UI.ps1:47` |
| A11 | P2 testing | Parser đọc hosted get.ps1 bằng ANSI; legacy launcher không có baseline vẫn bị báo chung tất cả PASS | Đọc hosted text bằng UTF-8; runner ghi rõ SKIPPED cho legacy comparison. `Run-Tests.ps1` |
| A12 | P2 | Batch WinGet gom exit code 3010 về 0 và UI cài đặt ghi đè cảnh báo restart | Giữ RestartRequested trong kết quả tổng và nhắc người dùng tự restart; không tự reboot. `Tools.Core/Worker/UI.ps1`; fixture + WPF test |
| A13 | P1 rollback | Read-FullRegistry dùng so tên phân biệt hoa/thường dù Windows không phân biệt; có thể coi giá trị cũ là vắng | Dùng so tên không phân biệt hoa/thường để sao lưu/hoàn tác đúng; mock OWNED/owned. `FullTweaks.Core.ps1:79` |

## Kiểm tra chức năng và rollback

[Ma trận từng mục](AUDIT_FEATURE_MATRIX.md) liệt kê 113 catalog entries, 44 mục cũ, 17 phần mềm và 30 app gợi ý. Catalog/hash gốc giữ nguyên. Các test generic chứng minh dispatch, preview/apply/undo bằng mock; test adapter bổ sung chứng minh một số ánh xạ API. **Không đồng nghĩa 113 mutation đã chạy trên Windows thật.**

Đã kiểm tra theo đường logic: quyền/confirmation, min build, ID/target allowlist, trạng thái trước/đích/sau, thao tác lặp, key vắng/chuỗi rỗng/kiểu Registry, partial failure, journal hỏng, ngoại lai, rollback theo thứ tự ngược, không tự reboot. Registry state match chỉ chứng minh giá trị khớp, chưa chứng minh Windows đã sử dụng chính sách đó.

DPAPI CurrentUser không bảo vệ trước chương trình chạy cùng tài khoản. System Restore khác undo cấu hình; gỡ Appx chỉ có thể cài lại khi có nguồn phù hợp; xóa dữ liệu, giải mã, công cụ bên ngoài không được quảng cáo là phục hồi dữ liệu tự động. Journal native không thể đảm bảo giao dịch nguyên tử khi mất điện giữa mọi API; Flush cải thiện độ bền nhưng cần thử crash/power-loss trên VM riêng.

## Chất lượng mã, UI và phần chưa sửa

- WPF controls chỉ cập nhật ở dispatcher. Monitor dùng số slot hữu hạn, không tạo job mới khi slot đang chạy; history tối đa 60 samples; theme windows dùng weak references. Không thêm GC.Collect hay pool/cache không có số đo.
- Không loại bỏ engine cũ, EXE wrappers, power/cleanup/update handlers chỉ vì sidebar không còn dùng: còn đường compatibility, lịch sử hoặc test tham chiếu. P3: có thể thu hẹp riêng sau khi kiểm tra migration và packaging.
- Catalog bounded 111 cards nên chưa thay kiến trúc sang virtualization. Lọc/render lại vẫn là O(n); stress với danh mục lớn hơn hoặc lịch sử dài chưa đo.
- Các catch rỗng ở nhãn app/sự kiện/DNS có fallback hoặc tiếp tục ứng viên; không coi chúng tự động là thành công mutation. Chưa thay hàng loạt bằng logger.
- Native tool chờ trong worker có thể chạy lâu; cố ý không kill DISM/SFC hay installer đang sửa máy. Shutdown monitor dọn runspaces sau dialog; độ trễ khi Windows provider bị kẹt vẫn cần thử riêng.
- Chưa chứng minh không có memory leak dài hạn, tương thích mọi edition/build, mọi mức DPI hoặc tác dụng của chính sách undocumented. Xem TEST_REPORT và PERFORMANCE_REPORT.

## Nguồn nghiên cứu đã truy cập

- [Microsoft WPF threading model](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/threading-model): giữ dispatcher work nhỏ, không chạm controls từ background.
- [PowerShell encoding 5.1](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-5.1), [automatic variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-5.1).
- [Process.Dispose](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.dispose?view=netframework-4.8.1), [AbandonedMutexException](https://learn.microsoft.com/en-us/dotnet/api/system.threading.abandonedmutexexception?view=netframework-4.8.1).
- [PowerShell performance](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations?view=powershell-7.5): tham khảo phương pháp, không suy các số đo PowerShell 7 thành kết quả 5.1.
- [WinUtil](https://github.com/ChrisTitusTech/winutil), [Win11Debloat](https://github.com/raphire/Win11Debloat), và snapshots ghim trong `sources/`. Không nhập thêm chức năng từ upstream.
- [Pester mocking](https://pester.dev/docs/usage/mocking): đã tham khảo; dự án hiện dùng các script assertion/mock độc lập, không cài thêm Pester.

Registry casing được đối chiếu với [Microsoft RegistryKey.GetValue](https://learn.microsoft.com/en-us/dotnet/api/microsoft.win32.registrykey.getvalue).

## Rà soát chức năng bổ sung cho v0.16.4

Theo yêu cầu kiểm tra thêm rồi đưa lên GitHub, đã rà độc lập lần nữa các nhánh áp dụng/hoàn tác, native adapter, worker/UI và đóng gói. Không thay catalog hoặc thêm chức năng.

| ID | Mức | Bằng chứng | Xử lý |
|---|---|---|---|
| A14 | P1 rollback | Khóa mới có nhiều giá trị của cùng đợt bị coi là dữ liệu ngoại lai; undo thất bại | Chỉ chấp nhận sibling cùng journal có Before vắng và current khớp chính xác After; từ chối ngoại lai trước xóa; kiểm thử bằng fake RegistryKey qua đường production |
| A15 | P1 recovery | Native gỡ ứng dụng lỗi trước khi đổi trạng thái vẫn bị skip undo, khóa Pending | Đọc current và xác minh bằng Before trước khi skip thao tác không thể hoàn tác; loại trừ marker opaque OOSU/DiskCleanup. Lỗi có thay đổi thật/không rõ vẫn khóa để kiểm tra |
| A16 | P1 correctness | WindowsAI nuốt lỗi servicing, coi Recall vắng; có thể gỡ app rồi mới phát hiện gói khác được bảo vệ | Truy vấn đầy đủ với ErrorAction Stop; preflight pending/protected trước registry/app mutation; writer kiểm tra lại. 30 native adapter checks |
| A17 | P1 rollback | Giá trị Registry ban đầu thuộc kiểu không hỗ trợ có thể bị thay nhưng undo không phục hồi được | Từ chối snapshot không thể phục hồi ngay tại bước chuẩn bị trước mutation; kiểm tra cả snapshot cây |

Các kiểm tra thay đổi Windows dùng mock. Khi gỡ/xóa/giải mã thật thất bại một phần, WinTune không hứa tự undo hoặc tự bỏ khóa an toàn; phải kiểm tra lịch sử và khôi phục điều kiện bằng công cụ phù hợp trong môi trường riêng.

User đã cho phép đưa bản vá lên GitHub sau kiểm thử. Phiên bản chuẩn bị: 0.16.4; không thay asset/tag 0.16.3. Trạng thái công khai và xác minh cuối được ghi riêng sau thao tác, không suy ra từ các test local.
