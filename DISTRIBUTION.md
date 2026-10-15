# Khởi chạy, phân phối và cập nhật WinTune VI

## Trạng thái hiện tại

Đã triển khai portable EXE, đăng ký lệnh theo tài khoản, bootstrapper và
cập nhật có xác nhận. Cấu hình hiện ghim **dinhluxury/WinTune-VI** và khóa
công khai RSA3072 của tác giả. Bộ local có manifest ký và checksum ZIP.
**Bản 0.15.2 đã do người dùng phát hành.** Online chỉ tải được sau khi
có bản stable với đầy đủ asset; thiếu nguồn/khóa vẫn dừng trước mạng.
Không đăng ký PATH/App Paths hay cài vào Windows trong quá trình kiểm thử.
Khóa riêng sản xuất tạo riêng ngoài dự án; bài kiểm thử chỉ dùng khóa thử.
Xem [PUBLISHING.md](PUBLISHING.md) để đưa mã và bộ tải lên từng bước.

## Người dùng: portable và lệnh wintune

### CMD online trên máy Windows 11 mới

Entry riêng `docs/run.cmd` được chuẩn bị bằng `Build-CmdLauncher.ps1` từ
bộ Source/Release đã ký hiện có. Không đổi asset của bản đã phát hành.
CMD dùng curl và Windows PowerShell có sẵn; không yêu cầu đăng ký lệnh,
cài dependency hoặc thay PATH. Launcher tải bootstrapper thành file trong
thư mục tạm riêng, kiểm SHA256 ghim rồi chạy `-File`; không IEX, không mã
hóa câu lệnh và không thử host khác sau khi Windows chặn.

```bat
curl.exe -q -fL --proto =https --proto-redir =https -o "%TEMP%\wintune.cmd" https://dinhluxury.github.io/WinTune-VI/run.cmd && "%TEMP%\wintune.cmd"
```

Entry HTTP đầu tiên tin cậy HTTPS của repository; chưa được kiểm hash
trước khi batch này chạy. Đây không phải chữ ký Authenticode. Child host
dùng ExecutionPolicy Bypass chỉ trong tiến trình chạy file đã đối chiếu;
không thay cấu hình Defender/App Control. Không bảo đảm mọi chính sách máy
đều cho chạy. Khi có cảnh báo bảo mật, dừng và phân tích, không thêm ngoại lệ.
`run.cmd --check-only` chỉ tải/kiểm bootstrapper và metadata có chữ ký;
không tải ZIP, đăng ký lệnh, kích hoạt phiên bản hay mở ứng dụng.

Lệnh CMD phải chờ entry mới được đưa lên GitHub Pages và kiểm chứng từ URL
sản xuất. Cách `powershell -Command` chứa `irm | iex` từ CMD đã bị Defender
phát hiện loại CmdLine trên máy kiểm tra và được ngừng khuyến nghị.

### Portable và đăng ký lệnh tùy chọn

Giải nén toàn bộ ZIP rồi mở `Mo-WinTune.cmd`. Windows 11 x64, PowerShell
5.1 + WPF và .NET Framework có sẵn; không cài module/dependency âm thầm.

