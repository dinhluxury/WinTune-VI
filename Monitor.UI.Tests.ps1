# Dashboard tests use explicit fixtures; never display mock readings as live data.
$monitorWritesBefore=$SimWriteCount
$fixture=[pscustomobject]@{CpuName='CPU thử nghiệm (mô phỏng)';Cores=6;Threads=12;MaxClockMHz=4000;InstalledBytes=32GB;Memory=$null;MemoryModules=@([pscustomobject]@{Capacity=32GB;ConfiguredClockSpeed=3200;Manufacturer='Mô phỏng';PartNumber='TEST'});Board='Bo mạch mô phỏng';Windows='Windows thử nghiệm';GpuName='GPU mô phỏng';GpuLuid='luid_0x00000000_0x12345678';GpuBytes=8GB;Adapters=@();VideoControllers=@();Disks=@([pscustomobject]@{DeviceID='C:';VolumeName='Mô phỏng';Size=1000GB;FreeSpace=600GB});DiskHealth=@();Issues=@();Timestamp=[DateTime]::UtcNow}
Show-MonitorHardware $fixture
Assert-UI ($Window.FindName('HardwareDetails').Parent -is [Windows.Controls.StackPanel] -and $Window.FindName('HardwareDetails').Visibility -eq 'Visible' -and $Window.FindName('HardwareDetails').TextWrapping -eq 'Wrap') 'Hardware details are always displayed without an expander and wrap long lines'
Set-MainPage 'Dashboard'
Assert-UI ($Window.FindName('DashboardPage').Visibility -eq 'Visible' -and $Window.FindName('FeatureFooter').Visibility -eq 'Collapsed') 'Dashboard navigation hides apply controls without discarding selections'
Assert-UI ($Window.FindName('GpuSize').Text.Contains('8') -and $Window.FindName('HardwareDetails').Text.Contains('không phải xung nhịp tức thời')) 'Hardware details preserve true capacity and explain reported CPU clock'
$now=[DateTime]::UtcNow
$sample=[pscustomobject]@{Timestamp=$now;Completed=$now;Times=[pscustomobject]@{Idle=100;Kernel=200;User=100};Memory=[pscustomobject]@{Total=32GB;Available=16GB};Network=@{};NetworkTimestamp=$now;GpuPercent=$null;DiskRead=$null;DiskWrite=$null;ProcessCount=5;Processes=@([pscustomobject]@{Name='Tiến trình mô phỏng';Id=999;Bytes=100MB});Issues=@('Bộ đếm GPU mô phỏng không khả dụng')}
Show-MonitorSample $sample
Assert-UI ($Window.FindName('CpuUsage').Text -eq 'Đang lấy mẫu…' -and $Window.FindName('GpuUsage').Text -eq 'Chưa đọc được') 'Unknown CPU/GPU are not shown as zero'
Assert-UI ($Window.FindName('MonitorStatus').Text.Contains('MÔ PHỎNG') -and $Window.FindName('RamUsage').Text -eq '50 %') 'Demo data is explicitly marked and RAM uses real arithmetic'
$second=$sample.PSObject.Copy();$second.Timestamp=$now.AddSeconds(2);$second.NetworkTimestamp=$second.Timestamp;$second.Times=[pscustomobject]@{Idle=140;Kernel=270;User=130}
Show-MonitorSample $second
Assert-UI ($Window.FindName('CpuUsage').Text -eq '60 %' -and $Window.FindName('ProcessList').Items.Count -eq 1) 'Subsequent sample updates CPU and process rows'
Show-MonitorSample $sample
Assert-UI ($MonitorState.Samples -eq 2) 'Older asynchronous samples cannot overwrite newer values'
$Window.FindName('MonitorPause').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI ($MonitorState.Paused -and $Window.FindName('MonitorStatus').Text.Contains('Đã tạm dừng')) 'Pause visibly marks retained readings as paused'
$Window.FindName('MonitorPause').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
Assert-UI (-not $MonitorState.Paused -and $null -eq $MonitorState.Previous) 'Resume resets counter baseline'
Assert-UI (-not $Window.FindName('MonitorStatus').Text.Contains('Đã tạm dừng') -and $Window.FindName('MonitorStatus').Text.Contains('MÔ PHỎNG')) 'Resume caption no longer claims paused or genuine live readings in demo'
foreach ($size in @(@(1280,860),@(1024,650),@(900,560))) {
    $Window.Width=$size[0];$Window.Height=$size[1]
    $Window.FindName('HardwareCards').Columns=if ($size[0] -ge 1250) {4} else {2}
    $Window.Content.Measure([Windows.Size]::new($size[0]-16,$size[1]-40));$Window.Content.Arrange([Windows.Rect]::new(0,0,$size[0]-16,$size[1]-40));$Window.Content.UpdateLayout()
    Update-MonitorChart
    Assert-UI ($Window.FindName('CpuCanvas').ActualWidth -gt 160 -and $Window.FindName('DashboardPage').ActualHeight -gt 200) "Dashboard responsive layout at $($size[0])x$($size[1])"
    foreach ($scale in @(1.0,1.25,1.5)) {
        $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap ([int](($size[0]-16)*$scale)),([int](($size[1]-40)*$scale)),(96*$scale),(96*$scale),([Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($Window.Content);$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $stream=[IO.File]::Create((Join-Path $PSScriptRoot "evidence/dashboard-$($size[0])x$($size[1])-$([int]($scale*100)).png"))
        try {$encoder.Save($stream)} finally {$stream.Dispose()}
    }
}
# Render the actual always-visible card separately, using the explicitly labelled fixture above.
$hardwareCard=$Window.FindName('HardwareDetails').Parent.Parent
# Render a serialization of the real card without the dashboard viewport's off-screen clipping.
$hardwareVisual=[Windows.Markup.XamlReader]::Parse([Windows.Markup.XamlWriter]::Save($hardwareCard));$hardwareVisual.Resources=$Window.Resources
[Windows.Documents.TextElement]::SetForeground($hardwareVisual,$Window.Foreground);[Windows.Documents.TextElement]::SetFontSize($hardwareVisual,$Window.FontSize);[Windows.Documents.TextElement]::SetFontFamily($hardwareVisual,$Window.FontFamily)
$hardwareVisual.Width=850;$hardwareVisual.Measure([Windows.Size]::new(850,[double]::PositiveInfinity));$hardwareVisual.Arrange([Windows.Rect]::new(0,0,850,$hardwareVisual.DesiredSize.Height));$hardwareVisual.UpdateLayout()
$hardwareBitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap 850,([int][Math]::Ceiling($hardwareVisual.ActualHeight)),96,96,([Windows.Media.PixelFormats]::Pbgra32)
$hardwareBitmap.Render($hardwareVisual);$hardwareEncoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$hardwareEncoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($hardwareBitmap))
$hardwareStream=[IO.File]::Create((Join-Path $PSScriptRoot 'evidence/hardware-details-visible.png'));try {$hardwareEncoder.Save($hardwareStream)} finally {$hardwareStream.Dispose()}
# Use the production asynchronous job wrapper with a mocked reader that sleeps
# in its own runspace. No system reader or mutator is invoked here.
$ps=[PowerShell]::Create();$null=$ps.AddScript('Start-Sleep -Milliseconds 1500; [pscustomobject]@{Completed=$true}')
$job=[pscustomobject]@{PowerShell=$ps;Handle=$ps.BeginInvoke();Kind='Sample'}
$ticks=0;$deadline=[DateTime]::UtcNow.AddSeconds(6)
while (-not $job.Handle.IsCompleted -and [DateTime]::UtcNow -lt $deadline) {
    $frame=New-Object Windows.Threading.DispatcherFrame;$pump=New-Object Windows.Threading.DispatcherTimer;$pump.Interval=[TimeSpan]::FromMilliseconds(50);$pump.Tag=$frame
    $pump.Add_Tick({param($sender,$args) $sender.Stop();$sender.Tag.Continue=$false});$pump.Start();[Windows.Threading.Dispatcher]::PushFrame($frame);$ticks++
}
$received=Receive-MonitorJob $job
Assert-UI ($received.Completed -and $ticks -gt 5) 'Asynchronous monitor reader keeps WPF dispatcher responsive and disposes the reader'
# Production dispatcher polling with independent mocked jobs: the GPU/disk
# sample remains blocked while a fresh process sample reaches the table.
$Window.Show();$MonitorState.Suspended=$false
$slow=[PowerShell]::Create();$null=$slow.AddScript('Start-Sleep -Seconds 4; [pscustomobject]@{Unused=$true}')
$MonitorState.SampleJob=[pscustomobject]@{PowerShell=$slow;Handle=$slow.BeginInvoke();Kind='Sample'}
$fast=[PowerShell]::Create();$null=$fast.AddScript('param($t) Start-Sleep -Milliseconds 100; [pscustomobject]@{Timestamp=$t;ProcessCount=2;Processes=@([pscustomobject]@{Name="New process";Id=8;Bytes=300MB},[pscustomobject]@{Name="Retained process";Id=9;Bytes=100MB});Issues=@()}').AddArgument($now.AddSeconds(4))
$MonitorState.ProcessJob=[pscustomobject]@{PowerShell=$fast;Handle=$fast.BeginInvoke();Kind='Processes'}
$deadline=[DateTime]::UtcNow.AddSeconds(2)
while ($null -ne $MonitorState.ProcessJob -and [DateTime]::UtcNow -lt $deadline) {
    $frame=New-Object Windows.Threading.DispatcherFrame;$pump=New-Object Windows.Threading.DispatcherTimer;$pump.Interval=[TimeSpan]::FromMilliseconds(50);$pump.Tag=$frame
    $pump.Add_Tick({param($sender,$eventArgs) $sender.Stop();$sender.Tag.Continue=$false});$pump.Start();[Windows.Threading.Dispatcher]::PushFrame($frame);Invoke-MonitorTick
}
Assert-UI ($Window.FindName('ProcessList').Items[0].Id -eq 8 -and -not $MonitorState.SampleJob.Handle.IsCompleted -and $null -eq $MonitorState.ProcessJob) 'Fresh process rows appear independently while slow GPU/disk sample is still running'
Assert-UI ($Window.FindName('ProcessStatus').Text.Contains('2 giây') -and $Window.FindName('ProcessStatus').Text.Contains('MÔ PHỎNG')) 'Table explains its refresh interval and labels fixture readings honestly'
$slow.Stop();$slow.Dispose();$MonitorState.SampleJob=$null
$Window.FindName('ProcessList').SelectedIndex=1
$processNext=[pscustomobject]@{Timestamp=$now.AddSeconds(6);ProcessCount=2;Processes=@([pscustomobject]@{Name='Retained process';Id=9;Bytes=500MB},[pscustomobject]@{Name='Newest process';Id=10;Bytes=400MB});Issues=@()}
Show-MonitorProcesses $processNext
Assert-UI ($Window.FindName('ProcessList').Items[0].Id -eq 9 -and $Window.FindName('ProcessList').Items[0].Memory -eq '500 MB' -and 8 -notin $Window.FindName('ProcessList').Items.Id) 'RAM changes reorder rows and exited processes disappear on the next sample'
Assert-UI ($Window.FindName('ProcessList').SelectedItem.Id -eq 9 -and $Window.FindName('ProcessCount').Text -eq '2') 'Live refresh retains selected PID and updates total process count'
$processCountBefore=$MonitorState.ProcessSamples;Show-MonitorProcesses $second
Assert-UI ($MonitorState.ProcessSamples -eq $processCountBefore -and $Window.FindName('ProcessList').Items[0].Id -eq 9) 'Older process sample cannot replace fresh rows'
$failed=$false;try {Show-MonitorProcesses ([pscustomobject]@{Timestamp=$now.AddSeconds(8);ProcessCount=$null;Processes=@();Issues=@('Fixture failure')})} catch {$failed=$true}
Assert-UI ($failed -and $Window.FindName('ProcessList').Items.Count -eq 2) 'Process failure preserves last rows for a clearly marked stale/error status'
$Window.FindName('MonitorPause').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));Invoke-MonitorTick
Assert-UI ($Window.FindName('ProcessStatus').Text.Contains('Đã tạm dừng') -and $null -eq $MonitorState.ProcessJob) 'Pause marks the process table as paused and starts no reader'
$Window.FindName('MonitorPause').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
$Window.Hide()
$Selected['ads']=$true;Set-MainPage 'Features'
Assert-UI ($MonitorState.Page -eq 'Features' -and $Selected.ContainsKey('ads') -and $Window.FindName('DashboardPage').Visibility -eq 'Collapsed') 'Leaving dashboard suspends sampling and retains pending feature selection'
$Selected.Clear();Render-List
Assert-UI ($SimWriteCount -eq $monitorWritesBefore -and $null -eq $MonitorState.SampleJob -and $null -eq $MonitorState.ProcessJob) 'Dashboard tests perform no simulated or native system write'
