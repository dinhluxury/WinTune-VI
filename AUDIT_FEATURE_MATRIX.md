# Ma trận phạm vi chức năng đã audit

Sinh trực tiếp từ catalog v0.16.3. `MOCK` chứng minh đường logic với dữ liệu giả; không chứng minh tác dụng trên mọi bản Windows. `NOT TESTED` là thao tác Windows thật.

| ID | Tên | Handler | Build tối thiểu | Cần cân nhắc | Kiểm tra khả dụng | Thực thi Windows thật |
|---|---|---|---:|---|---|---|
| WPFTweaksActivity | Giảm lưu lịch sử hoạt động | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksHiber | Tắt chế độ ngủ đông | Hibernate | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksWidget | Gỡ Widgets trên taskbar và màn hình khóa | Widgets | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksRevertStartMenu | Dùng bố cục Start trước đây | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksDisableStoreSearch | Chặn gợi ý ứng dụng từ Store | StoreAcl | 22621 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksLocation | Tắt truy cập vị trí | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksServices | Giảm dịch vụ chạy tự động | Services | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksBraveDebloat | Giảm tính năng phụ của Brave | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksDisableWarningForUnsignedRdp | Bỏ cảnh báo tệp kết nối từ xa | Registry | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksEdgeDebloat | Giảm tính năng phụ của Edge | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksConsumerFeatures | Giảm nội dung và ứng dụng quảng bá | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksTelemetry | Giảm dữ liệu chẩn đoán và cá nhân hóa | Telemetry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksDeliveryOptimization | Tắt chia sẻ bản cập nhật với máy khác | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksRemoveEdge | Gỡ Microsoft Edge | Edge | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksDisableBitLocker | Tắt mã hóa BitLocker cho ổ đã chọn | BitLocker | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksUTC | Dùng giờ UTC cho đồng hồ phần cứng | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksRemoveOneDrive | Gỡ OneDrive | OneDrive | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksRemoveHomeAndGallery | Ẩn Home và Thư viện ảnh trong Explorer | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksDisplay | Giảm hiệu ứng hình ảnh | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksReservedStorage | Tắt dung lượng dự trữ của Windows | ReservedStorage | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksRestorePoint | Tạo điểm khôi phục Windows | Route | 22000 | False | Route kiểm tra tĩnh/UI | NOT TESTED |
| WPFTweaksEndTaskOnTaskbar | Thêm Kết thúc tác vụ khi chuột phải | Registry | 22631 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksStorage | Tắt tự dọn dẹp Storage Sense | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksWindowsAI | Tắt AI Windows và gỡ ứng dụng AI | WindowsAI | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksWPBT | Chặn phần mềm OEM qua WPBT | Registry | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksPreventDeviceMetadataFromNetwork | Ngăn tự tải ứng dụng đi kèm thiết bị | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksRazerBlock | Chặn tự cài tiện ích Razer | RazerAcl | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksLogiBlock | Chặn Logitech Download Assistant | LogitechAcl | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksDisableNotifications | Tắt trung tâm thông báo và lịch | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksBlockAdobeNet | Chặn kết nối theo danh sách Adobe | AdobeHosts | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksRightClickMenu | Dùng menu chuột phải kiểu Windows 10 | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksDiskCleanup | Dọn tệp hệ thống Windows | DiskCleanup | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksDeleteTempFiles | Dọn tệp tạm | Temp | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksIPv46 | Ưu tiên IPv4 khi kết nối mạng | Registry | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksTeredo | Tắt đường hầm Teredo | Registry | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksDisableIPv6 | Tắt IPv6 bằng chính sách Windows | Registry | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksDisableBGapps | Hạn chế ứng dụng Windows chạy nền | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFTweaksDisableExplorerAutoDiscovery | Tắt tự nhận diện loại thư mục | FolderDiscovery | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleDetailedBSoD | Chi tiết lỗi màn hình xanh | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleBatteryPercentage | Phần trăm pin trên taskbar | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleDarkMode | Giao diện Windows và ứng dụng | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleShowExt | Đuôi tên tệp | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleHiddenFiles | Tệp và thư mục ẩn | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleVerboseLogon | Thông tin khi đăng nhập và tắt máy | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleNewOutlook | Chuyển sang Outlook mới | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleScrollbars | Thanh cuộn của Windows | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFMultiplaneOverlay | Multiplane Overlay (MPO) | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleMouseAcceleration | Tăng tốc con trỏ chuột | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleNumLock | Bật Num Lock khi khởi động | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleWindowSnapping | Tự chia cửa sổ khi kéo tới cạnh | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleStandbyFix | Kết nối mạng khi ngủ Modern Standby | Registry | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleS3Sleep | Chế độ ngủ S3 | Registry | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleHideSettingsHome | Trang chủ của Settings | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleBingSearch | Tìm kiếm web trong Start | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleLoginBlur | Làm mờ nền màn hình đăng nhập | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleDisableLockscreen | Màn hình khóa trước đăng nhập | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleStartMenuRecommendations | Vùng Đề xuất trong Start | Registry | 22621 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleStickyKeys | Phím dính và phím tắt nhấn Shift 5 lần | Registry | 26100 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleTaskbarAlignment | Căn biểu tượng taskbar | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleTaskbarSearch | Kiểu tìm kiếm trên taskbar | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleTaskView | Nút Chế độ xem tác vụ | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleGameMode | Chế độ trò chơi | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFToggleLongPaths | Đường dẫn tệp dài | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFOOSUbutton | Chạy O&O ShutUp10++ | OOSU | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFchangedns | Đổi máy chủ DNS | Dns | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFAddUltPerf | Thêm chế độ hiệu năng tối đa | UltimateAdd | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WPFRemoveUltPerf | Xóa chế độ hiệu năng tối đa do WinTune tạo | UltimateRemove | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableSuggestions | Giảm mẹo và quảng cáo trong Windows | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableNotifications | Tắt thông báo từ ứng dụng | Registry | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableFindMyDevice | Tắt tìm thiết bị bị thất lạc | Registry | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableLockscreenTips | Ẩn mẹo trên màn hình khóa | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableEdgeAds | Ẩn quảng cáo và bảng tin trong Edge | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableCopilot | Tắt Microsoft Copilot | Copilot | 22621 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableRecall | Tắt Windows Recall | Optional | 22621 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableClickToDo | Tắt Click to Do | Registry | 22621 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableAISvcAutoStart | Ngăn dịch vụ AI tự chạy | Services | 22621 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableDVR | Tắt quay màn hình bằng Xbox Game Bar | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableGameBarIntegration | Ngăn Game Bar tự mở | Registry | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableStartPhoneLink | Ẩn điện thoại trong Start | Registry | 22621 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableSettings365Ads | Ẩn quảng cáo Microsoft 365 trong Settings | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableEdgeAI | Tắt AI trong Microsoft Edge | Registry | 22621 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisablePaintAI | Tắt AI trong Paint | Registry | 22621 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableNotepadAI | Tắt AI trong Notepad | Registry | 22621 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableDragTray | Tắt khay chia sẻ khi kéo tệp | Registry | 26200 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableSnapAssist | Tắt gợi ý cửa sổ khi chia màn hình | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableSnapLayouts | Ẩn bảng bố cục chia cửa sổ | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableFastStartup | Tắt khởi động nhanh | Registry | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableBitlockerAutoEncryption | Ngăn Windows tự bật mã hóa thiết bị | Registry | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBEnableLastActiveClick | Bấm taskbar để mở cửa sổ dùng gần nhất | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBHideDupliDrive | Ẩn ổ USB bị hiện hai lần | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBHideHome | Ẩn Home trong File Explorer | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBHideGallery | Ẩn Thư viện ảnh trong File Explorer | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableTransparency | Tắt hiệu ứng trong suốt | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableAnimations | Tắt hoạt ảnh của Windows | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDisableUpdateASAP | Không nhận cập nhật sớm nhất | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBPreventUpdateAutoReboot | Hạn chế tự khởi động lại sau cập nhật | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBHideOnedrive | Ẩn OneDrive trong File Explorer | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBAddFoldersToThisPC | Hiện thư mục quen thuộc trong This PC | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBEnableWindowsSandbox | Bật Windows Sandbox | Optional | 22483 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBEnableWindowsSubsystemForLinux | Bật môi trường Linux (WSL) | Optional | 22000 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDesktopSpotlight | Ảnh nền tự đổi của Windows | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBMultiMon | Màn hình nào hiện nút ứng dụng đang mở? | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBCombineButtons | Gộp cửa sổ cùng ứng dụng — màn hình chính | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBCombineMMButtons | Gộp cửa sổ cùng ứng dụng — màn hình phụ | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBExplorerLocation | Thư mục mở đầu của File Explorer | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBDriveLetterPosition | Vị trí chữ cái ổ đĩa | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBShowTabsInAltTab | Tab trình duyệt trong Alt+Tab | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBStartAllAppsView | Bố cục danh sách ứng dụng trong Start | Registry | 26200 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBClearStart | Bỏ ghim toàn bộ ứng dụng trong Start | StartPins | 22621 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| DBClearStartAllUsers | Bỏ ghim Start cho mọi tài khoản | StartPins | 22621 | True | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WTwidgets | Ẩn thời tiết và Widgets trên thanh tác vụ | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WTedgestartupboost | Tắt khởi chạy sẵn Microsoft Edge | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |
| WTedgebackground | Tắt Edge chạy nền sau khi đóng | Registry | 22000 | False | Preview/apply/undo hoặc giới hạn undo: MOCK | NOT TESTED |

