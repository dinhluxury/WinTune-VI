# WinTune VI — Báo cáo bảo mật

Ngày 16/10/2026. Sửa trong workspace; chưa deploy các thay đổi này. Không thực thi mã Internet để thử.

## Đường tin cậy thực tế

`irm https://dinhluxury.github.io/WinTune-VI | iex`
→ Pages text → get.ps1 → tải WinTune-Online.ps1 theo tag cố định → SHA256 ghim → public key RSA trong bootstrap → release.json + release.sig → SHA256/size ZIP → kiểm tra đường ZIP và inventory tài nguyên → PowerShell 5.1 STA mở WinTune.

Đã tải Pages **chỉ dưới dạng văn bản** trong audit: hash `61BD09AB063521A0CB8F8ECEEBE04AB6059716ED3B99F42A013C9EEEEA633EB4` trùng `docs/index.html` và `get.ps1` của tag v0.16.3. `git ls-remote` main trả `f3aad2f0b4bcbaa6336034263e68afaf6807c2d5` tại thời điểm kiểm tra. Entry ghim bootstrap v0.16.3 với SHA256 `8C63F1439F5415A5AB361754F1B79F647CC6F2DFA09C115D0840CD68388288E4`. Đây là quan sát theo thời điểm, không đảm bảo Pages/main luôn đồng bộ.

Lần tải tiếp bootstrap/manifest/chữ ký production bị auto-review dừng vì giới hạn sử dụng. Vì vậy **chưa xác minh chữ ký production trong lần audit này**. Kiểm thử RSA/ZIP bên dưới dùng khóa và gói fixture, không được thay bằng kết luận production đã đạt.

## Rủi ro còn lại của irm | iex

- First byte từ Pages được thực thi trước khi có hash độc lập. Ai chiếm repository/Pages/tài khoản xuất bản có thể thay cả script và hash/public key nhúng. HTTPS bảo vệ đường truyền nhưng không giải quyết quyền sở hữu nguồn.
- Checksum cùng nguồn giúp phát hiện lỗi/tamper so với giá trị ghim; không phải chứng thực nguồn độc lập nếu nguồn ghim cũng bị thay.
- RSA ký manifest không phải Authenticode ký từng script và không thay thế WDAC/AppLocker. ExecutionPolicy Bypass chỉ là cờ host, không phải sandbox hoặc ranh giới bảo mật.
- Chạy Administrator mở rộng hậu quả của mã bị thay. DPAPI CurrentUser không bảo vệ trước malware cùng tài khoản; dữ liệu/entry trong LocalAppData có thể bị cùng user sửa.
- Kiểm tra file rồi mở còn cửa sổ TOCTOU. Thay đổi mới giảm cache tamper trong đường online nhưng không tạo cách ly hoàn chỉnh trước một attacker cùng user đang chạy. Entry local/EXE cũ có mô hình tin cậy khác, cần người dùng tin gói local.

Giữ nguyên URL/lệnh theo yêu cầu. Không tự chuyển sang EXE, thay policy, thay nơi cài đặt/quyền ACL hoặc cách phát hành.

## Các bảo vệ đã kiểm tra

- Chỉ URL HTTPS và host GitHub được cho phép; kiểm tra redirect, không gửi tới localhost qua redirect.
- Manifest kiểm chữ ký trước parse JSON; tag/repository/version/architecture/asset/size phải khớp; RSA tối thiểu 2048 bit; không đưa private key vào config.
- Từ chối traversal, absolute path, ADS, tên Windows dành riêng, tên ZIP trùng không phân biệt hoa/thường, symlink/reparse; giới hạn số entry và dung lượng giải nén.
- Staging riêng, hash toàn bộ tài nguyên, kích hoạt side by side, không ghi đè app đang chạy hoặc lịch sử v2; không tiếp tục launch khi bước kiểm tra thất bại.
- Commands dùng handler/ID/target cố định và argument quoting; catalog không chứa script để evaluate. WPF nạp code/tài nguyên local đã được đóng gói, không tự nạp module từ URL tùy ý.
- Appx giới hạn theo user, xác minh exact package/publisher/protection, không AllUsers/forced Edge deletion. Không tự tắt Defender/Firewall/Update/UAC/Secure Boot.
- BitLocker, service, DNS, ACL, hosts, gỡ app và tool ngoài là lựa chọn nhạy cảm cần xác nhận; preset không chọn các mục có Risk hoặc native handler ngoài phạm vi đã duyệt.
- Backup/journal dùng DPAPI tài khoản, đường thuộc data root, reject reparse, schema/target allowlist; không thực thi nội dung log/journal như code.

