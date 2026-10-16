# WinTune VI — Báo cáo kiểm thử

Ngày 16/10/2026. Windows 11 Professional build 26300; Windows PowerShell 5.1.26100.9711 Desktop x64 STA; WPF có sẵn. Chỉ workspace fixtures, in-memory adapters và đọc hệ thống được phép. Không mutation Windows thật.

## Cách đọc kết quả

PASS ở unit/mock chứng minh đường logic đã chạy với fixture, không chứng minh Registry/service/Appx/repair thật trên mọi Windows. SKIPPED/UNAVAILABLE không được cộng thành PASS. Suite hiện có dùng assertion scripts; không cài framework/dependency mới.

## Kết quả chính

- `Run-Tests.ps1`: đã chạy đầy đủ sau các sửa chính và chạy các regression bổ sung theo thay đổi cuối; log `.audit/verified-final.log`, từng suite ở `evidence/`. Danh mục dưới đây lấy số thực trong log.
- `Audit.Regression.Tests.ps1`: bản cuối **19 PASS**, `.audit/regression-final.log`. Log hồi quy riêng giữ kết quả cuối, bao gồm snapshot Explorer không hỗ trợ và tên Registry khác hoa/thường. Lượt full runner chạy 18 case ở checkpoint; case casing thêm cuối được kiểm bằng lượt riêng 19 PASS trên nguồn cuối. Không cộng các lượt chạy lặp thành test mới.
- `WinTune.ps1 -SelfTest`: **310 PASS** WPF controls/isolated providers. `.audit/verified-final.log` và `.audit/ui-reviewed.log` và `evidence/UI.SelfTests.log`. Có thử timer responsiveness, đọc/preview async, đóng sau process exit, hủy reader, hủy bị từ chối, disposed Process guard.
- `WinTune.ps1 -GuiProbe`: **PASS** — cửa sổ chính và dialog có owner được ContentRendered rồi đóng thật; 111 unified features, 0 chọn, 0 write; DPI 1.25. `.audit/gui-final.log`, `evidence/gui-lifecycle.json`. Đây không phải thao tác chuột/bàn phím bên ngoài.
- Static parser toàn root: **114 PowerShell files**, **9 JSON** và XML MainWindow hợp lệ tại thời điểm quét. `.audit/static.json`/`.audit/code-inventory.csv`. Hosted get.ps1 được giải mã UTF-8 như đường HTTP.

| Suite | Kết quả có đếm |
|---|---:|
| FullTweaks.Tests | 358 PASS |
| FullTweaks.Native.Tests | 18 PASS |
| FullTweaks.Debloat.Tests | 563 PASS |
| FullTweaks.Profiles.Tests | 135 PASS |
| Actions.Tests | 42 PASS |
| Core.ExtendedTests | 100 PASS |
| Tools.Tests | 63 PASS |
| Tools.Worker.Tests | 20 PASS |
| Monitor.Tests | 25 PASS |
| Theme.Tests | 29 PASS |
| Usability.Core.Tests | 23 PASS |
| Registry.Typed.Tests | 8 PASS |
| Coverage.Tests | 69 PASS |
| Distribution.Tests | 79 PASS |
| Release.Author.Tests | 31 PASS |
| SourceCommand.Tests | 17 PASS |
| Setup.Tests | 22 PASS |
| QuickLauncher.Tests | 10 PASS |
| UX.Core.Tests | 12 PASS |
| WizTree.Tests | 14 PASS |
| WizTree.Launch.Tests | 15 PASS |
| UpdateStatus.Tests | 8 PASS |
| Care.Core.Tests | 13 PASS |

Core.Tests và Environment.Check cũng PASS; không tạo số assertion khi script không báo tổng. Catalog.Verify đối chiếu 51 DWORD, 5 REG_SZ, 31 choices, 17 software IDs và 30 app names với snapshots ghim; điều này không thay thế thử tác dụng Windows.

## Phạm vi lỗi đã thử

- Key/value vắng, kiểu dữ liệu/chuỗi rỗng/typed API, target bị sửa, no-op, thao tác lặp, conflict sau preview.
- Failure trước/giữa/sau write bằng mock; Pending giữ recovery; undo không liên quan không mở khóa; ngoại lai không bị ghi đè; DPAPI corruption; đường ngoài root bị từ chối.
- Native adapters DNS, services, BitLocker/AI/temp result giới hạn, hosts bảo toàn bytes; tất cả writer hệ thống được mock.
- HTTP timeout/error/retry/redirect/size, wrong RSA key/signature/tag, ZIP traversal/duplicate/symlink/size, inventory tamper, signed-cache tamper, fake newer version, Unicode/spaced paths, canceled install/UAC bằng mock.
- Startup/shutdown, các dialog, sáng/tối, layout nhỏ, hover/scroll, chọn preset rồi custom, disabled controls, timer poll, cleanup Process. Render PNG ở `evidence/`.

## FAIL, SKIPPED và UNAVAILABLE

