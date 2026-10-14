# Đưa WinTune VI lên GitHub

Repository chính thức: [dinhluxury/WinTune-VI](https://github.com/dinhluxury/WinTune-VI).
Mã nguồn và bộ tải đã chuẩn bị tại thư mục ghi trong `github-ready/LATEST.txt`.
Việc chuẩn bị chỉ tạo file local, chưa đưa gì lên GitHub hoặc phát hành.

## 1. Đưa mã nguồn lên bằng GitHub Desktop

1. Tải [GitHub Desktop chính thức](https://desktop.github.com/download/), mở và đăng nhập tài khoản **dinhluxury**.
2. Chọn **File → Clone repository → URL**, dán `https://github.com/dinhluxury/WinTune-VI`.
3. Chọn một thư mục mới cho bản Git, ví dụ `Documents\GitHub\WinTune-VI`, rồi bấm **Clone**.
   Không chọn thư mục phát triển cũ đang có nhiều ZIP/ISO/bản thử.
4. Mở thư mục `Source` trong bộ `github-ready` đã chuẩn bị. Chép **nội dung bên trong Source** vào thư mục vừa clone. Chép cả `.gitignore` và `.gitattributes`, giữ nguyên `.git` của GitHub Desktop.
5. Quay lại GitHub Desktop, xem danh sách thay đổi. Bộ Source gồm mã, XAML, JSON, tài liệu, license và snapshot tham khảo chỉ đọc. Không có EXE/ZIP/ISO, lịch sử máy hay khóa riêng.
6. Điền Summary: `WinTune VI 0.15.0: ứng dụng và hệ thống phân phối`, bấm **Commit to main**, rồi **Push origin** (hoặc **Publish branch** nếu nhánh main chưa có trên GitHub).
7. Mở lại repository trên web để kiểm tra README và các file đã xuất hiện.

[Hướng dẫn clone của GitHub](https://docs.github.com/en/desktop/adding-and-cloning-repositories/cloning-and-forking-repositories-from-github-desktop).
Không cần tải EXE/ZIP lên danh sách mã nguồn. Các gói tải nằm trong Releases.

## 2. Tạo bản phát hành 0.15.0

Làm sau khi mã nguồn đã lên repository:

1. Mở [tạo Release](https://github.com/dinhluxury/WinTune-VI/releases/new).
2. **Choose a tag:** gõ `v0.15.0`, chọn tạo tag mới. **Target:** `main` với commit vừa đưa lên.
3. **Release title:** `WinTune VI 0.15.0`.
4. Mở `RELEASE-NOTES.md` trong bộ `github-ready`, chép nội dung vào phần mô tả.
5. Kéo **6 file bên trong thư mục Release** vào ô đính kèm, giữ nguyên tên:
   - `WinTune-VI-v0.15.0-portable.zip`
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
