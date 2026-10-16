#Requires -Version 5.1
#Requires -PSEdition Desktop
param([Parameter(Mandatory=$true)][string]$RequestPath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Security
. "$PSScriptRoot/FullTweaks.Core.ps1"
. "$PSScriptRoot/FullTweaks.Native.ps1"
$root=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($RequestPath))
$build=[int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild
Initialize-FullTweaks $root $false $build
try {
    $r=Read-FullData $RequestPath
    if ($r.Version -ne 1 -or $r.User -cne $FullUser -or $r.Operation -cnotin @('Preview','Apply','Undo','Installed','Adapters') -or $r.Simulation -isnot [bool] -or $r.Confirmed -isnot [bool]) {throw 'Yêu cầu không hợp lệ.'}
    $script:FullSimulation=$r.Simulation
    $simulationPath=Join-Path $FullRoot 'simulation.dat'
    if ($FullSimulation -and (Test-Path -LiteralPath $simulationPath)) {$saved=Read-FullData $simulationPath;foreach ($p in $saved.PSObject.Properties) {$script:FullMemory[$p.Name]=$p.Value}}
    $lock=Enter-FullOperationLock
    try {
        $result=switch ($r.Operation) {
            'Preview' {@(New-FullPlan @($r.Ids) $r.Parameters)}
            'Installed' {@(Get-FullAppliedSelections)}
            'Adapters' {if ($FullSimulation) {[pscustomobject]@{Name='Card mạng mô phỏng';Index=12}} else {@(Get-NetAdapter -ErrorAction Stop | Where-Object Status -eq Up | ForEach-Object {[pscustomobject]@{Name=$_.Name;Index=$_.InterfaceIndex}})}}
            'Apply' {Invoke-FullPlan @($r.Rows) ([bool]$r.Confirmed)}
            'Undo' {Undo-FullSelection @($r.Ids) ([bool]$r.Confirmed)}
        }
        $message=switch ($r.Operation) {'Preview' {'Đã chuẩn bị xem trước. Chưa thay đổi Windows.'} 'Installed' {'Đã đọc các giá trị đang khớp. Chưa thay đổi Windows.'} 'Adapters' {'Đã đọc danh sách card mạng.'} 'Undo' {'Đã xử lý yêu cầu hoàn tác; xem ghi chú nếu có mục cần tự khôi phục.'} default {'Tác vụ đã kết thúc; xem kết quả trong Lịch sử. Một số thiết lập cần đăng xuất hoặc khởi động lại.'}}
        Write-FullData ([pscustomobject]@{Ok=$true;Operation=$r.Operation;Result=@($result);Message=$message}) ($RequestPath+'.result')
    } finally {try {if ($FullSimulation) {Write-FullData $FullMemory $simulationPath}} finally {Exit-FullOperationLock $lock}}
} catch {Write-FullData ([pscustomobject]@{Ok=$false;Operation='';Result=@();Message=$_.Exception.Message}) ($RequestPath+'.result');exit 1}
