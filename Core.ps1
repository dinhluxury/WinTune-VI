Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Initialize-WinTune([string]$CatalogPath,[string]$DataRoot,[string]$UserId,[int]$Build) {
    $catalog = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:Features = @($catalog)
    $script:DataRoot = $DataRoot
    $script:UserId = $UserId
    $script:Build = $Build
    $script:FeatureChoices=@{}
    $script:IsSimulation = $false
    $null = New-Item -ItemType Directory -Path $DataRoot -Force
    $ids = @{}; $targets = @{}
    foreach ($f in $script:Features) {
        if ($ids.ContainsKey($f.Id) -or $f.Id -notmatch '^[a-z]+$') { throw 'Danh mục tính năng không hợp lệ.' }
        $ids[$f.Id] = $true
        if (-not $f.PSObject.Properties['Kind']) { $f | Add-Member Kind 'Registry' }
        if (-not $f.PSObject.Properties['MaxBuild']) { $f | Add-Member MaxBuild 0 }
        if (-not $f.PSObject.Properties['Admin']) { $f | Add-Member Admin $false }
        if ($f.Kind -notin @('Registry','Settings','Action') -or ($f.Admin -ne $false -and $f.Id -ne 'notepadai') -or $f.MinBuild -lt 19041) { throw 'Danh mục chứa loại thao tác hoặc quyền chưa được hỗ trợ.' }
        if ($f.Kind -eq 'Action' -and ($f.Id -ne 'copilotapp' -or @($f.Changes).Count -ne 0)) {throw 'Thao tác ứng dụng không được đăng ký.'}
        if ($f.Kind -eq 'Settings' -and ($f.SettingsUri -notin @('ms-settings:startupapps','ms-settings:appsfeatures') -or @($f.Changes).Count -ne 0)) { throw 'Trang cài đặt không được hỗ trợ.' }
        foreach ($c in $f.Changes) {
            if (-not $c.PSObject.Properties['Type']) {$c | Add-Member Type 'DWord'}
            if (-not $c.PSObject.Properties['Hive']) {$c | Add-Member Hive 'HKCU'}
            if ($c.Path -notmatch '^(Software|System|Control Panel)\\' -or $c.Path.Contains('..') -or $c.Hive -notin @('HKCU','HKLM') -or $c.Type -notin @('DWord','String')) {throw 'Thiết lập không hợp lệ.'}
            if ($c.Hive -eq 'HKLM' -and ($f.Id -ne 'notepadai' -or $c.Path -cne 'Software\Policies\WindowsNotepad' -or $c.Name -cne 'DisableAIFeatures' -or $c.Value -ne 1 -or $c.Type -ne 'DWord')) {throw 'Đích máy tính ngoài phạm vi đã duyệt.'}
            if ($c.Type -eq 'String') {
                $classic=$f.Id -eq 'classicmenu' -and $c.Path -ceq 'Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' -and $c.Name -ceq '' -and $c.Value -ceq ''
                $mouse=$f.Id -eq 'pointerprecision' -and $c.Path -ceq 'Control Panel\Mouse' -and $c.Name -cin @('MouseSpeed','MouseThreshold1','MouseThreshold2') -and $c.Value -ceq '0'
                $snap=$f.Id -eq 'windowsnapping' -and $c.Path -ceq 'Control Panel\Desktop' -and $c.Name -ceq 'WindowArrangementActive' -and $c.Value -ceq '0'
                if ($c.Hive -ne 'HKCU' -or $c.Value -isnot [string] -or -not ($classic -or $mouse -or $snap)) {throw 'Đích chuỗi ngoài phạm vi đã duyệt.'}
            } else {if ([string]::IsNullOrWhiteSpace($c.Name) -or ($c.Value -isnot [long] -and $c.Value -isnot [int])) {throw 'DWORD không hợp lệ.'};$null=[int]$c.Value}
            $target = "$($c.Hive)\$($c.Path)\$($c.Name)".ToLowerInvariant()
            if ($targets.ContainsKey($target)) { throw 'Hai tính năng cùng thay đổi một giá trị.' }
            $targets[$target] = $true
        }
        if ($f.PSObject.Properties['Choices']) {
            if ($f.Kind -ne 'Registry' -or @($f.Choices).Count -lt 2 -or @($f.Choices).Count -gt 8) {throw 'Danh sách lựa chọn không hợp lệ.'}
            $choiceIds=@{}
            foreach ($choice in $f.Choices) {
                if ($choice.Id -notmatch '^[a-z]+$' -or $choiceIds.ContainsKey($choice.Id) -or @($choice.Values).Count -ne @($f.Changes).Count) {throw 'Lựa chọn lặp hoặc sai số giá trị.'}
                $choiceIds[$choice.Id]=$true
                for ($i=0;$i -lt @($f.Changes).Count;$i++) {if ($f.Changes[$i].Type -ne 'DWord' -or ($choice.Values[$i] -isnot [int] -and $choice.Values[$i] -isnot [long])) {throw 'Lựa chọn chỉ hỗ trợ DWORD được duyệt.'};$null=[int]$choice.Values[$i]}
            }
            for ($i=0;$i -lt @($f.Changes).Count;$i++) {if ($f.Choices[0].Values[$i] -ne $f.Changes[$i].Value) {throw 'Lựa chọn mặc định khác đích đã lưu.'}}
        }
    }
}
function Get-FeatureChoice($Feature,[string]$Id='') {
    if (-not $Feature.PSObject.Properties['Choices']) {if ($Id) {throw 'Tính năng không có lựa chọn.'};return $null}
    if (-not $Id) {$Id=if ($script:FeatureChoices.ContainsKey($Feature.Id)) {$script:FeatureChoices[$Feature.Id]} else {$Feature.Choices[0].Id}}
    $choice=@($Feature.Choices | Where-Object Id -CEQ $Id)
    if ($choice.Count -ne 1) {throw 'Không nhận diện lựa chọn.'};return $choice[0]
}
function Set-FeatureChoice([string]$FeatureId,[string]$Id) {
    $f=Get-Feature $FeatureId;$null=Get-FeatureChoice $f $Id;$script:FeatureChoices[$FeatureId]=$Id
}
function Get-FeatureChanges($Feature,[string]$ChoiceId='',[switch]$Original) {
    $choice=if ($Original) {$null} else {Get-FeatureChoice $Feature $ChoiceId}
    for ($i=0;$i -lt @($Feature.Changes).Count;$i++) {
        $c=$Feature.Changes[$i]
        [pscustomobject]@{Path=$c.Path;Name=$c.Name;Hive=$c.Hive;Type=$c.Type;Value=$(if ($null -ne $choice) {$choice.Values[$i]} else {$c.Value})}
    }
}
function Get-Feature([string]$Id) {
    $found = @($script:Features | Where-Object { $_.Id -ceq $Id })
    if ($found.Count -ne 1) { throw "Không nhận diện tính năng: $Id" }
    return $found[0]
}
function Get-RegistryBase($Change) {if ($Change.PSObject.Properties['Hive'] -and $Change.Hive -eq 'HKLM') {return [Microsoft.Win32.Registry]::LocalMachine};return [Microsoft.Win32.Registry]::CurrentUser}
function Read-RegistryValue($Change) {
    $key = (Get-RegistryBase $Change).OpenSubKey($Change.Path)
    try {
        if ($null -eq $key -or $Change.Name -notin $key.GetValueNames()) { return [pscustomobject]@{ Exists=$false; KeyExisted=($null -ne $key); Value=$(if ($Change.Type -eq 'String') {''} else {0}) } }
        $kind=if ($Change.Type -eq 'String') {[Microsoft.Win32.RegistryValueKind]::String} else {[Microsoft.Win32.RegistryValueKind]::DWord}
        if ($key.GetValueKind($Change.Name) -ne $kind) { throw "Không hỗ trợ kiểu dữ liệu hiện tại: $($Change.Name)" }
        $value=$key.GetValue($Change.Name)
        if ($Change.Type -eq 'String' -and $Change.Name -ceq '' -and $value -cne '') {throw 'Đăng ký menu đã chứa dữ liệu khác; không ghi đè tùy chỉnh đó.'}
        return [pscustomobject]@{ Exists=$true; KeyExisted=$true; Value=$value }
    } finally { if ($null -ne $key) { $key.Dispose() } }
}
function Set-RegistryValue($Change,[bool]$Exists,$Value,[bool]$RemoveNewEmptyKey=$false) {
    $key=$null
    try {
        if ($Exists) { $key = (Get-RegistryBase $Change).CreateSubKey($Change.Path) }
        else { $key = (Get-RegistryBase $Change).OpenSubKey($Change.Path,$true) }
        $kind=if ($Change.Type -eq 'String') {[Microsoft.Win32.RegistryValueKind]::String} else {[Microsoft.Win32.RegistryValueKind]::DWord}
        if ($Exists) { $key.SetValue($Change.Name,$Value,$kind) }
        elseif ($null -eq $key) { return }
        else {
            if ($RemoveNewEmptyKey -and ($Change.Type -ne 'String' -or $key.SubKeyCount -gt 0 -or @($key.GetValueNames() | Where-Object {$_ -cne $Change.Name}).Count -gt 0)) {throw 'Khóa mới có nội dung ngoài WinTune; giữ nguyên để tránh xóa dữ liệu khác.'}
            $key.DeleteValue($Change.Name,$false)
            if ($RemoveNewEmptyKey) {$key.Dispose();$key=$null;(Get-RegistryBase $Change).DeleteSubKey($Change.Path,$false)}
        }
    } finally { if ($null -ne $key) { $key.Dispose() } }
    $result = Read-RegistryValue $Change
    if (-not (Test-SameState $result ([pscustomobject]@{Exists=$Exists;Value=$Value}))) { throw "Không xác minh được: $($Change.Name)" }
}
# Opening a handle with write rights does not create a key or change a value.
# If the target is absent, check CreateSubKey on its nearest existing ancestor.
# ACLs may still change later, so the journal continues to protect partial writes.
function Test-RegistryWriteAccess($Change) {
    $path=[string]$Change.Path
    $probe=$null
    try {
        while ($true) {
            $base=Get-RegistryBase $Change
            $existing=$base.OpenSubKey($path)
            if ($null -ne $existing) {
                $existing.Dispose()
                if ($path -eq $Change.Path) { $probe=$base.OpenSubKey($path,$true) }
                else { $probe=$base.OpenSubKey($path,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[Security.AccessControl.RegistryRights]::CreateSubKey) }
                if ($null -eq $probe) { throw 'Không mở được khóa với quyền ghi.' }
                return [pscustomobject]@{Allowed=$true;Reason=''}
            }
            if (-not $path.Contains('\')) { $path='' } else { $path=$path.Substring(0,$path.LastIndexOf('\')) }
            if ($path -eq '') {
                $probe=$base.OpenSubKey('',[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[Security.AccessControl.RegistryRights]::CreateSubKey)
                if ($null -eq $probe) { throw 'Không mở được HKCU với quyền tạo khóa.' }
                return [pscustomobject]@{Allowed=$true;Reason=''}
            }
        }
    } catch { return [pscustomobject]@{Allowed=$false;Reason=$_.Exception.Message} }
    finally { if ($null -ne $probe) { $probe.Dispose() } }
}
function Assert-RegistryWriteAccess([object[]]$Rows) {
    $blocked=@()
    foreach ($row in $Rows) {
        $access=Test-RegistryWriteAccess (Assert-Row $row)
        if (-not $access.Allowed) {$c=Assert-Row $row;$blocked+="$((Get-Feature $row.Feature).Title): $($c.Hive)\$($row.Path)\$($row.Name)`n$($access.Reason)"}
    }
    if ($blocked.Count -gt 0) { throw ("Không đủ quyền ghi các mục sau. Đợt mới chưa ghi giá trị nào:`n"+($blocked -join "`n`n")+"`nBỏ chọn các mục bị chặn. Một số nhánh Policies có thể cần quyền quản trị; chính sách của máy vẫn có thể ngăn ghi. WinTune không tự nâng quyền hoặc sửa quyền registry.") }
}
function Test-SameState($A,$B) {
    $equal=if ($A.Value -is [string] -or $B.Value -is [string]) {$A.Value -is [string] -and $B.Value -is [string] -and $A.Value -ceq $B.Value} else {$A.Value -eq $B.Value}
    $keyEqual=$true
    if ($A.Value -is [string] -and $B.Value -is [string] -and (-not $B.PSObject.Properties['Name'] -or $B.Name -ceq '') -and $A.PSObject.Properties['KeyExisted'] -and $B.PSObject.Properties['KeyExisted'] -and $A.KeyExisted -ne $B.KeyExisted) {$keyEqual=$false}
    return ($keyEqual -and $A.Exists -eq $B.Exists -and ((-not $A.Exists) -or $equal))
}
function Save-Journal($Journal,[string]$Path) {
    $absolute=[IO.Path]::GetFullPath($Path)
    if ([IO.Path]::GetDirectoryName($absolute) -ne [IO.Path]::GetFullPath($script:DataRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)) { throw 'Không lưu nhật ký ra ngoài thư mục dữ liệu.' }
    $temp = Join-Path $script:DataRoot ([guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $writer=New-Object IO.StreamWriter($temp,$false,(New-Object Text.UTF8Encoding($true)))
        try {
            $writer.Write(($Journal | ConvertTo-Json -Depth 10))
            $writer.Flush()
            $writer.BaseStream.Flush($true)
        } finally { $writer.Dispose() }
        if (Test-Path -LiteralPath $Path) {
            $previous=$temp+'.bak'
            [IO.File]::Replace($temp,$Path,$previous)
            Remove-Item -LiteralPath $previous -ErrorAction SilentlyContinue
        }
        else { [IO.File]::Move($temp,$Path) }
    } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp } }
}
function Test-FeatureSupported($Feature) {
    return ($script:Build -ge $Feature.MinBuild -and ($Feature.MaxBuild -eq 0 -or $script:Build -le $Feature.MaxBuild))
}
function Assert-Row($row) {
    $f=Get-Feature $row.Feature
    if ($f.Kind -ne 'Registry' -or ($row.Index -isnot [int] -and $row.Index -isnot [long]) -or $row.Index -lt 0 -or $row.Index -ge @($f.Changes).Count) { throw 'Chỉ mục sao lưu không hợp lệ.' }
    $c=if ($row.PSObject.Properties['Choice'] -and $row.Choice) {@(Get-FeatureChanges $f $row.Choice)[$row.Index]} else {@(Get-FeatureChanges $f -Original)[$row.Index]}
    if ($row.Exists -isnot [bool]) {throw 'Dữ liệu sao lưu không hợp lệ.'}
    if ($c.Type -eq 'String') {if ($row.Value -isnot [string] -or $row.Value.Length -gt 4096 -or ($c.Name -ceq '' -and $row.Value -cne '') -or $row.Target -isnot [string] -or -not $row.PSObject.Properties['KeyExisted'] -or $row.KeyExisted -isnot [bool]) {throw 'Dữ liệu chuỗi sao lưu không hợp lệ.'}}
    else {if (($row.Value -isnot [int] -and $row.Value -isnot [long]) -or ($row.Target -isnot [int] -and $row.Target -isnot [long])) {throw 'Dữ liệu DWORD sao lưu không hợp lệ.'};$null=[int]$row.Value}
    if ($row.PSObject.Properties['Hive'] -and $row.Hive -cne $c.Hive) {throw 'Phạm vi bản sao lưu không khớp.'}
    if ($c.Hive -eq 'HKLM' -and -not $row.PSObject.Properties['Hive']) {throw 'Thiếu phạm vi máy tính trong bản sao lưu.'}
    if ($row.Target -ne $c.Value) { throw 'Danh mục đã thay đổi so với bản sao lưu.' }
    if ($row.PSObject.Properties['Path'] -and ($row.Path -cne $c.Path -or $row.Name -cne $c.Name)) { throw 'Đường dẫn danh mục khác bản sao lưu.' }
    return $c
}
function Get-Journals {
    $journals=@()
    foreach ($file in @(Get-ChildItem -LiteralPath $script:DataRoot -Filter '*.json' -File | Sort-Object Name -Descending)) {
        # Appearance preferences share the data folder but are not a backup.
        # Exclude only this reserved filename; unknown/corrupt journals still block writes.
        if ($file.Name -ieq 'ui-settings.json') {continue}
        $j = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($j.Version -notin @(2,3) -or $j.User -ne $script:UserId -or $j.Status -notin @('Pending','Applied','Undone')) { throw "Lịch sử không hợp lệ: $($file.Name). Không ghi thêm; giữ tệp để kiểm tra." }
        $rows=@($j.Rows); $seen=@{}
        Assert-PlanChoices $rows
        if ($rows.Count -lt 1 -or $rows.Count -gt 100) { throw 'Bản sao lưu không hợp lệ.' }
        foreach ($row in $rows) {
            $null=Assert-Row $row
            $key="$($row.Feature):$($row.Index)"
            if ($seen.ContainsKey($key)) { throw 'Bản sao lưu có mục lặp.' }; $seen[$key]=$true
            if ($j.Version -eq 3 -and ($row.State -notin @('Prepared','Writing','Applied','Failed','Skipped') -or $row.UndoState -notin @('None','Restoring','Restored','Failed'))) { throw 'Trạng thái sao lưu không hợp lệ.' }
            if ($j.Version -eq 3 -and (-not $row.PSObject.Properties['Path'] -or -not $row.PSObject.Properties['Name'])) { throw 'Thiếu đường dẫn trong sao lưu.' }
            if ($j.Version -eq 3 -and $j.Status -eq 'Applied' -and $row.State -ne 'Applied') { throw 'Kết quả đợt không khớp kết quả từng giá trị.' }
        }
        $journals += [pscustomobject]@{Path=$file.FullName;Journal=$j}
    }
    return $journals
}
function Get-LatestJournal {
    foreach ($entry in @(Get-Journals)) { if ($entry.Journal.Status -ne 'Undone') { return $entry } }
    return $null
}
function Get-FeatureState($Feature) {
    if (-not (Test-FeatureSupported $Feature)) { return 'Không hỗ trợ bản Windows này' }
    if ($Feature.Kind -eq 'Settings') { return 'Mở cài đặt — ứng dụng không tự áp dụng' }
    if ($Feature.Kind -eq 'Action') {return 'Chưa kiểm tra ứng dụng. Đánh dấu rồi xem trước và chạy để gỡ trực tiếp.'}
    $matches=0; $missing=0
    foreach ($c in @(Get-FeatureChanges $Feature)) {
        $current = Read-RegistryValue $c
        if (-not $current.Exists) { $missing++ }
        elseif ($current.Value -eq $c.Value) { $matches++ }
    }
    if ($matches -eq @($Feature.Changes).Count) { return 'Đã đặt giá trị yêu cầu' }
    if ($missing -eq @($Feature.Changes).Count) { return 'Chưa đặt giá trị — Windows tự quyết định mặc định' }
    if ($matches -gt 0) { return 'Mới khớp một phần' }
    return 'Chưa đặt giá trị yêu cầu'
}
function New-ChangePlan([string[]]$Ids) {
    $latest = Get-LatestJournal
    if ($null -ne $latest -and $latest.Journal.Status -eq 'Pending') { throw 'Đợt trước chưa hoàn tất. Hoàn tác đợt đó trước khi tiếp tục.' }
    $rows = @()
    foreach ($id in @($Ids | Select-Object -Unique)) {
        $f = Get-Feature $id
        if (-not (Test-FeatureSupported $f)) { throw "Không hỗ trợ: $($f.Title)" }
        if ($f.Kind -ne 'Registry') { throw 'Mục Mở cài đặt không thể đưa vào đợt áp dụng.' }
        for ($i=0; $i -lt @($f.Changes).Count; $i++) {
            $choice=Get-FeatureChoice $f
            $c = @(Get-FeatureChanges $f)[$i]
            $old = Read-RegistryValue $c
            if ($old.Exists -and $old.Value -eq $c.Value) { continue }
            $rows += [pscustomobject]@{ Feature=$id; Index=$i; Choice=$(if ($null -ne $choice) {$choice.Id} else {''}); Hive=$c.Hive; Path=$c.Path; Name=$c.Name; KeyExisted=$(if ($old.PSObject.Properties['KeyExisted']) {[bool]$old.KeyExisted} else {[bool]$old.Exists}); Exists=[bool]$old.Exists; Value=$old.Value; Target=$c.Value; State='Prepared'; Error=''; UndoState='None'; UndoError='' }
        }
    }
    return $rows
}
function Assert-PlanChoices([object[]]$Rows) {
    $seen=@{}
    foreach ($row in $Rows) {
        $choice=if ($row.PSObject.Properties['Choice']) {[string]$row.Choice} else {''}
        if ($seen.ContainsKey($row.Feature) -and $seen[$row.Feature] -cne $choice) {throw 'Một tính năng có các lựa chọn trái ngược trong cùng bản sao lưu.'}
        $seen[$row.Feature]=$choice
    }
}
function Invoke-ChangePlan([object[]]$Rows) {
    if ($null -eq $Rows -or $Rows.Count -eq 0) { throw 'Không có giá trị cần thay đổi.' }
    if ($Rows.Count -gt 100) { throw 'Đợt có quá nhiều thay đổi.' }
    Assert-PlanChoices $Rows
    # Validate every original state again immediately before starting the batch.
    $latest=Get-LatestJournal
    if ($null -ne $latest -and $latest.Journal.Status -eq 'Pending') { throw 'Đợt trước chưa hoàn tất; hãy hoàn tác trước.' }
    $seen=@{}
    foreach ($row in $Rows) {
        $c = Assert-Row $row
        if (-not (Test-FeatureSupported (Get-Feature $row.Feature))) { throw 'Không hỗ trợ Windows hiện tại.' }
        $key="$($row.Feature):$($row.Index)"
        if ($seen.ContainsKey($key) -or $row.State -ne 'Prepared') { throw 'Kế hoạch lặp hoặc đã sử dụng.' }; $seen[$key]=$true
        if (-not (Test-SameState (Read-RegistryValue $c) $row)) { throw 'Thiết lập đã thay đổi sau khi xem trước. Hãy đọc lại và thử lại.' }
    }
    Assert-RegistryWriteAccess $Rows
    $journal = [pscustomobject]@{ Version=3; User=$script:UserId; Created=(Get-Date).ToString('o'); Status='Pending'; Rows=@($Rows) }
    $path = Join-Path $script:DataRoot ((Get-Date -Format 'yyyyMMddHHmmssfffffff') + '-' + [guid]::NewGuid().ToString('N') + '.json')
    Save-Journal $journal $path
    try {
        foreach ($row in $Rows) {
            $c = Assert-Row $row
            if (-not (Test-SameState (Read-RegistryValue $c) $row)) { throw "Thiết lập đổi trong lúc áp dụng: $($c.Name)." }
            $row.State='Writing'; Save-Journal $journal $path
            Set-RegistryValue $c $true $c.Value
            if (-not (Test-SameState (Read-RegistryValue $c) ([pscustomobject]@{Exists=$true;Value=$c.Value}))) { throw "Giá trị sau khi ghi không khớp: $($c.Name)." }
            $row.State='Applied'; Save-Journal $journal $path
        }
    } catch {
        $reason=$_.Exception.Message
        if ($row.State -eq 'Writing') { $row.State='Failed'; $row.Error=$reason }
        elseif ($row.State -eq 'Prepared') { $row.State='Skipped'; $row.Error=$reason }
        foreach ($remaining in $Rows) { if ($remaining.State -eq 'Prepared') { $remaining.State='Skipped' } }
        try { Save-Journal $journal $path } catch { throw "Lỗi ghi nhật ký sau lỗi áp dụng. Giữ bản sao Pending tại $path; $reason" }
        throw "Đợt chưa hoàn tất: $reason Xem lịch sử và hoàn tác đợt gần nhất."
    }
    $journal.Status='Applied'
    Save-Journal $journal $path
    return $path
}
function Undo-LatestJournal {
    $latest = Get-LatestJournal
    if ($null -eq $latest) { throw 'Không còn đợt nào để hoàn tác.' }
    $rows = @($latest.Journal.Rows)
    if ($rows.Count -lt 1 -or $rows.Count -gt 100) { throw 'Bản sao lưu không hợp lệ.' }
    $seen = @{}
    foreach ($row in $rows) {
        $f = Get-Feature $row.Feature
        if (($row.Index -isnot [int] -and $row.Index -isnot [long]) -or $row.Index -lt 0 -or $row.Index -ge @($f.Changes).Count) { throw 'Chỉ mục sao lưu không hợp lệ.' }
        $key = "$($row.Feature):$($row.Index)"
        if ($seen.ContainsKey($key) -or $row.Exists -isnot [bool]) { throw 'Dữ liệu sao lưu không hợp lệ.' }
        $seen[$key]=$true
        $c = Assert-Row $row
        if ($latest.Journal.Version -eq 3 -and $row.State -in @('Prepared','Skipped')) { continue }
        if ($row.Target -ne $c.Value) { throw 'Danh mục đã thay đổi so với bản sao lưu.' }
        $now = Read-RegistryValue $c
        if ($latest.Journal.Version -eq 3 -and $row.UndoState -eq 'Restored' -and -not (Test-SameState $now $row)) { throw "Giá trị đã phục hồi bị sửa bên ngoài: $($c.Name). Không ghi đè." }
        $isApplied = $now.Exists -and $now.Value -eq $c.Value
        if (-not $isApplied -and -not (Test-SameState $now $row)) { throw "Có thay đổi bên ngoài ở '$($f.Title)'. Dừng để tránh ghi đè." }
    }
    foreach ($row in $rows) {
        if ($latest.Journal.Version -eq 3 -and $row.State -in @('Prepared','Skipped')) { continue }
        $c=Assert-Row $row
        $now=Read-RegistryValue $c
        if (Test-SameState $now $row) {
            if ($c.Type -eq 'String' -and $c.Name -ceq '' -and -not $row.KeyExisted) {Set-RegistryValue $c $false $row.Value $true}
            if ($latest.Journal.Version -eq 3) { $row.UndoState='Restored'; Save-Journal $latest.Journal $latest.Path }
            continue
        }
        if (-not ($now.Exists -and $now.Value -eq $row.Target)) { throw "Có thay đổi bên ngoài ở $($c.Name); dừng hoàn tác." }
        try {
            if ($latest.Journal.Version -eq 3) { $row.UndoState='Restoring'; Save-Journal $latest.Journal $latest.Path }
            Set-RegistryValue $c $row.Exists $row.Value ([bool]($c.Type -eq 'String' -and $c.Name -ceq '' -and -not $row.KeyExisted))
            if (-not (Test-SameState (Read-RegistryValue $c) $row)) { throw "Không xác minh được hoàn tác $($c.Name)." }
            if ($latest.Journal.Version -eq 3) { $row.UndoState='Restored'; Save-Journal $latest.Journal $latest.Path }
        } catch {
            $reason=$_.Exception.Message
            if ($latest.Journal.Version -eq 3) { $row.UndoState='Failed'; $row.UndoError=$reason; Save-Journal $latest.Journal $latest.Path }
            throw "Hoàn tác chưa hoàn tất: $reason. Các giá trị đã phục hồi được lưu trong lịch sử; có thể thử lại."
        }
    }
    $latest.Journal.Status='Undone'
    Save-Journal $latest.Journal $latest.Path
    return $latest.Journal.Created
}
