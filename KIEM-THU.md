# Bằng chứng và kiểm tra còn lại

Ngày 14/10/2026: Windows 26300.9550 Professional 26H2; Windows PowerShell
5.1.26100.9549 x64 STA; WPF .NET Framework 4.

## Đã thực hiện

| Kiểm tra | Kết quả | Phạm vi |
|---|---|---|
| Parser 5.1 | Qua | Tất cả script dự án |
| Core.Tests.ps1 | 18 qua | Registry mô phỏng |
| Core.ExtendedTests.ps1 | 71 qua | Lỗi ghi/sao lưu, lỗi hoàn tác, xung đột, tiền kiểm quyền, Widgets/Edge, dữ liệu sai, lịch sử v0.2 và Demo; registry mô phỏng |
| Actions.Tests.ps1 | 33 qua | Gỡ đúng gói giả, app đang chạy, lỗi sau ghi, lịch sử bền vững/mã hóa, sao lưu trước ghi, phục hồi Startup và xung đột; không gỡ app thật |
| WPF SelfTest | 78 qua | Handler thật: chọn/lọc, xem trước/hủy, gỡ app giả, lỗi giữa đợt, phục hồi Startup, mở Store giả; provider và xác nhận mô phỏng |
| Catalog.Verify.ps1 | 22 mục / 32 DWORD + 9 loại app khớp | Win11Debloat, Microsoft và danh mục WinUtil ghim; không chứng minh hiệu lực Windows |
| Actions.ReadCheck.ps1 | 3 app / 4 mục khởi động | Windows thật, chỉ đọc; hash HKCU Run trước/sau khớp, không gỡ app/không tạo nhật ký thao tác |
| VM.Verify.ps1 | 45 xác nhận | Chặn bộ chạy thật trên host; 32 DWORD host không đổi; bốn kịch bản MEMORY |
| RealRead.Check.ps1 | Qua | Đọc 29 giá trị thật, xem trước không ghi/không tạo đợt |
| WPF ReadOnlyProbe | Qua | Cửa sổ và hộp thoại Owner thật phát ContentRendered; DPI 125%; tự đóng, khóa ghi |
| Snapshot trước/sau ReadOnlyProbe | Không đổi | 29 giá trị app quản lý, không phải toàn bộ registry |
| Launcher Demo /probe | Mã thoát 0, bằng chứng mới | WPF mô phỏng mở rồi tự đóng |
| Ảnh RenderTargetBitmap | Đã xem/sửa sidebar | 3 kích thước × 100/125/150%, không đổi DPI máy |
| ZIP giải nén có dấu/khoảng trắng | Qua | SHA-256 mọi tệp khớp; launcher /probe thoát 0; nguồn đóng gói khớp |
| Bộ chạy VM — token thường | 16 vòng ghi/hoàn tác, 2 no-op, 1 chặn quyền | Báo cáo guest thật qua ảnh; Bing bị chặn |
| Bộ chạy VM — người dùng mở với quyền quản trị | 17 vòng ghi/hoàn tác, 2 no-op | Báo cáo guest thật qua ảnh; Bing ghi và hoàn tác được; chưa xác nhận tác dụng tìm kiếm |

Log ở `evidence`. Ảnh `render-*.png` dựng từ cây WPF, không phải ảnh desktop.
SelfTest gọi handler Preview/Undo/History thật nhưng tiêm câu trả lời hộp xác
nhận để không chờ người hoặc ghi thật. /probe xác nhận vòng đời, chưa xác nhận
các cú nhấp/chuột/bàn phím từ bên ngoài.

## Phạm vi mới của 0.5

Tổng 200 kiểm tra mô phỏng qua: 18 Core + 71 mở rộng + 33 Actions + 78 WPF.
Hai ảnh app-manager-render.png/startup-manager-render.png đã dựng và xem,
chữ tiếng Việt xuống dòng/cuộn; đây là RenderTargetBitmap, chưa phải thao tác
desktop trực tiếp cho hai cửa sổ mới. Chưa gỡ/cài lại app hoặc sửa khởi động
thật trong guest; chưa xác minh Edge qua edge://policy hay đo mức giảm RAM.
Kết quả VM 17 vòng thật bên dưới thuộc danh mục 0.3, không áp dụng cho chức
năng mới. Bộ chạy VM hiện chỉ kiểm tra registry, không kiểm tra gỡ/startup.
Danh mục gỡ giới hạn 9 loại app cho tài khoản hiện tại; Windows khác có thể
không cài những app này. Không coi danh sách trống là đã gỡ thành công.
Nhật ký Appx chỉ lưu danh sách gói/phiên bản/cài lại, không sao lưu dữ liệu app.

