# Bảng tùy chỉnh đầy đủ

Mở **Tùy chỉnh Windows**. Danh sách đầy đủ hiện trực tiếp trong trang, không cần mở cửa sổ phụ. Danh mục lưu 113 mục và ánh xạ 67 ID WinUtil; hiện 111 mục sau khi bỏ hai mục dọn tệp theo yêu cầu mới. Bảng đối chiếu 88 lựa chọn/checkbox Win11Debloat nằm trong `FullTweaks.json → Win11FeatureMap`; các lựa chọn cùng chức năng được gom chung. Giữ cả ba tùy chọn riêng về ẩn Widgets và Edge chạy nền/khởi chạy sẵn. Nhật ký cũ vẫn đọc và hoàn tác được qua Lịch sử bản cũ/Hoàn tác bản cũ.

## Cách dùng

1. Tìm tên tính năng hoặc chọn nhóm. Mỗi hàng đã có một câu giải thích; bấm tên hoặc khoảng trống của dòng để xem ảnh hưởng và cách hoàn tác. Ô đánh dấu chỉ chọn/bỏ chọn.
2. Với mục có nhiều lựa chọn, bấm dòng để mở phần giải thích, chọn giá trị mong muốn rồi đánh dấu mục. Danh sách đang chọn ghi cả tên và giá trị. Chọn nhanh chỉ chuẩn bị danh sách; chưa đổi Windows. Tối thiểu (8 mục), Tiêu chuẩn (19 mục), Nâng cao (31 mục) có mô tả ngay dưới bộ chọn; máy dùng Windows cũ bỏ qua mục chưa hỗ trợ. Tự chuyển sang **Tùy chỉnh** khi đánh dấu thêm, bỏ chọn hoặc đổi giá trị. Chọn một bộ khác thay danh sách chờ, còn chọn Tùy chỉnh giữ nguyên các lựa chọn. Các thao tác gỡ ứng dụng, giải mã ổ, đổi DNS hoặc cần xử lý riêng không được chọn sẵn.
3. Bấm **Xem trước các mục đã chọn**, đọc lại rồi xác nhận. Tác vụ chạy riêng nên cửa sổ vẫn phản hồi. Lưu công việc trước; ứng dụng không tự khởi động lại hoặc ép đóng chương trình.

**Hiệu năng và chế độ ngủ** là nhóm thiết lập về cách máy hoạt động và dùng điện: ngủ/ngủ đông, kết nối khi ngủ, cấu hình ưu tiên hiệu năng. Ví dụ, ngủ đông lưu phiên làm việc xuống ổ đĩa; chế độ hiệu năng cao có thể tăng điện, nhiệt và tiếng quạt. Đây không phải các thao tác cần bật cho mọi máy.

## Các giới hạn cần hiểu

