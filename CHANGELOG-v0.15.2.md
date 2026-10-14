# WinTune VI 0.15.2 — mở online một dòng

Yêu cầu mới cho phép cách chạy giống WinUtil: irm URL | iex, thay hạn chế
IEX trước đây. get.ps1 được sinh vào Source, tải launcher đã ghim SHA256
rồi gọi host PowerShell Microsoft -Confirmed để mở ngay. Không đăng ký
PATH khi dùng online; không cần vào app thiết lập lệnh. Bootstrap giữ
RSA manifest, ZIP SHA và kiểm tài nguyên. Entry get.ps1 đầu tiên tin cậy
repository HTTPS, không có hash được kiểm trước IEX. Lệnh dài ghim hash
trước chạy vẫn được giữ để chọn. Hỗ trợ cả dòng PowerShell và CMD.

Tùy chọn thiết lập offline đã xây dựng vẫn được giữ, không còn là mặc định
online. Các tính năng Windows và dữ liệu cũ không đổi. Source/get.ps1 phải
lên main và Release stable mới phải được công khai trước khi lệnh ngắn
hoạt động. Không tự push/publish hoặc tải/chạy app thật trong kiểm thử.


Trước đây tải online mở app nhưng người dùng còn phải tìm trang đăng ký
lệnh. Luồng thiết lập mới gộp tải/xác minh, đăng ký User PATH và mở app
sau một xác nhận cụ thể. Từ lần sau chỉ gõ `wintune`.

- Gói portable có `Cai-WinTune.cmd`: chạy một lần trên mỗi máy/tài khoản;
  xác nhận Yes để lưu gói, đăng ký lệnh và mở app. Dùng offline được.
- Online command có `-Setup`: giải thích thay đổi trước xác nhận DONG Y,
  thiết lập lệnh trong cùng luồng. Không tự đăng ký khi dùng `-CheckOnly`.
- `Setup.Core.ps1` dùng lại installer có checksum, receipt/rollback và
  reader PowerShell hiện có; chỉ đổi User PATH, không tạo App Paths mới.
- Cấm ghi đè App Paths cũ/khác; đăng ký thất bại không tuyên bố thành công
  hoặc mở app. Lỗi launch báo rõ, không đổi chính sách bảo mật.
- `Mo-WinTune.cmd` vẫn là portable thuần: mở app, không đổi PATH.
- Máy chưa từng nhận bộ WinTune cần thiết lập một lần để Windows tìm
  được lệnh; xem tài liệu Microsoft về PATH/Command Precedence.

Giữ toàn bộ tính năng Windows và dữ liệu cũ; không tự phát hành bản mới,
không sửa asset 0.15.1 đã công khai hoặc cài/đăng ký trên Windows để thử.
Setup22 và Author25 kiểm logic xác nhận, hủy, CheckOnly, lỗi và ghim trust;
mọi install/PATH/start adapter đều mock. Source command dùng fixture riêng
chỉ đổi PATH trong process. Hồi quy/giới hạn ghi KIEM-THU.md.

File mới: Setup.Core.ps1, Setup.Tests.ps1, Install-WinTune.ps1,
Cai-WinTune.cmd. Cập nhật Bootstrapper.template, Build-Distribution,
Release.Author.Tests, Run-Tests, Build-Package, Package.Check, version,
Prepare-GitHub và tài liệu. Chưa phát hành 0.15.2.

URL rút gọn bằng GitHub Pages: irm https://dinhluxury.github.io/WinTune-VI | iex. Publisher cần bật Pages main /docs một lần. index.html chứa entry PS cùngbyte get.ps1, nojekyll rỗng, UTF8khôngBOM cho IEX quaHTTP. Pages5 thử localHTTP/redirect/htmlMIME đạt; sửa lỗi BOM được phát hiện. Chưa bật/pháthànhPageshoặcRelease mới. Source/Releasebộlatest cần được đưa lên cùng nhau; không dùng bộ get cóBOM đã chuẩn bị trước.
