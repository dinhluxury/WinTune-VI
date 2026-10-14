# Native registry adapters are only called after explicit registration confirmation.
function Get-WinTuneInstallRoot {return Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'WinTuneVI'}
function Get-CommandRegistrationUser {return [Security.Principal.WindowsIdentity]::GetCurrent().User.Value}
function Get-UserCommandRegistration {
    $envKey=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment',$false)
    $appKey=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\App Paths\wintune.exe',$false)
    try {
        $pathExists=$null -ne $envKey -and 'Path' -in $envKey.GetValueNames()
        return [pscustomobject]@{Path=$(if ($pathExists) {[string]$envKey.GetValue('Path','',[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)} else {''});PathExists=$pathExists;PathKind=$(if ($pathExists) {[string]$envKey.GetValueKind('Path')} else {'ExpandString'});AppExists=($null -ne $appKey);AppTarget=$(if ($null -ne $appKey) {[string]$appKey.GetValue('','')} else {''});AppPath=$(if ($null -ne $appKey) {[string]$appKey.GetValue('Path','')} else {''});AppNames=$(if ($null -ne $appKey) {@($appKey.GetValueNames())} else {@()})}
    } finally {if ($null -ne $envKey) {$envKey.Dispose()};if ($null -ne $appKey) {$appKey.Dispose()}}
}
function Set-UserCommandPath([string]$Value,[string]$Kind,[bool]$Exists=$true) {
    if ($Kind -notin @('String','ExpandString')) {throw 'Kiểu User PATH không hỗ trợ; không ghi.'}
    $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try {if ($Exists) {$key.SetValue('Path',$Value,[Microsoft.Win32.RegistryValueKind]::$Kind)} else {$key.DeleteValue('Path',$false)}} finally {$key.Dispose()}
}
function Set-UserCommandAppPath([string]$Target,[string]$Folder,[bool]$Remove=$false) {
    $name='Software\Microsoft\Windows\CurrentVersion\App Paths\wintune.exe'
    if ($Remove) {[Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($name,$false);return}
    $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($name)
    try {$key.SetValue('',$Target,[Microsoft.Win32.RegistryValueKind]::String);$key.SetValue('Path',$Folder,[Microsoft.Win32.RegistryValueKind]::String)} finally {$key.Dispose()}
}
function Notify-UserCommandEnvironment {
    if (-not ('WinTuneEnvironmentNotify' -as [type])) {Add-Type @'
using System;using System.Runtime.InteropServices;
public static class WinTuneEnvironmentNotify {
 [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr SendMessageTimeout(IntPtr h,uint m,IntPtr w,string l,uint f,uint t,out IntPtr r);
 public static void Refresh(){IntPtr result;SendMessageTimeout(new IntPtr(0xffff),0x001A,IntPtr.Zero,"Environment",2,2000,out result);}
}
'@}
    [WinTuneEnvironmentNotify]::Refresh()
}
function Get-CommandPathPlan($Before,[string]$Folder,[string]$Target) {
    if ($Before.PathKind -notin @('String','ExpandString')) {throw 'User PATH không phải kiểu chuỗi được hỗ trợ.'}
    if ($Before.AppExists -and ($Before.AppTarget -ine $Target -or $Before.AppPath -ine $Folder -or @($Before.AppNames | Where-Object {$_ -notin @('','Path')}).Count)) {throw 'Đã có App Paths wintune.exe khác. Không ghi đè lệnh đang có.'}
    $parts=@($Before.Path -split ';' | Where-Object {$_.Trim()});$found=$false
    foreach ($part in $parts) {if ([Environment]::ExpandEnvironmentVariables($part.Trim().Trim('"')).TrimEnd('\') -ieq $Folder.TrimEnd('\')) {$found=$true}}
    $after=if ($found) {$Before.Path} elseif (-not $Before.Path) {$Folder} else {$Before.Path.TrimEnd(';')+';'+$Folder}
    if ($after.Length -gt 30000) {throw 'User PATH quá dài; không ghi.'}
    return [pscustomobject]@{After=$after;Added=(-not $found);Before=$Before;Folder=$Folder;Target=$Target}
}
function Register-WinTuneCommand([string]$Package,[string]$Root,[bool]$Confirmed) {
    if (-not $Confirmed) {throw 'Chưa xác nhận đăng ký lệnh.'}
    $mutex=Enter-WinTuneDistributionLock $Root
    try {return Complete-WinTuneCommandRegistration $Package $Root $Confirmed} finally {Exit-WinTuneDistributionLock $mutex}
}
function Complete-LegacyWinTuneCommandRegistration([string]$Package,[string]$Root,[bool]$Confirmed) {
    if (-not $Confirmed) {throw 'Chưa xác nhận đăng ký lệnh; không sửa User PATH/App Paths.'}
    $root=Assert-DistributionPath $Root $Root;$folder=Assert-DistributionPath (Join-Path $root 'launcher') $root;$target=Join-Path $folder 'wintune.exe'
    $before=Get-UserCommandRegistration;$plan=Get-CommandPathPlan $before $folder $target
    $receipt=Join-Path $root 'command-registration.json'
    if (Test-Path -LiteralPath $receipt) {
        $existing=Get-Content -LiteralPath $receipt -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($existing.User -ne (Get-CommandRegistrationUser) -or $existing.Status -notin @('Registered','Removed','RolledBack')) {throw 'Có đợt đăng ký chưa hoàn tất hoặc khác tài khoản. Giữ receipt để kiểm tra.'}
        if ($existing.Status -eq 'Registered' -and $before.AppTarget -ieq $target -and -not $plan.Added) {return [pscustomobject]@{Status='NoOp';Message='Lệnh wintune đã được đăng ký cho tài khoản này.'}}
    }
    Test-PortableIntegrity $Package (Get-WinTuneVersion $Package).Version
    $null=New-Item -ItemType Directory -Path $folder -Force
    # Never overwrite a running command binary. This resolver format stays stable.
    $source=Join-Path $Package 'Wintune.Command.exe'
    if (Test-Path -LiteralPath $target) {
        $hash=(Get-FileHash -LiteralPath $target).Hash
        $owned=Test-Path -LiteralPath $receipt
        if ($hash -cne (Get-FileHash -LiteralPath $source).Hash -and (-not $owned -or -not $existing.PSObject.Properties['ResolverSHA256'] -or $hash -cne $existing.ResolverSHA256)) {throw 'Resolver hiện tại khác bản đã xác minh; không ghi đè.'}
    } else {[IO.File]::Copy($source,$target,$false)}
    $j=[pscustomobject]@{Schema=1;User=(Get-CommandRegistrationUser);Created=(Get-Date).ToString('o');Status='Pending';AddedPath=$plan.Added;CreatedApp=(-not $before.AppExists);Before=$before;After=$plan.After;Folder=$folder;Target=$target;ResolverSHA256=(Get-FileHash -LiteralPath $target).Hash}
    Write-DistributionAtomic $receipt ($j | ConvertTo-Json -Depth 5)
    try {
        $now=Get-UserCommandRegistration
        if ($now.Path -cne $before.Path -or $now.AppTarget -cne $before.AppTarget) {throw 'PATH/App Paths đổi sau xem trước; không ghi.'}
        if ($plan.Added) {Set-UserCommandPath $plan.After $before.PathKind}
        if (-not $before.AppExists) {Set-UserCommandAppPath $target $folder}
        $check=Get-UserCommandRegistration
        if ($check.Path -cne $plan.After -or $check.AppTarget -ine $target -or $check.AppPath -ine $folder) {throw 'Không xác minh được lệnh đã đăng ký.'}
        $j.Status='Registered';Write-DistributionAtomic $receipt ($j | ConvertTo-Json -Depth 5);Notify-UserCommandEnvironment
        return [pscustomobject]@{Status='Registered';Message='Đã đăng ký wintune cho tài khoản này. Mở lại CMD/PowerShell; Win + R dùng App Paths. Không thay Machine PATH.'}
    } catch {
        $reason=$_.Exception.Message
        # Roll back only the values we changed and only if nobody changed them again.
        $j.Status='Pending'
        try {
            $now=Get-UserCommandRegistration
            if ($plan.Added -and $now.Path -ceq $plan.After) {Set-UserCommandPath $before.Path $before.PathKind $before.PathExists}
            if (-not $before.AppExists -and $now.AppTarget -ieq $target -and $now.AppPath -ieq $folder) {Set-UserCommandAppPath '' '' $true}
            $restored=Get-UserCommandRegistration
            if ($restored.Path -ceq $before.Path -and $restored.AppExists -eq $before.AppExists -and $restored.AppTarget -ceq $before.AppTarget) {$j.Status='RolledBack'}
        } catch {$reason+='; không hoàn tất phục hồi đăng ký: '+$_.Exception.Message}
        Write-DistributionAtomic $receipt ($j | ConvertTo-Json -Depth 5);throw $reason
    }
}
function Unregister-WinTuneCommand([string]$Root,[bool]$Confirmed) {
    if (-not $Confirmed) {throw 'Chưa xác nhận bỏ đăng ký lệnh.'}
    $mutex=Enter-WinTuneDistributionLock $Root
    try {return Complete-WinTuneCommandRemoval $Root $Confirmed} finally {Exit-WinTuneDistributionLock $mutex}
}
function Complete-LegacyWinTuneCommandRemoval([string]$Root,[bool]$Confirmed) {
    if (-not $Confirmed) {throw 'Chưa xác nhận bỏ đăng ký lệnh.'}
    $root=Assert-DistributionPath $Root $Root;$receipt=Join-Path $root 'command-registration.json';$j=Get-Content -LiteralPath $receipt -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($j.User -ne (Get-CommandRegistrationUser) -or $j.Status -ne 'Registered' -or $j.Folder -ine (Join-Path $root 'launcher') -or $j.Target -ine (Join-Path $root 'launcher/wintune.exe')) {throw 'Receipt không thuộc đăng ký đang hoạt động của tài khoản này.'}
    $now=Get-UserCommandRegistration
    if ($now.AppTarget -ine $j.Target -or $now.AppPath -ine $j.Folder -or @($now.AppNames | Where-Object {$_ -notin @('','Path')}).Count) {throw 'App Paths đã đổi bên ngoài; không xóa.'}
    $after=$now.Path
    if ($j.AddedPath) {
        $parts=@($now.Path -split ';');$kept=@($parts | Where-Object {[Environment]::ExpandEnvironmentVariables($_.Trim().Trim('"')).TrimEnd('\') -ine $j.Folder.TrimEnd('\')})
        $after=$kept -join ';'
    }
    $j | Add-Member -NotePropertyName RemovalBefore -NotePropertyValue $now -Force
    $j | Add-Member -NotePropertyName RemovalAfter -NotePropertyValue $after -Force
    $j.Status='PendingRemoval';Write-DistributionAtomic $receipt ($j | ConvertTo-Json -Depth 5)
    if ($after -cne $now.Path) {Set-UserCommandPath $after $now.PathKind $(if (-not $after -and -not $j.Before.PathExists) {$false} else {$true})}
    if ($j.CreatedApp) {Set-UserCommandAppPath '' '' $true}
    $j.Status='Removed';Write-DistributionAtomic $receipt ($j | ConvertTo-Json -Depth 5);Notify-UserCommandEnvironment
    return [pscustomobject]@{Status='Removed';Message='Đã bỏ đăng ký lệnh. Giữ ứng dụng, bản cũ và mọi nhật ký Windows.'}
}
function Repair-WinTuneCommandRegistration([string]$Root,[bool]$Confirmed) {
    if (-not $Confirmed) {throw 'Chưa xác nhận phục hồi đăng ký.'}
    $mutex=Enter-WinTuneDistributionLock $Root
    try {return Complete-WinTuneCommandRepair $Root $Confirmed} finally {Exit-WinTuneDistributionLock $mutex}
}
function Complete-LegacyWinTuneCommandRepair([string]$Root,[bool]$Confirmed) {
    if (-not $Confirmed) {throw 'Chưa xác nhận phục hồi đăng ký dang dở.'}
    $root=Assert-DistributionPath $Root $Root;$receipt=Join-Path $root 'command-registration.json';$j=Get-Content -LiteralPath $receipt -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($j.Schema -ne 1 -or $j.User -ne (Get-CommandRegistrationUser) -or $j.Status -notin @('Pending','PendingRemoval') -or $j.Folder -ine (Join-Path $root 'launcher') -or $j.Target -ine (Join-Path $root 'launcher/wintune.exe')) {throw 'Không có đăng ký dang dở hợp lệ của tài khoản này.'}
    $now=Get-UserCommandRegistration
    if ($j.Status -eq 'PendingRemoval') {
        if ($now.Path -cne $j.RemovalBefore.Path -and $now.Path -cne $j.RemovalAfter) {throw 'User PATH đã đổi bên ngoài; không tiếp tục bỏ đăng ký.'}
        if ($now.AppExists -and ($now.AppTarget -ine $j.Target -or $now.AppPath -ine $j.Folder -or @($now.AppNames | Where-Object {$_ -notin @('','Path')}).Count)) {throw 'App Paths đã đổi bên ngoài; không xóa.'}
        if ($now.Path -cne $j.RemovalAfter) {Set-UserCommandPath $j.RemovalAfter $j.RemovalBefore.PathKind $(if (-not $j.RemovalAfter -and -not $j.Before.PathExists) {$false} else {$true})}
        if ($j.CreatedApp -and $now.AppExists) {Set-UserCommandAppPath '' '' $true}
        $check=Get-UserCommandRegistration
        if ($check.Path -cne $j.RemovalAfter -or ($j.CreatedApp -and $check.AppExists)) {throw 'Chưa hoàn tất bỏ đăng ký; giữ receipt.'}
        $j.Status='Removed';Write-DistributionAtomic $receipt ($j|ConvertTo-Json -Depth 5);Notify-UserCommandEnvironment
        return [pscustomobject]@{Status='Removed';Message='Đã hoàn tất bỏ đăng ký dang dở. Giữ ứng dụng và nhật ký.'}
    }
    if ($now.Path -cne $j.Before.Path -and $now.Path -cne $j.After) {throw 'User PATH đã đổi bên ngoài; không ghi đè.'}
    if ($now.AppExists -and ($now.AppTarget -ine $j.Target -or $now.AppPath -ine $j.Folder -or @($now.AppNames | Where-Object {$_ -notin @('','Path')}).Count)) {throw 'App Paths đã đổi bên ngoài; không xóa.'}
    if ($j.AddedPath -and $now.Path -ceq $j.After) {Set-UserCommandPath $j.Before.Path $j.Before.PathKind $j.Before.PathExists}
    if ($j.CreatedApp -and $now.AppExists) {Set-UserCommandAppPath '' '' $true}
    $check=Get-UserCommandRegistration
    if ($check.Path -cne $j.Before.Path -or $check.AppExists -ne $j.Before.AppExists) {throw 'Chưa phục hồi được hết; giữ receipt Pending.'}
    $j.Status='RolledBack';Write-DistributionAtomic $receipt ($j|ConvertTo-Json -Depth 5);Notify-UserCommandEnvironment
    return [pscustomobject]@{Status='RolledBack';Message='Đã trả đăng ký về trước đợt lỗi. Có thể đăng ký lại; không xóa ứng dụng hoặc nhật ký.'}
}
