# Separate engine: the original catalog, journals and app protection stay compatible.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Security
function Initialize-FullTweaks([string]$Root,[bool]$Simulation=$false,[int]$Build=22000) {
    $script:FullCatalog=@((Get-Content -LiteralPath "$PSScriptRoot/FullTweaks.json" -Raw -Encoding UTF8 | ConvertFrom-Json).Features)
    if ((Get-FileHash -LiteralPath "$PSScriptRoot/FullTweaks.json" -Algorithm SHA256).Hash -cne '284C2B1CD80BF01D8C6861CEFD90EAF65ED4C9029DBBAEDC590E93B6E48EFBB2') {throw 'Danh mục tinh chỉnh đã đổi; cần dùng bộ WinTune đầy đủ, đã kiểm tra.'}
    if ($FullCatalog.Count -lt 67 -or @($FullCatalog.Id | Select-Object -Unique).Count -ne $FullCatalog.Count) {throw 'Danh mục thiếu hoặc trùng mục.'}
    $script:FullCatalogById=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($feature in $FullCatalog) {$script:FullCatalogById.Add($feature.Id,$feature)}
    $script:FullRoot=[IO.Path]::GetFullPath($Root);$script:FullSimulation=$Simulation;$script:FullBuild=$Build
    $script:FullUser=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $script:FullMemory=@{};$script:FullMockWrites=0;$script:FullFailAfter=-1
    $null=New-Item -ItemType Directory -Path $FullRoot -Force
    Assert-FullPath $FullRoot
}
function Assert-FullPath([string]$Path) {
    $cursor=[IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Không dùng dữ liệu qua liên kết thư mục/tệp.'}}
        $parent=[IO.Path]::GetDirectoryName($cursor);if ($parent -eq $cursor) {break};$cursor=$parent
    }
}
function Write-FullData($Data,[string]$Path) {
    $full=[IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($FullRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Không ghi dữ liệu ngoài thư mục tinh chỉnh.'}
    Assert-FullPath $full
    $bytes=[Text.Encoding]::UTF8.GetBytes(($Data | ConvertTo-Json -Depth 80 -Compress))
    $sealed=[Security.Cryptography.ProtectedData]::Protect($bytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
    $temp=$full+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    [IO.File]::WriteAllBytes($temp,$sealed)
    if (Test-Path -LiteralPath $full) {$backup=$temp+'.previous';[IO.File]::Replace($temp,$full,$backup);[IO.File]::Delete($backup)} else {[IO.File]::Move($temp,$full)}
}
function Read-FullData([string]$Path) {
    $full=[IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($FullRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Đường dẫn dữ liệu không hợp lệ.'}
    Assert-FullPath $full
    $bytes=[Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($full),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
    return ([Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json)
}
function Get-FullFeature([string]$Id) {
    if (-not $script:FullCatalogById.ContainsKey($Id)) {throw 'Không nhận diện tính năng; chưa thực hiện.'};return $script:FullCatalogById[$Id]
}
function Get-FullBase([string]$Hive) {
    switch -CaseSensitive ($Hive) {'HKCU' {return [Microsoft.Win32.Registry]::CurrentUser} 'HKLM' {return [Microsoft.Win32.Registry]::LocalMachine} 'HKU' {return [Microsoft.Win32.Registry]::Users} default {throw 'Nhánh registry không được hỗ trợ.'}}
}
function Get-FullChanges($Feature,[string]$Option='Apply') {
    if ($Option -ceq 'Apply') {return @($Feature.Changes)}
    if (-not $Feature.PSObject.Properties['Choices']) {throw 'Mục này không có lựa chọn đó.'}
    $choice=@($Feature.Choices | Where-Object Id -CEQ $Option)
    if ($choice.Count -ne 1) {throw 'Lựa chọn không có trong danh mục đã kiểm tra.'}
    return @($choice[0].Changes)
}
function Get-FullChoiceId($Feature,$Parameters) {
    if ($null -ne $Parameters -and (($Parameters -is [Collections.IDictionary] -and $Parameters.Contains('Choices')) -or $Parameters.PSObject.Properties['Choices'])) {
        $map=$Parameters.Choices
        $value=if ($map -is [Collections.IDictionary]) {$map[$Feature.Id]} elseif ($map.PSObject.Properties[$Feature.Id]) {$map.PSObject.Properties[$Feature.Id].Value} else {$null}
        if ($value) {$null=Get-FullChanges $Feature ([string]$value);return [string]$value}
    }
    return 'Apply'
}
function Get-FullMemoryKey($Row) {
    $f=Get-FullFeature $Row.Id
    if ($Row.Kind -eq 'Registry') {$c=@(Get-FullChanges $f $Row.Option)[$Row.Index];return ('Registry:'+$c.Hive+'\'+$c.Path+'\'+$c.Name).ToLowerInvariant()}
    if ($Row.Kind -eq 'Service') {return 'Service:'+$f.Services[$Row.Index].Name.ToLowerInvariant()}
    return 'Native:'+$Row.Id
}
function Read-FullRegistry($Change) {
    if ($Change.Type -eq 'Tree') {return Read-FullRegistryTree $Change.Hive $Change.Path}
    $key=(Get-FullBase $Change.Hive).OpenSubKey($Change.Path)
    try {
        if ($null -eq $key -or $Change.Name -cnotin $key.GetValueNames()) {return [pscustomobject]@{Exists=$false;KeyExisted=($null -ne $key);Type=$Change.Type;Value=$null}}
        $type=[string]$key.GetValueKind($Change.Name)
        $value=$key.GetValue($Change.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($type -eq 'Binary') {$value=[Convert]::ToBase64String($value)}
        return [pscustomobject]@{Exists=$true;KeyExisted=$true;Type=$type;Value=$value}
    } finally {if ($null -ne $key) {$key.Dispose()}}
}
function Read-FullRegistryTree([string]$Hive,[string]$Path,[int]$Depth=0) {
    if ($Depth -gt 16) {throw 'Khóa registry quá sâu; chưa xóa để tránh sao lưu thiếu.'}
    $key=(Get-FullBase $Hive).OpenSubKey($Path)
    try {
        if ($null -eq $key) {return [pscustomobject]@{Exists=$false;KeyExisted=$false;Type='Tree';Value=$null}}
        $values=@();foreach ($name in @($key.GetValueNames() | Sort-Object)) {$c=[pscustomobject]@{Hive=$Hive;Path=$Path;Name=$name;Type='String'};$values+=[pscustomobject]@{Name=$name;Data=(Read-FullRegistry $c)}}
        $children=@();foreach ($name in @($key.GetSubKeyNames() | Sort-Object)) {$children+=[pscustomobject]@{Name=$name;Data=(Read-FullRegistryTree $Hive ($Path+'\'+$name) ($Depth+1))}}
        $value=[pscustomobject]@{Values=$values;Children=$children;Sddl=$key.GetAccessControl().GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)}
        if (($value | ConvertTo-Json -Depth 80 -Compress).Length -gt 2MB) {throw 'Bản sao registry quá lớn; chưa xóa.'}
        return [pscustomobject]@{Exists=$true;KeyExisted=$true;Type='Tree';Value=$value}
    } finally {if ($null -ne $key) {$key.Dispose()}}
}
function Set-FullRegistryTree([string]$Hive,[string]$Path,$State,[int]$Depth=0) {
    if ($Depth -gt 16) {throw 'Bản sao cây registry quá sâu.'}
    if ($Depth -eq 0 -and ($Hive -cne 'HKLM' -or $Path -cne 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}')) {throw 'Không xóa cây registry ngoài khóa ổ đĩa trùng đã cho phép.'}
    $base=Get-FullBase $Hive
    if ($Depth -eq 0) {$base.DeleteSubKeyTree($Path,$false)}
    if (-not $State.Exists) {return}
    $key=$base.CreateSubKey($Path)
    try {
        foreach ($v in $State.Value.Values) {if ($v.Name -match '[\\/\x00]') {throw 'Tên giá trị sao lưu không hợp lệ.'};Set-FullRegistry ([pscustomobject]@{Hive=$Hive;Path=$Path;Name=$v.Name;Type=$v.Data.Type}) $v.Data}
        foreach ($child in $State.Value.Children) {if (-not $child.Name -or $child.Name -match '[\\/\x00]') {throw 'Tên khóa sao lưu không hợp lệ.'};Set-FullRegistryTree $Hive ($Path+'\'+$child.Name) $child.Data ($Depth+1)}
        $acl=New-Object Security.AccessControl.RegistrySecurity;$acl.SetSecurityDescriptorSddlForm($State.Value.Sddl,[Security.AccessControl.AccessControlSections]::Access);$key.SetAccessControl($acl)
    } finally {$key.Dispose()}
}
function Set-FullRegistry($Change,$State) {
    if ($Change.Type -eq 'Tree') {Set-FullRegistryTree $Change.Hive $Change.Path $State;return}
    $base=Get-FullBase $Change.Hive
    $key=if ($State.Exists) {$base.CreateSubKey($Change.Path)} else {$base.OpenSubKey($Change.Path,$true)}
    try {
        if (-not $State.Exists) {
            if ($null -eq $key) {return};$key.DeleteValue($Change.Name,$false)
            if ($State.PSObject.Properties['KeyExisted'] -and -not $State.KeyExisted) {if ($key.SubKeyCount -gt 0 -or $key.ValueCount -gt 0) {throw 'Khóa mới chứa dữ liệu khác; không xóa thêm để tránh mất dữ liệu.'};$key.Dispose();$key=$null;$base.DeleteSubKey($Change.Path,$false)}
            return
        }
        $kind=[Microsoft.Win32.RegistryValueKind][Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$State.Type)
        $value=$State.Value
        switch ($State.Type) {'DWord' {$value=[int]$value} 'QWord' {$value=[long]$value} 'Binary' {$value=[Convert]::FromBase64String($value)} 'MultiString' {$value=[string[]]$value} 'String' {$value=[string]$value} 'ExpandString' {$value=[string]$value} default {throw 'Không hỗ trợ kiểu giá trị này.'}}
        $key.SetValue($Change.Name,$value,$kind)
    } finally {if ($null -ne $key) {$key.Dispose()}}
}
function Test-FullSame($A,$B) {
    if ($null -ne $A -and $null -ne $B -and $A.PSObject.Properties['KeyExisted'] -and $B.PSObject.Properties['KeyExisted'] -and -not $A.Exists -and -not $B.Exists) {return $true}
    if ($null -ne $A -and $null -ne $B -and $A.PSObject.Properties['Features'] -and $B.PSObject.Properties['Features']) {
        $left=@($A.Features | ForEach-Object {$state=[string]$_.State;if ($state -eq 'EnablePending') {$state='Enabled'} elseif ($state -eq 'DisablePending') {$state='Disabled'};[pscustomobject]@{Name=$_.Name;State=$state}})
        $right=@($B.Features | ForEach-Object {$state=[string]$_.State;if ($state -eq 'EnablePending') {$state='Enabled'} elseif ($state -eq 'DisablePending') {$state='Disabled'};[pscustomobject]@{Name=$_.Name;State=$state}})
        return (($left | ConvertTo-Json -Compress) -ceq ($right | ConvertTo-Json -Compress))
    }
    return (($A | ConvertTo-Json -Depth 80 -Compress) -ceq ($B | ConvertTo-Json -Depth 80 -Compress))
}
function Get-FullTarget($Change) {
    if ($Change.Type -eq 'Tree') {return [pscustomobject]@{Exists=$false;KeyExisted=$false;Type='Tree';Value=$null}}
    $value=$Change.Value;if ($Change.Type -eq 'Binary') {$value=[Convert]::ToBase64String([byte[]]$value)}
    return [pscustomobject]@{Exists=[bool]$Change.Exists;KeyExisted=$true;Type=$Change.Type;Value=$value}
}
function Assert-FullRow($Row) {
    $feature=Get-FullFeature $Row.Id
    if ($Row.Kind -notin @('Registry','Service','Native') -or $Row.Index -isnot [long] -and $Row.Index -isnot [int] -or $Row.State -notin @('Prepared','Writing','Applied','Failed','Restored')) {throw 'Dòng sao lưu không hợp lệ.'}
    $changes=@(Get-FullChanges $feature $Row.Option)
    if ($Row.Kind -eq 'Registry') {
        if ($Row.Index -lt 0 -or $Row.Index -ge $changes.Count) {throw 'Sai đích registry.'}
        if (-not (Test-FullSame $Row.Target (Get-FullTarget $changes[$Row.Index]))) {throw 'Đích registry khác danh mục đã chốt.'}
    } elseif ($Row.Kind -eq 'Service') {if ($Row.Index -lt 0 -or $Row.Index -ge $feature.Services.Count -or $Row.Target -cne $feature.Services[$Row.Index].StartupType) {throw 'Sai dịch vụ hoặc chế độ khởi động.'}}
    elseif ($feature.Handler -in @('Registry','Route') -or $Row.Index -ne 0 -or $Row.Target -cne $feature.Handler) {throw 'Handler chưa được đăng ký.'}
    if ($null -eq $Row.Before -or $Row.Before.PSObject.Properties['Exists'] -and $Row.Before.Exists -isnot [bool]) {throw 'Thiếu trạng thái trước thay đổi.'}
    return $feature
}
function Read-FullResource($Row) {
    $feature=Assert-FullRow $Row
    if ($FullSimulation) { $key=Get-FullMemoryKey $Row;if ($FullMemory.ContainsKey($key)) {return $FullMemory[$key]};if ($Row.Kind -eq 'Service') {return [pscustomobject]@{Exists=$true;Start=2;Delayed=$null}};return [pscustomobject]@{Exists=$false;KeyExisted=$false;Type='DWord';Value=$null} }
    switch ($Row.Kind) {'Registry' {return Read-FullRegistry @(Get-FullChanges $feature $Row.Option)[$Row.Index]} 'Service' {return Read-FullService $feature.Services[$Row.Index].Name} 'Native' {return Read-FullNative $feature $Row.Parameters}}
}
function Write-FullResource($Row,$State,[bool]$Undo=$false) {
    $feature=Assert-FullRow $Row
    if ($FullSimulation) {
        if ($script:FullFailAfter -ge 0 -and $script:FullMockWrites -ge $script:FullFailAfter) {throw 'Lỗi mô phỏng khi ghi.'}
        $script:FullMockWrites++;$script:FullMemory[(Get-FullMemoryKey $Row)]=$State;return
    }
    switch ($Row.Kind) {'Registry' {Set-FullRegistry @(Get-FullChanges $feature $Row.Option)[$Row.Index] $State} 'Service' {Set-FullService $feature.Services[$Row.Index].Name $State} 'Native' {Write-FullNative $feature $Row.Parameters $State $Undo}}
}
function New-FullPlan([string[]]$Ids,$Parameters) {
    $rows=@();$seen=@{}
    foreach ($id in @($Ids | Select-Object -Unique)) {
        $feature=Get-FullFeature $id
        $option=Get-FullChoiceId $feature $Parameters;$changes=@(Get-FullChanges $feature $option)
        if ($option -cne 'Off') {Assert-FullHardware $feature}
        if ($FullBuild -lt $feature.MinBuild -or $feature.Handler -eq 'Route') {throw ('Mở công cụ riêng hoặc dùng bản Windows được hỗ trợ: '+$feature.Title)}
        foreach ($kind in @('Registry','Service','Native')) {
            $count=switch ($kind) {'Registry' {$changes.Count} 'Service' {$feature.Services.Count} 'Native' {if ($feature.Handler -notin @('Registry','Route','Services')) {1} else {0}}}
            for ($i=0;$i -lt $count;$i++) {
                $target=switch ($kind) {'Registry' {Get-FullTarget $changes[$i]} 'Service' {$feature.Services[$i].StartupType} 'Native' {$feature.Handler}}
                $row=[pscustomobject]@{Kind=$kind;Id=$id;Index=$i;Option=$option;Target=$target;Parameters=$Parameters;Before=[pscustomobject]@{Exists=$false};After=$null;State='Prepared';Error=''}
                if ($kind -in @('Registry','Service')) {$key=if ($kind -eq 'Registry') {$c=$changes[$i];$c.Hive+'\'+$c.Path+'\'+$c.Name} else {'Service:'+$feature.Services[$i].Name};if ($seen.ContainsKey($key) -and -not (Test-FullSame $seen[$key] $target)) {throw 'Hai mục đang chọn đặt cùng thiết lập theo hai cách khác nhau. Hãy chọn một mục.'};if ($seen.ContainsKey($key)) {continue};$seen[$key]=$target}
                $row.Before=Read-FullResource $row
                if ($kind -eq 'Registry' -and $changes[$i].Name -ceq 'SettingsPageVisibility' -and $row.Before.Exists -and [string]$row.Before.Value -cnotin @('','hide:home')) {throw 'Đang có chính sách ẩn/hiện trang Settings khác. WinTune không ghi đè chính sách đó.'}
                if ($kind -eq 'Native' -and $feature.Handler -eq 'Optional' -and -not $FullSimulation) {$null=Get-FullOptionalTarget $feature $row.Before}
                if ($kind -eq 'Service' -and -not $row.Before.Exists) {continue}
                if ($kind -eq 'Registry' -and (Test-FullSame $row.Before $target)) {continue}
                $rows+=$row
            }
        }
    }
    if ($rows.Count -gt 250) {throw 'Chọn ít mục hơn trong một lần áp dụng.'}
    return $rows
}
function Get-FullJournals {
    $results=@()
    foreach ($file in @(Get-ChildItem -LiteralPath $FullRoot -Filter 'batch-*.dat' -File | Sort-Object Name -Descending)) {
        $journal=Read-FullData $file.FullName
        if ($journal.Version -ne 1 -or $journal.User -cne $FullUser -or $journal.Mode -cne $(if ($FullSimulation) {'Simulation'} else {'Native'}) -or $journal.Status -notin @('Pending','Applied','Partial','Undone') -or @($journal.Rows).Count -gt 250) {throw 'Nhật ký khác tài khoản/chế độ hoặc bị hỏng. Chưa ghi thêm.'}
        $seen=@{};foreach ($row in $journal.Rows) {$null=Assert-FullRow $row;$key=$row.Kind+':'+$row.Id+':'+$row.Index;if ($seen.ContainsKey($key)) {throw 'Nhật ký lặp mục.'};$seen[$key]=$true}
        $results+=[pscustomobject]@{Path=$file.FullName;Data=$journal}
    };return $results
}
function Invoke-FullPlan([object[]]$Rows,[bool]$Confirmed=$false) {
    if (-not $Confirmed -or -not $Rows.Count -or $Rows.Count -gt 250) {throw 'Cần xem trước và xác nhận một kế hoạch hợp lệ.'}
    if (@(Get-FullJournals | Where-Object {$_.Data.Status -eq 'Pending'}).Count) {throw 'Có đợt bị ngắt. Hoàn tác hoặc kiểm tra lịch sử trước.'}
    $seen=@{}
    foreach ($row in $Rows) {
        $feature=Assert-FullRow $row;$key=$row.Kind+':'+$row.Id+':'+$row.Index
        if ($seen.ContainsKey($key) -or $row.State -cne 'Prepared') {throw 'Kế hoạch trùng hoặc đã chạy.'};$seen[$key]=$true
        if ($FullBuild -lt $feature.MinBuild -or -not (Test-FullSame (Read-FullResource $row) $row.Before)) {throw 'Thiết lập đã đổi sau khi xem trước hoặc Windows không hỗ trợ. Hãy đọc lại.'}
        if ($row.Option -cne 'Off') {Assert-FullHardware $feature}
    }
    if (-not $FullSimulation -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {throw 'Windows chưa cấp quyền cho thao tác này. Chưa thay đổi.'}
    $journal=[pscustomobject]@{Version=1;User=$FullUser;Mode=$(if ($FullSimulation) {'Simulation'} else {'Native'});Created=(Get-Date).ToString('o');Status='Pending';Rows=@($Rows)}
    $path=Join-Path $FullRoot ('batch-'+(Get-Date -Format yyyyMMddHHmmssfffffff)+'-'+[guid]::NewGuid().ToString('N')+'.dat');Write-FullData $journal $path
    foreach ($row in $Rows) {
        try {
            if (-not (Test-FullSame (Read-FullResource $row) $row.Before)) {throw 'Thiết lập bị đổi trong lúc thực hiện.'}
            $row.State='Writing';Write-FullData $journal $path
            $state=switch ($row.Kind) {'Registry' {$row.Target} 'Service' {Get-FullServiceTarget $row.Target $row.Before} 'Native' {Get-FullNativeTarget (Get-FullFeature $row.Id) $row.Parameters $row.Before}}
            # Save the intended result before any native write, so interrupted writes can be inspected.
            $row.After=$state;Write-FullData $journal $path
            Write-FullResource $row $state
            $actual=Read-FullResource $row
            if ($row.Kind -eq 'Native' -and -not $FullSimulation) {Assert-FullNativeResult (Get-FullFeature $row.Id) $row.Parameters $row.Before $actual $state;$row.After=$actual}
            elseif (-not (Test-FullSame $actual $state)) {throw 'Không xác minh được thay đổi; giữ bản sao để kiểm tra.'}
            $row.State='Applied';Write-FullData $journal $path
        } catch {$failure=$_.Exception.Message;if ($row.Kind -eq 'Native' -and $row.State -eq 'Writing') {try {$row.After=Read-FullResource $row} catch {}};$row.State='Failed';$row.Error=$failure;Write-FullData $journal $path;throw ('Chưa hoàn tất: '+$failure+'. Các mục trước có thể đã áp dụng; xem lịch sử và hoàn tác.')}
    }
    $journal.Status='Applied';Write-FullData $journal $path;return $journal
}
function Undo-FullSelection([string[]]$Ids,[bool]$Confirmed=$false) {
    if (-not $Confirmed -or -not $Ids.Count) {throw 'Chọn mục rồi xác nhận hoàn tác.'}
    $remaining=@{};foreach ($id in $Ids) {$null=Get-FullFeature $id;$remaining[$id]=$true}
    $notes=@()
    foreach ($entry in @(Get-FullJournals)) {
        $journal=$entry.Data;$rows=@($journal.Rows);[array]::Reverse($rows);$handled=@{}
        foreach ($row in $rows) {
            if (-not $remaining.ContainsKey($row.Id) -or $row.State -in @('Prepared','Restored')) {continue}
            if ($null -eq $row.After) {throw 'Đợt bị ngắt trước khi lưu đích. Giữ nhật ký để kiểm tra.'}
            if ($row.Kind -eq 'Native' -and (Get-FullFeature $row.Id).Handler -in @('Widgets','Copilot','Edge','OneDrive','WindowsAI','BitLocker','OOSU','UltimateRemove','Temp','DiskCleanup')) {$notes+='Không tự hoàn tác thao tác gỡ/xóa/giải mã/công cụ ngoài: '+(Get-FullFeature $row.Id).Title;$handled[$row.Id]=$true;continue}
            $current=Read-FullResource $row
            if (Test-FullSame $current $row.Before) {$row.State='Restored';$handled[$row.Id]=$true;Write-FullData $journal $entry.Path;continue}
            if (-not (Test-FullSame $current $row.After)) {throw ('Thiết lập đã đổi bên ngoài WinTune: '+(Get-FullFeature $row.Id).Title+'. Không ghi đè thay đổi đó.')}
            Write-FullResource $row $row.Before $true
            if (-not (Test-FullSame (Read-FullResource $row) $row.Before)) {throw 'Hoàn tác chưa được xác minh; giữ nhật ký.'}
            $row.State='Restored';$handled[$row.Id]=$true;Write-FullData $journal $entry.Path
        }
        foreach ($id in @($handled.Keys)) {$remaining.Remove($id)}
        if (@($journal.Rows | Where-Object State -notin @('Prepared','Restored')).Count -eq 0) {$journal.Status='Undone'} elseif ($journal.Status -eq 'Pending') {$journal.Status='Partial'}
        Write-FullData $journal $entry.Path
    }
    if ($remaining.Count) {$notes+='Chưa có thay đổi đã lưu cho: '+(($remaining.Keys | ForEach-Object {(Get-FullFeature $_).Title}) -join ', ')}
    return [pscustomobject]@{Message='Đã xử lý các mục có bản sao và không xung đột.';Notes=$notes}
}
function Get-FullAppliedIds {
    foreach ($selection in @(Get-FullAppliedSelections)) {$selection.Id}
}
function Get-FullAppliedSelections {
    foreach ($feature in $FullCatalog) {
        if (-not $feature.Changes.Count -or $feature.Handler -cne 'Registry' -or $FullBuild -lt $feature.MinBuild) {continue}
        $options=if ($feature.PSObject.Properties['Choices']) {@($feature.Choices.Id)} else {@('Apply')}
        foreach ($option in $options) {
            $changes=@(Get-FullChanges $feature $option);$ok=$true
            for ($i=0;$i -lt $changes.Count;$i++) {
                $row=[pscustomobject]@{Kind='Registry';Id=$feature.Id;Index=$i;Option=$option;Target=(Get-FullTarget $changes[$i]);Before=[pscustomobject]@{Exists=$false};State='Prepared';Parameters=@{}}
                try {if (-not (Test-FullSame (Read-FullResource $row) $row.Target)) {$ok=$false;break}} catch {$ok=$false;break}
            }
            if ($ok) {[pscustomobject]@{Id=$feature.Id;Option=$option};break}
        }
    }
}
