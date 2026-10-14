# User-scoped app/startup actions. Native mutations are only called by an
# explicit plan confirmation; tests use separate in-memory providers.
Set-StrictMode -Version Latest
function Initialize-Actions([string]$Root,[bool]$Simulation,[string]$User) {
    $script:ActionRoot=[IO.Path]::GetFullPath($Root)
    $script:ActionSimulation=$Simulation; $script:ActionUser=$User
    $appData=Get-Content "$PSScriptRoot/app-catalog.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:AppCatalog=@($appData)
    if ($AppCatalog.Count -ne 30) { throw 'Danh mục ứng dụng không hợp lệ.' }
    $allowed=@('Microsoft.WindowsFeedbackHub','Microsoft.GetHelp','MSTeams','Clipchamp.Clipchamp','Microsoft.YourPhone','Microsoft.BingNews','Microsoft.BingWeather','Microsoft.GamingApp','Microsoft.XboxGamingOverlay','Microsoft.Copilot','Microsoft.OutlookForWindows','Microsoft.MicrosoftOfficeHub','Microsoft.ZuneMusic','Microsoft.BingSearch','MicrosoftCorporationII.QuickAssist','Microsoft.Windows.DevHome','MicrosoftWindows.CrossDevice','Microsoft.Todos','Microsoft.PowerAutomateDesktop','Microsoft.MicrosoftStickyNotes','Microsoft.WindowsSoundRecorder','Microsoft.WindowsAlarms','Microsoft.Paint','Microsoft.WindowsNotepad','Microsoft.ScreenSketch','Microsoft.WindowsCalculator','Microsoft.WindowsCamera','Microsoft.Windows.Photos','Microsoft.MicrosoftSolitaireCollection','Microsoft.ZuneVideo')
    $labels=Get-Content "$PSScriptRoot/app-labels.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:AppLabels=@{};foreach ($label in $labels.Apps) {if ($label.Name -and $label.Title -and $label.Title.Length -lt 150) {$script:AppLabels[$label.Name]=$label.Title}}
    $seen=@{}
    foreach ($c in $AppCatalog) {
        $publisher=if ($c.Name -eq 'Clipchamp.Clipchamp') {'yxz26nhyzhsrt'} else {'8wekyb3d8bbwe'}
        if ($c.Name -cnotin $allowed -or $seen.ContainsKey($c.Name) -or $c.Publisher -ne $publisher -or ($c.StoreId -and $c.StoreId -notmatch '^[A-Z0-9]{12,14}$') -or $c.Recommendation -notin @('Review','Normal')) { throw 'Danh mục có gói/nhà phát hành ngoài phạm vi; không thao tác.' }
        $seen[$c.Name]=$true
    }
    $null=New-Item -ItemType Directory -Path $ActionRoot -Force
    $script:ActionMemoryApps=@{}; $script:ActionMemoryStartup=@{}; $script:ActionWrites=0
    $script:ActionBusyApps=@(); $script:ActionFailId=''; $script:ActionFailAfter=$false
    if ($Simulation) {
        $statePath=Join-Path $ActionRoot 'simulation.dat'
        if (Test-Path -LiteralPath $statePath) {
            $state=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in @($state.Apps)) { $script:ActionMemoryApps[$p.Id]=$p }
            foreach ($p in @($state.Startup)) { $script:ActionMemoryStartup[$p.Id]=$p }
        } else {
            foreach ($c in $AppCatalog) {
                $id=$c.Name+'_1.0.0.0_x64__'+$c.Publisher
                $script:ActionMemoryApps[$id]=[pscustomobject]@{Kind='Appx';Id=$id;Name=$c.Name;Title=$c.Title;Version='1.0.0.0';PublisherId=$c.Publisher;InstallLocation='';Framework=$false;NonRemovable=$false;Command='';ValueKind='';StoreId=$c.StoreId;Impact=$c.Impact}
            }
            $script:ActionMemoryStartup['Discord']=[pscustomobject]@{Kind='Startup';Id='Discord';Name='Discord';Title='Discord';Version='';PublisherId='';InstallLocation='';Framework=$false;NonRemovable=$false;Command='"C:\Demo\Discord.exe" --startup';ValueKind='String';StoreId='';Impact='Không tự mở khi đăng nhập. Không đóng Discord đang chạy; mở thủ công vẫn được.'}
            Save-ActionSimulation
        }
    }
}
function Save-ActionSimulation {
    if (-not $ActionSimulation) { return }
    [pscustomobject]@{Apps=@($ActionMemoryApps.Values);Startup=@($ActionMemoryStartup.Values)} | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $ActionRoot 'simulation.dat') -Encoding UTF8
}
function Test-StartupAllowed([string]$Name,[string]$Command) {
    return $Name -match '^(OneDrive|Discord|Spotify|Steam|EpicGamesLauncher|Skype for Desktop|com\.squirrel\.Teams\.Teams|MicrosoftEdgeAutoLaunch_[a-f0-9]+)$' -and $Command -notmatch '(?i)Defender|SecurityHealth|MsMpEng|Firewall|Antivirus|Bitdefender|Kaspersky|CrowdStrike|Sentinel|Sophos|McAfee|Norton|Avast|Malwarebytes'
}
function Get-AppProtection($Item) {
    $known=@($AppCatalog | Where-Object {$_.Name -ceq $Item.Name -and $_.Publisher -ceq $Item.PublisherId})
    $publisher=if ($Item.PSObject.Properties['Publisher']) {[string]$Item.Publisher} else {''}
    if ($Item.Framework -or $Item.NonRemovable -or ($Item.Name+' '+$publisher) -match '(?i)Store|DesktopAppInstaller|WebView|GamingServices|XboxIdentity|XboxSpeech|VCLibs|NET\.Native|UI\.Xaml|WindowsAppRuntime|Shell|Client\.CBS|SecHealth|WindowsSecurity|Edge|Driver|Intel|NVIDIA|Realtek|AdvancedMicroDevices|Razer|Logitech|Corsair|ASUSTeK|Armoury|GIGABYTE|MicroStar|Lenovo|Alienware|Firmware|TPM' -or $Item.InstallLocation -match '(?i)\\Windows\\SystemApps\\') { return [pscustomobject]@{Protected=$true;Category='Thành phần được bảo vệ';Reason='Hệ thống/runtime/bảo mật/game/driver hoặc gói không cho gỡ.'} }
    if ($known.Count -eq 1) {return [pscustomobject]@{Protected=$false;Category=$(if ($known[0].Recommendation -eq 'Review') {'Đề xuất xem xét'} else {'Ứng dụng thông thường'});Reason='Không đồng nghĩa vô dụng: chỉ gỡ nếu bạn không dùng.'}}
    if ($Item.Name -match '^(Microsoft|Windows)\.' -or $Item.PublisherId -eq '8wekyb3d8bbwe') {return [pscustomobject]@{Protected=$true;Category='Hệ thống / chưa xác minh';Reason='Chưa đủ cơ sở gỡ trong WinTune, giữ nguyên.'}}
    return [pscustomobject]@{Protected=$false;Category='Ứng dụng thông thường';Reason='Không đề xuất gỡ mặc định. Tự sao lưu dữ liệu và xác nhận đúng gói.'}
}
function Get-ReadableAppTitle($Package) {
    if ($script:AppLabels.ContainsKey($Package.Name)) {return [string]$script:AppLabels[$Package.Name]}
    if ($Package.Name -match '^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$') {return 'Thành phần Windows (tên gói chưa rõ)'}
    if (-not $Package.IsFramework -and $Package.InstallLocation) {
        $manifest=Join-Path $Package.InstallLocation 'AppxManifest.xml'
        $reader=$null
        try {
            if ((Get-Item -LiteralPath $manifest -ErrorAction Stop).Length -le 2MB) {
                $settings=New-Object Xml.XmlReaderSettings;$settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit;$settings.XmlResolver=$null
                $reader=[Xml.XmlReader]::Create($manifest,$settings);$xml=New-Object Xml.XmlDocument;$xml.XmlResolver=$null;$xml.Load($reader)
                $node=$xml.SelectSingleNode('/*[local-name()="Package"]/*[local-name()="Properties"]/*[local-name()="DisplayName"]')
                if ($null -ne $node -and $node.InnerText -and $node.InnerText -notmatch '^(?i)(ms-resource:|@)' -and $node.InnerText.Length -lt 150) {return $node.InnerText}
            }
        } catch { # Optional label lookup failure leaves the verified package ID intact.
        } finally {if ($null -ne $reader) {$reader.Dispose()}}
    }
    return [string]$Package.Name
}
function Get-AppPurpose([string]$Name) {
    $purposes=@{'Microsoft.WindowsCalculator'='Máy tính để tính toán thông thường và chuyển đổi đơn vị.';'Microsoft.WindowsCamera'='Chụp ảnh hoặc quay video bằng camera của máy.';'Microsoft.Windows.Photos'='Xem và chỉnh sửa ảnh.';'Microsoft.Paint'='Vẽ và chỉnh sửa ảnh đơn giản.';'Microsoft.WindowsNotepad'='Đọc và soạn thảo file văn bản.';'Microsoft.WindowsAlarms'='Đồng hồ, báo thức và bộ đếm giờ.';'Microsoft.WindowsSoundRecorder'='Ghi âm từ micro.';'Microsoft.MicrosoftStickyNotes'='Lưu ghi chú nhanh trên màn hình.';'Microsoft.Todos'='Quản lý danh sách việc cần làm.';'Microsoft.OutlookForWindows'='Quản lý email và lịch bằng Outlook mới.';'Microsoft.MicrosoftOfficeHub'='Trang mở nhanh và quản lý nội dung Microsoft 365/Copilot; đây không phải toàn bộ Word, Excel hoặc PowerPoint.';'Microsoft.WindowsMaps'='Xem bản đồ và tìm đường.';'Microsoft.ScreenSketch'='Chụp ảnh màn hình bằng Snipping Tool.';'Microsoft.549981C3F5F10'='Trợ lý Cortana cũ, khác với ứng dụng Copilot mới.';'Microsoft.WindowsTerminal'='Mở các dòng lệnh PowerShell và Command Prompt.';'Microsoft.Getstarted'='Ứng dụng giới thiệu và hướng dẫn sử dụng Windows.';'Microsoft.Windows.DevHome'='Công cụ Dev Home dành cho lập trình viên.';'Microsoft.PowerAutomateDesktop'='Tự động hóa công việc trên máy; giữ nếu bạn có quy trình đang dùng.';'Microsoft.MicrosoftSolitaireCollection'='Bộ trò chơi bài Solitaire của Microsoft.'}
    if ($purposes.ContainsKey($Name)) {return $purposes[$Name]}
    return ''
}
function Get-AllAppInventory {
    if ($ActionSimulation) {return @($ActionMemoryApps.Values | Sort-Object Title)}
    foreach ($p in @(Get-AppxPackage -ErrorAction Stop)) {
        $c=@($AppCatalog | Where-Object {$_.Name -ceq $p.Name -and $_.Publisher -ceq $p.PublisherId})
        $item=[pscustomobject]@{Kind='Appx';Id=$p.PackageFullName;Name=$p.Name;Title=$p.Name;Version=[string]$p.Version;PublisherId=$p.PublisherId;Publisher=[string]$p.Publisher;InstallLocation=[string]$p.InstallLocation;Framework=[bool]($p.IsFramework -or $p.IsResourcePackage);NonRemovable=[bool]$p.NonRemovable;Command='';ValueKind='';StoreId='';Impact='Ứng dụng ngoài danh mục gợi ý. Gỡ sẽ mất chức năng và có thể xóa dữ liệu cục bộ. Chưa có phương pháp cài lại đáng tin cậy trong WinTune: ghi lại nguồn cài chính thức của bạn trước khi gỡ.'}
        if ($c.Count -eq 1) {$item.Title=$c[0].Title;$item.StoreId=$c[0].StoreId;$item.Impact=$c[0].Impact}
        else {$item.Title=Get-ReadableAppTitle $p;$purpose=Get-AppPurpose $p.Name;if ($purpose) {$item.Impact=$purpose+' Gỡ có thể mất dữ liệu cục bộ; chưa có nguồn cài lại được xác minh trong WinTune.'};if ($p.IsFramework -or $p.NonRemovable -or $p.InstallLocation -match '(?i)\\Windows\\SystemApps\\') {$item.Impact='Thành phần hỗ trợ Windows hoặc ứng dụng. WinTune giữ lại để tránh làm lỗi tính năng hệ thống; không dùng mục này để dọn ứng dụng.'}}
        $item
    }
}
function Get-ActionInventory([string]$Kind) {
    if ($Kind -notin @('Appx','Startup')) { throw 'Loại thao tác không hợp lệ.' }
    if ($ActionSimulation) { if ($Kind -eq 'Appx') { return @($ActionMemoryApps.Values | Sort-Object Title) }; return @($ActionMemoryStartup.Values | Sort-Object Title) }
    if ($Kind -eq 'Appx') {
        Get-AllAppInventory | Where-Object {-not (Get-AppProtection $_).Protected}
    } else {
        $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
        try {
            if ($null -eq $key) { return }
            foreach ($name in $key.GetValueNames()) {
                $type=[string]$key.GetValueKind($name)
                if ($type -notin @('String','ExpandString')) { continue }
                $cmd=[string]$key.GetValue($name,'',[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                if (-not (Test-StartupAllowed $name $cmd)) { continue }
                [pscustomobject]@{Kind='Startup';Id=$name;Name=$name;Title=$name;Version='';PublisherId='';InstallLocation='';Framework=$false;NonRemovable=$false;Command=$cmd;ValueKind=$type;StoreId='';Impact='Xóa lệnh tự mở ở HKCU Run, áp dụng ở lần đăng nhập sau. Không đóng app đang chạy, không gỡ app. Có thể mất đồng bộ/thông báo khi app chưa mở; OneDrive không tự đồng bộ, Teams/Discord không tự nhận tin. Đây chỉ là một nguồn khởi động, không bao gồm dịch vụ, tác vụ lịch, HKLM hoặc mọi app Store.'}
            }
        } finally { if ($null -ne $key) { $key.Dispose() } }
    }
}
function Assert-ActionItem($Item) {
    if ($Item.Kind -eq 'Appx') {
        $c=@($AppCatalog | Where-Object Name -CEQ $Item.Name)
        $badKnown=$c.Count -gt 0 -and ($Item.PublisherId -ne $c[0].Publisher -or $Item.StoreId -ne $c[0].StoreId)
        if ((Get-AppProtection $Item).Protected -or $badKnown -or $Item.Name -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]{2,150}$' -or $Item.PublisherId -notmatch '^[a-z0-9]{13}$' -or $Item.Id -notmatch ('^'+[regex]::Escape($Item.Name)+'_[0-9.]+_(x64|x86|arm64|neutral)_[A-Za-z0-9.]*_'+[regex]::Escape($Item.PublisherId)+'$') -or ($c.Count -eq 0 -and $Item.StoreId)) { throw 'Gói bị bảo vệ hoặc định danh không hợp lệ; không gỡ.' }
    } elseif ($Item.Kind -eq 'Startup') {
        if ($Item.Id -cne $Item.Name -or -not (Test-StartupAllowed $Item.Name $Item.Command) -or $Item.ValueKind -notin @('String','ExpandString')) { throw 'Mục tự khởi động không được hỗ trợ; không ghi.' }
    } else { throw 'Loại thao tác không được hỗ trợ.' }
}
function Test-ActionSame($A,$B) {
    if ($null -eq $A -or $null -eq $B) { return $null -eq $A -and $null -eq $B }
    return $A.Kind -ceq $B.Kind -and $A.Id -ceq $B.Id -and $A.Name -ceq $B.Name -and $A.Command -ceq $B.Command -and $A.ValueKind -ceq $B.ValueKind -and $A.Version -ceq $B.Version -and $A.PublisherId -ceq $B.PublisherId -and $A.InstallLocation -ceq $B.InstallLocation
}
function Read-StartupExact([string]$Name) {
    if ($ActionSimulation) { if ($ActionMemoryStartup.ContainsKey($Name)) { return $ActionMemoryStartup[$Name] }; return $null }
    $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
    try {
        if ($null -eq $key -or $Name -notin $key.GetValueNames()) { return $null }
        return [pscustomobject]@{Kind='Startup';Id=$Name;Name=$Name;Title=$Name;Version='';PublisherId='';InstallLocation='';Framework=$false;NonRemovable=$false;Command=[string]$key.GetValue($Name,'',[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);ValueKind=[string]$key.GetValueKind($Name);StoreId='';Impact=''}
    } finally { if ($null -ne $key) { $key.Dispose() } }
}
function Test-ActionRunning($Item) {
    if ($Item.Kind -ne 'Appx') { return $false }
    if ($ActionSimulation) { return $Item.Id -in $ActionBusyApps }
    if (-not $Item.InstallLocation) { throw 'Không xác định được thư mục gói; chưa gỡ.' }
    $processNames=switch ($Item.Name) {
        'Microsoft.YourPhone' {@('PhoneExperienceHost','YourPhone')}
        'MSTeams' {@('ms-teams','msteams')}
        'Clipchamp.Clipchamp' {@('Clipchamp')}
        'Microsoft.XboxGamingOverlay' {@('GameBar','GameBarFTServer','GameBarPresenceWriter')}
        'Microsoft.GamingApp' {@('XboxPcApp','XboxApp')}
        'Microsoft.GetHelp' {@('GetHelp')}
        'Microsoft.WindowsFeedbackHub' {@('FeedbackHub')}
        default {@()}
    }
    foreach ($p in @(Get-Process)) {
        if ($p.ProcessName -in $processNames) { return $true }
        try { $path=$p.Path } catch { $path='' }
        if ($path -and $path.StartsWith($Item.InstallLocation.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}
function Save-ActionJournal($Journal,[string]$Path) {
    $full=[IO.Path]::GetFullPath($Path)
    if ([IO.Path]::GetDirectoryName($full) -ne $ActionRoot -or [IO.Path]::GetFileName($full) -notmatch '^batch-[a-f0-9]{32}\.json$') { throw 'Không ghi nhật ký ngoài thư mục thao tác.' }
    Add-Type -AssemblyName System.Security
    $plain=[Text.Encoding]::UTF8.GetBytes(($Journal | ConvertTo-Json -Depth 12))
    $sealed=[Security.Cryptography.ProtectedData]::Protect($plain,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
    $text=[pscustomobject]@{Version=1;User=$ActionUser;Protected=[Convert]::ToBase64String($sealed)} | ConvertTo-Json
    $temp=Join-Path $ActionRoot ([guid]::NewGuid().ToString('N')+'.tmp')
    $writer=New-Object IO.StreamWriter($temp,$false,(New-Object Text.UTF8Encoding($true)))
    try { $writer.Write($text); $writer.Flush(); $writer.BaseStream.Flush($true) } finally { $writer.Dispose() }
    try {
        if (Test-Path -LiteralPath $full) { $backup=$temp+'.bak'; [IO.File]::Replace($temp,$full,$backup); Remove-Item -LiteralPath $backup }
        else { [IO.File]::Move($temp,$full) }
    } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp } }
}
function Get-ActionJournals {
    Add-Type -AssemblyName System.Security
    foreach ($file in @(Get-ChildItem -LiteralPath $ActionRoot -Filter 'batch-*.json' -File | Sort-Object Name -Descending)) {
        $sealed=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($sealed.Version -ne 1 -or $sealed.User -ne $ActionUser) { throw 'Nhật ký khác tài khoản; không ghi thêm.' }
        $bytes=[Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String($sealed.Protected),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
        $j=[Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
        if ($j.User -ne $ActionUser -or $j.Mode -ne $(if ($ActionSimulation) {'Simulation'} else {'Native'}) -or $j.Kind -notin @('Appx','Startup') -or $j.Status -notin @('Pending','Completed','Partial','Undone') -or @($j.Rows).Count -lt 1 -or @($j.Rows).Count -gt 50) { throw 'Nhật ký không hợp lệ; giữ tệp để kiểm tra.' }
        $seen=@{}
        foreach ($r in $j.Rows) {
            Assert-ActionItem $r.Item
            if ($r.Item.Kind -ne $j.Kind -or $seen.ContainsKey($r.Item.Id) -or $r.State -notin @('Prepared','Writing','Applied','Failed','Skipped') -or $r.UndoState -notin @('None','Restoring','Restored','Failed')) { throw 'Kết quả từng mục không hợp lệ.' }
            $seen[$r.Item.Id]=$true
        }
        [pscustomobject]@{Path=$file.FullName;Journal=$j}
    }
}
function New-ActionPlan([string]$Kind,[string[]]$Ids) {
    $null=@(Get-ActionJournals) # Fail closed if history cannot be trusted.
    $items=@(Get-ActionInventory $Kind); $rows=@()
    foreach ($id in @($Ids | Select-Object -Unique)) {
        $found=@($items | Where-Object Id -CEQ $id)
        if ($found.Count -ne 1) { throw 'Ứng dụng hoặc mục khởi động đã thay đổi; đọc lại danh sách.' }
        Assert-ActionItem $found[0]
        if (Test-ActionRunning $found[0]) { throw ('Bạn tự lưu dữ liệu và đóng '+$found[0].Title+' trước khi gỡ. WinTune không tự đóng app.') }
        $rows+=[pscustomobject]@{Item=$found[0].PSObject.Copy();State='Prepared';Error='';UndoState='None';UndoError=''}
    }
    return $rows
}
function Remove-ActionItem($Item) {
    Assert-ActionItem $Item
    if ($ActionSimulation) {
        $script:ActionWrites++
        if ($Item.Id -eq $ActionFailId -and -not $ActionFailAfter) { throw 'Injected failure before write' }
        if ($Item.Kind -eq 'Appx') { $script:ActionMemoryApps.Remove($Item.Id) } else { $script:ActionMemoryStartup.Remove($Item.Id) }
        Save-ActionSimulation
        if ($Item.Id -eq $ActionFailId -and $ActionFailAfter) { throw 'Injected failure after write' }
        return
    }
    if ($Item.Kind -eq 'Appx') { Remove-AppxPackage -Package $Item.Id -Confirm:$false -ErrorAction Stop }
    else {
        $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run',$true)
        try { if ($null -eq $key) { throw 'Khóa khởi động không còn.' }; $key.DeleteValue($Item.Name,$false) } finally { if ($null -ne $key) { $key.Dispose() } }
    }
}
function Invoke-ActionPlan([object[]]$Rows) {
    if ($Rows.Count -lt 1 -or $Rows.Count -gt 50) { throw 'Không có thay đổi hoặc quá nhiều mục; không tạo đợt.' }
    $kind=$Rows[0].Item.Kind; $seen=@{}; $null=@(Get-ActionJournals)
    $pending=@(Get-ActionJournals | Where-Object { $_.Journal.Kind -eq 'Startup' -and $_.Journal.Status -in @('Pending','Partial') })
    if ($pending.Count) { throw 'Có đợt khởi động chưa hoàn tất; phục hồi trước khi ghi thêm.' }
    $inventory=@(Get-ActionInventory $kind)
    foreach ($r in $Rows) {
        Assert-ActionItem $r.Item
        if ($r.State -ne 'Prepared' -or $r.Item.Kind -ne $kind -or $seen.ContainsKey($r.Item.Id)) { throw 'Kế hoạch không hợp lệ.' }
        $seen[$r.Item.Id]=$true; $now=@($inventory | Where-Object Id -CEQ $r.Item.Id)
        if ($now.Count -ne 1 -or -not (Test-ActionSame $now[0] $r.Item)) { throw 'Trạng thái thay đổi sau xem trước; không ghi.' }
        if (Test-ActionRunning $r.Item) { throw 'App đang chạy; tự lưu và đóng app trước.' }
    }
    if ($kind -eq 'Startup' -and -not $ActionSimulation) {
        $probe=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run',$true)
        try { if ($null -eq $probe) { throw 'Không có quyền ghi khóa khởi động.' } } finally { if ($null -ne $probe) { $probe.Dispose() } }
    }
    $j=[pscustomobject]@{Version=1;User=$ActionUser;Mode=$(if ($ActionSimulation) {'Simulation'} else {'Native'});Kind=$kind;Created=(Get-Date).ToString('o');Status='Pending';Rows=$Rows}
    $path=Join-Path $ActionRoot ('batch-'+[guid]::NewGuid().ToString('N')+'.json')
    Save-ActionJournal $j $path
    try {
        foreach ($r in $Rows) {
            $now=@(Get-ActionInventory $kind | Where-Object Id -CEQ $r.Item.Id)
            if ($now.Count -ne 1 -or -not (Test-ActionSame $now[0] $r.Item)) { throw 'Mục đổi trong lúc áp dụng; dừng.' }
            if (Test-ActionRunning $r.Item) { throw 'App vừa được mở; dừng trước khi gỡ.' }
            $r.State='Writing'; Save-ActionJournal $j $path
            Remove-ActionItem $r.Item
            $remainingItems=@(Get-ActionInventory $kind)
            if (@($remainingItems | Where-Object Id -CEQ $r.Item.Id).Count -ne 0 -or ($kind -eq 'Appx' -and @($remainingItems | Where-Object Name -CEQ $r.Item.Name).Count -gt 0)) { throw 'Đọc lại vẫn thấy mục hoặc phiên bản khác của app; không báo gỡ xong.' }
            $r.State='Applied'; Save-ActionJournal $j $path
        }
        $j.Status='Completed'; Save-ActionJournal $j $path
    } catch {
        $reason=$_.Exception.Message
        if ($r.State -eq 'Writing') { $r.State='Failed' } else { $r.State='Skipped' }
        $r.Error=$reason
        foreach ($remaining in $Rows) { if ($remaining.State -eq 'Prepared') { $remaining.State='Skipped' } }
        $j.Status='Partial'; Save-ActionJournal $j $path
        throw "Đợt chưa hoàn tất: $reason. Xem lịch sử từng mục. Startup có thể phục hồi; Appx dùng liên kết cài lại, không khôi phục dữ liệu."
    }
    return $path
}
function Get-LatestStartupAction {
    return (Get-ActionJournals | Where-Object { $_.Journal.Kind -eq 'Startup' -and $_.Journal.Status -ne 'Undone' } | Sort-Object { $_.Journal.Created } -Descending | Select-Object -First 1)
}
function Undo-StartupAction {
    $last=Get-LatestStartupAction
    if ($null -eq $last) { throw 'Không còn đợt khởi động cần phục hồi.' }
    foreach ($r in $last.Journal.Rows) {
        if ($r.State -in @('Prepared','Skipped')) { continue }
        $now=Read-StartupExact $r.Item.Id
        if ($r.UndoState -eq 'Restored' -and -not (Test-ActionSame $now $r.Item)) { throw 'Lệnh đã phục hồi bị sửa hoặc xóa bên ngoài; không ghi lại.' }
        if ($null -ne $now -and -not (Test-ActionSame $now $r.Item)) { throw 'Có thay đổi bên ngoài trong lệnh khởi động; không ghi đè.' }
    }
    foreach ($r in $last.Journal.Rows) {
        if ($r.State -in @('Prepared','Skipped')) { continue }
        $now=Read-StartupExact $r.Item.Id
        if ($null -ne $now -and -not (Test-ActionSame $now $r.Item)) { throw 'Lệnh đổi trong lúc phục hồi; không ghi đè.' }
        if ($null -eq $now) {
            $r.UndoState='Restoring'; Save-ActionJournal $last.Journal $last.Path
            try {
                if ($ActionSimulation) { $script:ActionMemoryStartup[$r.Item.Id]=$r.Item; $script:ActionWrites++; Save-ActionSimulation }
                else {
                    $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
                    try { $key.SetValue($r.Item.Name,$r.Item.Command,([Enum]::Parse([Microsoft.Win32.RegistryValueKind],$r.Item.ValueKind))) } finally { $key.Dispose() }
                }
                $verified=@(Get-ActionInventory 'Startup' | Where-Object Id -CEQ $r.Item.Id)
                if ($verified.Count -ne 1 -or -not (Test-ActionSame $verified[0] $r.Item)) { throw 'Phục hồi không khớp lệnh gốc.' }
            } catch { $r.UndoState='Failed'; $r.UndoError=$_.Exception.Message; Save-ActionJournal $last.Journal $last.Path; throw }
        }
        $r.UndoState='Restored'; Save-ActionJournal $last.Journal $last.Path
    }
    $last.Journal.Status='Undone'; Save-ActionJournal $last.Journal $last.Path
}