## Đã tăng cường local

1. **Cache installed**: bootstrap không còn chỉ tin checksum nằm cùng thư mục app. `Assert-InstalledRelease` kiểm manifest lại bằng key từ bootstrap, yêu cầu version khớp signed release, kiểm ZIP cached theo signed size/hash, lấy inventory từ ZIP và so với inventory cài đặt trước khi verify từng file.
2. Cache ZIP dùng tên digest; nội dung vẫn phải kiểm mỗi lần. Bản cũ chưa có cache sẽ tải ZIP có chữ ký một lần; cache hỏng hoặc version giả sẽ từ chối chạy. Đây là thay đổi fail-closed, có thể cần hỗ trợ người dùng có cache đã hỏng; không tự ghi đè dữ liệu để che lỗi.
3. Hỗ trợ tên entry ZIP dùng slash hoặc backslash do .NET Windows tạo; không mở rộng quyền thoát root.
4. Kiểm thử sửa cả code + checksum chứng minh cơ chế cũ vẫn có thể pass local checksum, nhưng signed inventory mới từ chối; cache ZIP bị đổi, fake version, wrong signature cũng bị từ chối.
5. Kiểu JSON result được kiểm tra trước đưa vào formatter; lỗi đọc không được gán thành công. Timer/lifecycle và phục hồi Pending được sửa để không bỏ qua trạng thái thất bại.

Các thay đổi template/Core **không làm bản bootstrap đang phát hành trên GitHub tự được bảo vệ**. Cần quy trình review/build/sign/publish được chủ dự án cho phép ở bước riêng.

## Đề xuất chưa áp dụng

- Phương án tùy chọn cho người cần bảo đảm cao hơn: tải gói theo tag cố định và xác minh khóa/hash nhận qua kênh tin cậy độc lập; hướng dẫn fingerprint ngoài Pages. Việc thay lệnh chính cần quyết định riêng.
- Bảo vệ kho phát hành bằng MFA, quyền tối thiểu, branch/release protections và bảo vệ khóa ký; chưa kiểm tra cấu hình tài khoản GitHub nên không khẳng định đang bật.
- Nếu cần chống attacker cùng user khi launch elevated: cần thiết kế vị trí/ACL, signed code/WDAC và xử lý TOCTOU nhất quán. Không tự áp ACL hoặc cài vào vùng hệ thống trong audit.
- Thử crash/power-loss và mutation trên VM snapshot; không thực hiện trên máy cá nhân.

Tham khảo đã truy cập: [Microsoft DPAPI scope](https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.dataprotectionscope?view=netframework-4.8.1), [PowerShell encoding](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-5.1). Số liệu live và log fixture ở `.audit/live`, `evidence/Distribution.Tests.ps1.log`, `evidence/Release.Author.Tests.ps1.log`.

## Bản vá v0.16.4 và phạm vi phát hành

User đã yêu cầu kiểm thử tiếp và đưa lên GitHub. Bản mới dùng khóa RSA gốc, không đổi URL/lệnh mở. Việc chuẩn bị/ký local không tự chứng minh byte đang phục vụ production; chỉ coi live đã xác minh sau khi tải đối chiếu chữ ký/hash từ GitHub. Không thực thi mã Internet bằng Administrator để test.

Rà soát thêm: không ghi đè giá trị Registry cùng khóa khi thiếu bằng chứng ownership; chặn giá trị sao lưu không phục hồi được trước mutation; không coi lỗi đọc Recall là không cài Recall. Trường hợp native irreversible bị đổi một phần/không rõ vẫn giữ journal và khóa recovery, không báo hoàn tác thành công.