- **Windows/build/edition/phần cứng:** có nút không đồng nghĩa Windows chắc chắn cho phép. Gói không có/không cho gỡ, chính sách doanh nghiệp, quyền truy cập hoặc phần cứng không hỗ trợ sẽ được báo. Riêng S3 có kiểm tra khả năng ngủ do Windows báo trước khi ghi.
- **Chọn mục đã áp dụng:** chọn các mục registry thuần có giá trị khớp cấu hình. Không suy ra rằng mọi chức năng đã có hiệu lực; không tự suy ra trạng thái gỡ app, DISM, DNS hay BitLocker từ checkbox.
- **Lựa chọn giao diện:** kiểu tìm kiếm, gộp nút, nhiều màn hình, thư mục mở đầu Explorer, chữ cái ổ đĩa, Spotlight, tab Alt+Tab và bố cục Start đều có giá trị tiếng Việt. All Apps mới chỉ cho chọn từ build 26200; Windows vẫn có thể chưa triển khai giao diện đó trên máy cụ thể.
- **Ngăn tự mã hóa thiết bị:** khác với giải mã BitLocker. Chỉ đặt chính sách ngăn tự bật mã hóa; không tự giải mã ổ đã mã hóa.
- **Bỏ ghim Start:** dùng mẫu `start2.bin` 972 byte từ Win11Debloat đã kiểm tra hash, sao lưu nguyên tệp cũ. Có mục riêng cho tài khoản hiện tại và mọi hồ sơ hiện có/mặc định. Xem trước liệt kê đường dẫn; nên đăng xuất tài khoản khác và đóng Start. Không ép đóng tiến trình hay sửa quyền nếu Windows khóa tệp. Không gỡ ứng dụng. Tệp bị Windows sửa sau đó sẽ chặn hoàn tác để tránh ghi đè bố cục mới.
- **Sandbox và WSL:** bật đúng các thành phần được liệt kê; không tự khởi động lại, cài distro Linux hay xóa dữ liệu Linux. Không tự bật phụ thuộc ngoài danh sách: Windows yêu cầu phụ thuộc khác sẽ báo lỗi. Sandbox cần edition và ảo hóa phù hợp. Hoàn tác trả trạng thái bật/tắt, không cố xóa bộ tệp Windows đã tải. Thành phần đang chờ khởi động lại phải hoàn tất trước khi thực hiện tiếp.
- **AI từng ứng dụng:** có các mục riêng cho Copilot, Recall, Click to Do, Edge, Paint và Notepad. Chính sách không bảo đảm chặn AI từ mọi trang web/ứng dụng. Nhóm tắt AI tổng thể dùng riêng một lần để tránh lựa chọn dịch vụ AI xung đột.
- **Chẩn đoán theo lịch:** chỉ xử lý tám tác vụ được nêu tên trong mã; lưu trạng thái bật/tắt, không xóa tác vụ. Không tắt Defender và không cam kết Windows Home/Pro ngừng mọi dữ liệu bắt buộc.
- **Hoàn tác:** khôi phục lần thay đổi gần nhất có bản sao cho mỗi mục được chọn, theo thứ tự ngược. Lưu cả kiểu dữ liệu, nhánh HKCU/HKLM/HKU, trạng thái chưa có giá trị/khóa, kiểu dịch vụ và quyền truy cập. Nếu ứng dụng khác đã đổi đích, WinTune dừng để không ghi đè.
- **Giải mã BitLocker:** chỉ đúng ổ đĩa được chọn; bắt đầu giải mã, không đợi toàn bộ quá trình hoàn tất. Phải tự bật lại mã hóa nếu cần. Không khôi phục khóa bảo vệ hay hứa hoàn tác tự động.
- **Edge/OneDrive:** dùng trình gỡ có chữ ký Microsoft. Yêu cầu đóng chương trình trước; không giả tệp trong SystemApps, không dùng force-uninstall/delete-profile và không dọn dữ liệu OneDrive. Nếu Windows không cho phép gỡ Edge, báo chưa hoàn tất.
- **Widgets/AI:** chỉ gói được nêu tên của tài khoản hiện tại; không AllUsers/provisioned. AI gồm Copilot, CoreAI và Microsoft 365 Hub khi cho gỡ, chính sách Notepad, dịch vụ AI và optional feature Recall khi có. Gói hệ thống bị bảo vệ có thể khiến tác vụ chỉ làm được một phần; không tự xóa cưỡng bức. Cài lại app không khôi phục dữ liệu đã mất.
- **Giảm dữ liệu chẩn đoán:** có các chính sách và dịch vụ liên quan, nhưng không tắt Defender/gửi mẫu chống virus. Home/Pro có thể vẫn gửi dữ liệu bắt buộc; không tuyên bố tắt mọi telemetry.
- **Dịch vụ:** danh sách cố định của WinUtil, gồm CscService, DiagTrack, MapsBroker, StorSvc và SharedAccess. Lưu cấu hình trước, bỏ mục không tồn tại, không tự dừng dịch vụ. Các thiết lập này có thể ảnh hưởng tệp ngoại tuyến, báo lỗi, bản đồ và chia sẻ mạng.
- **Dung lượng ổ đĩa:** bấm ở thanh bên để tự cài WizTree nếu chưa có, mở trực tiếp C: và tự quét. Không mở báo cáo CSV. Xem cây thư mục và bản đồ màu trong WizTree; muốn xem ổ khác dùng Select/Scan. Không tự xóa tệp.
- **Quyền Store/Razer/Logitech:** có thể làm lỗi Store hoặc chặn cài tiện ích; lưu ACL cũ và kiểm tra đường dẫn không qua liên kết. Không xóa dữ liệu/thư mục có sẵn chỉ để đặt quyền chặn.
- **Adobe:** danh sách tên miền có thể ảnh hưởng kích hoạt, đăng nhập, đồng bộ và cập nhật. Chỉ thêm dữ liệu tên miền đã chốt vào hosts, không tải/chạy script ở ngoài. Hoàn tác chỉ ghi lại tệp cũ khi chưa bị sửa bên ngoài.
- **DNS:** chọn đúng một card mạng đang có và nhà cung cấp. Hiện đổi IPv4; không tự thiết lập IPv6 hoặc DNS-over-HTTPS. Tùy chọn nhanh nhất chỉ là phép đo ngắn trên máy lúc chạy, không cam kết tốc độ luôn nhanh nhất. Hoàn tác giữ phân biệt DNS thủ công và tự động từ DHCP.
- **Ultimate Performance:** chỉ xóa plan do chính WinTune tạo và ghi lại; không xóa plan của hãng hoặc của người dùng. Có thể tăng nhiệt/điện, không bảo đảm FPS. Phần đổi plan đã có của WinTune vẫn sử dụng được.
- **O&O:** mở trang chính thức để tải, sau đó chọn EXE có chữ ký O&O hợp lệ. Không tự tải/chạy công cụ ngoài, không kiểm soát hoặc hoàn tác các lựa chọn bạn làm trong O&O.