Có 113 mục trong catalog; 111 mục xuất hiện ở bảng hiện tại. Hai mục dọn file được ẩn để dùng WizTree theo thiết kế hiện có. Đường khôi phục mở công cụ riêng. Không xóa dữ liệu trong audit.

## Danh mục cũ

| ID | Tên | Loại | Kiểm tra |
|---|---|---|---|
| ads | Tắt mã quảng cáo của Windows | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| tailored | Tắt trải nghiệm dựa trên dữ liệu chẩn đoán | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| tracking | Tắt theo dõi số lần mở ứng dụng | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| tips | Giảm mẹo và gợi ý Windows | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| explorerads | Ẩn gợi ý nhà cung cấp đồng bộ | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| locktips | Giảm mẹo trên màn hình khóa | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| bing | Tắt gợi ý tìm kiếm Bing trong Start | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| search | Tìm kiếm trên thanh tác vụ | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| taskview | Nút Task View | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| align | Vị trí nút trên thanh tác vụ | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| endtask | Thêm Kết thúc tác vụ vào taskbar | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| alttab | Thẻ ứng dụng trong Alt + Tab | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| extensions | Hiện phần mở rộng của tệp | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| thispc | Thư mục mở khi vào File Explorer | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| transparency | Tắt hiệu ứng trong suốt | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| dvr | Tắt ghi hình bằng Xbox Game Bar | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| darkmode | Màu giao diện Windows và ứng dụng | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| lastactive | Nhấp biểu tượng taskbar để chuyển cửa sổ gần nhất | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| hiddenfiles | Hiện tệp và thư mục ẩn trong Explorer | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| widgets | Ẩn thời tiết và Widgets trên thanh tác vụ | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| edgestartupboost | Tắt khởi chạy sẵn Microsoft Edge | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| edgebackground | Tắt Edge chạy nền sau khi đóng | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| classicmenu | Menu chuột phải kiểu Windows 10 | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| notepadai | Tắt AI trong Notepad | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| recall | Tắt lưu ảnh màn hình cho Recall | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| copilotapp | Gỡ ứng dụng Microsoft Copilot | Action | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| starttips | Giảm đề xuất và mẹo trong Start | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| startaccount | Ẩn nhắc tài khoản trong Start | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| accountnotices | Giảm gợi ý tài khoản trong Settings | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| setupoffers | Tắt lời mời hoàn tất thiết lập Windows | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| suggestedapps | Hạn chế tự cài ứng dụng được gợi ý | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| suggestiontoast | Tắt thông báo gợi ý Windows | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| phonelinkstart | Ẩn Phone Link bên cạnh Start | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| dragtray | Ẩn khay chia sẻ khi kéo tệp | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| snapassist | Tắt gợi ý cửa sổ khi chia màn hình | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| snaplayouts | Ẩn bảng bố cục khi kéo hoặc rê nút phóng to | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| scrollbars | Luôn hiện thanh cuộn của Windows | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| pointerprecision | Tắt tăng độ chính xác con trỏ | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| windowsnapping | Tắt tự chia cửa sổ khi kéo tới cạnh | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| notifications | Tắt thông báo ứng dụng Windows | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| taskbarcombine | Gộp cửa sổ cùng ứng dụng — màn hình chính | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| multicombine | Gộp cửa sổ cùng ứng dụng — màn hình phụ | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| multitaskbar | Màn hình nào hiện nút ứng dụng đang mở? | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |
| driveletters | Cách hiển thị ký tự ổ đĩa | Registry | Core/Extended/Coverage/UI MOCK; Registry thật NOT TESTED |