| Mục | Trạng thái | Giải thích |
|---|---|---|
| Legacy compiled launcher A/B | SKIPPED | Không có `baseline-v0.14`; Launcher.Tests trả thông báo baseline unavailable, không tính PASS |
| Pages.Serving.Tests (loopback) | UNAVAILABLE — phép chạy thất bại | Invoke-RestMethod không nối được listener local trong môi trường; `.audit/pages-loopback.log`; chưa chứng minh nguyên nhân là app hay policy/proxy, không báo PASS |
| CIM CPU / Appx read native | UNAVAILABLE | Sandbox từ chối quyền; `.audit/read-performance.json` |
| Hardware overview native | PARTIAL | Có record/fallback nhưng một số CIM/provider không đọc được; không gọi là full hardware verification |
| Production bootstrap/manifest signature | NOT VERIFIED | Auto-review dừng lần tải do giới hạn sử dụng; không chạy Internet launcher |
| Mutation Windows thật | NOT TESTED theo yêu cầu | Không sửa Registry, gỡ/cài app, service, DNS, power, repair hoặc System Restore thật |
| CmdLauncher.Tests | NOT RUN | Cần Prepared package; giữ entry PowerShell là đường chính. Không dùng thiếu tham số tương tác làm kết quả kiểm thử |
| PowerShell 7 GUI, Windows 10, ARM64, x86 | NOT SUPPORTED/NOT VERIFIED | App entry yêu cầu Desktop; release khai báo x64/min build 22000; không tuyên bố hỗ trợ thêm |
| Nhiều edition/build/DPI 100–200% thực | NOT TESTED đầy đủ | Có fixture build 22000/22621/22631/26100/26300 và render scale 100/125/150%; runtime thực chỉ máy build 26300/DPI 125% |
| Soak dài hạn, mất điện, kill lúc native mutation | NOT TESTED | Cần VM snapshot/môi trường riêng |

Một lần harness đầu sai PSModulePath khi Start-Process từ PS7; lần sau ExitCode null; các kết quả đó bị loại khỏi kết luận. Lượt parser đầu dừng get.ps1 không BOM đã được sửa theo cách tải HTTP đúng. Những lỗi phát hiện trong quá trình sửa (ZIP backslash, event args, disposed guard) đều có log ban đầu và case hồi quy; không xóa test để đạt PASS.

## Kiểm tra thủ công còn cần trước phát hành

Trên VM snapshot: apply/undo mỗi nhóm nhạy cảm, nhiều thay đổi liên tiếp, crash trong write/backup/log, UAC từ chối và tài khoản khác, provider CIM treo, offline/GitHub 404/timeout thực, app bị khóa, DPI 100/150/200% trên màn hình thật, keyboard navigation và screen reader. Xác minh bản build/sign mới qua đường Pages chỉ sau khi chủ dự án cho phép phát hành.

Probe vòng đời 30 chu kỳ mô phỏng hoàn tất với 0 write; sau cleanup 0 monitor job, 3 timer chính dừng và process đã thoát. Private bytes có tăng và giảm tự nhiên, nên không chứng nhận không có leak dài hạn. Lượt đầu probe sai đường lưu trong harness; đã giữ log và sửa harness, không coi là lỗi ứng dụng.

## Lượt kiểm thử bổ sung trước v0.16.4

Lượt trước là checkpoint audit ban đầu. Lượt cuối trước phát hành dùng `.audit/qa-v0164-final.log`; không cộng các lần chạy lặp thành test mới. Native adapter bổ sung truy vấn Recall bị từ chối, pending restart và gói AI được bảo vệ. Audit regression bổ sung recovery trước gỡ và loại trừ opaque tool markers. Registry undo dùng API RegistryKey giả nhưng đi qua planner/writer/undo thật.

Pages.Serving.Tests đã được chạy lại ngoài sandbox bị chặn loopback: **5 PASS**, `.audit/pages-host-final.log`. Có redirect HTTP thật trên 127.0.0.1, MIME text/html, mocked lượt tải thứ hai, script con vô hại và cleanup. Lượt sandbox thất bại vẫn giữ trong log; đã xác định được phạm vi môi trường, không xóa lỗi cũ.

Git CLI chưa có credential sử dụng được; connector GitHub đang đăng nhập đúng chủ repository. Nguồn có thể đưa lên bằng GitHub API và bộ tải qua phiên GitHub trình duyệt; không tạo token hoặc thay quyền tài khoản.

Kết quả nguồn ổn định cuối: FullTweaks 358 PASS, Native adapter 30 PASS, Audit regression 26 PASS, Registry undo 18 PASS; parser 115 PowerShell/9 JSON/MainWindow XML PASS. Full runner đã chạy RegistryUndo12 tại checkpoint trước khi thêm 6 case snapshot; lượt riêng cuối 18 và FullTweaks358 sau sửa đã PASS, không cộng lượt lặp. Raw log riêng được giữ trong .audit; các thay đổi Windows đều được mock.

Run-Tests.ps1 lượt cuối kết thúc exit 0: 310 WPF checks PASS và tất cả suite khả dụng PASS; legacy compiled launcher A/B SKIPPED do thiếu baseline. Log .audit/qa-v0164-final.log. Thay đổi guard snapshot thêm cuối được chạy riêng RegistryUndo18/FullTweaks358 sau khi nguồn ổn định. Không có regression xác nhận được trong phạm vi mô phỏng đã chạy.

Kiểm thử artifact phát hiện SelfTest chạy trực tiếp trên ZIP mới chưa có thư mục evidence để lưu ảnh. Đã bổ sung tạo thư mục trong UI.SelfTests.ps1; không thay runtime Windows. Bản build trước sửa được giữ làm log thất bại, không phát hành. CmdLauncher fixture đạt 17 assertions (không chạy launcher Internet).

Artifact cuối v0.16.4: chữ ký manifest bằng khóa RSA gốc PASS, ZIP 787977 byte / SHA256 F2C8AAC9AD4035C6370FE1DFF261843F33499EF473549A5972B2A36D7729F6EA PASS, inventory và parser bootstrap PS5 PASS. SelfTest trực tiếp trên ZIP mới: 310 PASS; GuiProbe PASS, 111 mục/0 chọn/0 write. Log .audit/package-ui-v0164-final.log, .audit/package-gui-v0164-final.log và artifact-validation.json. Không có private key/evidence trong gói public. Các dòng UNAVAILABLE/NOT RUN ở bảng checkpoint cũ cần đọc cùng các kết quả bổ sung Pages5 và CMD17 ở trên; không phải mutation Windows thật.
