# Native operations are dispatched by fixed handler names; downloaded code is never evaluated.
function Invoke-FullExe([string]$File,[string[]]$Arguments) {
    if ($FullSimulation) {throw 'Mô phỏng không được gọi chương trình thật.'}
    $info=New-Object Diagnostics.ProcessStartInfo;$info.FileName=$File
    $info.Arguments=($Arguments | ForEach-Object {'"'+([regex]::Replace([regex]::Replace($_,'(\\*)"','$1$1\"'),'(\\+)$','$1$1'))+'"'}) -join ' '
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $p=New-Object Diagnostics.Process;$p.StartInfo=$info
    try {$null=$p.Start();$out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();$p.WaitForExit();$text=$out.Result+"`n"+$err.Result;if ($p.ExitCode -notin @(0,3010)) {throw ('Lệnh bị Windows từ chối (mã '+$p.ExitCode+'): '+$text)};return $text} finally {$p.Dispose()}
}
function Get-FullSystemExe([string]$Name) {return (Join-Path $env:WINDIR ('System32\'+$Name))}
function Get-FullServiceTarget([string]$Mode,$Before) {
    if (-not $Before.Exists) {throw 'Dịch vụ không có trên máy này.'}
    return [pscustomobject]@{Exists=$true;Start=$(switch ($Mode) {'Automatic' {2} 'Manual' {3} 'Disabled' {4} default {throw 'Kiểu dịch vụ không hợp lệ.'}});Delayed=$Before.Delayed}
}
function Read-FullService([string]$Name) {
    $key=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Services\'+$Name)
    try {if ($null -eq $key) {return [pscustomobject]@{Exists=$false;Start=0;Delayed=$null}};return [pscustomobject]@{Exists=$true;Start=[int]$key.GetValue('Start');Delayed=$key.GetValue('DelayedAutoStart',$null)}} finally {if ($key) {$key.Dispose()}}
}
function Set-FullService([string]$Name,$State) {
    if (-not $State.Exists -or $State.Start -notin @(2,3,4)) {throw 'Không khôi phục được dịch vụ đã bị xóa hoặc loại hệ thống đặc biệt.'}
    $mode=switch ([int]$State.Start) {2 {'Automatic'} 3 {'Manual'} 4 {'Disabled'}}
    Set-Service -Name $Name -StartupType $mode -ErrorAction Stop
    $key=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Services\'+$Name,$true)
    try {if ($null -eq $State.Delayed) {$key.DeleteValue('DelayedAutoStart',$false)} else {$key.SetValue('DelayedAutoStart',[int]$State.Delayed,[Microsoft.Win32.RegistryValueKind]::DWord)}} finally {$key.Dispose()}
}
function Get-FullAclPath([string]$Handler) {
    switch ($Handler) {'StoreAcl' {return (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db')} 'RazerAcl' {return (Join-Path $env:WINDIR 'Installer\Razer')} 'LogitechAcl' {return (Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'LogiDownloadAssistant')} default {throw 'Không có đích quyền truy cập này.'}}
}
function Read-FullAcl([string]$Handler) {
    $path=Get-FullAclPath $Handler;Assert-FullPath $path
    if (-not (Test-Path -LiteralPath $path)) {return [pscustomobject]@{Exists=$false;Sddl=''}}
    return [pscustomobject]@{Exists=$true;Sddl=(Get-Acl -LiteralPath $path).Sddl}
}
function Get-FullApps([string[]]$Names) {
    $result=@();foreach ($name in $Names) {foreach ($app in @(Get-AppxPackage -Name $name -ErrorAction Stop)) {$result+=[pscustomobject]@{Name=$app.Name;FullName=$app.PackageFullName;NonRemovable=[bool]$app.NonRemovable}}};return @($result | Sort-Object FullName)
}
function Get-FullUninstaller([string]$Handler) {
    $paths=@()
    if ($Handler -eq 'Edge') {
        $base=Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application'
        if (Test-Path -LiteralPath $base) {$paths=@(Get-ChildItem -LiteralPath $base -Directory | Where-Object Name -match '^\d+\.\d+\.\d+\.\d+$' | Sort-Object {[version]$_.Name} -Descending | ForEach-Object {Join-Path $_.FullName 'Installer\setup.exe'})}
    } else {$paths=@((Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\OneDriveSetup.exe'),(Join-Path $env:WINDIR 'System32\OneDriveSetup.exe'),(Join-Path $env:WINDIR 'SysWOW64\OneDriveSetup.exe'))}
    foreach ($path in $paths) {if (Test-Path -LiteralPath $path) {Assert-FullPath $path;return $path}}
    return ''
}
function Assert-FullMicrosoftSignature([string]$Path) {
    Assert-FullPath $Path;$signature=Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation(?:,|$)') {throw 'Không xác minh được chữ ký Microsoft của trình cài/gỡ. Chưa chạy.'}
}
function Get-FullInstalledDesktop([string]$Handler) {
    $relative=if ($Handler -eq 'Edge') {'Microsoft\Edge\Application\msedge.exe'} else {'Microsoft\OneDrive\OneDrive.exe'}
    $roots=if ($Handler -eq 'Edge') {@(${env:ProgramFiles(x86)},$env:ProgramFiles)} else {@($env:LOCALAPPDATA,$env:ProgramFiles,${env:ProgramFiles(x86)})}
    foreach ($root in $roots) {if ($root -and (Test-Path -LiteralPath (Join-Path $root $relative))) {return $true}};return $false
}
function Get-FullTree([string]$Path,[int]$Depth=0) {
    if ($Depth -gt 18) {throw 'Bố cục thư mục quá sâu; chưa xóa để tránh bản sao không đầy đủ.'}
    $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Path)
    try {
        if (-not $key) {return [pscustomobject]@{Exists=$false;Values=@();Children=@()}}
        $values=@();foreach ($name in @($key.GetValueNames() | Sort-Object)) {$type=[string]$key.GetValueKind($name);$value=$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);if ($type -eq 'Binary') {$value=[Convert]::ToBase64String($value)};$values+=[pscustomobject]@{Name=$name;Type=$type;Value=$value}}
        $children=@();foreach ($name in @($key.GetSubKeyNames() | Sort-Object)) {$children+=[pscustomobject]@{Name=$name;Data=(Get-FullTree ($Path+'\'+$name) ($Depth+1))}}
        return [pscustomobject]@{Exists=$true;Values=$values;Children=$children}
    } finally {if ($key) {$key.Dispose()}}
}
function Set-FullTree([string]$Path,$Tree) {
    if (-not $Path.StartsWith('Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags',[StringComparison]::Ordinal) -and -not $Path.StartsWith('Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU',[StringComparison]::Ordinal)) {throw 'Không xóa cây registry ngoài bố cục Explorer.'}
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($Path,$false)
    if (-not $Tree.Exists) {return}
    $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($Path);$key.Dispose()
    foreach ($value in $Tree.Values) {Set-FullRegistry ([pscustomobject]@{Hive='HKCU';Path=$Path;Name=$value.Name}) ([pscustomobject]@{Exists=$true;Type=$value.Type;Value=$value.Value})}
    foreach ($child in $Tree.Children) {Set-FullTree ($Path+'\'+$child.Name) $child.Data}
}
function Get-FullDnsProviders {
    return @(
        [pscustomobject]@{Id='dhcp';Title='Tự động từ mạng (DHCP)';Servers=@()},
        [pscustomobject]@{Id='fastest';Title='Đo và chọn nhanh nhất trong các nhà cung cấp';Servers=@()},
        [pscustomobject]@{Id='google';Title='Google';Servers=@('8.8.8.8','8.8.4.4')},
        [pscustomobject]@{Id='cloudflare';Title='Cloudflare';Servers=@('1.1.1.1','1.0.0.1')},
        [pscustomobject]@{Id='cloudflaremalware';Title='Cloudflare: lọc mã độc';Servers=@('1.1.1.2','1.0.0.2')},
        [pscustomobject]@{Id='cloudflarefamily';Title='Cloudflare: lọc mã độc và nội dung người lớn';Servers=@('1.1.1.3','1.0.0.3')},
        [pscustomobject]@{Id='opendns';Title='OpenDNS';Servers=@('208.67.222.222','208.67.220.220')},
        [pscustomobject]@{Id='quad9';Title='Quad9';Servers=@('9.9.9.9','149.112.112.112')},
        [pscustomobject]@{Id='adguard';Title='AdGuard: lọc quảng cáo và theo dõi';Servers=@('94.140.14.14','94.140.15.15')},
        [pscustomobject]@{Id='adguardfamily';Title='AdGuard: lọc quảng cáo và nội dung người lớn';Servers=@('94.140.14.15','94.140.15.16')}
    )
}
function Get-FullDnsState($Parameters) {
    $index=[int]$Parameters.InterfaceIndex;$adapters=@(Get-NetAdapter -IncludeHidden -ErrorAction Stop | Where-Object InterfaceIndex -eq $index)
    if ($index -le 0 -or $adapters.Count -ne 1) {throw 'Chọn một card mạng còn tồn tại.'};$adapter=$adapters[0];$guid=[guid]$adapter.InterfaceGuid
    $key=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\'+$guid.ToString('B'))
    try {$static=[string]$key.GetValue('NameServer','')} finally {if ($key) {$key.Dispose()}}
    return [pscustomobject]@{Index=$index;Guid=$guid.ToString('D');Manual=(-not [string]::IsNullOrWhiteSpace($static));Servers=@($static -split '[,; ]+' | Where-Object {$_})}
}
function Get-FullOwnedPlan {
    $path=Join-Path $FullRoot 'owned-plan.dat';if (Test-Path -LiteralPath $path) {return Read-FullData $path};return [pscustomobject]@{Guid='';Previous=''}
}
function Get-FullTempInventory {
    $roots=@([IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Temp')),[IO.Path]::GetFullPath((Join-Path $env:WINDIR 'Temp')));$files=@();$script:FullTempReadErrors=0
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {continue};Assert-FullPath $root
        $stack=New-Object 'Collections.Generic.Stack[string]';$stack.Push($root)
        while ($stack.Count) {
            $dir=$stack.Pop();try {$children=@(Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop)} catch {$script:FullTempReadErrors++;continue}
            foreach ($file in $children) {
                if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) {continue}
                if ($file.PSIsContainer) {$stack.Push($file.FullName);continue}
                if ($file.LastWriteTimeUtc -gt [DateTime]::UtcNow.AddDays(-7)) {continue}
                $files+=[pscustomobject]@{Path=$file.FullName;Root=$root;Length=$file.Length;Ticks=$file.LastWriteTimeUtc.Ticks}
                if ($files.Count -ge 5000) {throw 'Có hơn 5.000 tệp tạm; dùng công cụ Dọn dẹp để chia thành các lần nhỏ.'}
            }
        }
    };return @($files | Sort-Object Path)
}
function Assert-FullHardware($Feature) {
    if ($FullSimulation -or $Feature.Id -cne 'WPFToggleS3Sleep') {return}
    if (-not ('WinTunePowerCapabilities' -as [type])) {Add-Type @'
using System; using System.Runtime.InteropServices;
public static class WinTunePowerCapabilities {
 [DllImport("powrprof.dll", SetLastError=true)] [return: MarshalAs(UnmanagedType.U1)] static extern bool GetPwrCapabilities(IntPtr data);
 public static bool Supported(int offset) { IntPtr p=Marshal.AllocHGlobal(256);try { for(int i=0;i<256;i++)Marshal.WriteByte(p,i,0); if(!GetPwrCapabilities(p))throw new System.ComponentModel.Win32Exception(); return Marshal.ReadByte(p,offset)!=0; }finally {Marshal.FreeHGlobal(p);} }
}
'@}
    if (-not [WinTunePowerCapabilities]::Supported(5)) {throw 'Windows/firmware hiện không báo hỗ trợ kiểu ngủ này; chưa áp dụng. Thay registry không bổ sung được phần cứng.'}
}
function Read-FullNative($Feature,$Parameters) {
    switch ($Feature.Handler) {
        'Hibernate' {$c=[pscustomobject]@{Hive='HKLM';Path='SYSTEM\CurrentControlSet\Control\Power';Name='HibernateEnabled';Type='DWord'};$v=Read-FullRegistry $c;return [pscustomobject]@{Enabled=($v.Exists -and [int]$v.Value -ne 0)}}
        'Widgets' {return [pscustomobject]@{Apps=@(Get-FullApps @('Microsoft.StartExperiencesApp','Microsoft.WidgetsPlatformRuntime','MicrosoftWindows.Client.WebExperience'))}}
        'Copilot' {return [pscustomobject]@{Apps=@(Get-FullApps @('Microsoft.Copilot'))}}
        'Optional' {return Get-FullOptionalState $Feature}
        'StartPins' {return Get-FullStartPins $Feature}
        'Telemetry' {return Get-FullTelemetryState}
        {$_ -in @('StoreAcl','RazerAcl','LogitechAcl')} {return Read-FullAcl $Feature.Handler}
        'Services' {return [pscustomobject]@{Marker='ServicesConfigured'}}
        'DiskCleanup' {return [pscustomobject]@{Marker='DiskCleanupInteractive'}}
        'Temp' {$files=@(Get-FullTempInventory);return [pscustomobject]@{Files=$files;SkippedDirectories=$script:FullTempReadErrors}}
        {$_ -in @('Edge','OneDrive')} {return [pscustomobject]@{Installed=(Get-FullInstalledDesktop $Feature.Handler)}}
        'BitLocker' {if ($Parameters.MountPoint -notmatch '^[A-Z]:$') {throw 'Chọn đúng ổ đĩa cần giải mã.'};$b=Get-BitLockerVolume -MountPoint $Parameters.MountPoint -ErrorAction Stop;return [pscustomobject]@{MountPoint=$b.MountPoint;Status=[string]$b.VolumeStatus}}
        'ReservedStorage' {$text=Invoke-FullExe (Get-FullSystemExe 'dism.exe') @('/Online','/Get-ReservedStorageState','/English');if ($text -notmatch '(?im)(?:State|storage)\s*:\s*(Enabled|Disabled)') {throw 'Không đọc được trạng thái dung lượng dự trữ.'};return [pscustomobject]@{Enabled=($Matches[1] -eq 'Enabled')}}
        'WindowsAI' {$recall=Get-WindowsOptionalFeature -Online -FeatureName Recall -ErrorAction SilentlyContinue;return [pscustomobject]@{Apps=@(Get-FullApps @('Microsoft.Copilot','MicrosoftWindows.Client.CoreAI','Microsoft.MicrosoftOfficeHub'));Recall=$(if ($recall) {[string]$recall.State} else {'Absent'})}}
        'AdobeHosts' {$path=Join-Path $env:WINDIR 'System32\drivers\etc\hosts';Assert-FullPath $path;if ((Get-Item -LiteralPath $path).Length -gt 4MB) {throw 'Tệp hosts lớn hơn 4 MB; chưa thay đổi để tránh sao lưu không đầy đủ.'};return [pscustomobject]@{Bytes=[Convert]::ToBase64String([IO.File]::ReadAllBytes($path))}}
        'FolderDiscovery' {$base='Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\';return [pscustomobject]@{Bags=(Get-FullTree ($base+'Bags'));BagMRU=(Get-FullTree ($base+'BagMRU'))}}
        'OOSU' {return [pscustomobject]@{External='Không theo dõi thay đổi bên trong công cụ O&O'}}
        'Dns' {return Get-FullDnsState $Parameters}
        {$_ -in @('UltimateAdd','UltimateRemove')} {$owned=Get-FullOwnedPlan;$listing=Invoke-FullExe (Get-FullSystemExe 'powercfg.exe') @('/list');$active=Invoke-FullExe (Get-FullSystemExe 'powercfg.exe') @('/getactivescheme');$guid=[regex]::Match($active,'[a-fA-F0-9]{8}-(?:[a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}').Value;return [pscustomobject]@{Guid=$owned.Guid;Previous=$owned.Previous;Exists=([bool]$owned.Guid -and $listing.Contains($owned.Guid));Active=$guid}}
        default {throw 'Thiếu handler đọc trạng thái.'}
    }
}
function Get-FullNativeTarget($Feature,$Parameters,$Before) {
    if ($FullSimulation) {return [pscustomobject]@{Handler=$Feature.Handler;Simulated=$true}}
    switch ($Feature.Handler) {
        'Optional' {return Get-FullOptionalTarget $Feature $Before}
        'StartPins' {return Get-FullStartTarget $Before}
        'Telemetry' {return Get-FullTelemetryTarget $Before}
        'Hibernate' {return [pscustomobject]@{Enabled=$false}}
        'Temp' {return $Before}
        {$_ -in @('StoreAcl','RazerAcl','LogitechAcl')} {
            $path=Get-FullAclPath $Feature.Handler
            if (-not $Before.Exists -and $Feature.Handler -eq 'StoreAcl') {throw 'Tệp gợi ý Store chưa có; không tạo tệp giả.'}
            $acl=if ($Before.Exists) {Get-Acl -LiteralPath $path} else {New-Object Security.AccessControl.DirectorySecurity}
            # Block database content access while keeping READ_CONTROL/WRITE_DAC available for verified undo.
            $rights=if ($Feature.Handler -eq 'StoreAcl') {[Security.AccessControl.FileSystemRights]([int][Security.AccessControl.FileSystemRights]::ReadData -bor [int][Security.AccessControl.FileSystemRights]::WriteData -bor [int][Security.AccessControl.FileSystemRights]::AppendData)} else {[Security.AccessControl.FileSystemRights]::Write}
            $rule=New-Object Security.AccessControl.FileSystemAccessRule ((New-Object Security.Principal.SecurityIdentifier 'S-1-1-0'),$rights,[Security.AccessControl.AccessControlType]::Deny)
            $acl.AddAccessRule($rule);return [pscustomobject]@{Exists=$true;Sddl=$acl.Sddl}
        }
        'AdobeHosts' {
            $file=Join-Path $PSScriptRoot 'sources\full-tweaks\adobe-domains.txt'
            if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -cne 'DCA4B8D424A8FCDE0C0A4CFB2F7ABB1B1A0389898A3E64FDBA3A9A9407D9F78D') {throw 'Danh sách Adobe khác bản đã kiểm tra.'}
            $domains=@(Get-Content -LiteralPath $file -Encoding UTF8 | Where-Object {$_ -and -not $_.StartsWith('#')})
            if (@($domains | Where-Object {$_ -notmatch '^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$'}).Count) {throw 'Tên miền không hợp lệ.'}
            $bytes=[Convert]::FromBase64String($Before.Bytes)
            if ([Text.Encoding]::ASCII.GetString($bytes).Contains('# WinTuneVI Adobe BEGIN')) {throw 'Đã có danh sách WinTune; dùng hoàn tác trước nếu muốn làm lại.'}
            $append=[Text.Encoding]::ASCII.GetBytes("`r`n# WinTuneVI Adobe BEGIN`r`n"+(($domains | ForEach-Object {'0.0.0.0 '+$_}) -join "`r`n")+"`r`n# WinTuneVI Adobe END`r`n")
            return [pscustomobject]@{Bytes=[Convert]::ToBase64String([byte[]]($bytes+$append))}
        }
        default {return [pscustomobject]@{Handler=$Feature.Handler;Requested=$true}}
    }
}
function Write-FullNative($Feature,$Parameters,$State,[bool]$Undo) {
    switch ($Feature.Handler) {
        'Copilot' {foreach ($app in @(Get-FullApps @('Microsoft.Copilot'))) {if ($app.NonRemovable) {throw 'Gói Copilot được Windows bảo vệ; không gỡ cưỡng bức.'};Remove-AppxPackage -Package $app.FullName -ErrorAction Stop}}
        'Optional' {Set-FullOptionalState $Feature $State $Undo}
        'StartPins' {Set-FullStartPins $Feature $State}
        'Telemetry' {Set-FullTelemetryState $State}
        'Hibernate' {$null=Invoke-FullExe (Get-FullSystemExe 'powercfg.exe') @('/hibernate',$(if ($State.Enabled) {'on'} else {'off'}))}
        'Services' {return}
        'DiskCleanup' {
            $path=Get-FullSystemExe 'cleanmgr.exe';if (-not (Test-Path -LiteralPath $path)) {throw 'Windows không có Disk Cleanup trên máy này.'}
            $p=Start-Process -FilePath $path -ArgumentList @('/d',$env:SystemDrive.TrimEnd(':')) -WindowStyle Normal -PassThru;$p.WaitForExit();if ($p.ExitCode -ne 0) {throw 'Disk Cleanup báo lỗi.'}
            if ($Parameters.PSObject.Properties['ComponentCleanup'] -and $Parameters.ComponentCleanup) {$null=Invoke-FullExe (Get-FullSystemExe 'dism.exe') @('/Online','/Cleanup-Image','/StartComponentCleanup','/NoRestart','/English')}
        }
        'Temp' {
            # Use the existing handle-based deletion code; it verifies final path, size and modification time.
            . "$PSScriptRoot/Tools.Core.ps1";Initialize-Tools (Join-Path $FullRoot 'temp-safety') $false $FullUser
            $allowedRoots=@([IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Temp')),[IO.Path]::GetFullPath((Join-Path $env:WINDIR 'Temp')))
            foreach ($file in $State.Files) {if ($file.Root -cnotin $allowedRoots -or -not ([IO.Path]::GetFullPath($file.Path)).StartsWith($file.Root+'\',[StringComparison]::OrdinalIgnoreCase) -or [long]$file.Ticks -gt [DateTime]::UtcNow.AddDays(-7).Ticks) {throw 'Đường dẫn/tệp tạm nằm ngoài phạm vi đã quét.'};Assert-FullPath $file.Path;try {Remove-TempHandle $file.Path ([long]$file.Length) ([long]$file.Ticks) $file.Root} catch {throw ('Không xóa được một số tệp (có thể đang dùng): '+$_.Exception.Message)}}
        }
        {$_ -in @('StoreAcl','RazerAcl','LogitechAcl')} {
            $path=Get-FullAclPath $Feature.Handler;Assert-FullPath $path
            if (-not $State.Exists) {
                if (Test-Path -LiteralPath $path) {$acl=Get-Acl -LiteralPath $path;$sid=New-Object Security.Principal.SecurityIdentifier 'S-1-1-0';foreach ($rule in @($acl.Access)) {if ($rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -eq $sid.Value -and $rule.AccessControlType -eq 'Deny') {$null=$acl.RemoveAccessRuleSpecific($rule)}};Set-Acl -LiteralPath $path -AclObject $acl; if (@(Get-ChildItem -LiteralPath $path -Force).Count -eq 0) {[IO.Directory]::Delete($path,$false)}}
                return
            }
            if (-not (Test-Path -LiteralPath $path)) {$null=New-Item -ItemType Directory -Path $path}
            $acl=Get-Acl -LiteralPath $path;$acl.SetSecurityDescriptorSddlForm($State.Sddl);Set-Acl -LiteralPath $path -AclObject $acl -ErrorAction Stop
        }
        'Widgets' {foreach ($app in @(Get-FullApps @('Microsoft.StartExperiencesApp','Microsoft.WidgetsPlatformRuntime','MicrosoftWindows.Client.WebExperience'))) {if ($app.NonRemovable) {throw ('Windows không cho gỡ: '+$app.Name)};Remove-AppxPackage -Package $app.FullName -ErrorAction Stop}}
        {$_ -in @('Edge','OneDrive')} {
            if (Get-Process -Name $(if ($Feature.Handler -eq 'Edge') {'msedge'} else {'OneDrive'}) -ErrorAction SilentlyContinue) {throw 'Đóng ứng dụng và lưu dữ liệu trước khi gỡ; WinTune không ép kết thúc.'}
            $path=Get-FullUninstaller $Feature.Handler;if (-not $path) {throw 'Không tìm được trình gỡ chính thức.'};Assert-FullMicrosoftSignature $path
            $args=if ($Feature.Handler -eq 'Edge') {@('--uninstall','--system-level')} else {@('/uninstall')};$null=Invoke-FullExe $path $args
        }
        'BitLocker' {Disable-BitLocker -MountPoint $Parameters.MountPoint -Confirm:$false -ErrorAction Stop | Out-Null}
        'ReservedStorage' {$null=Invoke-FullExe (Get-FullSystemExe 'dism.exe') @('/Online','/Set-ReservedStorageState',('/State:'+$(if ($State.PSObject.Properties['Enabled'] -and $State.Enabled) {'Enabled'} else {'Disabled'})),'/English')}
        'WindowsAI' {
            foreach ($app in @(Get-FullApps @('Microsoft.Copilot','MicrosoftWindows.Client.CoreAI','Microsoft.MicrosoftOfficeHub'))) {if ($app.NonRemovable) {throw ('Windows bảo vệ gói '+$app.Name+'; không ép gỡ. Các bước trước có thể đã thực hiện.')};Remove-AppxPackage -Package $app.FullName -ErrorAction Stop}
            $recall=Get-WindowsOptionalFeature -Online -FeatureName Recall -ErrorAction SilentlyContinue;if ($recall -and $recall.State -eq 'Enabled') {Disable-WindowsOptionalFeature -Online -FeatureName Recall -NoRestart -ErrorAction Stop | Out-Null}
        }
        'AdobeHosts' {$path=Join-Path $env:WINDIR 'System32\drivers\etc\hosts';Assert-FullPath $path;[IO.File]::WriteAllBytes($path,[Convert]::FromBase64String($State.Bytes));$null=Invoke-FullExe (Get-FullSystemExe 'ipconfig.exe') @('/flushdns')}
        'FolderDiscovery' {
            $base='Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\'
            if ($Undo) {Set-FullTree ($base+'Bags') $State.Bags;Set-FullTree ($base+'BagMRU') $State.BagMRU}
            else {[Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($base+'Bags',$false);[Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($base+'BagMRU',$false);Set-FullRegistry ([pscustomobject]@{Hive='HKCU';Path=($base+'Bags\AllFolders\Shell');Name='FolderType'}) ([pscustomobject]@{Exists=$true;Type='String';Value='NotSpecified'})}
        }
        'OOSU' {
            $path=[IO.Path]::GetFullPath([string]$Parameters.Executable);Assert-FullPath $path;$sig=Get-AuthenticodeSignature -LiteralPath $path
            if ($sig.Status -ne 'Valid' -or $null -eq $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch '(?:^|,\s*)O=O&O Software GmbH(?:,|$)') {throw 'Tệp chưa có chữ ký O&O hợp lệ. Tải từ trang chính thức rồi chọn lại.'}
            $p=Start-Process -FilePath $path -PassThru -WindowStyle Normal;$p.WaitForExit();if ($p.ExitCode -ne 0) {throw 'Công cụ O&O kết thúc với lỗi.'}
        }
        'Dns' {
            $current=Get-FullDnsState $Parameters
            if ($Undo) {if ($current.Guid -cne $State.Guid) {throw 'Card mạng đã thay đổi.'};if (-not $State.Manual) {Set-DnsClientServerAddress -InterfaceIndex $State.Index -ResetServerAddresses -ErrorAction Stop} else {Set-DnsClientServerAddress -InterfaceIndex $State.Index -ServerAddresses @($State.Servers) -ErrorAction Stop}}
            else {
                $provider=@(Get-FullDnsProviders | Where-Object Id -CEQ $Parameters.Provider);if ($provider.Count -ne 1) {throw 'Chọn nhà cung cấp DNS trong danh sách.'}
                if ($provider[0].Id -eq 'fastest') {$times=@();foreach ($candidate in @(Get-FullDnsProviders | Where-Object {$_.Id -in @('google','cloudflare','quad9','opendns')})) {$watch=[Diagnostics.Stopwatch]::StartNew();try {Resolve-DnsName -Name 'www.microsoft.com' -Server $candidate.Servers[0] -Type A -DnsOnly -QuickTimeout -ErrorAction Stop | Out-Null;$times+=[pscustomobject]@{Item=$candidate;Ms=$watch.ElapsedMilliseconds}} catch {} finally {$watch.Stop()}};if (-not $times.Count) {throw 'Không đo được DNS; chưa đổi.'};$provider=@(($times | Sort-Object Ms | Select-Object -First 1).Item)}
                if ($provider[0].Id -eq 'dhcp') {Set-DnsClientServerAddress -InterfaceIndex $current.Index -ResetServerAddresses -ErrorAction Stop} else {Set-DnsClientServerAddress -InterfaceIndex $current.Index -ServerAddresses $provider[0].Servers -ErrorAction Stop}
            }
        }
        'UltimateAdd' {
            if ($Undo) {$current=Get-FullOwnedPlan;if (-not $current.Guid) {return};$null=Invoke-FullExe (Get-FullSystemExe 'powercfg.exe') @('/setactive',$State.Active);$null=Invoke-FullExe (Get-FullSystemExe 'powercfg.exe') @('/delete',$current.Guid);Write-FullData ([pscustomobject]@{Guid=$State.Guid;Previous=$State.Previous}) (Join-Path $FullRoot 'owned-plan.dat')}
            else {$old=Read-FullNative $Feature $Parameters;if ($old.Exists) {throw 'Đã có plan do WinTune tạo; không tạo lặp.'};$guid=[guid]::NewGuid().ToString('D');Write-FullData ([pscustomobject]@{Guid=$guid;Previous=$old.Active}) (Join-Path $FullRoot 'owned-plan.dat');$null=Invoke-FullExe (Get-FullSystemExe 'powercfg.exe') @('/duplicatescheme','e9a42b02-d5df-448d-aa00-03f14749eb61',$guid);$null=Invoke-FullExe (Get-FullSystemExe 'powercfg.exe') @('/setactive',$guid)}
        }
        'UltimateRemove' {$owned=Get-FullOwnedPlan;if (-not $owned.Guid -or $owned.Guid -notmatch '^[0-9a-f-]{36}$' -or $owned.Previous -notmatch '^[0-9a-f-]{36}$') {throw 'Không có plan do WinTune tạo để xóa.'};$null=Invoke-FullExe (Get-FullSystemExe 'powercfg.exe') @('/setactive',$owned.Previous);$null=Invoke-FullExe (Get-FullSystemExe 'powercfg.exe') @('/delete',$owned.Guid);Write-FullData ([pscustomobject]@{Guid='';Previous=''}) (Join-Path $FullRoot 'owned-plan.dat')}
        default {throw 'Chưa đăng ký thao tác Windows này.'}
    }
}
function Assert-FullNativeResult($Feature,$Parameters,$Before,$After,$Expected) {
    $ok=switch ($Feature.Handler) {
        'Hibernate' {-not $After.Enabled}
        'Temp' {$After.Files.Count -eq 0 -and $After.SkippedDirectories -eq 0}
        {$_ -in @('Widgets','Copilot')} {$After.Apps.Count -eq 0}
        'Optional' {Test-FullOptionalResult $After $Expected}
        {$_ -in @('StartPins','Telemetry')} {Test-FullSame $After $Expected}
        {$_ -in @('Edge','OneDrive')} {-not $After.Installed}
        'BitLocker' {$After.Status -in @('FullyDecrypted','DecryptionInProgress')}
        'ReservedStorage' {-not $After.Enabled}
        'WindowsAI' {$After.Apps.Count -eq 0 -and $After.Recall -notin @('Enabled','EnablePending')}
        'FolderDiscovery' {$c=[pscustomobject]@{Hive='HKCU';Path='Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell';Name='FolderType';Type='String'};(Read-FullRegistry $c).Value -ceq 'NotSpecified'}
        'Dns' {
            $provider=@(Get-FullDnsProviders | Where-Object Id -CEQ $Parameters.Provider)
            if ($After.Guid -cne $Before.Guid -or $provider.Count -ne 1) {$false}
            elseif ($Parameters.Provider -eq 'dhcp') {-not $After.Manual}
            elseif ($Parameters.Provider -eq 'fastest') {$After.Manual -and @((Get-FullDnsProviders | Where-Object {$_.Id -in @('google','cloudflare','quad9','opendns')}) | Where-Object {($_.Servers -join ',') -ceq ($After.Servers -join ',')}).Count -eq 1}
            else {$After.Manual -and ($provider[0].Servers -join ',') -ceq ($After.Servers -join ',')}
        }
        'UltimateAdd' {$After.Exists -and $After.Active -ceq $After.Guid}
        'UltimateRemove' {-not $After.Exists -and -not $After.Guid}
        {$_ -in @('StoreAcl','RazerAcl','LogitechAcl')} {
            $path=Get-FullAclPath $Feature.Handler;$acl=Get-Acl -LiteralPath $path
            @($acl.Access | Where-Object {$_.AccessControlType -eq 'Deny' -and $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -eq 'S-1-1-0'}).Count -gt 0
        }
        'AdobeHosts' {Test-FullSame $After $Expected}
        default {$true}
    }
    if (-not $ok) {throw 'Windows chưa đạt trạng thái yêu cầu; không báo là đã hoàn tất.'}
}
. "$PSScriptRoot/FullTweaks.Debloat.ps1"
