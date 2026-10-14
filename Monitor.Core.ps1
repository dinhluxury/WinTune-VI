#Requires -Version 5.1
# All providers in this module are read-only. No registry/configuration writes.
function Initialize-MonitorNative {
    if (-not ('WinTune.Monitor.Native' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'Monitor.Native.cs') }
}
function Get-MonitorCpuPercent($Before,$After) {
    if ($null -eq $Before -or $null -eq $After) { return $null }
    $kernel=[decimal]$After.Kernel-[decimal]$Before.Kernel
    $user=[decimal]$After.User-[decimal]$Before.User
    $idle=[decimal]$After.Idle-[decimal]$Before.Idle
    if ($kernel -lt 0 -or $user -lt 0 -or $idle -lt 0 -or ($kernel+$user) -le 0 -or $idle -gt ($kernel+$user)) { return $null }
    return [Math]::Round([double](100*($kernel+$user-$idle)/($kernel+$user)),1)
}
function Get-MonitorRate([double]$Before,[double]$After,[double]$Seconds) {
    if ($Seconds -le 0 -or $After -lt $Before) {return $null}
    return ($After-$Before)/$Seconds
}
function Format-MonitorSize($Bytes) {
    if ($null -eq $Bytes) {return 'Chưa đọc được'}
    if ($Bytes -ge 1GB) {return ('{0:N1} GB' -f ($Bytes/1GB))}
    if ($Bytes -ge 1MB) {return ('{0:N0} MB' -f ($Bytes/1MB))}
    if ($Bytes -ge 1KB) {return ('{0:N0} KB' -f ($Bytes/1KB))}
    return ('{0:N0} B' -f $Bytes)
}
function Get-MonitorGpuPercent($Rows,[string]$Luid) {
    if (-not $Luid) {return $null}
    $engines=@{}
    foreach ($r in $Rows) {
        if ($r.Name -notmatch ([regex]::Escape($Luid)+'_phys_\d+_eng_\d+_engtype_')) {continue}
        $key=($r.Name -replace '^pid_\d+_','')
        $value=[double]$r.UtilizationPercentage
        if ($value -lt 0 -or [double]::IsNaN($value) -or [double]::IsInfinity($value)) {continue}
        if (-not $engines.ContainsKey($key)) {$engines[$key]=0.0}
        $engines[$key]+=$value
    }
    if ($engines.Count -eq 0) {return $null}
    # Windows Task Manager represents GPU load with the busiest engine, not the
    # sum of engines running concurrently. Aggregate process counters per engine.
    return [Math]::Round([Math]::Min(100,($engines.Values | Measure-Object -Maximum).Maximum),1)
}
function Get-MonitorHardware {
    Initialize-MonitorNative
    $issues=New-Object 'Collections.Generic.List[string]'
    $cpu=@();$ram=@();$board=@();$os=@();$gpu=@();$disks=@();$health=@()
    foreach ($pair in @(@('cpu','Win32_Processor'),@('ram','Win32_PhysicalMemory'),@('board','Win32_BaseBoard'),@('os','Win32_OperatingSystem'),@('gpu','Win32_VideoController'),@('disks','Win32_LogicalDisk'))) {
        try {
            $rows=@(Get-CimInstance -ClassName $pair[1] -OperationTimeoutSec 4 -ErrorAction Stop)
            if ($pair[0] -eq 'disks') {$rows=@($rows | Where-Object DriveType -eq 3)}
            Set-Variable -Name $pair[0] -Value $rows
        } catch {$issues.Add("$($pair[1]): $($_.Exception.Message)")}
    }
    $adapters=@()
    try {$adapters=@([WinTune.Monitor.Native]::ReadAdapters())} catch {$issues.Add('DXGI: '+$_.Exception.Message)}
    $primary=@($adapters | Sort-Object DedicatedBytes -Descending | Select-Object -First 1)
    $mem=$null;try {$mem=[WinTune.Monitor.Native]::ReadMemory()} catch {$issues.Add('RAM: '+$_.Exception.Message)}
    try { $health=@(Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,Size) } catch { $issues.Add('Trạng thái ổ đĩa: '+$_.Exception.Message) }
    $installed=if ($ram.Count) {($ram | Measure-Object Capacity -Sum).Sum} elseif ($null -ne $mem) {$mem.Total} else {$null}
    [pscustomobject]@{
        CpuName=if ($cpu.Count) {($cpu.Name -join ' / ').Trim()} else {'Chưa đọc được bộ xử lý'}
        Cores=if ($cpu.Count) {($cpu | Measure-Object NumberOfCores -Sum).Sum} else {$null}
        Threads=if ($cpu.Count) {($cpu | Measure-Object NumberOfLogicalProcessors -Sum).Sum} else {$null}
        MaxClockMHz=if ($cpu.Count) {($cpu | Measure-Object MaxClockSpeed -Maximum).Maximum} else {$null}
        InstalledBytes=$installed; Memory=$mem; MemoryModules=@($ram | Select-Object Capacity,ConfiguredClockSpeed,Manufacturer,PartNumber)
        Board=if ($board.Count) {($board | ForEach-Object {($_.Manufacturer+' '+$_.Product).Trim()}) -join ' / '} else {'Chưa đọc được'}
        Windows=if ($os.Count) {$os[0].Caption+' • Build '+$os[0].BuildNumber} else {'Chưa đọc được'}
        GpuName=if ($primary.Count) {$primary[0].Name} elseif ($gpu.Count) {$gpu[0].Name} else {'Chưa đọc được GPU'}
        GpuLuid=if ($primary.Count) {$primary[0].Luid} else {''}
        GpuBytes=if ($primary.Count) {$primary[0].DedicatedBytes} else {$null}
        Adapters=$adapters; VideoControllers=@($gpu | Select-Object Name,DriverVersion)
        Disks=@($disks | Select-Object DeviceID,VolumeName,Size,FreeSpace); DiskHealth=$health
        Issues=@($issues); Timestamp=[DateTime]::UtcNow
    }
}
function Read-MonitorProcesses { [Diagnostics.Process]::GetProcesses() }
function Get-MonitorProcesses {
    # This fast reader is independent of CIM/GPU/storage and never changes a process.
    $rows=New-Object 'Collections.Generic.List[object]';$count=$null;$skipped=0
    $issues=New-Object 'Collections.Generic.List[string]'
    try {
        $all=@(Read-MonitorProcesses);$count=$all.Count
        foreach ($process in $all) {
            try {
                $bytes=$process.WorkingSet64
                if ($null -eq $bytes) {throw 'Windows chưa cung cấp working set của tiến trình.'}
                $rows.Add([pscustomobject]@{Name=$process.ProcessName;Id=$process.Id;Bytes=[double]$bytes})
            }
            catch {$skipped++} # A process may exit or Windows may deny access during enumeration.
            finally {$process.Dispose()}
        }
    } catch {$issues.Add('Không đọc được danh sách tiến trình: '+$_.Exception.Message)}
    if ($skipped) {$issues.Add("Bỏ qua $skipped tiến trình đã thoát hoặc không cho phép đọc RAM.")}
    [pscustomobject]@{Timestamp=[DateTime]::UtcNow;ProcessCount=$count;Processes=@($rows | Sort-Object @{Expression='Bytes';Descending=$true},Id | Select-Object -First 10);Issues=@($issues)}
}
function Get-MonitorSample([string]$GpuLuid='',[switch]$SkipProcesses) {
    Initialize-MonitorNative
    $issues=New-Object 'Collections.Generic.List[string]'
    $times=$null;$memory=$null;$gpu=$null;$diskRead=$null;$diskWrite=$null
    try {$times=[WinTune.Monitor.Native]::ReadTimes()} catch {$issues.Add('CPU: '+$_.Exception.Message)}
    try {$memory=[WinTune.Monitor.Native]::ReadMemory()} catch {$issues.Add('RAM: '+$_.Exception.Message)}
    $cpuTimestamp=[DateTime]::UtcNow
    $network=@{}
    try {
        foreach ($nic in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ($nic.OperationalStatus -ne 'Up' -or $nic.NetworkInterfaceType -eq 'Loopback') {continue}
            $s=$nic.GetIPv4Statistics()
            $network[$nic.Id]=[pscustomobject]@{Received=[double]$s.BytesReceived;Sent=[double]$s.BytesSent}
        }
    } catch {$issues.Add('Mạng: '+$_.Exception.Message)}
    $networkTimestamp=[DateTime]::UtcNow
    $processes=@();$processCount=$null
    if (-not $SkipProcesses) {
        $processSample=Get-MonitorProcesses;$processes=$processSample.Processes;$processCount=$processSample.ProcessCount
        foreach ($issue in $processSample.Issues) {$issues.Add($issue)}
    }
    $volumes=@()
    try {
        $volumes=@(foreach ($drive in [IO.DriveInfo]::GetDrives()) {
            if ($drive.DriveType -ne 'Fixed') {continue}
            try {if ($drive.IsReady) {[pscustomobject]@{DeviceID=$drive.Name.TrimEnd('\');VolumeName=$drive.VolumeLabel;Size=$drive.TotalSize;FreeSpace=$drive.TotalFreeSpace}}} catch {$issues.Add('Ổ '+$drive.Name+': '+$_.Exception.Message)}
        })
    } catch {$issues.Add('Dung lượng ổ: '+$_.Exception.Message)}
    if ($GpuLuid) {
        try {
            $rows=@(Get-CimInstance -ClassName Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -OperationTimeoutSec 3 -ErrorAction Stop)
            $gpu=Get-MonitorGpuPercent $rows $GpuLuid
            if ($null -eq $gpu) {$issues.Add('GPU: chưa có bộ đếm cho GPU đang hiển thị.')}
        } catch {$issues.Add('GPU: '+$_.Exception.Message)}
    }
    try {
        $d=Get-CimInstance -ClassName Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" -OperationTimeoutSec 3 -ErrorAction Stop
        if ($null -ne $d) {$diskRead=[double]$d.DiskReadBytesPersec;$diskWrite=[double]$d.DiskWriteBytesPersec}
    } catch {$issues.Add('Tốc độ ổ đĩa: '+$_.Exception.Message)}
    [pscustomobject]@{Timestamp=$cpuTimestamp; Completed=[DateTime]::UtcNow; Times=$times; Memory=$memory; Network=$network; NetworkTimestamp=$networkTimestamp; GpuPercent=$gpu; DiskRead=$diskRead; DiskWrite=$diskWrite; Disks=$volumes; ProcessCount=$processCount; Processes=$processes; Issues=@($issues)}
}
function Get-MonitorNetworkRates($Before,$After) {
    if ($null -eq $Before) {return [pscustomobject]@{Received=$null;Sent=$null}}
    $secs=($After.NetworkTimestamp-$Before.NetworkTimestamp).TotalSeconds
    $received=0.0;$sent=0.0;$valid=0
    foreach ($id in $After.Network.Keys) {
        if (-not $Before.Network.ContainsKey($id)) {continue}
        $rx=Get-MonitorRate $Before.Network[$id].Received $After.Network[$id].Received $secs
        $tx=Get-MonitorRate $Before.Network[$id].Sent $After.Network[$id].Sent $secs
        if ($null -ne $rx -and $null -ne $tx) {$received+=$rx;$sent+=$tx;$valid++}
    }
    [pscustomobject]@{Received=if ($valid) {$received} else {$null};Sent=if ($valid) {$sent} else {$null}}
}
