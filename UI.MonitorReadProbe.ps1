# Production WPF dashboard + production asynchronous readers, with writes blocked.
if (-not $script:WriteBlocked -or $script:IsSimulation) {throw 'Live dashboard audit requires native readers and blocked writes.'}
$script:MonitorProbeRecord=$null
$script:MonitorProbeStart=[DateTime]::UtcNow
$script:ProcessProbeSamples=New-Object 'Collections.Generic.List[object]'
$script:LastProcessProbeCount=0
$probeTimer=New-Object Windows.Threading.DispatcherTimer;$probeTimer.Interval=[TimeSpan]::FromMilliseconds(400)
$probeTimer.Add_Tick({
    if ($LastProcessProbeCount -lt $MonitorState.ProcessSamples) {$ProcessProbeSamples.Add([pscustomobject]@{Timestamp=$MonitorState.ProcessTimestamp;Number=$MonitorState.ProcessSamples;Rows=@($Window.FindName('ProcessList').Items | Select-Object Name,Id,Memory);Status=$Window.FindName('ProcessStatus').Text});$script:LastProcessProbeCount=$MonitorState.ProcessSamples}
    $ready=$null -ne $MonitorState.Hardware -and $MonitorState.Samples -ge 3 -and $MonitorState.ProcessSamples -ge 3 -and $Window.FindName('ProcessList').Items.Count -gt 0 -and -not $MonitorState.ProcessLastError
    if (-not $ready -and ([DateTime]::UtcNow-$script:MonitorProbeStart).TotalSeconds -lt 45) {return}
    $probeTimer.Stop()
    $Window.Content.UpdateLayout()
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap ([int]$Window.Content.ActualWidth),([int]$Window.Content.ActualHeight),96,96,([Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($Window.Content);$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $PSScriptRoot 'evidence/dashboard-native.png'))
    try {$encoder.Save($stream)} finally {$stream.Dispose()}
    $Window.FindName('ProcessList').BringIntoView();$Window.Content.UpdateLayout()
    $processBitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap ([int]$Window.Content.ActualWidth),([int]$Window.Content.ActualHeight),96,96,([Windows.Media.PixelFormats]::Pbgra32)
    $processBitmap.Render($Window.Content);$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($processBitmap))
    $stream=[IO.File]::Create((Join-Path $PSScriptRoot 'evidence/dashboard-process-live.png'));try {$encoder.Save($stream)} finally {$stream.Dispose()}
    $script:MonitorProbeRecord=[pscustomobject]@{Ready=$ready;Visible=$Window.IsVisible;Page=$MonitorState.Page;Samples=$MonitorState.Samples;Cpu=$Window.FindName('CpuUsage').Text;Ram=$Window.FindName('RamUsage').Text;Gpu=$Window.FindName('GpuUsage').Text;CpuName=$Window.FindName('CpuName').Text;GpuSize=$Window.FindName('GpuSize').Text;Status=$Window.FindName('MonitorStatus').Text;Selected=$Selected.Count;RealWritesBlocked=$WriteBlocked;SystemWrites=$SimWriteCount;ElapsedSeconds=([DateTime]::UtcNow-$script:MonitorProbeStart).TotalSeconds;Error=$MonitorState.LastError;Scope='Native WPF rendering and asynchronous read-only sampling; not external desktop interaction.'}
    $script:MonitorProbeRecord | Add-Member -NotePropertyName ProcessSamples -NotePropertyValue ($ProcessProbeSamples.ToArray())
    $script:MonitorProbeRecord | Add-Member -NotePropertyName ProcessError -NotePropertyValue $MonitorState.ProcessLastError
    $script:MonitorProbeRecord | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "$PSScriptRoot/evidence/monitor-ui-read-only.json" -Encoding UTF8
    $Window.Close()
})
$probeTimer.Start();$null=$Window.ShowDialog();$probeTimer.Stop()
if ($null -eq $script:MonitorProbeRecord -or -not $script:MonitorProbeRecord.Ready -or $SimWriteCount -ne 0 -or $Selected.Count -ne 0) {throw 'Live WPF dashboard audit did not complete; see evidence/monitor-ui-read-only.json.'}
Write-Output "LIVE WPF MONITOR PASSED: $($MonitorProbeRecord.Samples) asynchronous samples; visible dashboard; writes blocked; $($MonitorProbeRecord.CpuName); CPU $($MonitorProbeRecord.Cpu); RAM $($MonitorProbeRecord.Ram)."
