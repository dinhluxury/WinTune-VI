# Fixed Win11Debloat operations. All writers are called only after the protected preview is confirmed.
function Get-FullTelemetryTasks {
    return @(
        @('\Microsoft\Windows\Application Experience\','Microsoft Compatibility Appraiser'),
        @('\Microsoft\Windows\Application Experience\','Microsoft Compatibility Appraiser Exp'),
        @('\Microsoft\Windows\Application Experience\','ProgramDataUpdater'),
        @('\Microsoft\Windows\Application Experience\','StartupAppTask'),
        @('\Microsoft\Windows\Customer Experience Improvement Program\','Consolidator'),
        @('\Microsoft\Windows\Customer Experience Improvement Program\','UsbCeip'),
        @('\Microsoft\Windows\DiskDiagnostic\','Microsoft-Windows-DiskDiagnosticDataCollector'),
        @('\Microsoft\Windows\Autochk\','Proxy'))
}
function Get-FullTelemetryState {
    $rows=@();foreach ($task in @(Get-FullTelemetryTasks)) {
        try {$found=Get-ScheduledTask -TaskPath $task[0] -TaskName $task[1] -ErrorAction Stop;$rows+=[pscustomobject]@{Path=$task[0];Name=$task[1];Exists=$true;Enabled=[bool]$found.Settings.Enabled}}
        catch {if ($_.CategoryInfo.Category -ne 'ObjectNotFound') {throw};$rows+=[pscustomobject]@{Path=$task[0];Name=$task[1];Exists=$false;Enabled=$false}}
    };return [pscustomobject]@{Tasks=$rows}
}
function Get-FullTelemetryTarget($Before) {
    return [pscustomobject]@{Tasks=@($Before.Tasks | ForEach-Object {[pscustomobject]@{Path=$_.Path;Name=$_.Name;Exists=$_.Exists;Enabled=$false}})}
}
function Set-FullTelemetryState($State) {
    foreach ($task in $State.Tasks) {
        if (-not $task.Exists) {continue}
        if (-not @((Get-FullTelemetryTasks) | Where-Object {$_[0] -ceq $task.Path -and $_[1] -ceq $task.Name}).Count) {throw 'Tác vụ không thuộc danh sách chẩn đoán đã kiểm tra.'}
        if ($task.Enabled) {Enable-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction Stop | Out-Null}
        else {Disable-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction Stop | Out-Null}
    }
}
function Get-FullOptionalState($Feature) {
    $available=@(Get-WindowsOptionalFeature -Online -ErrorAction Stop)
    $items=@();foreach ($f in $Feature.NativeFeatures) {
        $match=@($available | Where-Object FeatureName -CEQ $f.Name)
        if (-not $match.Count -and -not $f.MayBeAbsent) {throw ('Bản Windows này không có thành phần '+$f.Name+'. Sandbox cần Windows Pro/Enterprise/Education và hỗ trợ ảo hóa.')}
        $state=if ($match.Count) {[string]$match[0].State} else {'Absent'}
        if ($state -eq 'DisabledWithPayloadRemoved') {$state='Disabled'}
        if ($state -notin @('Enabled','Disabled','EnablePending','DisablePending','Absent')) {throw ('Thành phần '+$f.Name+' có trạng thái chưa hỗ trợ.')}
        $items+=[pscustomobject]@{Name=$f.Name;State=$state}
    };return [pscustomobject]@{Features=$items}
}
function Get-FullOptionalTarget($Feature,$Before) {
    if (@($Before.Features | Where-Object State -match 'Pending').Count) {throw 'Thành phần Windows đang chờ khởi động lại. Hoàn tất khởi động lại trước khi thay đổi tiếp.'}
    return [pscustomobject]@{Features=@(foreach ($f in $Before.Features) {$definition=@($Feature.NativeFeatures | Where-Object Name -CEQ $f.Name)[0];[pscustomobject]@{Name=$f.Name;State=$(if ($f.State -eq 'Absent') {'Absent'} else {$definition.Desired})}})}
}
function Set-FullOptionalState($Feature,$State,[bool]$Undo) {
    if (@((Get-FullOptionalState $Feature).Features | Where-Object State -match 'Pending').Count) {throw 'Thành phần đang chờ khởi động lại; chưa thay đổi tiếp.'}
    foreach ($f in $State.Features) {
        if ($f.Name -cnotin @($Feature.NativeFeatures.Name) -or $f.State -notin @('Enabled','Disabled','DisabledWithPayloadRemoved','Absent')) {throw 'Không có thao tác thành phần Windows đó trong danh mục.'}
        if ($f.State -eq 'Absent') {continue}
        if ($f.State -eq 'Enabled') {Enable-WindowsOptionalFeature -Online -FeatureName $f.Name -NoRestart -ErrorAction Stop | Out-Null}
        else {
            # Never remove downloaded component payloads, Linux distributions or user data.
            Disable-WindowsOptionalFeature -Online -FeatureName $f.Name -NoRestart -ErrorAction Stop | Out-Null
        }
    }
}
function Test-FullOptionalResult($After,$Expected) {
    foreach ($f in $Expected.Features) {
        $actual=@($After.Features | Where-Object Name -CEQ $f.Name)
        if ($actual.Count -ne 1) {return $false}
        $allowed=switch ($f.State) {'Enabled' {@('Enabled','EnablePending')} 'Disabled' {@('Disabled','DisabledWithPayloadRemoved','DisablePending')} default {@($f.State)}}
        if ($actual[0].State -cnotin $allowed) {return $false}
    };return $true
}
function Get-FullStartProfileRoots($Feature) {
    if (-not $Feature.AllProfiles) {return @([Environment]::GetFolderPath('UserProfile'))}
    $list='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    $roots=@(Get-ChildItem -LiteralPath $list -ErrorAction Stop | Where-Object PSChildName -match '^S-1-(5-21|12-1)-' | ForEach-Object {[Environment]::ExpandEnvironmentVariables((Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction Stop).ProfileImagePath)})
    $default=[Environment]::ExpandEnvironmentVariables((Get-ItemProperty -LiteralPath $list -ErrorAction Stop).Default)
    return @((@($roots)+@($default)) | Where-Object {$_ -and (Test-Path -LiteralPath $_ -PathType Container)} | Sort-Object -Unique)
}
function Get-FullStartPaths($Feature) {
    $result=@();foreach ($root in @(Get-FullStartProfileRoots $Feature)) {
        $root=[IO.Path]::GetFullPath($root).TrimEnd('\');Assert-FullPath $root
        $dirs=@();$path=$root
        foreach ($name in @('AppData','Local','Packages','Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy','LocalState')) {$path=Join-Path $path $name;Assert-FullPath $path;$dirs+=$path}
        $result+=[pscustomobject]@{Path=(Join-Path $path 'start2.bin');Directories=$dirs}
    };if (-not $result.Count) {throw 'Không tìm thấy hồ sơ người dùng để đổi bố cục Start.'};return $result
}
function Get-FullStartPins($Feature) {
    $files=@();$dirs=@();$total=0
    foreach ($entry in @(Get-FullStartPaths $Feature)) {
        Assert-FullPath $entry.Path;$exists=Test-Path -LiteralPath $entry.Path -PathType Leaf;$bytes=''
        if ($exists) {$size=(Get-Item -LiteralPath $entry.Path).Length;$total+=$size;if ($size -gt 4MB -or $total -gt 16MB) {throw 'Bố cục Start quá lớn để sao lưu trong tác vụ này.'};$bytes=[Convert]::ToBase64String([IO.File]::ReadAllBytes($entry.Path))}
        $files+=[pscustomobject]@{Path=$entry.Path;Exists=[bool]$exists;Bytes=$bytes}
        foreach ($dir in $entry.Directories) {$dirs+=[pscustomobject]@{Path=$dir;Exists=[bool](Test-Path -LiteralPath $dir -PathType Container)}}
    };return [pscustomobject]@{Files=$files;Directories=$dirs}
}
function Get-FullStartTarget($Before) {
    $template=Join-Path $PSScriptRoot 'sources\full-tweaks\start2.bin';Assert-FullPath $template
    if ((Get-FileHash -LiteralPath $template -Algorithm SHA256).Hash -cne '2378A237691508B6BFE78AAE3B8C54D626F230D00BFC888213868C02EC81EE65') {throw 'Tệp mẫu Start khác bản đã kiểm tra.'}
    $bytes=[Convert]::ToBase64String([IO.File]::ReadAllBytes($template))
    return [pscustomobject]@{Files=@($Before.Files | ForEach-Object {[pscustomobject]@{Path=$_.Path;Exists=$true;Bytes=$bytes}});Directories=@($Before.Directories | ForEach-Object {[pscustomobject]@{Path=$_.Path;Exists=$true}})}
}
function Set-FullStartPins($Feature,$State) {
    $allowed=@(Get-FullStartPaths $Feature);$files=@($allowed.Path);$dirs=@($allowed | ForEach-Object {$_.Directories})
    foreach ($entry in $State.Files) {if ($entry.Path -cnotin $files) {throw 'Không thay bố cục Start ngoài hồ sơ đã chọn.'};Assert-FullPath $entry.Path}
    foreach ($dir in $State.Directories) {if ($dir.Path -cnotin $dirs) {throw 'Thư mục bố cục Start không hợp lệ.'};Assert-FullPath $dir.Path}
    foreach ($entry in $State.Files) {
        if ($entry.Exists) {
            $parent=[IO.Path]::GetDirectoryName($entry.Path);$null=[IO.Directory]::CreateDirectory($parent);Assert-FullPath $entry.Path
            $temp=Join-Path $parent ('wt'+[guid]::NewGuid().ToString('N').Substring(0,8)+'.tmp');[IO.File]::WriteAllBytes($temp,[Convert]::FromBase64String($entry.Bytes))
            try {if (Test-Path -LiteralPath $entry.Path) {$backup=$temp+'.old';[IO.File]::Replace($temp,$entry.Path,$backup);[IO.File]::Delete($backup)} else {[IO.File]::Move($temp,$entry.Path)}} finally {if (Test-Path -LiteralPath $temp) {[IO.File]::Delete($temp)}}
        } elseif (Test-Path -LiteralPath $entry.Path) {[IO.File]::Delete($entry.Path)}
    }
    $reverse=@($State.Directories);[array]::Reverse($reverse)
    foreach ($dir in $reverse) {if (-not $dir.Exists -and (Test-Path -LiteralPath $dir.Path) -and -not @(Get-ChildItem -LiteralPath $dir.Path -Force).Count) {[IO.Directory]::Delete($dir.Path,$false)}}
}