## Phần mềm cài qua WinGet

| ID | Tên | Kiểm tra |
|---|---|---|
| 7zip.7zip | 7-Zip | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| Google.Chrome | Google Chrome | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| Mozilla.Firefox | Firefox | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| VideoLAN.VLC | VLC | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| SumatraPDF.SumatraPDF | Sumatra PDF | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| UniKey.UniKey | UniKey | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| Valve.Steam | Steam | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| EpicGames.EpicGamesLauncher | Epic Games | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| Discord.Discord | Discord | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| OBSProject.OBSStudio | OBS Studio | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| Audacity.Audacity | Audacity | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| HandBrake.HandBrake | HandBrake | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| TheDocumentFoundation.LibreOffice | LibreOffice | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| Zoom.Zoom | Zoom | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| Notepad++.Notepad++ | Notepad++ | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| Microsoft.PowerToys | PowerToys | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |
| Microsoft.VisualStudioCode | Visual Studio Code | Danh mục, tham số, chọn/xác nhận/worker MOCK; cài thật NOT TESTED |

## Gỡ ứng dụng

30 ứng dụng trong danh mục gợi ý; inventory có thể hiển thị thêm Appx/MSIX hiện có. Từng ứng dụng được xét bảo vệ, tên gói, publisher, đang chạy, xác nhận, đọc lại sau thao tác. Tests mô phỏng; không gỡ Appx thật.

