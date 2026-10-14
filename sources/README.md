# Nguồn đối chiếu — KHÔNG chạy các tệp .reg

Đợt0.6: review-20261014 lưu snapshot WinUtil
07ccd8e2e755a706f31569808b31f5b77acad6a9 và Win11Debloat mới
4079b276e9e93aa8698a9f70f5aa228ba11f8265. Config/cây module/license/selected
implementation lưu .txt để đọc, không chạy. FEATURE_MATRIX.md liệt kê100
cấu hình WinUtil và104 mục Win11Debloat, hợp nhất/loại bỏ. 8 package IDs
được kiểm tra qua kho manifest Microsoft, ghi ở winget-package-ids.json.

Các tệp trong thư mục này chỉ để kiểm tra nguồn. App không nhập hoặc chạy chúng.
Trong gói portable, tệp nguồn được giữ nguyên nội dung với đuôi `.reg.txt` để
mở dưới dạng văn bản, tránh vô tình nhập cả tệp vào registry.
Một số tệp chứa cả HKLM, tắt dịch vụ/chính sách ngoài phạm vi WinTune; không bấm
đúp hoặc nhập chúng vào Registry Editor. WinTune chỉ áp dụng những DWORD HKCU
đã liệt kê trong features.json sau khi người dùng xác nhận xem trước.

Nguồn: [Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat), commit
47cc891547192d228475e8e69bb196d7d20abe1e, thư mục Regfiles. MIT, giữ nguyên
LICENSE-Win11Debloat.txt bên cạnh mã nguồn. Mỗi tính năng có đường dẫn nguồn
cụ thể. Catalog.Verify.ps1 chỉ đọc tệp và đối chiếu, không ghi registry.

Hai mục Mở cài đặt dùng URI từ [tài liệu Microsoft](https://learn.microsoft.com/en-us/windows/apps/develop/launch/launch-settings).
Phần khởi chạy WPF, giao diện và sao lưu/hoàn tác là phần triển khai của WinTune.

Mục Widgets không lấy từ tập .reg Win11Debloat trên. Đối chiếu với resource
Taskbar của Microsoft/winget-dsc, commit b4b1867fe8ef748198fb56476d15f435a66eca46:
https://github.com/microsoft/winget-dsc/blob/b4b1867fe8ef748198fb56476d15f435a66eca46/resources/Microsoft.Windows.Developer/Microsoft.Windows.Developer.psm1
Resource này dùng HKCU Explorer\Advanced, TaskbarDa; Hide tương ứng 0.
Snapshot đầy đủ lưu dạng .psm1.txt CHỈ ĐỂ ĐỌC, không import/chạy. Metadata
JSON lưu SHA-256, Catalog.Verify.ps1 đối chiếu đúng đích và nguồn đã ghim.
Giữ LICENSE-Microsoft-winget-dsc.txt (MIT). Không sao chép hoặc chạy phần
restart Explorer, bảo mật hoặc các resource khác trong tệp tham chiếu.

Tác dụng và giới hạn ẩn nút Widgets:
https://support.microsoft.com/en-us/windows/experience/personalization/stay-up-to-date-with-widgets-in-windows
Ẩn nút/thời tiết trên taskbar; Win+W vẫn có thể mở Widgets. Không gỡ Weather.

0.5 tham khảo danh mục Appx của ChrisTitusTech/winutil, commit
07ccd8e2e755a706f31569808b31f5b77acad6a9. Snapshot appx.json.txt, tweaks.json,
preset.json, Remove-WinUtilAPPX.ps1.txt và metadata/hash ở winutil/ chỉ để đọc.
Không chạy script gỡ upstream; WinTune gỡ tên gói chính xác cho tài khoản
hiện tại sau xem trước, không dùng wildcard/AllUsers. Giữ LICENSE-WinUtil.txt.
https://github.com/ChrisTitusTech/winutil/tree/07ccd8e2e755a706f31569808b31f5b77acad6a9
https://learn.microsoft.com/en-us/powershell/module/appx/remove-appxpackage?view=windowsserver2025-ps

Hai mục Edge đối chiếu chính sách Microsoft, không nhập toàn bộ tweak WinUtil:
https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled
https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/backgroundmodeenabled
Tắt Startup Boost và tiếp tục chạy nền sau đóng; không tắt WebView2.

0.13: HEAD đọc lại qua GitHub API vẫn trùng các commit snapshot; bằng chứng
ở evidence/upstream-heads-v013.json.30 Appx/234 phần mềm lấy dữ liệu tên/ID
có ghi công từ WinUtil MIT; nhãn app từ Win11Debloat MIT. Chỉ dùng WinGet,
không nhập code Chocolatey/Scoop.51 DWORD+5 REG_SZ và31 lựa chọn đối chiếu
nguồn, file .reg.txt chỉ đọc. Khi hai nguồn khác kiểu chuột, chọn REG_SZ
của Win11Debloat; có reader/backup/undo kiểu thực. Không chạy source script.
# Danh mục cài ứng dụng 0.14

Chỉ giữ 17 ứng dụng theo công dụng: 16 ID từ snapshot WinUtil đã ghim,
thêm UniKey.UniKey. Manifest UniKey ghim winget-pkgs commit
2266f556516ee3159b4f2ac38a3e38e04ba6af3c tại curated-v014, SHA256 ghi
trong source.json; kèm LICENSE MIT của manifest. Điều khoản của UniKey
và các ứng dụng vẫn thuộc nhà phát hành, không phân phối bộ cài.
4.6.230919 có x64/x86, 4.6.250531 chỉ ARM64 (lưu trong arm64-only).
WinTune x64 ghim 4.6.230919 và architecture x64; show/install dùng cùng
đích. Đối chiếu https://www.unikey.org/download.html ngày 14/10/2026.
Không thực thi các YAML lưu ở đây. Không cài ứng dụng để kiểm thử.

