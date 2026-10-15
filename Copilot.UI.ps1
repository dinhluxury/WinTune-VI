function Set-MainActionBusy([bool]$Busy) {
    $script:MainActionBusy=$Busy
    $names=@('FullFeatures','ManageApps','ManageStartup','Software','Cleanup','Repair','Profile','Clear','Refresh','BackupTools','RestoreWindows','Undo')
    if ($Busy) {
        $script:MainActionControls=@{}
        foreach ($name in $names) {$control=$Window.FindName($name);$script:MainActionControls[$name]=$control.IsEnabled;$control.IsEnabled=$false}
    } else {foreach ($name in @($script:MainActionControls.Keys)) {$Window.FindName($name).IsEnabled=$script:MainActionControls[$name]}}
    Render-List;Update-Selection
}
function Complete-MainCopilot([string]$Text,[bool]$ClearSelection=$false) {
    $state=$script:MainActionState
    if ($ClearSelection) {foreach ($id in $state.Ids) {$script:Selected.Remove($id)}}
    $script:MainActionTimer.Stop();$script:MainActionState=$null
    Set-MainActionBusy $false;Refresh-UI
    $Window.FindName('Status').Text=$(if ($script:IsSimulation) {'MÔ PHỎNG — '} else {''})+$Text
}
function Start-MainCopilotReview([string[]]$Ids,[object[]]$RegistryRows) {
    if ($script:MainActionBusy -or $script:PendingBatch -or $script:HistoryError) {throw 'Đợi thao tác đang chạy hoặc xử lý bản sao lưu trước.'}
    if ($null -ne $script:FullJob -and -not $script:FullJob.Process.HasExited) {throw 'Đợi tác vụ tinh chỉnh đang chạy.'}
    $actionRoot=Join-Path $script:DataRoot 'actions'
    $job=Start-ToolJob 'copilotpreview' ([pscustomobject]@{ActionRoot=$actionRoot}) $false
    $script:MainActionState=[pscustomobject]@{Stage='Preview';Ids=@($Ids);RegistryRows=@($RegistryRows);ActionRoot=$actionRoot;Job=$job;RegistryApplied=$false}
    Set-MainActionBusy $true
    $Window.FindName('Status').Text='Đang kiểm tra ứng dụng Copilot của tài khoản hiện tại… Chưa gỡ.'
    $script:MainActionTimer.Start()
}
function Get-MainCopilotPreviewText($State,$AppPreview) {
    $lines=@('XEM TRƯỚC — chưa thay đổi máy.','')
    if ($script:IsSimulation) {$lines+='MÔ PHỎNG — không thay đổi Windows thật.'}
    foreach ($id in $State.Ids) {
        $f=Get-Feature $id;$lines+=($f.Title+"`n"+$f.Benefit+"`nẢnh hưởng: "+$f.Cost)
        if ($id -eq 'copilotapp') {
            $lines+=$AppPreview.Message
            foreach ($row in $AppPreview.Rows) {$lines+=('Gói sẽ gỡ: '+$row.Item.Id);$lines+='Dữ liệu ứng dụng không được sao lưu. Cần cài lại từ Microsoft Store nếu muốn dùng lại.'}
        } else {
            $rows=@($State.RegistryRows | Where-Object Feature -CEQ $id)
            if (-not $rows.Count) {$lines+='Đã có giá trị yêu cầu; không ghi lại.'}
            foreach ($row in $rows) {$c=Assert-Row $row;$old=if ($row.Exists) {[string]$row.Value} else {'chưa có'};$lines+=($c.Hive+'\'+$row.Path+'\'+$row.Name+': '+$old+' → '+$row.Target)}
            $lines+=('Hoàn tác thiết lập: '+$f.Undo)
        };$lines+=''
    }
    $lines+='Gỡ đúng Microsoft.Copilot của tài khoản này. Không tự đóng ứng dụng hoặc khởi động lại. Các thiết lập có bản sao riêng; gỡ app không tự hoàn tác dữ liệu.'
    return ($lines -join "`r`n")
}
function Poll-MainCopilot {
    $state=$script:MainActionState;if ($null -eq $state) {return}
    try {
        $result=Get-ToolJobResult $state.Job;if ($null -eq $result) {return};$state.Job.Handled=$true;$script:MainActionTimer.Stop()
        if ($result.Status -ne 'Completed') {throw $result.Message}
        if ($state.Stage -eq 'Preview') {
            $preview=$result.Result
            if (-not @($preview.Rows).Count -and -not $state.RegistryRows.Count) {Complete-MainCopilot $preview.Message $true;return}
            $text=Get-MainCopilotPreviewText $state $preview
            if (-not (Show-TextDialog 'Xem trước thay đổi' $text $true 'Áp dụng các mục đã chọn')) {Complete-MainCopilot 'Đã hủy. Chưa áp dụng hoặc gỡ ứng dụng.';return}
            if ($state.RegistryRows.Count) {$null=Invoke-ChangePlan $state.RegistryRows;$state.RegistryApplied=$true}
            if (-not @($preview.Rows).Count) {Complete-MainCopilot ('Đã áp dụng thiết lập và lưu bản sao. '+$preview.Message) $true;return}
            $state.Job=Start-ToolJob 'actionsapply' ([pscustomobject]@{ActionRoot=$state.ActionRoot;Rows=@($preview.Rows)}) $true
            $state.Stage='Apply';$Window.FindName('Status').Text='Đang gỡ Microsoft Copilot… Bạn vẫn có thể cuộn và xem thông tin.';$script:MainActionTimer.Start()
        } else {
            $text='Đã gỡ ứng dụng Microsoft Copilot của tài khoản hiện tại và kiểm tra lại. Cài lại từ Microsoft Store nếu cần.'
            if ($state.RegistryApplied) {$text+=' Các thiết lập đã chọn cũng đã áp dụng và lưu bản sao.'}
            Complete-MainCopilot $text $true
        }
    } catch {
        $text='Chưa hoàn tất: '+$_.Exception.Message
        if ($state.RegistryApplied) {$text+=' Các thiết lập trước đó đã áp dụng; có thể dùng Hoàn tác để trả lại. Không tự gỡ tiếp khi có lỗi.'}
        Complete-MainCopilot $text
    }
}
function Initialize-MainCopilot {
    $script:MainActionBusy=$false;$script:MainActionState=$null;$script:MainActionControls=@{}
    $script:MainActionTimer=New-Object Windows.Threading.DispatcherTimer;$script:MainActionTimer.Interval=[TimeSpan]::FromMilliseconds(250);$script:MainActionTimer.Add_Tick({Poll-MainCopilot})
    $Window.Add_Closing({param($sender,$args) if ($script:MainActionBusy) {$args.Cancel=$true;$Window.FindName('Status').Text='Đợi thao tác Copilot hoàn tất trước khi đóng WinTune.'}})
}
