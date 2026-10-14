#Requires -Version 5.1
# Stable per-user command. Fixed modes, no evaluation of pointer/arguments as code.
param([string]$Mode='',[string]$Extra='')
$ErrorActionPreference='Stop'
try {
    if ($Extra) {throw 'Dùng wintune, wintune demo, wintune update hoặc wintune help.'}
    if (-not $Mode) {$Mode='app'}
    $mode=$Mode.ToLowerInvariant()
    if ($mode -notin @('app','demo','update','probe','resolve','help')) {throw 'Tham số không được hỗ trợ.'}
    if ($mode -eq 'help') {Write-Output 'wintune: mở app; wintune demo: mô phỏng; wintune update: trang cập nhật';exit 0}
    $install=[IO.Directory]::GetParent($PSScriptRoot).FullName
    $apps=[IO.Path]::GetFullPath((Join-Path $install 'apps')).TrimEnd('\')+'\'
    $root=[IO.Path]::GetFullPath((Get-Content -LiteralPath (Join-Path $install 'current.txt') -Raw -Encoding UTF8).Trim())
    if (-not $root.StartsWith($apps,[StringComparison]::OrdinalIgnoreCase)) {throw 'Đích mở nằm ngoài thư mục ứng dụng WinTune.'}
    for ($cursor=$root;$cursor;$cursor=[IO.Path]::GetDirectoryName($cursor)) {
        if ((Test-Path -LiteralPath $cursor) -and (([IO.File]::GetAttributes($cursor) -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {throw 'Không mở qua junction/symlink.'}
    }
    # Verify the local immutable file inventory before loading any app module.
    $seen=@{}
    foreach ($line in Get-Content (Join-Path $root 'SHA256.txt') -Encoding UTF8) {
        if ($line -notmatch '^([0-9A-F]{64})  (.+)$') {throw 'Bảng checksum không hợp lệ.'}
        $expected=$Matches[1];$name=$Matches[2].Replace('\','/')
        if ($name -match '^/|[\x00-\x1f:]' -or @($name.Split('/')|Where-Object {$_ -in @('','..','.')}).Count -or $seen.ContainsKey($name)) {throw 'Đường dẫn checksum không hợp lệ hoặc trùng tên.'}
        $file=[IO.Path]::GetFullPath((Join-Path $root $name))
        if (-not $file.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Checksum có đích ngoài gói.'}
        $seen[$name]=$true
        $mutable=$name -in @('startup-error.log','launcher-error.log') -or $name -match '^(simulation-data|\.test-runs)/|^evidence/.+\.(log|png|json)$'
        if (-not $mutable -and (Get-FileHash -LiteralPath $file).Hash -cne $expected) {throw ('Tệp thiếu hoặc đã thay đổi: '+$name)}
    }
    foreach ($required in @('Core.ps1','WinTune.ps1','Distribution.Core.ps1','version.json')) {if (-not $seen.ContainsKey($required)) {throw ('Gói thiếu: '+$required)}}
    . (Join-Path $root 'Distribution.Core.ps1')
    Test-PortableIntegrity $root (Get-WinTuneVersion $root).Version
    if ($mode -eq 'resolve') {Write-Output $root;exit 0}
    $entry=Join-Path $root 'WinTune.ps1'
    if ($entry.Contains('"')) {throw 'Đường dẫn không hợp lệ.'}
    $hostExe=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments='-NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$entry+'"'+$(switch ($mode) {'demo' {' -Simulation'} 'update' {' -Updates'} 'probe' {' -GuiProbe'} default {''}})
    if ($mode -eq 'probe') {$process=Start-Process -FilePath $hostExe -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -Wait -PassThru;exit $process.ExitCode}
    Start-Process -FilePath $hostExe -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden
} catch {Write-Error ('Không mở được WinTune. '+$_.Exception.Message);exit 1}
