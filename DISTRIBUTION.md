# Khởi chạy, phân phối và cập nhật WinTune VI

## Trạng thái hiện tại

Đã triển khai portable EXE, đăng ký lệnh theo tài khoản, bootstrapper và
cập nhật có xác nhận. Cấu hình hiện ghim **dinhluxury/WinTune-VI** và khóa
công khai RSA3072 của tác giả. Bộ local có manifest ký và checksum ZIP.
**Chưa đăng mã hoặc phát hành GitHub Release.** Online chỉ tải được sau khi
có bản stable với đầy đủ asset; thiếu nguồn/khóa vẫn dừng trước mạng.
Không đăng ký PATH/App Paths hay cài vào Windows trong quá trình kiểm thử.
Khóa riêng sản xuất tạo riêng ngoài dự án; bài kiểm thử chỉ dùng khóa thử.
Xem [PUBLISHING.md](PUBLISHING.md) để đưa mã và bộ tải lên từng bước.

## Người dùng: portable và lệnh wintune

Giải nén toàn bộ ZIP rồi mở `WinTune-VI.exe`. Windows 11 x64, PowerShell
5.1 + WPF và .NET Framework có sẵn; không cài module/dependency âm thầm.

Để dùng lệnh ở mọi nơi, mở **WinTune và cập nhật → Đăng ký lệnh wintune**,
đọc phạm vi rồi xác nhận. Hoặc tự chạy tại thư mục portable:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Register-WinTune.ps1
```

Script hỏi `DONG Y` trước khi chép bản vào `%LOCALAPPDATA%\WinTuneVI\apps`
và đăng ký `%LOCALAPPDATA%\WinTuneVI\launcher` vào **User PATH**, cùng
**HKCU App Paths\wintune.exe** cho Win + R. Không đổi Machine PATH,
không ghi đè lệnh cùng tên của chương trình khác. Mở lại CMD/PowerShell;
cửa sổ cũ có thể giữ PATH cũ. Một số terminal thừa hưởng môi trường từ
process cha cũ và cần mở lại ứng dụng terminal hoặc đăng xuất/đăng nhập.

- `wintune`: mở ứng dụng đang được chọn trong `current.txt`.
- `wintune demo`: mở mô phỏng.
- `wintune update`: mở cửa sổ khởi chạy/cập nhật; chưa kết nối hoặc tải gì.
- `wintune.cmd` trong portable vẫn hỗ trợ demo/test/probe/help; có thêm
  update/register/unregister cho người đang dùng bản portable.

**Bỏ đăng ký lệnh** chỉ loại bỏ mục WinTune đã thêm nếu chưa có xung đột;
giữ ứng dụng, bản cũ và lịch sử. Nếu đợt đăng ký bị ngắt, nút **Khắc phục
đăng ký lỗi** chỉ xuất hiện khi có receipt Pending; khôi phục có điều kiện.
CLI tương ứng: `Register-WinTune.ps1 -Remove` hoặc `-Recover`.
`-Confirmed` chỉ dành cho người chủ động chấp thuận phạm vi đó; không là mặc định.

## Cập nhật trong ứng dụng

Không kiểm tra mạng lúc mở app. Bấm **Kiểm tra phiên bản** mới đọc GitHub
Releases stable và xác minh RSA-SHA256 của `release.json` bằng khóa công
khai đã ghim. Metadata được đọc trước; ZIP chưa được tải. Chỉ sau khi xem
phiên bản/dung lượng/nguồn và xác nhận mới tải ZIP, kiểm tra SHA256 và kích
thước, kiểm tra đường dẫn ZIP và toàn bộ thành phần bất biến.

Bản mới đặt cạnh bản cũ, đổi `current.txt` nguyên tử và giữ pointer trước.
Không ghi đè file đang chạy, không tự mở bản mới, không restart, không đổi
`v2` chứa sao lưu/hoàn tác. Nếu chưa đăng ký lệnh, kết quả cho biết đường
dẫn EXE mới; người dùng tự mở sau khi đóng bản cũ. Có lịch sử riêng
`distribution-history.jsonl`; receipt đăng ký là `command-registration.json`.
Không hạ bản mới hơn đã được chuẩn bị. Tác vụ dùng runspace riêng, có hủy
tải/kiểm tra, dọn tài nguyên sau khi xong; không có timer cập nhật chạy nền.

## Tác giả: chuẩn bị nguồn tin cậy

Repository phải là repository của chính WinTune, không dùng repo WinUtil
hoặc Win11Debloat làm nguồn binary của ứng dụng. Thực hiện thủ công:

1. Tạo khóa **ngoài repo** bằng `New-ReleaseSigningKey.ps1 -Directory C:\Keys\WinTune`.
   Công cụ tạo RSA3072; `private.dpapi` mã hóa cho tài khoản Windows hiện tại.
   Giữ bản sao lưu bảo mật cho tài khoản/máy đó; file này không di chuyển được
   như một khóa PEM độc lập. Không đưa khóa riêng vào Git, ZIP, ISO hoặc Release.
2. `Configure-Release.ps1 -Repository OWNER/REPO -PublicKeyFile C:\Keys\WinTune\public.xml`.
   Đây chỉ là sửa cấu hình local, không upload hoặc phát hành. Khóa công khai
   được ghim; không tự tải/đổi khóa từ API GitHub. Khi đổi khóa cần kênh
   phân phối bootstrapper/gói đáng tin cậy mới, không bỏ kiểm tra chữ ký.
3. Chỉnh `version.json` theo `X.Y.Z`, chạy `Run-Tests.ps1`, `Build-Package.ps1 -PublicRelease`.
   Switch public loại dữ liệu/ảnh thử của máy và các bộ thử VM cũ khỏi ZIP.
4. Chạy `Build-Distribution.ps1`. Bộ chuẩn bị ở `release-assets/LATEST.txt`:
   ZIP portable, `WinTune-Online.ps1`, `release.json`, checksum bootstrapper,
   `ONLINE-COMMAND.txt`. Bản chưa có repo/khóa chỉ là bộ chuẩn bị, chưa dùng online.
5. Tự ký bằng `Sign-Release.ps1 -Manifest <release-assets\...\release.json> -PrivateKey C:\Keys\WinTune\private.dpapi`.
   Công cụ kiểm tra khóa đúng, ZIP khớp và tạo chữ ký detached `release.sig`.
6. Sau khi review, tự tạo GitHub Release **stable**, tag `vX.Y.Z`, upload
   đúng tên các asset. WinTune không chạy bước này. Draft/prerelease, tag
   sai, thiếu chữ ký, sai kiến trúc/build, asset ngoài repository bị từ chối.
7. `Prepare-GitHub.ps1` tách bộ Source và Release sau khi kiểm chữ ký/hash.
   Không upload, khởi tạo Git hoặc publish tự động. Khóa riêng luôn ở ngoài.

Không sao chép nguyên WinUtil; cơ chế phân phối viết riêng. Các giấy phép
MIT đang có được giữ trong portable. Không nhúng thư viện PS2EXE hoặc mã
launcher upstream nên không phát sinh phân phối mã của PS2EXE.

## Online Launcher một lệnh

`ONLINE-COMMAND.txt` do build tạo một lệnh PowerShell với **URL Release có
phiên bản và SHA256 bootstrapper ghim sẵn**. Lệnh tải ra file riêng, xác
minh hash rồi chạy file; không dùng `irm | iex`, `Invoke-Expression` hoặc
tạo ScriptBlock từ dữ liệu Internet. Bootstrapper chứa repository/khóa
công khai đã ghim và tự xác minh manifest/ZIP trước khi khởi chạy.

Người dùng phải lấy lệnh/hash ban đầu từ **kênh tin cậy của tác giả**.
Tải script cùng checksum từ một nguồn bị chiếm quyền không chứng minh
danh tính tác giả. File `.sha256` cùng Release chỉ giúp đối chiếu; không
thay thế trust anchor. Không có chứng chỉ Authenticode sản xuất trong bản
này và không tuyên bố EXE đã ký bằng chứng chỉ Windows.

Bootstrapper hỏi trước khi tải/khởi chạy. `-CheckOnly` chỉ kiểm tra metadata;
`-RegisterCommand` là lựa chọn chủ động để đăng ký lệnh. Không có tải âm thầm
khi mở UI. HTTP chỉ HTTPS GitHub, redirect giới hạn, tối đa ba lần thử,
giới hạn dung lượng/thời gian. Lỗi mạng/API được báo; không chạy dữ liệu lỗi.

## Vì sao chọn portable EXE

[PS2EXE](https://github.com/MScholtes/PS2EXE) hỗ trợ script PowerShell 5.x,
nhưng các biến đường dẫn script như `$PSScriptRoot` thay đổi khi biên dịch;
nhúng tài nguyên cần thêm xử lý giải nén. WinTune có worker PowerShell
riêng, XAML/JSON và module dùng đường dẫn local. Chuyển cả app sang host
PS2EXE sẽ ảnh hưởng nhiều phần đang chạy tốt.

Vì vậy đã thử và giữ phương án **C# EXE nhỏ + PowerShell/WPF + toàn bộ tài
nguyên trong ZIP**, không cài PS2EXE để thử. EXE x64 biên dịch bằng compiler
.NET Framework sẵn có. Mở thường: wrapper kết thúc sau khi tạo PowerShell,
không giữ thêm một process Forms và buffer output suốt phiên. `/probe` vẫn
đợi để xác minh lỗi/giao diện. App tự báo lỗi khởi động vào startup-error.log.
Không phải single EXE; tách một EXE khỏi thư mục sẽ thiếu tài nguyên.

## Kiểm thử và giới hạn

Distribution.Tests dùng chữ ký thật với khóa thử chỉ trong bộ nhớ, HttpClient
transport giả, registry/environment adapters giả và file fixture trong workspace.
WPF thử mở không tự chạy, xác nhận/hủy, tác vụ chậm, dispatcher, đóng cửa sổ,
hai theme. Package/launcher dùng `/probe` chỉ mô phỏng. Không thử thay PATH,
HKCU, cài app hoặc cập nhật Windows thật. Chưa kiểm tra chuỗi đầy đủ qua
Release sản xuất, Win + R/PATH thật hoặc Authenticode. Các giới hạn Windows
build/DPI và tinh chỉnh cũ giữ nguyên. Không hứa giảm RAM cố định.

Nguồn tham khảo: [WinUtil](https://github.com/ChrisTitusTech/winutil),
[Microsoft App Paths](https://learn.microsoft.com/en-us/windows/win32/shell/app-registration),
[GitHub Release API](https://docs.github.com/en/rest/releases/releases),
[PS2EXE](https://github.com/MScholtes/PS2EXE). Chỉ tham khảo tài liệu, không
thực thi script tải từ các repository này.

Application Control trên host đã chặn một số EXE fixture mới biên dịch. Không tắt/bỏ qua chính sách; kết quả có ghi Executable/benchmark chưa xác minh khi bị chặn. PowerShell/WPF trực tiếp vẫn được thử. Chữ ký manifest RSA không phải chữ ký Authenticode và không tự cho phép EXE qua Application Control.

Gói cuối và resolver đã chạy /probe mô phỏng thành công; phần đo so sánh wrapper cũ/mới còn bị chặn. Không áp dụng kết quả probe cho PATH/Win + R thật hoặc Release online. Bộ dữ liệu mô phỏng ở workspace không phải cài ứng dụng vào Windows.