Chạy lại kiểm thử an toàn trong thư mục mã nguồn:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Run-Tests.ps1
```

Chỉ tạo dữ liệu mô phỏng và log trong dự án. RealRead.Check.ps1 và
WinTune.ps1 -ReadOnlyProbe là các kiểm tra chỉ đọc riêng.

## Cần kiểm tra trực tiếp trên desktop

- Mở WinTune-Demo.exe, nhấp tên/đánh dấu và đối chiếu tên với chi tiết.
- Chọn hai nhóm, tìm kiếm có/không dấu, lọc/quay lại, bỏ chọn.
- Xem trước rồi đóng: không tạo đợt; xem trước rồi áp dụng trong Demo.
- Xem lịch sử, đóng/mở lại Demo, kiểm tra trạng thái giả vẫn còn.
- Xem trước hoàn tác và hủy, sau đó hoàn tác trong Demo.
- Cuộn ba cột tại DPI 100/125/150%; chuyển màn hình nếu có.
- Kiểm tra Tab, Space, focus bàn phím, nút xác nhận và đóng hộp thoại.
- Mở bản thật chỉ xem trạng thái; kiểm tra lỗi quyền/chính sách quản trị.

Computer-use từ chối mở WinTune-Demo hai lần vì chưa cấp quyền trong cấu hình
công cụ. Đồng ý trong chat chưa thay đổi quyền đó. Không coi ảnh dựng hoặc
ContentRendered là bằng chứng đã kiểm thử chuột trên desktop.

## Tích hợp thay đổi thật

Ưu tiên Windows Sandbox/máy ảo có snapshot. Chỉ thử máy chính sau khi chủ máy
xác nhận cụ thể từng mục và phương án khôi phục:

1. Ghi trạng thái registry, build/edition và hành vi Windows ban đầu.
2. Chọn riêng một mục; lưu xem trước và vị trí bản sao.
3. Áp dụng, đọc lại; nếu cần, chủ máy tự đăng xuất/mở lại ứng dụng.
4. Kiểm tra hành vi và ảnh hưởng đã giải thích.
5. Hoàn tác, xác minh giá trị/trạng thái chưa tồn tại và hành vi trở lại.
6. Giữ log; không ép ghi khi xung đột.

Ứng viên đầu tiên: Hiện phần mở rộng tệp, khôi phục HideFileExt. Chưa ghi mục
nào trên máy chính. Search/Bing, Game DVR và gợi ý cần thử riêng từng bản/edition.

## Kết quả thử có người thao tác trong máy ảo

Ngày 13/10/2026, Windows 11 Professional build 26300, máy ảo WinTune-Test:
ảnh người dùng xác nhận cửa sổ mô phỏng mở được, giữ hai mục chọn thuộc hai
nhóm trong xem trước, áp dụng và hiển thị lịch sử hai giá trị, hoàn tác mô
phỏng báo đã phục hồi. Chưa xác nhận riêng tìm kiếm, thao tác bàn phím hoặc
lịch sử sau đóng/mở bằng ảnh.

Với bản thật, ảnh xem trước ghi HideFileExt 1 -> 0 và lịch sử báo đã ghi/
xác minh. Explorer ban đầu chưa hiện đuôi ngay sau ghi. Người dùng báo đuôi
đã hiện sau khởi động lại riêng VM, và đã ẩn lại sau hoàn tác. Đây là bằng
chứng kết hợp ảnh và báo cáo người dùng cho một mục, chưa có đọc registry
độc lập sau hoàn tác. Chi tiết từng bước ở TIEN-DO.md.

## Giới hạn

Bản 0.4 thêm ẩn thời tiết/Widgets và ghi chú quyền quản trị trong tên Bing.
150 kiểm tra mô phỏng qua. Widgets mới chưa thử tác dụng hoặc hoàn tác thật
trong máy ảo; bảng kết quả guest 17 mục phía trên thuộc danh mục 0.3.

Sau lỗi áp dụng 19 mục do quyền ghi nhánh Policies trong guest, đã bổ sung
tiền kiểm quyền toàn đợt và cập nhật UI phục hồi trước hộp lỗi. 138 kiểm
tra mô phỏng qua (18 core, 64 extended, 56 WPF). VM.Verify.ps1 có 42 xác
nhận qua trên máy chính: chặn 3 chế độ thật trên host, 29 giá trị host không
đổi, bốn kịch bản bộ chạy dùng MEMORY. Bộ kiểm tra một lần trong guest ở
Kiem-Thu-May-Ao.cmd; xem KIEM-THU-TU-DONG.txt. Chưa có kết quả chạy thật của
bộ này trong guest tại thời điểm tạo gói. Sau đó người dùng gửi đủ báo cáo
đợt run-036d36408f9743cf9efac9ec5e49fe93: 16 mục đạt vòng ghi/đọc/lịch sử/
hoàn tác thật, 2 mục ads/tailored chỉ no-op, bing bị chặn quyền; không có
fatal trong báo cáo. Hai mục Settings không thử ghi. Đây là bằng chứng qua
ảnh báo cáo, chưa có JSON/journal lấy ra để đọc độc lập. Sau khi được hướng
dẫn Run as administrator, người dùng gửi báo cáo thứ hai có 17 vòng ghi/
hoàn tác đạt, gồm Bing; ads/tailored vẫn chỉ no-op. Chưa xác nhận tác dụng
Windows của các mục chỉ từ kết quả registry. Luồng UAC thực tế không được
công cụ trực tiếp quan sát; biết kết quả qua báo cáo.

- 17 mục có báo cáo vòng ghi/đọc/lịch sử/hoàn tác thật qua ảnh trong VM khi
  người dùng chạy với quyền quản trị. Hai mục chỉ no-op. Một tùy chỉnh (Hiện phần mở rộng
  của tệp) còn được người dùng báo có hiệu lực và hoàn tác hành vi trong VM;
  18 tùy chỉnh còn lại chưa xác nhận hiệu lực hành vi Windows.
- Chưa thử Windows 10, ARM64, nhiều màn hình hoặc mọi cập nhật Windows 11.
- Bản 0.5 đã có trình quản lý gỡ Appx/tự khởi động riêng; chưa thử thay đổi
  thật/cài lại app, chưa chứng minh giảm RAM. Hai mục Settings cũ vẫn chỉ mở Settings.
- EXE chưa ký số, cần toàn bộ thư mục portable.
- Phát hiện xung đột theo giá trị hiện tại; không phát hiện sửa rồi trả lại cùng
  giá trị, hoặc bảo đảm loại trừ việc phần mềm khác sửa ngay giữa đọc và ghi.
- Phục hồi giá trị, không phục hồi cây registry/dữ liệu app; khóa trống có thể
  còn. Không tạo System Restore Point.

## Cập nhật 0.6 — 14/10/2026

293 kiểm tra tự động: Core18, Extended71, Actions42, Tools56, Worker16,
WPF90. Mọi thao tác sửa/xóa/cài/gỡ dùng mô phỏng hoặc writer/filesystem mock.
Worker16 gồm13 yêu cầu Simulation và2 checks từ chối start/UAC bằng hàm
Start-Process mock: không khởi động lệnh Native. Trường hợp file đổi size/
mtime dùng filesystem/handle writer mock, không tạo/xóa TEMP thật. WPF event/
handler/dispatcher trên Windows PS5.1, worker2200ms, timer WPF tiếp tục chạy.

Native read-only0.6: CPU/GPU/RAM/bo mạch/Windows/drives/driver lỗi/Defender/
Firewall/TPM/SecureBoot có dữ liệu/lỗi/quyền đúng thực tế. WinGet--version
v1.29.380,4 power plans, /getactivescheme trước/sau khớp, không setactive.
Log evidence/tools-read-only.json. Chưa native install/upgrade/repair/cleanup/
power/restorepoint/appx/startup mới/UAC worker. Không chạy ghi thật để chứng
minh test. Native VM autotest bị chặn theo yêu cầu mới, CMD gọi Run-Tests.
Ảnh tools/app/startup manager được dựng và xem, không desktop screenshot.
Parser/XAML/C# helper qua; package ở evidence/package-check.log. Chưa mọi
Windows/build/DPI/màn hình/ARM64 hoặc chuột desktop. Không tuyên bố mọi chức
năng đã có hiệu lực thật. Nội dung0.3–0.5 phía trên là bằng chứng lịch sử.
Native read-only thêm cho code0.6: Actions.ReadCheck qua với10 Appx được phép
trong inventory và4 HKCU Run, fingerprint không đổi;0 gỡ/sửa/journal.
Chỉ đọc lớp inventory/protection mới; không chứng minh gỡ/cài lại. Logroot
mới cập nhật sau đóng gói (gói giữ bằng chứng read-only cũ3 app của0.5).
## 0.7 — Settings và monitor (2026-10-14)

328 assertions:18+71+42+56+16+20+105. Mọi bài thử thay đổi Windows dùng mock.
Monitor.Tests kiểm tra CPUdelta/idle/reset, GPU aggregate/LUID/100%, mạng
elapsed/interface mới/reset, 64-bit VRAM và CIM lỗi. Monitor.UI.Tests kiểm tra
unknown/demo label, cập nhật mẫu mới, loại mẫu cũ, pause/resume/navigation,
3 kích thước ×3 scale, bộ đọc async không chặn dispatcher và không ghi.
Native chỉ đọc: Monitor.ReadCheck ba mẫu, UI.MonitorReadProbe bộ đọc sản xuất
và WPF thật ba mẫu; zero writes, selected0. Evidence monitor-read-only.json,
monitor-ui-read-only.json, dashboard-native.png. Không thay đổi host/guest.
Đã xem ảnh dựng dashboard native và900x560; ngoại tác chuột desktop chưa thử.
Không dùng kết quả native0.3 hoặc mock để khẳng định hiệu lực tweak0.7.

## 0.8 — kiểm thử giao diện

373assertions:18+71+42+56+16+20+29+121. Theme29: resolver, lưu/đọc3mode,
ID sai/corruptJSON/array/version khác, file bị khóa, atomic và contrast>=4.5.
WPF thêm16: đổi ngay các cửa sổ/hộp thoại, accentforeground, giữ input/chọn,
Systemreader mock chuyểnLight/Dark, manualmode không đổi theo system, watcher
bật/tắt, zero registry writes. Ảnh theme-light/dark và theme-tools-light/dark
được xem, nền ảnh dùng brush thật. Không đổi Windows theme thật để thử.

## 0.9 — board/hover
398assertions:18+71+42+56+16+20+29+146. Board16 vàHover9 WPF: profiles
resetfilter, all-selected names/chips/filter, detaildrawer, 1280/900 cards
nằm ngang ở2theme; template giữ3columns, hover/selected opaque theo màu.
Hoverfixture trigger có kiểm soát, không desktop pointer. Toàn bộ writesmock.
Ảnh board-dark-1280, board-light-900, process-hover-dark/light đã xem.

## 0.10 — giao diện gọn (2026-10-14)

406 assertions:18+71+42+56+16+20+29+154. WPF kiểm tra không còn danh mục
lặp/slogan, Chọn nhanh và Đọc lại nằm trên bảng, hồ sơ bỏ bộ lọc cũ, chuyển
Tổng quan/Tùy chỉnh không mất lựa chọn, input không chồng nhau và các nút
Hoàn tác/Lịch sử hiện trực tiếp. Giữ mọi kiểm tra ghi/đọc/xem trước/hoàn tác,
worker bất đồng bộ và theme/hover. Bố cục ở1180x800/1024x650/900x560,
bảng1280/900 tối/sáng; ảnh dựng scale100/125/150%, không đổi DPI Windows.

Đã xem ảnh dựng tối1280 và sáng900. Lỗi fixture IsVisible qua Window chưa
Show đã sửa bằng bounds đã arrange; không phải lỗi nút trong app thật.
Không tự di chuột hoặc áp dụng tinh chỉnh để thử. Mọi bài thử thay đổi
hệ thống vẫn mock. Nguồn/hiệu lực/native read của bản trước giữ đúng phạm vi.

## 0.11 — thao tác trực tiếp và thông báo dễ hiểu

458 assertions:18+74+42+56+16+20+29+23+5+175. Hai bộ mới kiểm tra chuỗi
registry/phạm vi/tampering, API RegistryKey giả và không xóa nội dung ngoài;
SFC/DISM/disk kết luận rõ hoặc unknown, sự kiện41 không suy ra lỗi nguồn,
CIM/quyền từng nguồn độc lập. WPF175: kiểm tra một nút không mở Tools,
khôi phục có giải thích/hủy/worker, software trực tiếp không update menu,
hyperlink, profiles có chọn lọc và bánh xe tổng hợp cuộn trang ngoài.

Đã xem ảnh security/restore/software/app manager. Native đọc bảo mật và
63 events, zero log-read failures ngoài sandbox; restore list quyền từ
chối và giữ unknown. Không dùng native read để chứng minh các thao tác
ghi/gỡ/cài/sửa mới. Không đổi registry thật hoặc chạy sửa chữa để thử.

## 0.12 — cập nhật tiến trình và giao diện không khóa áp dụng

483 assertions:18+82+42+56+16+25+29+23+5+187. Thêm kiểm tra file giao diện
và nhật ký chung thư mục, lưu/đọc lại/khởi động lại/hoàn tác; file hỏng thật
và đợt Pending vẫn khóa, chọn nhanh không che cảnh báo. Mock tiến trình
xác minh top10, lỗi đọc/thoát và giải phóng handle. WPF dispatcher xác minh
bảng cập nhật khi cảm biến đang chậm, RAM thay thứ tự, giữ PID, không nhận
mẫu cũ, tạm dừng và không thay đổi Windows.

Native WPF read-only ngoài sandbox:5 lần cập nhật độc lập trong10.85 giây,
10 hàng/lần, timestamp tăng, zero process errors, zero system writes.
Sandbox chỉ thấy4 tiến trình và CIM bị hạn chế; đã xác minh riêng ngoài
sandbox để không coi dữ liệu đó là toàn bộ máy. Ảnh WPF tại dashboard-process-live.png;
JSON tại monitor-ui-read-only.json. Không tự dùng chuột hoặc áp dụng tối ưu
trong máy ảo để chứng minh. Mọi bài thử thao tác thay đổi hệ thống đều mock.
## 0.13 — đối chiếu tính năng, lựa chọn và danh mục ứng dụng

599 assertions:18+100+42+56+16+25+29+23+8+69+213. Source verification:
51 DWORD+5 REG_SZ,31 lựa chọn,30 Appx và234 phần mềm khớp nguồn ghim.
69 mới kiểm tra mọi choice qua preview/apply/reinitialize/undo mô phỏng,
chuỗi mouse gốc, target ngoài danh sách, choice trộn và gói gaming bảo vệ.
Typed API8 xác minh mouse REG_SZ qua RegistryKey giả. WPF213 gồm giữ các
bài trước và kiểm tra dropdown/chip, giá trị chính xác, hủy, hoàn tác sau
đổi lựa chọn, danh mục/tìm/lọc software, không chấp nhận điều khoản, theme.

Native chỉ đọc ngoài sandbox:56 giá trị,21 đề xuất, zero writes/journals.
Không áp dụng các tính năng mới hoặc gỡ/cài phần mềm thật để thử. Không
khẳng định234 installer đã chạy hoặc mọi tweak có hiệu lực trên mọi build.
Ảnh software-expanded/app-manager/board được dựng từ WPF fixtures,
không phải tự thao tác chuột trong máy ảo. Các giới hạn0.12 giữ nguyên.
## 0.14 — bảng cài ứng dụng rút gọn

616 assertions đạt: 18 Core + 100 Extended + 42 Actions + 60 Tools +
16 Worker + 25 Monitor + 29 Theme + 23 Usability + 8 Typed + 69 Coverage +
226 WPF. Mọi thao tác thay đổi Windows đều dùng mock/simulation.
Không gỡ/cài ứng dụng, xóa file tạm, sửa registry, chạy sửa chữa hay đổi plan thật.

WPF tại 1180×800, 1024×650, 900×580: cùng chiều rộng/chiều cao ô, cột tự
đổi, nút cài/đồng ý/đóng trong khung, chỉ một vùng cuộn danh mục. Kiểm tra
17 ứng dụng mở với lựa chọn0, tìm UniKey và công dụng tiếng Việt, tên thật
trong xem trước, hủy không chạy worker. Các bài lọc/giữ lựa chọn cũ vẫn đạt.
Ảnh software-curated-dark/light.png dựng từ WPF với lựa chọn/đồng ý trống,
không phải tự thao tác bằng chuột trên máy ảo. Theme Theo hệ thống giữ các
bài thử cũ. Chưa kiểm thử trực quan mọi DPI/build hoặc cài thực tế 17 app.

Source verifier khớp 16 ID WinUtil + UniKey từ winget-pkgs, SHA256 nguồn/
LICENSE, bản4.6.230919/x64 và URL bộ cài của unikey.org. Tools mock kiểm tra
show/install cùng pin x64, list không ghim version, tham số không ghi đè
version/architecture và các ứng dụng khác không bị ghim. WinGet không có
cờ force/ignore hash/override/allow reboot hoặc đồng ý điều khoản mặc định.
Giới hạn của các bản trước giữ nguyên; source match không chứng minh
installer đã chạy hoặc tác dụng thực của mọi tinh chỉnh.

## 0.15.0 — khởi chạy/phân phối

695 assertions:18+100+42+60+16+25+29+23+8+69+67+238. PowerShell5.1
và module/XAML được kiểm tra; tính năng cũ vẫn đạt. Distribution67 dùng
RSA thật với khóa thử trong bộ nhớ, HTTP transport giả (không DNS/socket),
registry/environment giả. Phần filesystem chỉ tạo fixture trong workspace.
Kiểm tra chữ ký/khóa/tag/checksum sai, URL/redirect, lỗi HTTP/retry, giới
hạn byte, traversal/ADS/tên Windows/ZIP trùng, hủy, tài nguyên thay đổi,
không tải trước xác nhận, current pointer/không downgrade, ký metadata,
PATH/App Paths/idempotence/xung đột/rollback và bỏ đăng ký dang dở.

WPF238: mở không có worker/timer/network tự chạy; thiếu repo/khóa có giải
thích; xác nhận/hủy, dispatcher vẫn hoạt động, đóng/hủy/dispose, hai theme.
Các ảnh distribution-dark/light.png là render mô phỏng, không phải thao
tác desktop hoặc chứng minh PATH/Win + R thật. Module lazy import được sửa
để các handler vẫn tìm được hàm sau khi mở cửa sổ.

C# launcher/resolver biên dịch được. Một số lần thử fixture ban đầu đã
chạy launcher/child/probe, nhưng Application Control sau đó chặn EXE mới
biên dịch, cả fixture và EXE gói. Không thay/bypass chính sách. Không tính
các bài EXE bị chặn là PASS; xem Launcher.Tests.ps1.log và package-v015.json.
Chưa xác minh native CMD/PATH/Win + R hoặc startup/RAM so sánh trên host.
Wrapper được đổi để không giữ process khi mở thường; chưa có số phần trăm
hiệu năng. Không thử PS2EXE; chọn giữ C# + đầy đủ file PowerShell/WPF.

Gói được kiểm checksum và mở/đóng WPF bằng PowerShell trực tiếp -GuiProbe
mô phỏng khi EXE bị chặn. Không thực hiện cài vào LOCALAPPDATA, PATH/HKCU,
ứng dụng, registry Windows, cleanup/repair/update thật trong kiểm thử.
Đợt đầu người dùng chưa có repository nên bộ chỉ chuẩn bị offline. Sau khi
người dùng cung cấp dinhluxury/WinTune-VI, cấu hình ghim khóa RSA3072 thật,
khóa riêng giữ ngoài workspace. Chưa đăng mã hoặc phát hành. Chuỗi tải/chạy
Release thật chưa được thử; thiếu trust vẫn dừng trước mạng và thực thi.

Kiểm tra gói trước khi cấu hình repository:353 SHA256 entries khớp; compiled WinTune-Demo.exe /probe
đã đạt, WPF main/owned dialog46 entries, lựa chọn0/write0. Resolver EXE
/resolve và /probe đạt trong cấu trúc apps/launcher/current.txt tại workspace.
Không đăng ký User PATH/HKCU/Win+R thật. Chính sách Application Control đã
chặn một số fixture/gói ở lần thử trước; fixture so sánh startup/RAM chưa
xác minh, không coi là PASS hoặc đổi policy. Bootstrapper sinh sẵn được
parse, kiểm hash ZIP/script và từ chối cấu hình thiếu trước mạng. Bộ asset
đợt đầu chưa ký/chưa phát hành. Không dùng bằng chứng đó thay kiểm gói public.

### Chuẩn bị repository của tác giả

Release.Author.Tests.ps1:20 kiểm tra PowerShell5.1 thật, RSA3072/DPAPI với
khóa thử riêng. Không kết nối mạng, không sửa registry/PATH hoặc khởi chạy
app từ Internet. Kiểm tra xuất public key, mã hóa private, từ chối khóa
trong project/ghi đè, ghim cấu hình, ký và verify, yêu cầu build từ package,
bootstrapper parse/hash/URL, tách Source/Release, ZIP thay đổi hoặc cấu hình
không khớp bị từ chối. Private key fixture xóa sau bài đạt; khóa tác giả thật
không dùng trong bài thử. Thiếu assembly System.Security của author tool
đã được sửa; không nhầm chữ ký RSA manifest với chữ ký EXE Authenticode.

WPF bổ sung nhánh nguồn đã cấu hình: chỉ bật nút kiểm tra, không tự chạy
worker/network. Bộ PublicRelease loại ảnh/log/inventory máy và runner VM
cũ; giữ toàn bộ runtime/module/catalog/nguồn/license. Source không có EXE,
ZIP/ISO hoặc khóa riêng. `.gitattributes` giữ byte/hash qua Git. Gói public
còn được kiểm checksum, Catalog và các mock trong Package.Check.ps1.

EXE fixture có thể bị Application Control chặn. Nếu vậy ghi UNVERIFIED
và kiểm WPF mô phỏng qua PowerShell, không đổi hoặc vượt chính sách.
CMD/PATH/Win+R thật và chuỗi GitHub Release sản xuất còn chưa xác minh.
Không coi số assertion là bảo đảm mọi tinh chỉnh có hiệu lực trên mọi build.

### Lệnh online từ phiên PowerShell Restricted

Ảnh người dùng cho thấy `& $p` bị chặn bởi ExecutionPolicy. Bộ sinh lệnh
chuyển sang host Windows PowerShell riêng với `-ExecutionPolicy Bypass`
chỉ trong process con; SHA256 vẫn kiểm trước chạy, tải lỗi dừng ngay.
24 bài author đạt (thêm4), gồm kiểm parent Restricted giữ nguyên, child STA,
checksum sai/lỗi mạng không tạo child. Network/hash dùng provider giả;
child chỉ là fixture local, không cài/khởi chạy app hoặc sửa Windows.

Lệnh sửa cũng đã thử với GitHub thật bằng `-CheckOnly`, parent trước/sau
Restricted, child exit0; chỉ tải bootstrapper có hash ghim và đọc chữ ký
metadata. Không cài, chạy EXE, đăng ký PATH hoặc đổi policy lưu trong registry.
evidence/online-policy-fix.json và .test-runs/online-policy-fix/live-check.log.
Năm asset còn lại byte-identical với bộ0.15.0 đã phát hành. GitHub chưa được
chỉnh asset; ONLINE-COMMAND-FIXED.txt là hướng dẫn local cho người dùng.

## 0.15.1 — entry PowerShell/WPF

743 assertion core/mock/WPF đạt:18+100+42+60+16+25+29+23+8+69+74+24+17+238.
Thêm7 bài compiled fixture launcher/resolver cũ đã đạt ở lượt hồi quy này;
không dùng kết quả đó bảo đảm EXE của gói sẽ được mọi chính sách chấp nhận.
Primary source entry và các component Windows vẫn chịu App Control.

Distribution74 thử register/remove/repair schema2 bằng native adapters giả,
giữ kiểu dữ liệu PATH và xung đột; schema1 vẫn gỡ/repair có điều kiện.
Pointer UTF-8 không BOM và đường dẫn chứa dấu tiếng Việt được kiểm tra.
Source17 dùng CMD/PowerShell/ShellExecute thật với child fixture an toàn,
PATH chỉ trong process rồi trả lại. Không đọc/ghi User/Machine PATH để thử,
không cài app, không chạy tinh chỉnh; pointer/tamper/extra args/mode kiểm thật.
WPF238 hồi quy giữ theme/lựa chọn/handler cũ. Đọc source/catalog vẫn khớp
51DWORD/5REG_SZ/31choices/17software/30apps đã ghim.

Native Win+R qua Explorer, User PATH sau đăng ký, cài/cập nhật Release0.15.1
thật và hiệu lực mọi tinh chỉnh vẫn chưa thử. Người dùng đã tự mở bản0.15.0
qua PowerShell/WPF và xác nhận; không coi đó là test gỡ/cài/repair mới.

Đợt cấu hình repository:715 assertions đạt (695 bài cũ, gồm WPF238,
+20 author). Public source chỉ lấy file đã liệt kê trong checksum; không
đưa simulation-data hoặc file phát sinh sau khi chạy vào Source.
