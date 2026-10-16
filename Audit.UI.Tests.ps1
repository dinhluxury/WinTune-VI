# Loaded by WinTune -SelfTest. Real WPF and isolated Simulation workers only.
$auditSavedRoot=$script:DataRoot;$auditSavedToolRoot=$script:ToolRoot
$auditSelfTest=$SelfTest
$script:DataRoot=Join-Path $PSScriptRoot ('.test-runs/audit-ui-'+[guid]::NewGuid().ToString('N').Substring(0,8))
Initialize-Tools (Join-Path $script:DataRoot 'tools') $true $script:UserId
$script:ToolJob=$null
$auditWindow=New-ManagementWindow Appx
$script:SelfTest=$false
try {
    Refresh-Management
    Assert-UI ($ManagerState.ReadOperation -eq 'actionsread' -and -not $auditWindow.FindName('Reload').IsEnabled) 'Inventory refresh queues a worker and returns before completion'
    Stop-ManagementRead
    $fakeProcess=[pscustomobject]@{HasExited=$false}
    $fakeProcess|Add-Member ScriptMethod Kill {throw 'Injected refusal'}
    $fakeProcess|Add-Member ScriptMethod Dispose {}
    $script:ToolJob=[pscustomobject]@{Id='actionsread';Process=$fakeProcess;Handled=$false;Started=Get-Date}
    $ManagerState.ReadOperation='actionsread';$stopFailed=$false
    try {Stop-ManagementRead} catch {$stopFailed=$true}
    Assert-UI ($stopFailed -and $ManagerState.ReadOperation -eq 'actionsread' -and -not $ToolJob.Handled) 'Failed reader cancellation retains its safe retry classification'
    $auditWindow.Show();$auditWindow.Close()
    Assert-UI ($auditWindow.IsVisible -and $ManagerState.ReadOperation -eq 'actionsread') 'Window Close catches reader cancellation failure and remains usable'
    $fakeProcess.HasExited=$true;Stop-ManagementRead
    Assert-UI ($null -eq $ToolJob -and -not $ManagerState.ReadOperation) 'Reader that exited during cancellation still releases its state'
    $null=Start-ToolJob actionsread ([pscustomobject]@{ActionRoot=$ActionRoot;Kind='Appx';MockDelayMs=1200}) $false
    $ManagerState.ReadOperation='actionsread';Start-ManagementPolling
    $script:AuditTicks=0;$tick=New-Object Windows.Threading.DispatcherTimer;$tick.Interval=[TimeSpan]::FromMilliseconds(50)
    $tick.Add_Tick({$script:AuditTicks++});$tick.Start()
    $deadline=[DateTime]::UtcNow.AddSeconds(15)
    while($ManagerState.ReadOperation -and [DateTime]::UtcNow -lt $deadline){
        $frame=New-Object Windows.Threading.DispatcherFrame
        $pump=New-Object Windows.Threading.DispatcherTimer;$pump.Interval=[TimeSpan]::FromMilliseconds(40);$pump.Tag=$frame
        $pump.Add_Tick({param($sender,$args) $sender.Stop();$sender.Tag.Continue=$false});$pump.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
    }
    $tick.Stop()
    Assert-UI (-not $ManagerState.ReadOperation -and $ManagerState.Inventory.Count -eq 30 -and $AuditTicks -gt 8) 'Delayed app inventory leaves dispatcher responsive and returns all fixture apps'
    Assert-UI ($ToolJob.Handled -and -not $ManagerState.Timer.IsEnabled) 'Finished inventory releases process and stops polling'
    $id=$ManagerState.Inventory[0].Id;$ManagerState.Selected[$id]=$true
    $script:DialogResponse=$false;Invoke-ManagementReview
    $deadline=[DateTime]::UtcNow.AddSeconds(15)
    while($ManagerState.ReadOperation -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 40;Poll-ManagementJob}
    Assert-UI ($LastDialogText.Contains($id) -and @(Get-ActionJournals).Count -eq 0) 'Async preview cancellation never removes an app or creates a mutation journal'
    $null=Start-ToolJob wingetcheck ([pscustomobject]@{SourceAgreed=$false}) $false
    Start-ManagementPolling
    $null=$ToolJob.Process.WaitForExit(15000)
    $auditWindow.Close()
    Assert-UI (-not $ToolJob.Handled -and $ManagerState.Timer.IsEnabled) 'Window cannot close between worker exit and result handling'
    Poll-ManagementJob
    $auditWindow.Close()
    Assert-UI (-not $ManagerState.Timer.IsEnabled -and -not $ManagerState.ReadOperation) 'Closing during inventory refresh cancels only reader and stops its timer'
    $script:ToolJob=$null
} finally {
    if ($ManagerState.ReadOperation) {Stop-ManagementRead}
    $auditWindow.Close();$script:ManagerState=$null;$script:ManagementWindow=$null
    $script:SelfTest=$auditSelfTest;$script:DataRoot=$auditSavedRoot
    Initialize-Tools $auditSavedToolRoot $true $script:UserId;$script:ToolJob=$null
}
