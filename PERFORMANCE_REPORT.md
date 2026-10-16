# WinTune VI — Báo cáo hiệu năng

Ngày 16/10/2026. Có phép đo local; chưa có benchmark online/cold start hoặc soak test dài hạn.

## Môi trường và phương pháp

Windows 11 Professional build 26300, Windows PowerShell **5.1.26100.9711 Desktop x64 STA**, CLR 4.0.30319.42000; WPF .NET Framework hiện có. GUI lifecycle thực tế ghi DPI scale **1.25**. CIM/Appx bị từ chối quyền trong sandbox; không tự nâng quyền để lấy số đẹp.

`Audit.Benchmark.ps1` tạo entry đo cục bộ từ nguồn WinTune, chạy `-GuiProbe` với provider mô phỏng và data root riêng. Stopwatch bắt đầu trong script: đo tải WPF, XAML, khởi tạo và ContentRendered; không bao gồm mạng hay toàn bộ tạo PowerShell process. Sau đó chờ timer 2s, render lại 10 vòng, lưu JSON và đóng. Không chạy tweak. Ba process mới trước khi bỏ render trùng và ba process sau. OS/.NET/disk caches không bị xóa; cả nhóm là fresh-process/warm-cache quan sát được, **không gọi lượt đầu là cold start**.

Bằng chứng: `.audit/performance-before`, `.audit/performance-after`, `.audit/performance-summary.json`. Baseline archive giữ nguồn trước audit. Một số test khác có chạy trong phiên; tải máy chưa được kiểm soát/đảo thứ tự A/B. Cỡ mẫu nhỏ nên không khẳng định mức tăng tốc ổn định hoặc quy toàn bộ chênh lệch cho một dòng sửa.

## Số đo thực tế

| Chỉ số, median 3 lượt | Trước | Sau | Kết luận |
|---|---:|---:|---|
| Script -> ContentRendered | 2195.7 ms | 1804.4 ms | Giảm quan sát khoảng 17.8%; không phải thời gian lệnh online |
| Working set lúc render | 206.8 MiB | 209.9 MiB | Không có bằng chứng giảm RAM |
| Private bytes lúc render | 199.6 MiB | 202.8 MiB | Tăng nhẹ; chưa xác định là regression hoặc nhiễu |
| Process handles | 655 | 671 | Snapshot, không chứng minh leak |
| CPU time trong cửa sổ chờ ~2s | 15.625 ms | 0.000 ms | Độ phân giải CPU hữu hạn; 0 không nghĩa app không dùng CPU |
| Số card được hiển thị | 111 | 111 | Giữ đủ tính năng |

Render 10 lượt/process có số đo thô, nhưng thân hàm render không được tối ưu trong audit. Chênh lệch giữa các nhóm không được dùng làm tuyên bố tăng tốc render do code. CPU trên là trang Features trong probe, theme auto-watch và hardware polling không chạy như chế độ production; **không dùng để kết luận idle CPU của Dashboard thật**.

## Thay đổi có căn cứ

1. `New-FullTweaksWindow`: SelectionChanged đã render khi đặt SelectedIndex=0; bỏ lời gọi lặp làm giảm một lần dựng 111 card. Không bỏ kiểm tra hash/security.
2. Inventory/plan Appx được chuyển ra worker. Đây là cải thiện đáp ứng, có thêm một process PowerShell lúc đọc; không quảng cáo giảm tổng thời gian hoặc peak RAM. WPF test với worker trì hoãn 1200ms vẫn nhận nhiều timer ticks.
3. Dispose Process và dừng timer khi nhận kết quả/đóng; giữ guard đến khi result được xử lý. Đây là sửa vòng đời, chưa có số đo memory leak dài hạn.
4. Flush(true) backup có thể chậm hơn; chấp nhận để ưu tiên độ bền rollback. Không bỏ flush để rút ngắn benchmark.

Không áp dụng runspace pool mới, cache trạng thái Registry/CIM lâu, minify code, lazy-load tùy tiện, ép GC, đổi công nghệ hoặc cắt kiểm tra chữ ký. Chưa có bằng chứng đủ để chấp nhận các đánh đổi này.

## Các phép đọc riêng

Nguồn `.audit/read-performance.json`; một lượt, không phải A/B:

- Tạo host `powershell.exe -NoProfile -STA` rồi thoát: 5 lượt 152.8–179.4ms, median 155.8ms; bao gồm tạo process/host/thoát, không tách hoàn toàn từng pha.
- Đọc applied Registry selections: 256.8ms, 25 selection khớp; chỉ đọc.
- CPU CIM: **UNAVAILABLE**, bị từ chối quyền sau 230.7ms. Đây là thời gian thất bại, không phải hiệu năng truy vấn thành công.
- Appx inventory: **UNAVAILABLE**, Access denied sau 101.0ms; không lấy con số này làm benchmark tải danh sách.
- Hardware overview trả cấu trúc sau 2698.1ms nhưng một số provider bị chặn; đó là xử lý dữ liệu thiếu, không chứng nhận đầy đủ thông tin phần cứng.
- Process reader trả một cấu trúc tổng hợp sau 34.0ms; không phải số process bằng 1.

## Chưa đo / cần môi trường khác

Network launcher, download/bootstrap/RSA/ZIP end-to-end với production, true cold cache, input-to-dispatch latency chuẩn hóa, CPU khi repair/native installer chạy, peak memory gồm worker, Dashboard native soak, shutdown khi CIM treo, warm page transitions từng loại, 100–200% DPI thực và multi-monitor. Chưa thể kết luận không có memory leak sau nhiều giờ.

Để lặp đo an toàn, dùng Windows PowerShell 5.1 STA và `./Audit.Benchmark.ps1 -Label measured -Runs 3`. Tạo baseline từ archive trong một thư mục riêng trước khi so sánh; không ghi đè workspace hiện có. Cần tách test load, chạy xen kẽ A/B nhiều lượt và theo dõi child PIDs nếu muốn kết luận mạnh hơn.

## Vòng đời ngắn bổ sung

Đã chạy 30 chu kỳ trong một process mô phỏng: đổi Dashboard/Features, render catalog, mở/đóng dialog. Không gọi GC.Collect; 0 write. Raw data `.audit/lifecycle-samples.json`. Private bytes: 226.0 MiB ở chu kỳ 1, đỉnh 295.8 MiB, 262.6 MiB ở chu kỳ 30; có giảm tự nhiên giữa các chu kỳ, chưa chứng minh plateau hoặc không có leak. Handles 693 -> 695. Sau đóng: 0 monitor jobs, Monitor/Theme/Full timers đều dừng (`.audit/lifecycle-cleanup.json`); process probe đã thoát. Đây là stress ngắn, không thay soak test nhiều giờ hay native polling.