Từ 0.16.0, trang cập nhật đã bỏ đăng ký lệnh `wintune`. Để mở online,
dùng lệnh PowerShell trong README. Công cụ CLI cũ vẫn được giữ để quản lý
đăng ký từ bản trước; chỉ khi chủ động cần mới chạy tại thư mục portable:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Register-WinTune.ps1
```

Script hỏi `DONG Y` trước khi chép bản vào `%LOCALAPPDATA%\WinTuneVI\apps`
và đăng ký `%LOCALAPPDATA%\WinTuneVI\command` vào **User PATH**. Lệnh CMD
đọc pointer rồi mở PowerShell/WPF; không tạo App Paths mới. Không đổi Machine PATH,
không ghi đè lệnh cùng tên của chương trình khác. Mở lại CMD/PowerShell;
cửa sổ cũ có thể giữ PATH cũ. Một số terminal thừa hưởng môi trường từ
process cha cũ và cần mở lại ứng dụng terminal hoặc đăng xuất/đăng nhập.

- `wintune`: mở ứng dụng đang được chọn trong `current.txt`.
- `wintune demo`: mở mô phỏng.
- `wintune update`: tên gọi cũ được giữ tương thích và chỉ mở ứng dụng; không còn cửa sổ cập nhật.
- `wintune.cmd` trong portable vẫn hỗ trợ demo/test/probe/help; có thêm
  update/register/unregister cho người đang dùng bản portable.

**Bỏ đăng ký lệnh** chỉ loại bỏ mục WinTune đã thêm nếu chưa có xung đột;
giữ ứng dụng, bản cũ và lịch sử. Nếu đợt đăng ký cũ bị ngắt, CLI phục hồi
có điều kiện: `Register-WinTune.ps1 -Remove` hoặc `-Recover`.
`-Confirmed` chỉ dành cho người chủ động chấp thuận phạm vi đó; không là mặc định.

## Dùng bản WinTune mới

Từ 0.16.2 đã bỏ giao diện cập nhật trong ứng dụng. Đóng bản cũ rồi mở lại bằng lệnh online để bộ tải kiểm tra bản stable, chữ ký và checksum. Bản portable dùng gói ZIP mới khi người dùng tải lại. Các thư viện phân phối/xác minh vẫn được giữ cho bộ tải.

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

### Sửa lỗi PowerShell chặn script

Lệnh trong ONLINE-COMMAND.txt đã phát hành ở0.15.0 dùng `& $p`, nên phiên
PowerShell có ExecutionPolicy Restricted chặn script sau khi tải/hash đúng.
Bộ sinh lệnh local đã sửa để gọi host Windows PowerShell cố định với
`-NoProfile -STA -ExecutionPolicy Bypass -File $p` sau bước kiểm SHA256.
Tham số chỉ áp dụng cho process con; không gọi Set-ExecutionPolicy, không
thay CurrentUser/LocalMachine hoặc chính sách Group Policy/Application Control.
[Tài liệu Microsoft](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_exe?view=powershell-5.1).

Lệnh sửa cho bản0.15.0 tại `ONLINE-COMMAND-FIXED.txt`. Chỉ thay cách gọi;
ZIP, bootstrapper, khóa, manifest và chữ ký khớp bộ đã phát hành.
Chưa thay file công khai trên GitHub. Bộ local mới tại release-assets/LATEST.txt
chứa ONLINE-COMMAND.txt đã sửa để tác giả kiểm tra/cập nhật có chủ ý.

24 bài author đạt, gồm Restricted parent/STA child, checksum sai và lỗi
mạng. Kiểm tra Release thật với lệnh mới `-CheckOnly` đạt; parent vẫn
Restricted. Chưa dùng kết quả này để khẳng định đã cài/khởi chạy EXE hoặc
đăng ký lệnh thật. Bằng chứng local: evidence/online-policy-fix.json.

## Vì sao chọn portable EXE

### Windows Application Control chặn EXE

Ảnh lỗi và CodeIntegrity3077 trên máy người dùng xác nhận `WinTune-VI.exe`
bị chính sách `VerifiedAndReputableDesktop` chặn. File chưa có Authenticode;
gói tải/295checksum vẫn đúng và đã được lưu trong apps/current.txt. Quyền
Administrator hoặc ExecutionPolicy của PowerShell không cấp phép cho EXE.
Khóa RSA của release.sig chỉ xác minh manifest/ZIP; không thay chứng chỉ
code signing được Windows tin cậy. Không tắt Smart App Control/Defender,
thay rule hoặc tạo chứng chỉ tự ký rồi thêm vào Trusted Root để khắc phục.

WinTune vốn có lối chạy PowerShell/WPF ở `Mo-WinTune.cmd`; đây là entry
point có sẵn từ trước EXE. Chỉ dùng nếu chính sách Windows cho phép script
và các module/assembly phụ thuộc. Windows vẫn kiểm tra chúng. Không tự
chuyển sang lối khác sau khi bị App Control chặn. Đã thử trực tiếp script
trong gói tải đã xác minh bằng -GuiProbe: WPF main/owned dialog render,
46 entries, lựa chọn0/ghi0; đây là mô phỏng, không thực thi các tinh chỉnh.

Nếu người dùng chọn mở lối PowerShell/WPF của bản đã tải, thư mục hiện tại
đọc từ `%LOCALAPPDATA%\WinTuneVI\current.txt`; có thể mở `Mo-WinTune.cmd`
trong thư mục đó. Muốn phân phối EXE trên máy yêu cầu chữ ký cần chứng chỉ
Authenticode được tin cậy và đáp ứng chính sách của máy; hiện không có
chứng chỉ đó trong workspace. Không hứa tự ký RSA manifest sẽ làm EXE được
chấp nhận. Bootstrapper local báo lỗi tiếng Việt và dừng, không fallback.
[Microsoft: sự kiện App Control](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/operations/event-id-explanations),
[Microsoft: script enforcement](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/design/script-enforcement).

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

## Đăng ký source của0.15.1

Lối mở online chọn PowerShell/WPF ngay từ đầu, không thử EXE rồi tự đổihost
sau khi bị từ chối. Mọi file trong gói được kiểm checksum trước mở.
Đăng ký mới copy Wintune.Registered.cmd thành command/wintune.cmd và
CommandRouter.ps1, thêm command vào User PATH. Không đăng ký App Paths mới.
Receipt schema2 chỉ theo dõi User PATH. Đăng ký/hoàn tác schema1 EXE cũ
vẫn hỗ trợ; cần tự bỏ đăng ký cũ trước khi chuyển, không tự thay lệnh khác.

Gõ wintune / wintune demo / wintune update; CLI và ShellExecute đã thử bằng
fixture PATH trong process. Native Win+R sau đăng ký User PATH vẫn chưa thử;
Explorer/terminal đang mở có thể giữ PATH cũ và cần mở lại/đăng nhập lại.
File lệnh/phiên bản cũ/lịch sử giữ khi bỏ đăng ký. Không thử native PATH.

## Thiết lập gọn cho máy khác (0.15.2)

Gói portable có Cai-WinTune.cmd: giải nén và chạy một lần; xác nhận vị trí lưu và thêm lệnh cho tài khoản. Sau đó mở CMD/PowerShell mới từ Start và gõ wintune. Online caller mới truyền -Setup; một xác nhận gộp tải/xác minh, đăng ký và mở. -CheckOnly luôn chỉ đọc. Không thực thi setup khi chỉ mở portable bằng Mo-WinTune.cmd. Không đổi Machine PATH hoặc tự cài dependency. Máy chưa từng nhận bộ WinTune phải thiết lập lần đầu để Windows tìm được tên lệnh. Gói0.15.2 còn local; Release0.15.1 không bị sửa.

## Online một dòng — yêu cầu cập nhật

Người dùng đã yêu cầu dùng cách irm URL | iex giống WinUtil; hạn chế IEX trước đó được thay cho entry chính thức này. get.ps1 nằm trên main, sinh từ QuickLauncher.template cùng SHA launcher của bộ Release. Dùng lệnh ngắn PowerShell hoặc CMD trong ONLINE-COMMAND.txt. Không truyền -Setup/-RegisterCommand; dán lệnh chủ động tải/mở với -Confirmed. Entry đầu tin cậy HTTPS/repository, không được hash-check trước IEX; những bước sau kiểm SHA launcher/RSA manifest/ZIP/resource. Lệnh dài hash-check vẫn giữ, installer offline tùy chọn. Gói app cache theo tài khoản, không cài thêm dependency/PATH/service. Không còn màn hình cập nhật riêng trong app. get.ps1 được sinh sau ZIP và chỉ thêm vào Source qua Prepare-GitHub có kiểm template/hash; không phải runtime cần chép trong portable. Source/get.ps1 và Release0.15.2 chưa công khai.

## URL ngắn GitHub Pages

Địa chỉ chuẩn bị: https://dinhluxury.github.io/WinTune-VI. Builder sinh Pages/index.html cùng byte get.ps1 (UTF-8 không BOM), .nojekyll rỗng. Prepare kiểm cả ba tệp, thêm docs vào Source; không phải runtime ZIP. Bật Pages main /docs một lần theo PUBLISHING.md. IRM theo redirect cuối slash, MIME text/html trả entry nguyên văn; đã kiểm loopback. URL chưa kích hoạt trên GitHub. Phục vụ mã PowerShell tại index.html là chủ đích, không phải trang giao diện. Không thêm HTML/BOM hay Jekyll layout vào tệp này. Raw get.ps1 dự phòng vẫn giữ. Entry đầu dựa HTTPS, không kiểm hash trước IEX, các bước sau giữ SHA/RSA/resources.