## Nguồn và bảo trì

- [WinUtil, commit đã đối chiếu](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json). Giữ LICENSE-WinUtil.txt. Cấu hình là dữ liệu, không thực thi InvokeScript/UndoScript lấy từ upstream.
- [Win11Debloat, commit đã đối chiếu](https://github.com/Raphire/Win11Debloat/tree/4079b276e9e93aa8698a9f70f5aa228ba11f8265). Giữ LICENSE-Win11Debloat.txt. Dùng dữ liệu registry và mẫu bố cục Start; không chạy script upstream. Liên kết Game Bar dùng HKCU thay HKCR; Store/Widgets/Copilot chỉ tài khoản hiện tại, không sao chép gỡ Appx mọi tài khoản.
- [Danh sách tên miền Adobe đã chốt](https://github.com/Ruddernation-Designs/Adobe-URL-Block-List/tree/3cba6db8b7cf53a270ce7357ed711dd0a5aa7898). Chỉ giữ dữ liệu tên miền, nguồn và checksum; không sao chép/chạy apply.bat/apply.sh.
- [Microsoft: BitLocker](https://learn.microsoft.com/en-us/powershell/module/bitlocker/disable-bitlocker), [DNS](https://learn.microsoft.com/en-us/powershell/module/dnsclient/set-dnsclientserveraddress), [powercfg](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options), [dung lượng dự trữ](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism-storage-reserve), [khả năng ngủ của máy](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-system_power_capabilities).
- [Cloudflare DNS](https://developers.cloudflare.com/1.1.1.1/ip-addresses/) và [AdGuard DNS](https://adguard-dns.io/en/public-dns.html) là tài liệu nhà cung cấp đã kiểm tra cho các lựa chọn lọc nội dung.

FullTweaks.json là danh mục mới, FullTweaks.Core.ps1 quản lý kế hoạch/nhật ký, FullTweaks.Native.ps1 chứa các thao tác Windows cố định, FullTweaks.Worker.ps1 chạy nền và FullTweaks.UI.ps1 tạo giao diện. Không đưa lệnh/script tùy ý vào JSON. Danh mục và dữ liệu Adobe được ghim checksum trong engine; thay đổi có chủ ý cần cập nhật checksum và chạy lại kiểm tra trước khi đóng gói.

Các kiểm tra mô phỏng không thay thế thử nghiệm thủ công trong máy ảo và không chứng minh mọi installer/edition/phần cứng đều hoạt động. Bản 0.15.2 và các gói trước vẫn được giữ nguyên; bản mới cần được chủ dự án phát hành riêng sau khi kiểm tra.
