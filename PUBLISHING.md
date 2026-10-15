> Bản tiếp theo là v0.16.1. Kiểm thử bằng Run-Tests.ps1, đóng gói với -PublicRelease, chuẩn bị/ký đủ sáu asset, đưa mã nguồn và tag mới lên GitHub. Không thay asset hoặc tag của v0.16.0 đã phát hành.

# Đưa WinTune VI lên GitHub

Repository chính thức: [dinhluxury/WinTune-VI](https://github.com/dinhluxury/WinTune-VI).
Mã nguồn và bộ tải đã chuẩn bị tại thư mục ghi trong `github-ready/LATEST.txt`.
Việc chuẩn bị chỉ tạo file local, chưa đưa gì lên GitHub hoặc phát hành.

## Bổ sung entry CMD cho bản 0.15.2 đã phát hành

Không thay 6 asset hoặc tag v0.15.2. Dùng bộ Source đã chuẩn bị mới nhất:

```powershell
.\Build-CmdLauncher.ps1 -Prepared .\github-ready\v0.15.2-dc6f7c74
```

Đường dẫn bộ mới được ghi riêng trong `github-ready/CMD-LATEST.txt`.
Chép nội dung `Source` trong bộ đó vào repository đã clone, xem thay đổi,
Commit rồi Push origin. Bộ này thêm `docs/run.cmd`, template, công cụ tạo
launcher và bài kiểm thử; mã ứng dụng và entry PowerShell cũ giữ nguyên.
Pages main /docs đã bật sẽ tự cập nhật. Không cần tạo Release mới.

Sau khi Pages deploy thành công, tải `run.cmd`, đối chiếu SHA256 với
`PREPARED.json` trong bộ mới rồi kiểm tra `--check-only` từ CMD. Chế độ này
không mở ứng dụng, tải ZIP hay thay PATH. Thử mở ứng dụng trên PC mới là
bước riêng; không coi kiểm thử metadata/mock là bảo đảm mọi PC cho chạy.
Nếu Defender/App Control chặn, dừng; không đổi host/câu lệnh để né nhận diện.
Cách tải thành file và kiểm hash có mục đích làm nguồn thực thi reviewable,
không phải che dấu lệnh. Không dùng lại wrapper CMD `irm | iex` đã bị chặn.

Entry batch đầu tiên tin cậy HTTPS của GitHub Pages; chưa được hash-check
trước khi chạy. Không sửa byte template/entry đã kiểm tra khi đưa lên Git.

## 1. Đưa mã nguồn lên bằng GitHub Desktop

Nếu đã clone repository và phát hành 0.15.1, dùng lại thư mục Git đó;
bỏ qua bước 1–3. Chỉ chép Source mới, commit và Push origin.

1. Tải [GitHub Desktop chính thức](https://desktop.github.com/download/), mở và đăng nhập tài khoản **dinhluxury**.
2. Chọn **File → Clone repository → URL**, dán `https://github.com/dinhluxury/WinTune-VI`.
3. Chọn một thư mục mới cho bản Git, ví dụ `Documents\GitHub\WinTune-VI`, rồi bấm **Clone**.
   Không chọn thư mục phát triển cũ đang có nhiều ZIP/ISO/bản thử.
4. Mở thư mục `Source` trong bộ `github-ready` đã chuẩn bị. Chép **nội dung bên trong Source** vào thư mục vừa clone. Chép cả `.gitignore` và `.gitattributes`, giữ nguyên `.git` của GitHub Desktop.
5. Quay lại GitHub Desktop, xem danh sách thay đổi. Bộ Source gồm mã, XAML, JSON, tài liệu, license và snapshot tham khảo chỉ đọc. Không có EXE/ZIP/ISO, lịch sử máy hay khóa riêng.
6. Điền Summary: `WinTune VI 0.15.2: ứng dụng và hệ thống phân phối`, bấm **Commit to main**, rồi **Push origin** (hoặc **Publish branch** nếu nhánh main chưa có trên GitHub).
7. Mở lại repository trên web để kiểm tra README và các file đã xuất hiện.

Source có **get.ps1** ở thư mục gốc và **docs/index.html**, **docs/.nojekyll**.
Entry được sinh theo hash launcher trong đúng bộ Release; index.html là
cùng mã PowerShell để phục vụ cho URL ngắn. Không sửa nội dung hoặc thêm
BOM/HTML vào index.html. Chép toàn bộ Source đã chuẩn bị.

Để bật URL ngắn một lần: mở Settings → Pages của repository, chọn Source
**Deploy from a branch**, Branch **main**, Folder **/docs**, rồi **Save**.
Sau khi workflow Pages hoàn tất, URL là https://dinhluxury.github.io/WinTune-VI.
Nguồn: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site.
Lệnh mở chỉ dùng khi Pages đã phục vụ đúng entry và Release mới công khai.

[Hướng dẫn clone của GitHub](https://docs.github.com/en/desktop/adding-and-cloning-repositories/cloning-and-forking-repositories-from-github-desktop).
Không cần tải EXE/ZIP lên danh sách mã nguồn. Các gói tải nằm trong Releases.

## 2. Tạo bản phát hành 0.15.2

Làm sau khi mã nguồn đã lên repository:

1. Mở [tạo Release](https://github.com/dinhluxury/WinTune-VI/releases/new).
2. **Choose a tag:** gõ `v0.15.2`, chọn tạo tag mới. **Target:** `main` với commit vừa đưa lên.
3. **Release title:** `WinTune VI 0.15.2`.
4. Mở `RELEASE-NOTES.md` trong bộ `github-ready`, chép nội dung vào phần mô tả.
5. Kéo **6 file bên trong thư mục Release** vào ô đính kèm, giữ nguyên tên:
   - `WinTune-VI-v0.15.2-portable.zip`
   - `WinTune-Online.ps1`
   - `WinTune-Online.ps1.sha256`
   - `release.json`
   - `release.sig`
   - `ONLINE-COMMAND.txt`
6. Bấm **Save draft** để kiểm tra trước. Bản draft chưa cho người dùng tải qua launcher.
7. Khi muốn công khai, mở bản draft, kiểm tra đủ 6 file rồi bấm **Publish release**.
   Bản dùng với launcher phải là stable; không chọn **Set as a pre-release**.

[Hướng dẫn Releases chính thức](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).

Sau khi publish, kiểm tra tải từng asset, đối chiếu hash và chạy bootstrapper
với `-CheckOnly` trước. Lệnh kiểm tra chỉ đọc metadata ký, không tải ZIP hay
chạy WinTune. Thử đầy đủ tải/khởi chạy hoặc đăng ký lệnh là thao tác riêng có
xác nhận; không coi kiểm thử mock là bằng chứng chuỗi online đã hoạt động thật.

## 3. Khóa và bản phát hành kế tiếp

Khóa riêng được giữ **ngoài dự án**, trong thư mục khóa riêng của tác giả
dưới `%LOCALAPPDATA%\WinTuneVI-ReleaseKeys`. Không đưa `private.dpapi` lên
GitHub, ZIP/ISO hoặc gửi cho người khác. File mã hóa DPAPI thuộc tài khoản
Windows hiện tại; giữ máy/tài khoản và bản sao lưu hệ thống phù hợp, không
cho rằng chép riêng file này sang máy khác sẽ giải mã được.

Khóa công khai nằm trong `release-config.json`, được phân phối để kiểm tra
chữ ký. Đừng tạo khóa mới cho mỗi bản cập nhật: người dùng cũ cần cùng khóa
tin cậy. Nếu mất khóa, không thay âm thầm hoặc bỏ xác minh chữ ký; cần phân
phối bootstrapper/gói với khóa mới qua kênh tin cậy.

Quy trình local cho lần sau:

```powershell
.\Run-Tests.ps1
.\Build-Package.ps1 -PublicRelease
.\Build-Distribution.ps1
# Tự truyền đường dẫn khóa riêng đang giữ, không đưa vào mã nguồn:
.\Sign-Release.ps1 -Manifest <thu-muc-assets>\release.json -PrivateKey <thu-muc-khoa>\private.dpapi
.\Prepare-GitHub.ps1
```

Tăng `version.json` trước khi tạo phiên bản mới. Không sửa/ghi đè asset của
bản đã phát hành; tạo tag và bộ ký mới. `.gitattributes` giữ nguyên byte các
snapshot và file để hash nguồn không bị đổi bởi quy tắc xuống dòng của Git.

Các tệp LICENSE upstream phải được giữ cùng nguồn và gói. Dự án hiện giữ
giấy phép/ghi công MIT của những phần tham khảo. Chưa lựa chọn giấy phép cho
mã riêng WinTune; các file LICENSE upstream không tự cấp phép cho toàn bộ
mã riêng. Không dùng trình chọn license của GitHub để thay thế chúng.

Chữ ký manifest RSA là cơ chế xác minh của WinTune, không phải chữ ký
Authenticode của EXE. Không thay chính sách Application Control hoặc tắt
bảo mật Windows để phát hành/chạy thử.

Sau khi Source/get.ps1 và Release cùng phiên bản đã công khai, tải entry từ URL raw và đối chiếu Source/get.ps1 đã chuẩn bị trước khi thử. Có thể chạy bản local đã xác minh với -CheckOnly để chỉ kiểm metadata; không thử mở mặc định trong bài tự động vì nó chủ động tải và mở app. Entry đầu IEX tin cậy qua HTTPS; bản dài vẫn giữ hash-check trước chạy.
