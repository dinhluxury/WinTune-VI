> WinTune VI 0.16.1: danh mục lưu 113 mục (111 mục hiển thị, đã bỏ hai mục dọn tệp) và các lựa chọn tương ứng ảnh WinUtil/Win11Debloat. Chi tiết phần cứng hiện sẵn trên Tổng quan. Mở **Tùy chỉnh Windows** để xem ngay toàn bộ danh sách. Bấm tên hoặc khoảng trống của từng dòng để đọc chi tiết; không cần nút Chi tiết. Các bộ Tối thiểu/Tiêu chuẩn/Nâng cao có 8/19/31 mục trên Windows hiện tại. Chọn thêm, bỏ chọn hoặc đổi giá trị sẽ tự chuyển sang **Tùy chỉnh**. Đọc [hướng dẫn, ảnh hưởng và giới hạn](TINH-CHINH-DAY-DU.md). Tải bản portable tại [GitHub Releases](https://github.com/dinhluxury/WinTune-VI/releases/latest).

**Dung lượng ổ đĩa** tự cài WizTree nếu chưa có, mở trực tiếp **ổ C:** và tự quét. WizTree hiển thị tổng dung lượng, đã dùng và còn trống; không mở CSV. Đã bỏ trình xem cơ bản. Xem [cách dùng](WIZTREE.md). Khôi phục và Công cụ Windows hiện trực tiếp; cuối thanh bên có cập nhật và trạng thái phiên bản, đã bỏ phần đăng ký lệnh.

# WinTune VI 0.16.1

Ứng dụng Windows 11 cá nhân, PowerShell 5.1 + WPF, giao diện tiếng Việt.
Repository chính thức: [dinhluxury/WinTune-VI](https://github.com/dinhluxury/WinTune-VI).
Nguồn/cập nhật ghim khóa công khai RSA3072; bộ tải có manifest ký. Bản 0.15.2
đã được tác giả phát hành. [PUBLISHING.md](PUBLISHING.md) hướng
dẫn đưa mã và bộ phát hành lên GitHub; [DISTRIBUTION.md](DISTRIBUTION.md)
giải thích tải/cập nhật có xác nhận và đăng ký lệnh `wintune`.
Giữ các tính năng và dữ liệu của 0.14; giao diện gọn theo cách tổ chức Windows Settings, có trang theo dõi máy. Các công cụ viết riêng, chỉ tham khảo có chọn lọc WinUtil và
Win11Debloat. Không có preset tăng FPS/RAM hoặc thay bảo mật để giảm tiến trình.

## Mở ứng dụng

**Online — mở bằng một dòng trên máy mới:**

PowerShell:

```powershell
irm https://dinhluxury.github.io/WinTune-VI | iex
```

CMD trên máy Windows 11 mới:

```bat
curl.exe -q -fL --proto =https --proto-redir =https -o "%TEMP%\wintune.cmd" https://dinhluxury.github.io/WinTune-VI/run.cmd && "%TEMP%\wintune.cmd"
```

Lệnh CMD dùng entry `run.cmd` riêng: tải file bootstrapper, kiểm SHA256 ghim
rồi mới chạy file đã đối chiếu. Lệnh chỉ sẵn sàng sau khi tác giả đưa entry
CMD mới lên GitHub Pages; bản 0.15.2 và entry PowerShell đã công khai.
Không dùng lại cách gọi `powershell -Command` chứa `irm | iex` từ CMD:
Defender đã chặn cách gọi đó trên máy kiểm tra. Nếu Windows chặn bất kỳ
launcher/file nào, dừng lại; không tắt Defender hoặc thêm ngoại lệ.
Chỉ dùng URL chính thức. Raw get.ps1 vẫn được giữ trong ONLINE-COMMAND.txt.
Dán lệnh là yêu cầu tải và mở app: không có bước đăng ký PATH, không cần
cài dependency và không tự áp dụng tinh chỉnh. Gói app được lưu trong
cache WinTune của tài khoản; không tạo shortcut hoặc thay Machine PATH.

Entry đầu tiên của cả hai cách tin cậy repository qua HTTPS. Entry CMD
không dùng IEX/EncodedCommand. Hash của entry HTTP đầu tiên chưa được kiểm
trước khi chạy. Các bước sau vẫn ghim SHA256 launcher, chữ ký RSA manifest/ZIP và
checksum tài nguyên. ONLINE-COMMAND.txt cũng giữ lệnh dài kiểm hash trước
khi chạy để tự chọn; không đồng nhất hai mức xác minh.

**Tùy chọn mở offline bằng tên wintune:** chạy Cai-WinTune.cmd một lần,
xác nhận thêm User PATH rồi mở CMD/PowerShell mới từ Start. Đăng ký lệnh
là tùy chọn riêng, không bắt buộc khi dùng online. Không tự tải cập nhật
trong app; màn hình cập nhật vẫn cần xác nhận của người dùng.

**Muốn dùng portable ngay:**

1. Giải nén **toàn bộ** gói portable vào thư mục có quyền ghi.
2. Mở **Mo-WinTune.cmd** (PowerShell/WPF). Thử mô phỏng bằng **Mo-Ban-Mo-Phong.cmd** trước. EXE là lựa chọn riêng khi chính sách Windows cho phép.
3. Trang Tổng quan mở trước. Chọn **Tùy chỉnh Windows** ở thanh trái. Dùng **Chọn nhanh** trên bảng hoặc tick từng mục; vùng **Đang chọn** liệt kê những gì sẽ áp dụng.
4. Đọc màn hình xem trước rồi mới xác nhận thao tác cụ thể.

Bản 0.12 sửa nút áp dụng bị khóa sau khi lưu giao diện. Không cần xóa
`ui-settings.json` hoặc các bản sao lưu cũ. Nếu nhật ký thật có lỗi hoặc đợt
trước chưa hoàn tất, thông báo phía trên bảng chỉ rõ lý do và cách tiếp tục.

Bảng **10 tiến trình dùng RAM nhiều nhất** tự cập nhật khi đang ở Tổng quan,
chu kỳ mục tiêu **2 giây**. Giờ cập nhật nằm ngay dưới tiêu đề; thứ tự thay
đổi theo RAM đang dùng. Bộ đọc riêng giúp bảng không phải chờ GPU/ổ đĩa.
Nhấn Tạm dừng để giữ mẫu; rời trang/thu nhỏ cũng tạm dừng. Không dừng hoặc
thay đổi tiến trình. RAM là working set, không cộng các hàng để tính tổng RAM.

Windows desktop x64, Windows PowerShell **5.1 STA**, .NET Framework/WPF có sẵn.
Không cần Python, Pester hoặc module tải thêm. EXE biên dịch thật từ Launcher.cs
nhưng vẫn cần các tệp bên cạnh. Chưa ký số; không vượt chính sách máy cơ quan.
Trong CMD tại thư mục app: `wintune`, `wintune demo`, `wintune test`.

## Những phần đã triển khai

| Phần | Cách dùng và giới hạn |
|---|---|
| Tùy chỉnh/Privacy/UI | Hiện trực tiếp 111 mục và 32 mục nhiều lựa chọn, kèm tác dụng/ảnh hưởng/hoàn tác. Giữ các đích registry của 43 mục cũ và lịch sử cũ; không hứa telemetry = 0 |
| Chọn nhanh | Tùy chỉnh / Tối thiểu / Tiêu chuẩn / Nâng cao: 8/19/31 thiết lập trên Windows hiện tại, bỏ qua mục chưa hỗ trợ. Chỉ chuẩn bị danh sách; đổi lựa chọn tự chuyển sang Tùy chỉnh. Không tự gỡ app, giải mã ổ hoặc đổi DNS |
| Dọn ứng dụng Windows | Appx/MSIX của user: đề xuất xem xét, thông thường, hệ thống/được bảo vệ. Tìm/lọc không mất lựa chọn. Gỡ đúng PackageFullName, không AllUsers/provisioned. Tên chưa giải mã thì hiện tên gói thật |
| Startup | Các lệnh phổ biến HKCU Run, giữ nguyên String/ExpandString, phục hồi khi không xung đột. Không bao gồm mọi nguồn tự chạy, không đóng app đang chạy |
| WinGet | 17 ứng dụng thông dụng trong 4 nhóm, ô có cùng kích thước và mô tả công dụng. Tìm tên/mã, giữ lựa chọn khi lọc; nút cài và ô đồng ý luôn nhìn thấy. Kiểm tra WinGet/ID/nguồn bên trong; không có menu cập nhật/check/list |
| Dung lượng ổ đĩa | Tự chuẩn bị WizTree và mở/quét trực tiếp ổ C:. Xem tổng/đã dùng/còn trống, cây thư mục, bản đồ màu và tệp lớn; không tự xóa tệp |
| Repair | SFC /scannow, DISM CheckHealth/ScanHealth/RestoreHealth từng lệnh riêng, chkdsk chỉ đọc ổ Windows. Không /f /r /scan, không hẹn boot, không tự chạy chuỗi hoặc restart |
| Power Plan | Đọc GUID thực có; đổi plan đã chọn và hoàn tác có điều kiện. Không thêm Ultimate, không sửa tham số sâu; thay đổi điện/nhiệt/pin tùy plan |
| Thông tin máy | CPU/GPU/RAM/bo mạch/Windows/ổ/thiết bị lỗi/Defender/Firewall/TPM/Secure Boot do Windows cung cấp; lỗi/quyền/thiếu dữ liệu hiển thị rõ. Không chỉ số sức khỏe giả |
| Restore Point | Checkpoint-Computer theo yêu cầu; điều kiện System Protection/tần suất của Windows. Không tự bật Protection, không bảo đảm file cá nhân. Mở System Restore riêng |
| Mở công cụ Windows | Chỉ giữ công cụ cần thiết như Quản lý thiết bị, nhật ký Windows có bản tóm tắt. Các đường tắt có sẵn trong Settings đã bỏ khỏi thanh trái |

Công cụ bổ sung nằm ở thanh trái, **Ứng dụng & công cụ**, **Khôi phục Windows**
và **Công cụ Windows**. **Hoàn tác** và **Lịch sử** hiện trực tiếp, không cần mở mục phụ. Cửa sổ công cụ có bộ lọc nhóm. Ghi chú Administrator đã
bỏ khỏi giao diện theo yêu cầu; kiểm tra quyền bên trong vẫn giữ. Nhật ký và
yêu cầu worker mã hóa cho chính tài khoản Windows đang dùng; tài khoản khác
không thể dùng chúng để thay đổi thiết lập của bạn.

## Theo dõi máy tính

Trang Tổng quan có CPU, RAM lắp đặt/tốc độ, GPU/VRAM, dung lượng các ổ cục bộ;
chi tiết Windows, bo mạch, thanh RAM và driver. Dữ liệu hoạt động gồm tải
CPU, RAM dùng/khả dụng, tiến trình, GPU, mạng, đọc/ghi ổ và dung lượng trống.
Cuộn xuống xem 10 tiến trình dùng RAM nhiều nhất và mở chi tiết phần cứng.
Bảo mật/TPM/thiết bị có giải thích cạnh nút Kiểm tra ngay; bấm để đọc và hiện kết quả trên Tổng quan, không mở cửa sổ công cụ.

CPU/RAM tổng và các bộ đếm lấy mẫu cách 2 giây sau khi bộ đọc xong;
Windows/WMI chậm thì chu kỳ có thể dài hơn. Bảng tiến trình dùng bộ đọc riêng
với chu kỳ mục tiêu 2 giây. Biểu đồ giữ 60 mẫu. Nút **Tạm dừng** ngừng lấy mẫu mới; chuyển
trang hoặc thu nhỏ cũng dừng lấy mẫu mới. Không chạy bộ theo dõi riêng sau
khi đóng app. Không ghi số liệu mỗi 2 giây vào lịch sử hay tự thay đổi máy.

VRAM dùng API DXGI 64-bit, thẻ làm tròn GB; tooltip/chi tiết giữ giá trị API
báo. Bộ đếm GPU chỉ cho GPU đang hiển thị, chọn engine bận nhất sau khi cộng
các tiến trình của cùng engine. Thiếu bộ đếm sẽ báo chưa đọc được, không đoán
0%. RAM lắp đặt khác RAM Windows có thể dùng. Working set tiến trình có bộ
nhớ chia sẻ; không cộng các hàng để tính tổng RAM. Dung lượng lưu trữ cộng
volume cục bộ đang truy cập được; có thể khác dung lượng ổ vật lý.

Không đo nhiệt độ/quạt/điện năng hoặc xung CPU tức thời. Không có điểm sức khỏe
giả. CPU >64 luồng có giới hạn processor group. Bộ đếm mạng có thể gồm card
ảo. Cấu hình đọc lúc mở/nhấn **Đọc lại cấu hình**; mẫu hoạt động mới cập nhật
liên tục. Demo ghi rõ mô phỏng và không tự đọc máy để giả dữ liệu thật.

Các việc lâu chạy trong PowerShell worker riêng; WPF vẫn cuộn/xem thông tin.
Đợi kết quả trước đóng cửa sổ/thêm tác vụ. Không tự kill worker/app đang chạy.
Nếu mất điện/ngắt tiến trình, giữ thư mục nhật ký; không coi thiếu result là
thành công. Repair/installer có thể có ảnh hưởng riêng; tự lưu công việc trước.

## WinGet: điều khoản và nguồn

Chỉ dùng nguồn tên `winget`, package ID chính xác, không thêm nguồn. Tìm/đọc
có thể cần mạng hoặc đồng ý điều khoản nguồn. Ô đồng ý nguồn và điều khoản
package **đều bỏ chọn mặc định**; UI cài đặt dùng trình cài tương tác. Không thêm các cờ chấp nhận khi
chưa đánh dấu. Nếu WinGet yêu cầu điều khoản mà chưa đồng ý, hiển thị mã lỗi;
không tự trả lời “yes”. Xem thông tin package/điều khoản trước xác nhận cài.
Không dùng `--all`, `--force`, bỏ qua hash, override lệnh hoặc cho phép reboot.
Không tự cài/cập nhật gì khi mở ứng dụng. Nếu thiếu WinGet, cập nhật **App
Installer** từ Microsoft Store bằng Windows; WinTune không tự cài dependency.
Không hứa hoàn tác phiên bản/dữ liệu. WinGet hiển thị output thật, không
phân tích bảng tiếng Anh để đoán phiên bản đã cài. UniKey dùng bản x64
4.6.230919 được xác minh từ nguồn chính thức; màn hình xem trước ghi rõ.
Không tự chọn bản ARM64 hoặc bỏ qua kiểm tra hash khi kho có thay đổi.

## Phục hồi: bốn việc khác nhau

- **Registry/configuration:** giá trị gốc và trạng thái chưa tồn tại, HKCU và
  thời điểm/kết quả từng mục. Hoàn tác có điều kiện; không ép ghi khi xung đột.
- **Startup/Power Plan:** nguyên lệnh/kiểu dữ liệu hoặc GUID trước; nhật ký
  mã hóa current-user. Không khôi phục nếu trạng thái ngoài đã thay đổi.
- **Restore Point:** công cụ Windows riêng; không phải sao lưu file cá nhân.
- **App đã gỡ/file đã xóa:** Store chỉ cài lại khi có ID đã xác minh; app khác
  tự giữ nguồn nhà phát hành. Không hứa phục hồi dữ liệu. TEMP/Thùng rác xóa
  vĩnh viễn, không có nút “Khôi phục tất cả”.

Dữ liệu thật: `%LOCALAPPDATA%\WinTuneVI\v2`, app/startup ở `actions`, công cụ
ở `tools`. Demo dùng `simulation-data` cạnh app. Giữ dữ liệu để phục hồi;
không chuyển nhật ký mã hóa sang tài khoản khác. Power Plan thuộc phạm vi máy,
registry/startup/Appx thuộc user. Không sửa danh mục khi còn đợt cần hoàn tác.

## Chọn lọc nguồn

[FEATURE_MATRIX.md](FEATURE_MATRIX.md) liệt kê 100 cấu hình WinUtil và 104
mục Win11Debloat mới, quyết định giữ/nâng cao/loại bỏ, cơ chế/quyền/hoàn tác.
Các chức năng trùng chỉ dùng một handler WinTune. Giữ MIT/copyright trong ba
tệp LICENSE; source ghim, hash và snapshot chỉ đọc trong `sources`.

- WinUtil: `07ccd8e2e755a706f31569808b31f5b77acad6a9`.
- Win11Debloat rà soát mới: `4079b276e9e93aa8698a9f70f5aa228ba11f8265`.
- 29 DWORD cũ vẫn ghim `47cc891547192d228475e8e69bb196d7d20abe1e` để không đổi
  âm thầm các đích đã kiểm tra. Widgets dùng Microsoft winget-dsc ghim; Edge
  theo chính sách Microsoft. Không tải/chạy script upstream khi mở app.

Loại bỏ: tắt hàng loạt service/bảo mật/Update/UAC/VBS/BitLocker, gỡ Edge,
block Adobe, timer/BCD/HPET, mạng không rõ lợi ích, xóa pagefile, format/phân
vùng/WinPE/ISO/cài lại Windows/remote tools. Không xóa Prefetch, log, restore
point, Driver Store, WinSxS, shader cache, dữ liệu trình duyệt hoặc Update cache.

## Kiểm thử và phần chưa kiểm chứng

Kiểm thử tự động chỉ dùng mock/mô phỏng cho mọi thao tác thay đổi hệ thống.
Đã dựng XAML/WPF trên Windows PS5.1, thử handler thật với provider giả, worker
riêng, WPF dispatcher còn phản hồi khi tác vụ kéo dài. Ảnh RenderTargetBitmap
đã xem là ảnh dựng, không phải thao tác desktop bằng chuột.

Kiểm tra thật chỉ đọc: Appx/startup, phần cứng/bảo mật, WinGet `--version`,
Power Plan trước/sau không đổi. Kết quả native v0.3 trong VM: báo cáo người dùng
17 vòng registry ghi/đọc/lịch sử/hoàn tác, 2 no-op; hiệu lực hiện/ẩn đuôi tệp
được người dùng xác nhận. **Không dùng bằng chứng đó cho chức năng mới.**

Chưa thực thi thật: WinGet tìm/cài/cập nhật, cleanup, repair, Restore Point,
Power Plan, gỡ/cài lại Appx mới, startup mới, Edge/Widgets mới hoặc giảm RAM.
Chưa quan sát hộp UAC thật cho worker, nhiều edition/build, ARM64/màn hình khác.
Start layout/AI sâu và bật/tắt optional feature trực tiếp
chưa đủ kiểm chứng nên không có nút áp dụng giả. WinTune hỗ trợ giao diện
Tối, Sáng và Theo hệ thống. WinGet output có thể theo ngôn
ngữ Windows, ghi chú và điều khiển WinTune bằng tiếng Việt.

Xem [KIEM-THU.md](KIEM-THU.md), [TIEN-DO.md](TIEN-DO.md) và
[CHANGELOG-v0.15.md](CHANGELOG-v0.15.md) để biết số kiểm tra và file thay đổi.
`wintune test` hoặc Run-Tests.ps1 chạy mock, không cần chạy bộ VM thật để phát
triển. Theo chỉ thị mới, không tự động chạy bài kiểm thử sửa/xóa/gỡ trên Windows
thật kể cả VM. Nếu muốn kiểm chứng hiệu lực: tự tạo snapshot VM và thử một
thao tác cụ thể đã đọc tác động/phương án phục hồi; đừng tick gỡ hết để thử.

## Chọn giao diện (0.8)

Ô Giao diện ở cuối thanh trái: **Tối**, **Sáng** hoặc **Theo hệ thống**.
Đổi ngay, áp dụng cả cửa sổ công cụ/hộp thoại và không mất lựa chọn đang chờ.
Mặc định Theo hệ thống, đọc màu dành cho ứng dụng Windows; khi Windows dùng
Custom, màu taskbar có thể khác. Tự cập nhật khoảng2 giây khi app còn mở.
Chỉ đổi giao diện WinTune; không thay màu Windows hay áp dụng tweak tối ưu.

Lựa chọn lưu ở `%LOCALAPPDATA%\WinTuneVI\v2\ui-settings.json`, đọc lại ở lần
mở sau. Nếu không lưu/đọc được, ứng dụng báo rõ ngay dưới ô chọn. Giữ nguyên
nhật ký hoàn tác và các tùy chỉnh cũ. Chi tiết/bằng chứng: CHANGELOG-v0.8.md.

## Bảng chọn (0.10)

Tùy chỉnh Windows hiển thị card theo nhóm trong bảng rộng; bỏ danh mục nhóm
lặp ở thanh trái và bỏ slogan. **Chọn nhanh**, **Tìm tính năng** và **Đọc lại**
nằm ngay trên bảng. Chọn nhanh chuẩn bị hồ sơ và xóa bộ lọc cũ; vùng
**Đang chọn** luôn liệt kê mọi tên đã tick. Nhấp × để bỏ từng mục;
**Chỉ hiện mục đã chọn** xem riêng lựa chọn. Nút ⓘ mở chi tiết/trạng thái/tác
động; Đóng chi tiết trả lại bảng rộng. Tìm kiếm không mất lựa chọn ở nhóm
khác. Hồ sơ chỉ chọn thiết lập, không tự gỡ/cài ứng dụng. Xem trước và xác
nhận vẫn là bước cuối; chọn một mục chưa làm thay đổi Windows.

Đã sửa nền rê chuột/chọn hàng danh sách tiến trình cho cả theme tối và sáng.

## Cách dùng các phần đã rút gọn ở 0.11

- **Tổng quan:** cuộn được cả khi con trỏ ở bảng tiến trình. Bảo mật và thiết
  bị: đọc giải thích cạnh nút **Kiểm tra ngay** rồi bấm; kết quả hiện bên dưới.
- **Tạo mốc khôi phục:** cửa sổ riêng có ba bước, giải thích Bảo vệ hệ thống.
  Nếu Windows báo đang tắt, mở cài đặt, chọn ổ Windows → Configure → Turn on
  system protection → chọn dung lượng → Apply. Tạo mốc cần xác nhận; quay về
  mốc cũ mở hướng dẫn Windows, không tự thực hiện khôi phục.
- **Cài ứng dụng:** chọn ứng dụng phổ biến, xem thông tin/điều khoản, đồng ý
  khi phù hợp rồi xem trước và cài. Không có menu cập nhật, không cài sẵn.
- **Gỡ ứng dụng:** mặc định chỉ hiện Có thể gỡ. Xanh là xem xét nếu không dùng,
  vàng là ứng dụng thông thường, xám là được bảo vệ; chữ kèm màu giữ ý nghĩa.
  Tên thân thiện không làm đổi PackageFullName hoặc bảo vệ gói hệ thống.
- **Nhật ký Windows dễ hiểu:** bảng lỗi/nghiêm trọng ba ngày. Xem điều ghi
  nhận, gợi ý và chi tiết gốc. Không dùng bảng này để đoán hỏng phần cứng.
- **Sửa lỗi:** kết luận tiếng Việt ở đầu kết quả. Nếu lệnh bị ngắt, quyền bị
  chặn hoặc thông báo không nhận diện được thì không báo máy đã ổn. Nguồn
  Microsoft/WinUtil/Win11Debloat là văn bản có thể bấm mở tài liệu.
- **Menu chuột phải / AI:** chọn từng mục trong bảng. Notepad AI đổi cấp máy;
  Recall chỉ hữu ích trên máy hỗ trợ và có thể xóa ảnh Recall cũ. Gỡ Copilot
  mở danh sách chọn gói, không gộp gỡ vào hồ sơ registry. Không hứa tắt AI
  trong Edge/Office/web hoặc AI khác bằng cùng một nút.

458 kiểm tra tự động đạt, mọi thay đổi hệ thống mock. Native chỉ đọc bảo mật
và nhật ký; quyền đọc điểm khôi phục chưa đủ trong môi trường kiểm tra.
Menu cũ, AI và gỡ Copilot mới chưa áp dụng thật để thử. Giữ snapshot VM và
thử từng thao tác sau khi đọc xem trước nếu cần kiểm chứng hiệu lực thực tế.

## Bản0.13 — tính năng hữu ích từ hai nguồn

Đối chiếu lại HEAD hai repository, trùng các commit đã ghim. Thêm18 tính
năng, hiện có43 tùy chỉnh registry. Những thiết lập có nhiều kiểu hiển thị
có ô chọn ngay dưới tên:31 lựa chọn trong10 ô. Chọn kiểu sẽ đưa đúng mục
vào danh sách chờ; vẫn phải xem trước và xác nhận. Chọn nhanh giữ các hồ
sơ cũ và trả ô chọn về giá trị mặc định của hồ sơ, không tự áp dụng.

Mục Gỡ ứng dụng nhận diện30 app:10 đề xuất xem xét,20 app thông thường.
Ảnh, Máy tính, Notepad và công cụ hằng ngày không được coi là rác. Đọc
công dụng, giữ nếu đang dùng. Store/Edge/Defender/Shell/framework/runtime/
Gaming Services/driver vẫn bảo vệ. Không gỡ AllUsers hoặc provisioned.

Trong bản 0.13, mục Cài ứng dụng có234 mã WinGet từ danh mục WinUtil, tìm bằng tên/mã,
lọc nhóm, và luôn hiện tên đã chọn. Mặc định chỉ hiện8 app phổ biến; tìm
kiếm sẽ tìm trong toàn bộ danh mục. Không chọn/cài mặc định hoặc tự chấp
nhận điều khoản. WinGet kiểm tra đúng ID trước cài; nguồn có thể thay đổi
hoặc không còn package. Chưa cài thử234 ứng dụng; installer có thể cần
bản quyền, quyền quản trị hoặc đóng ứng dụng theo nhà phát hành.

599 kiểm tra đạt, các thay đổi Windows đều dùng mock. Native đọc56 giá trị
registry và tạo xem trước, không ghi hoặc tạo nhật ký. Không tuyên bố hiệu
lực tất cả tinh chỉnh trên mọi build/edition. FEATURE_MATRIX.md và
feature-coverage.json liệt kê204 mục nguồn và trạng thái thật, gồm những
mục chờ kiểm chứng/loại bỏ. Không tích hợp toàn bộ hai dự án; giữ các mục
đã loại trừ theo yêu cầu. CHANGELOG-v0.13.md ghi giới hạn và file thay đổi.

## Bản 0.14 — cài ứng dụng dễ chọn

Theo yêu cầu rút gọn, danh mục hiện tại còn **17 ứng dụng**, không phải toàn
bộ danh mục WinUtil. Không có ứng dụng nào được chọn sẵn. Các ô tự chia
cột theo chiều rộng, cùng kích thước, tên rõ ràng và mô tả tiếng Việt;
ô đồng ý và nút cài cố định dưới bảng, không cần cuộn tìm.

| Nhóm | Ứng dụng có thể chọn |
|---|---|
| Hằng ngày | 7-Zip, Chrome, Firefox, VLC, SumatraPDF, UniKey |
| Chơi game & trò chuyện | Steam, Epic Games, Discord |
| Livestream & nội dung | OBS Studio, Audacity, HandBrake |
| Công việc & tiện ích | LibreOffice, Zoom, Notepad++, PowerToys, Visual Studio Code |

Đây là gợi ý theo công dụng, không phải yêu cầu phải cài hết. Chrome và
Firefox là hai lựa chọn trình duyệt; giữ Edge nếu đang dùng. Các công cụ
livestream/lập trình chỉ chọn khi cần. Không thêm bộ cài Adobe có bản quyền
hoặc trình tải không được xác minh.

16 ID đối chiếu snapshot WinUtil; UniKey đối chiếu manifest MIT trong
winget-pkgs tại commit 2266f556516ee3159b4f2ac38a3e38e04ba6af3c.
[UniKey chính thức](https://www.unikey.org/download.html) hiện phân biệt
build 230919 x64/x86 và build 250531 chỉ ARM64. WinTune kiểm tra và cài đúng
4.6.230919 x64, không thực thi manifest lưu trong dự án. Giấy phép manifest
khác với điều khoản phần mềm; không phân phối bộ cài của các ứng dụng này.

Kiểm thử và giới hạn ở [CHANGELOG-v0.14.md](CHANGELOG-v0.14.md).
Không cài phần mềm thật để chạy kiểm thử tự động.

## Bản 0.15.0 — mở nhanh và cập nhật có xác minh

**WinTune và cập nhật** ở thanh trái: kiểm tra phiên bản khi bấm, tải bản
mới chỉ sau xác nhận, giữ bản cũ và lịch sử. Không tự mở cập nhật. Có thể
đăng ký lệnh `wintune` cho CMD/PowerShell/Win + R qua User PATH.
Tính năng này có xác nhận riêng, không ghi Machine PATH. Chưa thực hiện
đăng ký thật khi phát triển. Portable vẫn mở EXE trực tiếp, không cần mạng.

Repository phát hành hiện là dinhluxury/WinTune-VI, khóa công khai RSA3072
đã ghim. Bản0.15.0 đã công khai; bộ0.15.1 chuẩn bị local có manifest ký/ZIP
được xác minh. Tác giả chủ động đưa mã/gói lên theo [PUBLISHING.md](PUBLISHING.md).
Không dùng `irm | iex`. Đọc [DISTRIBUTION.md](DISTRIBUTION.md)
để biết trust anchor, lệnh một dòng, đăng ký/bỏ đăng ký, tài nguyên portable
và những bước sản xuất còn cần. EXE mở PowerShell/WPF, không phải single EXE.
Wrapper mở thường kết thúc sớm; tác vụ cập nhật không có worker/timer khi
chưa dùng. Không tuyên bố phần trăm tăng tốc hoặc mức RAM cố định.

## Bản0.15.1 — mở trực tiếp PowerShell/WPF

Online và wintune dùng host PowerShell Microsoft với script WPF đã xác minh.
Không phụ thuộc EXE tự biên dịch chưa ký, không tự fallback sau lỗi bảo mật.
Đăng ký mới dùng User PATH và receipt schema2; không tạo App Paths mới.
Bỏ đăng ký EXE cũ bằng nút Bỏ đăng ký trước khi chuyển; không xóa app hoặcv2.
Mở lại CMD/PowerShell sau đăng ký. Win+R dùng đường tìm kiếm Windows;
ShellExecute đã kiểm trong fixture PATH process, chưa thử Win+R/PATH user thật.
Windows vẫn kiểm script/module/assembly, không đổi bảo mật hoặc allowlist.
Xem CHANGELOG-v0.15.1.md, DISTRIBUTION.md, KIEM-THU.md.
