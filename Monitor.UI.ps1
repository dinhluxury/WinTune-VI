# Read-only background runspaces; WPF controls are touched only on the dispatcher.
. (Join-Path $PSScriptRoot 'Monitor.Core.ps1')
$script:MonitorState=[pscustomobject]@{Page='Features';Paused=$false;Suspended=$false;Closing=$false;Hardware=$null;Previous=$null;Samples=0;HardwareJob=$null;SampleJob=$null;DiagnosticsJob=$null;ProcessJob=$null;ProcessTimestamp=$null;ProcessSamples=0;ProcessLastError='';NextProcess=[DateTime]::MinValue;NextSample=[DateTime]::MinValue;History=(New-Object 'Collections.Generic.List[object]');Timer=$null;LastError=''}
function Set-MonitorText([string]$Name,$Text) {$script:Window.FindName($Name).Text=[string]$Text}
function Show-MonitorStorage($Disks) {
    $total=($Disks | Measure-Object Size -Sum).Sum;$free=($Disks | Measure-Object FreeSpace -Sum).Sum
    Set-MonitorText 'StorageSize' $(if ($Disks.Count) {Format-MonitorSize $total} else {'Chưa đọc được'})
    Set-MonitorText 'StorageSpecs' $(if ($Disks.Count) {(Format-MonitorSize ($total-$free))+' đã dùng • '+(Format-MonitorSize $free)+' còn trống'} else {'Chưa đọc được dung lượng ổ'})
}
function New-MonitorJob([ValidateSet('Hardware','Sample','Processes','Diagnostics','RestorePoints','WindowsLogs')][string]$Kind) {
    $ps=[PowerShell]::Create()
    # Only this fixed local script and explicitly registered readers are executed.
    $bootstrap='param($root,$kind,$luid,$simulation) Set-StrictMode -Version Latest; $ErrorActionPreference="Stop"; if ($kind -eq "Diagnostics") { . (Join-Path $root "Tools.Core.ps1"); $script:ToolSimulation=$simulation; $script:ToolMockCimFail=$false; Get-SystemOverview -DiagnosticsOnly } elseif ($kind -eq "WindowsLogs") { . (Join-Path $root "Logs.Core.ps1"); Get-WindowsLogSummary $simulation } elseif ($kind -eq "RestorePoints") { if ($simulation) { [pscustomobject]@{Mode="Simulation";Points=@()} } else { [pscustomobject]@{Mode="Native";Points=@(Get-ComputerRestorePoint -ErrorAction Stop | Select-Object SequenceNumber,Description,CreationTime)} } } else { . (Join-Path $root "Monitor.Core.ps1"); if ($kind -eq "Hardware") { Get-MonitorHardware } elseif ($kind -eq "Processes") { Get-MonitorProcesses } else { Get-MonitorSample $luid -SkipProcesses } }'
    $null=$ps.AddScript($bootstrap).AddArgument($PSScriptRoot).AddArgument($Kind).AddArgument($(if ($null -ne $script:MonitorState.Hardware) {$script:MonitorState.Hardware.GpuLuid} else {''})).AddArgument([bool]$script:IsSimulation)
    try { $handle=$ps.BeginInvoke(); return [pscustomobject]@{PowerShell=$ps;Handle=$handle;Kind=$Kind} } catch {$ps.Dispose();throw}
}
function Receive-MonitorJob($Job) {
    try {
        $result=@($Job.PowerShell.EndInvoke($Job.Handle))
        if ($Job.PowerShell.HadErrors -and $Job.Kind -notin @('Diagnostics','WindowsLogs')) {throw ($Job.PowerShell.Streams.Error | Out-String)}
        if ($result.Count -ne 1) {throw 'Bộ đọc không trả về một kết quả hợp lệ.'}
        return $result[0]
    } finally {$Job.PowerShell.Dispose()}
}
function Show-MonitorHardware($Info) {
    $script:MonitorState.Hardware=$Info
    Set-MonitorText 'CpuName' $Info.CpuName
    Set-MonitorText 'CpuSpecs' $(if ($null -ne $Info.Cores) {"$($Info.Cores) nhân • $($Info.Threads) luồng"} else {'Chưa đọc được cấu hình CPU'})
    Set-MonitorText 'RamSize' (Format-MonitorSize $Info.InstalledBytes)
    $speed=@($Info.MemoryModules | Where-Object ConfiguredClockSpeed -gt 0 | Select-Object -ExpandProperty ConfiguredClockSpeed -Unique)
    Set-MonitorText 'RamSpecs' $(if ($speed.Count) {"Tốc độ báo bởi Windows: $($speed -join ' / ') MHz"} else {'Chưa đọc được tốc độ RAM'})
    Set-MonitorText 'GpuName' $Info.GpuName
    Set-MonitorText 'GpuSize' $(if ($null -ne $Info.GpuBytes -and $Info.GpuBytes -ge 1GB) {('{0:N0} GB VRAM' -f ($Info.GpuBytes/1GB))} elseif ($null -ne $Info.GpuBytes -and $Info.GpuBytes -gt 0) {(Format-MonitorSize $Info.GpuBytes)+' VRAM'} elseif ($null -ne $Info.GpuBytes) {'GPU dùng bộ nhớ chia sẻ'} else {'Chưa đọc được VRAM'})
    $Window.FindName('GpuSize').ToolTip='Windows báo: '+(Format-MonitorSize $Info.GpuBytes)+'. Thẻ làm tròn đến GB; xem chi tiết để đọc dung lượng API báo.'
    Show-MonitorStorage $Info.Disks
    $lines=@("Windows: $($Info.Windows)","Bo mạch chủ: $($Info.Board)","CPU: $($Info.CpuName)","Nhân / luồng: $($Info.Cores) / $($Info.Threads)")
    if ($null -ne $Info.MaxClockMHz) {$lines+="Xung nhịp tối đa do Windows báo: $($Info.MaxClockMHz) MHz (không phải xung nhịp tức thời)"}
    foreach ($m in $Info.MemoryModules) {$lines+="Thanh RAM: $(Format-MonitorSize $m.Capacity) • $($m.Manufacturer) • $(([string]$m.PartNumber).Trim()) • $($m.ConfiguredClockSpeed) MHz"}
    foreach ($g in $Info.Adapters) {$lines+="GPU: $($g.Name) • VRAM riêng: $(Format-MonitorSize $g.DedicatedBytes) • Bộ nhớ chia sẻ tối đa: $(Format-MonitorSize $g.SharedBytes)"}
    foreach ($g in $Info.VideoControllers) {$lines+="Driver GPU: $($g.Name) • $($g.DriverVersion)"}
    foreach ($d in $Info.Disks) {$lines+="Ổ $($d.DeviceID) $($d.VolumeName): $(Format-MonitorSize $d.Size) • Trống $(Format-MonitorSize $d.FreeSpace)"}
    foreach ($d in $Info.DiskHealth) {$lines+="Ổ vật lý: $($d.FriendlyName) • $($d.MediaType) • Trạng thái Windows: $($d.HealthStatus)"}
    if ($Info.Threads -gt 64) {$lines+='Máy có nhiều hơn 64 luồng: bộ đếm CPU chỉ đại diện nhóm bộ xử lý của tiến trình đọc.'}
    if ($Info.Issues.Count) {$lines+='';$lines+='Thông tin chưa đọc được:';$lines+=$Info.Issues}
    Set-MonitorText 'HardwareDetails' ($lines -join "`n")
}
function Update-MonitorChart {
    $history=$script:MonitorState.History
    foreach ($pair in @(@('CpuGraph','Cpu'),@('RamGraph','Ram'))) {
        $line=$Window.FindName($pair[0]);$canvas=$line.Parent
        $w=[Math]::Max(1,$canvas.ActualWidth);$h=[Math]::Max(1,$canvas.ActualHeight)
        $points=New-Object Windows.Media.PointCollection
        if ($history.Count -ge 2) {
            $start=$history[0].Time;$duration=[Math]::Max(120,($history[$history.Count-1].Time-$start).TotalSeconds)
            foreach ($r in $history) {
                $v=$r.($pair[1]);if ($null -eq $v) {continue}
                $points.Add([Windows.Point]::new(($r.Time-$start).TotalSeconds/$duration*$w,($h-($v/100*$h))))
            }
        }
        $line.Points=$points
    }
}
function Show-MonitorProcesses($Sample) {
    $state=$script:MonitorState
    if ($null -ne $state.ProcessTimestamp -and $Sample.Timestamp -le $state.ProcessTimestamp) {return}
    if ($null -eq $Sample.ProcessCount) {throw ($Sample.Issues -join ' ')}
    $list=$Window.FindName('ProcessList');$selectedId=if ($null -ne $list.SelectedItem) {$list.SelectedItem.Id} else {$null}
    $rows=@($Sample.Processes | Sort-Object @{Expression='Bytes';Descending=$true},Id | Select-Object -First 10 | ForEach-Object {[pscustomobject]@{Name=$_.Name;Id=$_.Id;Memory=(Format-MonitorSize $_.Bytes)}})
    $list.ItemsSource=$rows
    if ($null -ne $selectedId) {$list.SelectedItem=$rows | Where-Object Id -eq $selectedId | Select-Object -First 1}
    Set-MonitorText 'ProcessCount' $Sample.ProcessCount
    $state.ProcessTimestamp=$Sample.Timestamp;$state.ProcessSamples++;$state.ProcessLastError=''
    $mode=if ($script:IsSimulation) {'MÔ PHỎNG • '} else {''}
    Set-MonitorText 'ProcessStatus' ($mode+'Tự cập nhật mỗi 2 giây • Lần gần nhất: '+$Sample.Timestamp.ToLocalTime().ToString('HH:mm:ss')+$(if ($Sample.Issues.Count) {' • '+($Sample.Issues -join ' ')} else {''}))
}
function Set-MonitorProcessStatus([string]$Message) {
    $last=if ($null -ne $script:MonitorState.ProcessTimestamp) {' • Mẫu trước: '+$script:MonitorState.ProcessTimestamp.ToLocalTime().ToString('HH:mm:ss')} else {''}
    Set-MonitorText 'ProcessStatus' ($Message+$last)
}
function Show-MonitorSample($Sample) {
    $state=$script:MonitorState
    if ($null -ne $state.Previous -and $Sample.Timestamp -le $state.Previous.Timestamp) {return}
    $cpu=Get-MonitorCpuPercent $(if ($null -ne $state.Previous) {$state.Previous.Times} else {$null}) $Sample.Times
    $ramPercent=$null
    Set-MonitorText 'CpuUsage' $(if ($null -ne $cpu) {"$cpu %"} elseif ($null -eq $Sample.Times) {'Chưa đọc được'} else {'Đang lấy mẫu…'})
    if ($null -ne $Sample.Memory -and $Sample.Memory.Total -gt 0) {
        $used=$Sample.Memory.Total-$Sample.Memory.Available
        $ramPercent=[Math]::Round(100*$used/$Sample.Memory.Total,1)
        Set-MonitorText 'RamUsage' "$ramPercent %"
        Set-MonitorText 'RamUsageDetail' ((Format-MonitorSize $used)+' / '+(Format-MonitorSize $Sample.Memory.Total)+' khả dụng cho Windows')
    } else {Set-MonitorText 'RamUsage' 'Chưa đọc được';Set-MonitorText 'RamUsageDetail' 'Windows chưa cung cấp dữ liệu RAM.'}
    # Legacy/demo samples can include rows. Live sampling uses the independent process reader.
    if ($null -ne $Sample.ProcessCount) {Show-MonitorProcesses $Sample}
    if ($Sample.PSObject.Properties['Disks']) {Show-MonitorStorage $Sample.Disks}
    Set-MonitorText 'GpuUsage' $(if ($null -ne $Sample.GpuPercent) {"$($Sample.GpuPercent) %"} else {'Chưa đọc được'})
    $rates=Get-MonitorNetworkRates $state.Previous $Sample
    Set-MonitorText 'NetworkUsage' $(if ($null -ne $rates.Received) {'↓ '+(Format-MonitorSize $rates.Received)+'/s   ↑ '+(Format-MonitorSize $rates.Sent)+'/s'} else {'Đang lấy mẫu…'})
    Set-MonitorText 'DiskUsage' $(if ($null -ne $Sample.DiskRead) {'Đọc '+(Format-MonitorSize $Sample.DiskRead)+'/s • Ghi '+(Format-MonitorSize $Sample.DiskWrite)+'/s'} else {'Chưa đọc được'})
    $state.History.Add([pscustomobject]@{Time=$Sample.Timestamp;Cpu=$cpu;Ram=$ramPercent})
    while ($state.History.Count -gt 60) {$state.History.RemoveAt(0)}
    $state.Previous=$Sample;$state.Samples++;$state.LastError=''
    Update-MonitorChart
    $time=$Sample.Timestamp.ToLocalTime().ToString('HH:mm:ss')
    $mode=if ($script:IsSimulation) {'MÔ PHỎNG • '} else {''}
    Set-MonitorText 'MonitorStatus' ($mode+"Đã lấy mẫu lúc $time • Chu kỳ mục tiêu 2 giây")
    Set-MonitorText 'MonitorIssues' ($Sample.Issues -join "`n")
}
function Set-MainPage([ValidateSet('Dashboard','Features')][string]$Page) {
    $state=$script:MonitorState;$changed=$state.Page -ne $Page;$state.Page=$Page
    $Window.FindName('DashboardPage').Visibility=if ($Page -eq 'Dashboard') {'Visible'} else {'Collapsed'}
    $Window.FindName('FeaturesPage').Visibility=if ($Page -eq 'Features') {'Visible'} else {'Collapsed'}
    $Window.FindName('FeatureFooter').Visibility=if ($Page -eq 'Features') {'Visible'} else {'Collapsed'}
    $Window.FindName('PageTitle').Text=if ($Page -eq 'Dashboard') {'Tổng quan máy tính'} else {'Tùy chỉnh Windows'}
    Set-ThemeResource ($Window.FindName('Overview')) Background $(if ($Page -eq 'Dashboard') {'Selected'} else {'Button'})
    Set-ThemeResource ($Window.FindName('FeaturesNav')) Background $(if ($Page -eq 'Features') {'Selected'} else {'Button'})
    if ($Page -ne 'Dashboard') {Set-MonitorText 'MonitorStatus' 'Đã tạm dừng khi rời trang tổng quan.'}
    elseif ($changed) {$state.Previous=$null;$state.History.Clear();Update-MonitorChart;$state.NextSample=[DateTime]::MinValue;Set-MonitorText 'MonitorStatus' $(if ($script:IsSimulation) {'MÔ PHỎNG • Không theo dõi máy thật.'} elseif ($state.Paused) {'Đã tạm dừng • Dữ liệu trên màn hình là mẫu trước đó.'} else {'Đang chờ mẫu mới từ Windows…'})}
    if ($changed) {$state.NextProcess=[DateTime]::MinValue}
    if ($Page -ne 'Dashboard' -or $state.Paused) {Set-MonitorProcessStatus 'Đã tạm dừng cập nhật tiến trình.'}
    elseif ($changed) {Set-MonitorProcessStatus $(if ($script:IsSimulation) {'MÔ PHỎNG • Không theo dõi máy thật.'} else {'Đang đọc tiến trình…'})}
}
function Invoke-MonitorTick {
    $state=$script:MonitorState
    Poll-DashboardDiagnostics
    foreach ($slot in @('HardwareJob','SampleJob','ProcessJob')) {
        $job=$state.$slot
        if ($null -eq $job -or -not $job.Handle.IsCompleted) {continue}
        $state.$slot=$null
        try {
            $result=Receive-MonitorJob $job
            if ($state.Closing) {continue}
            if ($slot -eq 'HardwareJob') {Show-MonitorHardware $result}
            elseif ($state.Page -eq 'Dashboard' -and -not $state.Paused -and $Window.IsVisible -and $Window.WindowState -ne 'Minimized') {
                if ($slot -eq 'ProcessJob') {Show-MonitorProcesses $result} elseif (-not $state.Suspended) {Show-MonitorSample $result}
            }
        } catch {
            if ($slot -eq 'ProcessJob') {$state.ProcessLastError=$_.Exception.Message;Set-MonitorProcessStatus ('Không cập nhật được tiến trình: '+$state.ProcessLastError);$state.NextProcess=[DateTime]::UtcNow.AddSeconds(5)}
            else {$state.LastError=$_.Exception.Message;Set-MonitorText 'MonitorStatus' ('Không cập nhật được: '+$state.LastError)}
        }
        if ($slot -eq 'SampleJob') {$state.NextSample=[DateTime]::UtcNow.AddSeconds(2)}
    }
    if ($state.Closing) {
        if ($null -eq $state.HardwareJob -and $null -eq $state.SampleJob -and $null -eq $state.DiagnosticsJob -and $null -eq $state.ProcessJob) {$state.Timer.Stop()}
        return
    }
    if ($state.Page -ne 'Dashboard' -or $state.Paused -or -not $Window.IsVisible -or $Window.WindowState -eq 'Minimized') {$state.Suspended=$true;Set-MonitorProcessStatus 'Đã tạm dừng cập nhật tiến trình.';return}
    if ($state.Suspended) {$state.Suspended=$false;$state.Previous=$null;$state.History.Clear();Update-MonitorChart;$state.NextSample=[DateTime]::MinValue;Set-MonitorText 'MonitorStatus' 'Đang chờ mẫu mới từ Windows…'}
    if ($script:IsSimulation) {return} # Demo fixtures are explicit; never labelled live.
    if ($null -eq $state.ProcessJob -and [DateTime]::UtcNow -ge $state.NextProcess) {
        try {$state.ProcessJob=New-MonitorJob 'Processes';$state.NextProcess=[DateTime]::UtcNow.AddSeconds(2)} catch {$state.NextProcess=[DateTime]::UtcNow.AddSeconds(5);$state.ProcessLastError=$_.Exception.Message;Set-MonitorProcessStatus ('Không đọc được tiến trình: '+$state.ProcessLastError)}
    }
    if ($null -eq $state.Hardware -and $null -eq $state.HardwareJob) {
        try {$state.HardwareJob=New-MonitorJob 'Hardware'} catch {Set-MonitorText 'MonitorStatus' $_.Exception.Message}
    }
    if ($null -eq $state.SampleJob -and [DateTime]::UtcNow -ge $state.NextSample) {
        try {$state.SampleJob=New-MonitorJob 'Sample'} catch {$state.NextSample=[DateTime]::UtcNow.AddSeconds(5);Set-MonitorText 'MonitorStatus' $_.Exception.Message}
    }
    if ($null -ne $state.Previous -and ([DateTime]::UtcNow-$state.Previous.Timestamp).TotalSeconds -gt 10) {Set-MonitorText 'MonitorStatus' 'Mẫu đã cũ hơn 10 giây; đang chờ bộ đọc Windows.'}
    if ($null -ne $state.ProcessTimestamp -and ([DateTime]::UtcNow-$state.ProcessTimestamp).TotalSeconds -gt 10 -and -not $state.ProcessLastError) {Set-MonitorProcessStatus 'Dữ liệu tiến trình đã cũ hơn 10 giây; đang chờ bộ đọc.'}
}
function Stop-Monitor {
    $state=$script:MonitorState;$state.Closing=$true
    if ($null -ne $state.Timer) {$state.Timer.Stop()}
    foreach ($slot in @('HardwareJob','SampleJob','ProcessJob','DiagnosticsJob')) {
        $job=$state.$slot
        if ($null -eq $job) {continue}
        # Called after ShowDialog returns: background readers cannot block WPF.
        try {$job.PowerShell.Stop()} catch { }
        $job.PowerShell.Dispose();$state.$slot=$null
    }
}
function Initialize-MonitorUI {
    $Window.FindName('DashboardDiagnostics').Add_Click({Start-DashboardDiagnostics})
    $Window.Add_SizeChanged({$Window.FindName('HardwareCards').Columns=if ($Window.ActualWidth -ge 1250) {4} else {2}})
    $Window.FindName('Overview').Add_Click({Set-MainPage 'Dashboard'})
    $Window.FindName('FeaturesNav').Add_Click({Set-MainPage 'Features'})
    # The process table shows ten rows inside the page scroll viewer. Let the
    # outer page scroll when the pointer is over the rows instead of swallowing it.
    $Window.FindName('ProcessList').Add_PreviewMouseWheel({param($sender,$eventArgs)
        $outer=$script:Window.FindName('DashboardPage')
        $lines=[Windows.SystemParameters]::WheelScrollLines
        $step=if ($lines -lt 0) {$outer.ViewportHeight} else {[Math]::Max(1,$lines)*16}
        $outer.ScrollToVerticalOffset($outer.VerticalOffset-($eventArgs.Delta/120.0)*$step)
        $eventArgs.Handled=$true
    })
    $Window.FindName('MonitorPause').Add_Click({
        $state=$script:MonitorState;$state.Paused=-not $state.Paused
        $Window.FindName('MonitorPause').Content=if ($state.Paused) {'Tiếp tục theo dõi'} else {'Tạm dừng'}
        $state.Previous=$null;$state.History.Clear();Update-MonitorChart;$state.NextSample=[DateTime]::MinValue
        $state.NextProcess=[DateTime]::MinValue
        Set-MonitorProcessStatus $(if ($state.Paused) {'Đã tạm dừng cập nhật tiến trình.'} elseif ($script:IsSimulation) {'MÔ PHỎNG • Không theo dõi máy thật.'} else {'Đang đọc tiến trình…'})
        if ($state.Paused) {Set-MonitorText 'MonitorStatus' 'Đã tạm dừng • Dữ liệu trên màn hình là mẫu trước đó.'}
        else {Set-MonitorText 'MonitorStatus' $(if ($script:IsSimulation) {'MÔ PHỎNG • Không theo dõi máy thật.'} else {'Đang chờ mẫu mới từ Windows…'})}
    })
    $Window.FindName('HardwareRefresh').Add_Click({
        if ($script:IsSimulation) {return}
        try {if ($null -eq $script:MonitorState.HardwareJob) {$script:MonitorState.HardwareJob=New-MonitorJob 'Hardware'}} catch {Set-MonitorText 'MonitorStatus' $_.Exception.Message}
    })
    $Window.FindName('CpuCanvas').Add_SizeChanged({Update-MonitorChart})
    $Window.FindName('RamCanvas').Add_SizeChanged({Update-MonitorChart})
    $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(300)
    $timer.Add_Tick({Invoke-MonitorTick});$script:MonitorState.Timer=$timer
    $Window.Add_Closed({$script:MonitorState.Closing=$true;$script:MonitorState.Timer.Stop()})
    if (-not $SelfTest -and (-not $GuiProbe -or $MonitorProbe)) {
        if (-not $script:IsSimulation) {Initialize-MonitorNative;$timer.Start()}
        else {Set-MonitorText 'MonitorStatus' 'MÔ PHỎNG • Trang theo dõi không đọc hoặc thay đổi Windows.'}
        Set-MainPage 'Dashboard'
    }
}
