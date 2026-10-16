#Requires -Version 5.1
# Local simulated WPF benchmark. No downloaded code or native Windows writes.
param([string]$Label='before',[ValidateRange(1,10)][int]$Runs=3)
$ErrorActionPreference='Stop'
if ($Label -notmatch '^[a-z0-9-]+$') {throw 'Invalid label'}
$dest=Join-Path $PSScriptRoot ('.audit/performance-'+$Label)
$null=New-Item -ItemType Directory -Path $dest -Force
$quotedRoot=$PSScriptRoot.Replace("'","''")
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'WinTune.ps1'))
$source=$source.Replace('if ($MonitorProbe) {$ReadOnlyProbe=$true}',("`$PSScriptRoot='$quotedRoot'`r`n"+'$script:AuditClock=[Diagnostics.Stopwatch]::StartNew();$script:AuditStages=[ordered]@{}' +"`r`n"+'if ($MonitorProbe) {$ReadOnlyProbe=$true}'))
foreach($marker in @("Add-Type -AssemblyName @('PresentationFramework','PresentationCore','WindowsBase')",'$reader.Close()','Initialize-MonitorUI','if(-not $SelfTest){Initialize-UnifiedTweaksPage}')) {
    $source=$source.Replace($marker,($marker+"`r`n"+'$script:AuditStages['+"'"+$marker.Replace("'","''")+"'"+']=$script:AuditClock.Elapsed.TotalMilliseconds'))
}
$probe=Join-Path $dest 'probe.ps1'
$source=$source.Replace("(Join-Path `$PSScriptRoot 'UI.GuiProbe.ps1')",("'"+$probe.Replace("'","''")+"'"))
$entry=Join-Path $dest 'entry.ps1'
[IO.File]::WriteAllText($entry,$source,[Text.UTF8Encoding]::new($true))
$probeCode=@'
if (-not $script:IsSimulation) {throw 'Benchmark requires simulation'}
$script:AuditOnce=$false
$script:AuditTimer=New-Object Windows.Threading.DispatcherTimer
$script:AuditTimer.Interval=[TimeSpan]::FromSeconds(2)
$script:AuditTimer.Add_Tick({
    $script:AuditTimer.Stop()
    $p=[Diagnostics.Process]::GetCurrentProcess()
    $script:AuditRecord.IdleCpuMs=$p.TotalProcessorTime.TotalMilliseconds-$script:AuditCpu
    $script:AuditRecord.IdleWallMs=$script:AuditIdle.Elapsed.TotalMilliseconds
    $script:AuditRecord.PrivateAfterIdle=$p.PrivateMemorySize64
    $p.Dispose()
    $times=@()
    for($i=0;$i -lt 10;$i++) {$sw=[Diagnostics.Stopwatch]::StartNew();Render-FullTweaks;$times+=$sw.Elapsed.TotalMilliseconds}
    $script:AuditRecord.RenderMs=$times
    $script:AuditRecord.Writes=$script:FullMockWrites+$script:SimWriteCount
    $script:AuditRecord|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $env:WINTUNE_AUDIT_RESULT -Encoding UTF8
    $script:Window.Close()
})
$script:Window.Add_ContentRendered({
    if($script:AuditOnce){return};$script:AuditOnce=$true
    $p=[Diagnostics.Process]::GetCurrentProcess()
    $script:AuditRecord=[ordered]@{Stages=$script:AuditStages;ContentRenderedMs=$script:AuditClock.Elapsed.TotalMilliseconds;WorkingSet=$p.WorkingSet64;Private=$p.PrivateMemorySize64;Handles=$p.HandleCount;Threads=$p.Threads.Count;Cards=@($script:FullWindow.FindName('FullCards').Children|Where-Object {$_ -is [Windows.Controls.Border]}).Count;IdleCpuMs=0;IdleWallMs=0;PrivateAfterIdle=0;RenderMs=@();Writes=-1}
    $script:AuditCpu=$p.TotalProcessorTime.TotalMilliseconds;$p.Dispose()
    $script:AuditIdle=[Diagnostics.Stopwatch]::StartNew();$script:AuditTimer.Start()
})
$null=$script:Window.ShowDialog()
if(-not $script:AuditOnce){throw 'Window did not render'}
'@
[IO.File]::WriteAllText($probe,$probeCode,[Text.UTF8Encoding]::new($true))
$ps=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
for($i=1;$i -le $Runs;$i++) {
    $env:WINTUNE_AUDIT_RESULT=Join-Path $dest ('run-'+$i+'.json')
    $sw=[Diagnostics.Stopwatch]::StartNew()
    & $ps -NoProfile -STA -ExecutionPolicy Bypass -File $entry -GuiProbe -TestDataRoot (Join-Path $dest ('data-'+$i)) 2>&1 | Set-Content (Join-Path $dest ('run-'+$i+'.log')) -Encoding UTF8
    if($LASTEXITCODE -ne 0){throw "Benchmark failed: $i"}
    [pscustomobject]@{Run=$i;ProcessLifetimeMs=$sw.Elapsed.TotalMilliseconds}|ConvertTo-Json|Set-Content (Join-Path $dest ('lifetime-'+$i+'.json')) -Encoding UTF8
}
Remove-Item Env:WINTUNE_AUDIT_RESULT
Write-Output "Benchmark saved: $dest"