| Tên gói | Tên |
|---|---|
| Microsoft.WindowsFeedbackHub | Trung tâm phản hồi |
| Microsoft.GetHelp | Ứng dụng Trợ giúp |
| Microsoft.OutlookForWindows | Outlook for Windows |
| MSTeams | Microsoft Teams |
| Clipchamp.Clipchamp | Trình sửa video Clipchamp |
| Microsoft.MicrosoftOfficeHub | Office Hub |
| Microsoft.ZuneMusic | Media Player |
| Microsoft.BingSearch | Bing Search |
| MicrosoftCorporationII.QuickAssist | Quick Assist |
| Microsoft.Windows.DevHome | Dev Home |
| MicrosoftWindows.CrossDevice | Cross Device Experience |
| Microsoft.Todos | Microsoft To Do |
| Microsoft.PowerAutomateDesktop | Power Automate |
| Microsoft.YourPhone | Liên kết điện thoại |
| Microsoft.MicrosoftStickyNotes | Sticky Notes |
| Microsoft.WindowsSoundRecorder | Sound Recorder |
| Microsoft.WindowsAlarms | Alarms & Clock |
| Microsoft.Paint | Paint |
| Microsoft.WindowsNotepad | Notepad |
| Microsoft.ScreenSketch | Snipping Tool |
| Microsoft.Copilot | Microsoft Copilot |
| Microsoft.WindowsCalculator | Calculator |
| Microsoft.WindowsCamera | Camera |
| Microsoft.Windows.Photos | Photos |
| Microsoft.BingNews | Ứng dụng Tin tức |
| Microsoft.BingWeather | Ứng dụng Thời tiết |
| Microsoft.GamingApp | Ứng dụng Xbox |
| Microsoft.XboxGamingOverlay | Xbox Game Bar |
| Microsoft.MicrosoftSolitaireCollection | Solitaire Collection |
| Microsoft.ZuneVideo | Movies & TV |

## Những đường ngoài catalog

| Nhóm | Logic / kiểm tra | Giới hạn |
|---|---|---|
| Tổng quan CPU/RAM/GPU/ổ đĩa | Monitor tests, WPF mock, probe chỉ đọc khi chạy được | Không phải kiểm tra sức khỏe phần cứng |
| Khôi phục Windows | Worker, xác nhận, đọc lại mốc; UI mock | Không tạo/khôi phục mốc thật |
| Sửa Windows | DISM/SFC/CHKDSK tham số cố định, worker mock | Không sửa hệ thống thật |
| Nhật ký Windows | Giải mã/group sự kiện và trạng thái dịch vụ qua fixture | Không tự suy ra nguyên nhân |
| WizTree | Nhận diện/cài/mở ổ C trực tiếp, chữ ký và tham số qua mock | Không cài hoặc chạy WizTree thật |
| Giao diện sáng/tối | Palettes, weak references, layout và WPF tests | DPI thực/multi-monitor cần QA thủ công |
| Phân phối/launcher | RSA fixture, ZIP hostile cases, cache tamper, HTTP mock, đường dẫn Unicode | Online first byte và policy Windows còn là trust boundary |
| Lịch sử/hoàn tác/profile | DPAPI thật trong workspace + system adapters mock | Không thay thế backup dữ liệu cá nhân |