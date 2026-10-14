# Registered source entry; native PATH writers remain behind explicit confirmation.
function Assert-SourceCommandReceipt($Journal,[string]$Root,[string[]]$Statuses) {
    $folder=Join-Path $Root 'command'
    if ($Journal.Schema -ne 2 -or $Journal.User -ne (Get-CommandRegistrationUser) -or $Journal.Status -notin $Statuses -or $Journal.Folder -ine $folder -or $Journal.Target -ine (Join-Path $folder 'wintune.cmd')) {throw 'Receipt không thuộc đăng ký PowerShell của tài khoản này.'}
}
function Set-OwnedSourceCommandFile([string]$Source,[string]$Target,[string]$PreviousHash='') {
    $hash=(Get-FileHash -LiteralPath $Source).Hash
    if (Test-Path -LiteralPath $Target) {
        $current=(Get-FileHash -LiteralPath $Target).Hash
        if ($current -ceq $hash) {return}
        if (-not $PreviousHash -or $current -cne $PreviousHash) {throw 'File lệnh đã thay đổi bên ngoài; không ghi đè.'}
        $temp=$Target+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
        [IO.File]::Copy($Source,$temp,$false);[IO.File]::Replace($temp,$Target,$Target+'.previous')
    } else {[IO.File]::Copy($Source,$Target,$false)}
}
function Complete-WinTuneCommandRegistration([string]$Package,[string]$Root,[bool]$Confirmed) {
    if (-not $Confirmed) {throw 'Chưa xác nhận đăng ký lệnh.'}
    $root=Assert-DistributionPath $Root $Root;$folder=Assert-DistributionPath (Join-Path $root 'command') $root;$target=Join-Path $folder 'wintune.cmd';$router=Join-Path $folder 'CommandRouter.ps1'
    $before=Get-UserCommandRegistration
    if ($before.AppExists) {throw 'Có App Paths wintune.exe đang đăng ký. Bỏ đăng ký kiểu cũ của WinTune trước; không sửa mục của chương trình khác.'}
    $plan=Get-CommandPathPlan $before $folder $target;$receipt=Join-Path $root 'command-registration.json';$existing=$null
    if (Test-Path -LiteralPath $receipt) {
        $existing=Get-Content -LiteralPath $receipt -Raw -Encoding UTF8|ConvertFrom-Json
        if ($existing.User -ne (Get-CommandRegistrationUser) -or $existing.Status -notin @('Registered','Removed','RolledBack')) {throw 'Có đợt đăng ký chưa hoàn tất hoặc khác tài khoản; giữ receipt.'}
        if ($existing.Schema -eq 1 -and $existing.Status -eq 'Registered') {throw 'Bỏ đăng ký lệnh kiểu EXE cũ trước khi chuyển sang PowerShell.'}
        if ($existing.Schema -eq 2) {Assert-SourceCommandReceipt $existing $root @('Registered','Removed','RolledBack')}
    }
    Test-PortableIntegrity $Package (Get-WinTuneVersion $Package).Version
    $source=Join-Path $Package 'Wintune.Registered.cmd';$sourceRouter=Join-Path $Package 'CommandRouter.ps1'
    $sourceHash=(Get-FileHash $source).Hash;$routerHash=(Get-FileHash $sourceRouter).Hash
    if ($null -ne $existing -and $existing.Schema -eq 2 -and $existing.Status -eq 'Registered' -and -not $plan.Added -and (Test-Path $target) -and (Test-Path $router) -and (Get-FileHash $target).Hash -ceq $sourceHash -and (Get-FileHash $router).Hash -ceq $routerHash) {return [pscustomobject]@{Status='NoOp';Message='Lệnh wintune đã được đăng ký cho tài khoản này.'}}
    $null=New-Item -ItemType Directory -Path $folder -Force
    $oldCmd='';$oldRouter=''
    if ($null -ne $existing -and $existing.Schema -eq 2) {$oldCmd=$existing.ResolverSHA256;$oldRouter=$existing.RouterSHA256}
    Set-OwnedSourceCommandFile $source $target $oldCmd
    Set-OwnedSourceCommandFile $sourceRouter $router $oldRouter
    $j=[pscustomobject]@{Schema=2;User=(Get-CommandRegistrationUser);Created=(Get-Date).ToString('o');Status='Pending';AddedPath=$plan.Added;CreatedApp=$false;Before=$before;After=$plan.After;Folder=$folder;Target=$target;ResolverSHA256=$sourceHash;RouterSHA256=$routerHash}
    $wasRegistered=$null -ne $existing -and $existing.Schema -eq 2 -and $existing.Status -eq 'Registered'
    Write-DistributionAtomic $receipt ($j|ConvertTo-Json -Depth 5)
    try {
        $now=Get-UserCommandRegistration
        if ($now.Path -cne $before.Path -or $now.AppExists) {throw 'PATH/App Paths đổi sau xem trước; không ghi.'}
        if ($plan.Added) {Set-UserCommandPath $plan.After $before.PathKind}
        $check=Get-UserCommandRegistration
        if ($check.Path -cne $plan.After -or $check.AppExists) {throw 'Không xác minh được đăng ký User PATH.'}
        if ($wasRegistered) {$j.Before=$existing.Before;$j.AddedPath=$existing.AddedPath}
        $j.Status='Registered';Write-DistributionAtomic $receipt ($j|ConvertTo-Json -Depth 5);Notify-UserCommandEnvironment
        return [pscustomobject]@{Status='Registered';Message='Đã đăng ký wintune.cmd theo tài khoản. Mở lại CMD/PowerShell; Win + R dùng đường tìm kiếm của Windows. Không cần resolver EXE, không đổi Machine PATH.'}
    } catch {
        $reason=$_.Exception.Message
        try {
            $now=Get-UserCommandRegistration
            if ($plan.Added -and $now.Path -ceq $plan.After) {Set-UserCommandPath $before.Path $before.PathKind $before.PathExists}
            if ((Get-UserCommandRegistration).Path -ceq $before.Path) {
                if ($wasRegistered) {$j.Before=$existing.Before;$j.AddedPath=$existing.AddedPath;$j.Status='Registered'} else {$j.Status='RolledBack'}
            }
        } catch {$reason+='; không hoàn tất phục hồi PATH: '+$_.Exception.Message}
        Write-DistributionAtomic $receipt ($j|ConvertTo-Json -Depth 5);throw $reason
    }
}
function Complete-WinTuneCommandRemoval([string]$Root,[bool]$Confirmed) {
    if (-not $Confirmed) {throw 'Chưa xác nhận bỏ đăng ký lệnh.'}
    $root=Assert-DistributionPath $Root $Root;$receipt=Join-Path $root 'command-registration.json';$j=Get-Content $receipt -Raw -Encoding UTF8|ConvertFrom-Json
    if ($j.Schema -eq 1) {return Complete-LegacyWinTuneCommandRemoval $root $Confirmed}
    Assert-SourceCommandReceipt $j $root @('Registered')
    $now=Get-UserCommandRegistration;$after=$now.Path
    if ($j.AddedPath) {$after=@($now.Path -split ';'|Where-Object {[Environment]::ExpandEnvironmentVariables($_.Trim().Trim('"')).TrimEnd('\') -ine $j.Folder.TrimEnd('\')}) -join ';'}
    $j|Add-Member -NotePropertyName RemovalBefore -NotePropertyValue $now -Force
    $j|Add-Member -NotePropertyName RemovalAfter -NotePropertyValue $after -Force
    $j.Status='PendingRemoval';Write-DistributionAtomic $receipt ($j|ConvertTo-Json -Depth 5)
    if ($after -cne $now.Path) {Set-UserCommandPath $after $now.PathKind $(if (-not $after -and -not $j.Before.PathExists) {$false} else {$true})}
    $j.Status='Removed';Write-DistributionAtomic $receipt ($j|ConvertTo-Json -Depth 5);Notify-UserCommandEnvironment
    return [pscustomobject]@{Status='Removed';Message='Đã bỏ mục User PATH của WinTune. Giữ ứng dụng, bản cũ, file lệnh và nhật ký; không sửa App Paths.'}
}
function Complete-WinTuneCommandRepair([string]$Root,[bool]$Confirmed) {
    if (-not $Confirmed) {throw 'Chưa xác nhận phục hồi đăng ký.'}
    $root=Assert-DistributionPath $Root $Root;$receipt=Join-Path $root 'command-registration.json';$j=Get-Content $receipt -Raw -Encoding UTF8|ConvertFrom-Json
    if ($j.Schema -eq 1) {return Complete-LegacyWinTuneCommandRepair $root $Confirmed}
    Assert-SourceCommandReceipt $j $root @('Pending','PendingRemoval')
    $now=Get-UserCommandRegistration
    if ($j.Status -eq 'PendingRemoval') {
        if ($now.Path -cne $j.RemovalBefore.Path -and $now.Path -cne $j.RemovalAfter) {throw 'User PATH đã đổi bên ngoài; không tiếp tục.'}
        if ($now.Path -cne $j.RemovalAfter) {Set-UserCommandPath $j.RemovalAfter $j.RemovalBefore.PathKind $(if (-not $j.RemovalAfter -and -not $j.Before.PathExists) {$false} else {$true})}
        if ((Get-UserCommandRegistration).Path -cne $j.RemovalAfter) {throw 'Chưa xác minh được bỏ đăng ký.'}
        $j.Status='Removed'
    } else {
        if ($now.Path -cne $j.Before.Path -and $now.Path -cne $j.After) {throw 'User PATH đã đổi bên ngoài; không ghi đè.'}
        if ($j.AddedPath -and $now.Path -ceq $j.After) {Set-UserCommandPath $j.Before.Path $j.Before.PathKind $j.Before.PathExists}
        if ((Get-UserCommandRegistration).Path -cne $j.Before.Path) {throw 'Chưa xác minh được phục hồi PATH.'}
        $j.Status='RolledBack'
    }
    Write-DistributionAtomic $receipt ($j|ConvertTo-Json -Depth 5);Notify-UserCommandEnvironment
    return [pscustomobject]@{Status=$j.Status;Message='Đã hoàn tất phục hồi đăng ký User PATH có điều kiện. Giữ ứng dụng và nhật ký.'}
}
